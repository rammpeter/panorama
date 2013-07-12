# encoding: utf-8
class StorageController < ApplicationController


  # Groesse und Füllung der Tabelspaces
  def tablespace_usage
    @tablespaces = sql_select_all("\
      SELECT /* NOA-Tools Ramm */
             t.TableSpace_Name,
             t.contents,
             t.Block_Size                   BlockSize,
             f.FileSize                     MBTotal,
             NVL(free.MBFree,0)             MBFree,
             f.FileSize-NVL(free.MBFree,0)  MBUsed,
             (f.FileSize-NVL(free.MBFree,0))/f.FileSize*100 PctUsed,
             t.Allocation_Type,
             t.Segment_Space_Management,
             f.AutoExtensible
      FROM  DBA_Tablespaces t
      LEFT OUTER JOIN
            (
            SELECT /* NOA-Tools Ramm */
                   f.TABLESPACE_NAME,
                   Sum(f.BYTES)/1048576     MBFree
            FROM   DBA_FREE_SPACE f
            GROUP BY f.TABLESPACE_NAME
            ) free ON free.Tablespace_Name = t.Tablespace_Name
      LEFT OUTER JOIN
            (
            SELECT d.TableSpace_Name, SUM(d.Bytes)/1048576 FileSize,
                   CASE WHEN COUNT(DISTINCT AutoExtensible)> 1 THEN 'Partial' ELSE MIN(AutoExtensible) END AutoExtensible
            FROM   DBA_Data_Files d
            GROUP BY d.Tablespace_Name
            ) f ON f.Tablespace_Name = t.TableSpace_Name
      WHERE Contents != 'TEMPORARY'
      UNION ALL
      SELECT f.Tablespace_Name,
             t.Contents,
             t.Block_Size                   BlockSize,
             NVL(f.MBTotal,0)               MBTotal,
             NVL(f.MBTotal,0)-NVL(s.Used_Blocks,0)*t.Block_Size/1048576 MBFree,
             NVL(s.Used_Blocks,0)*t.Block_Size/1048576 MBUsed,
             (NVL(s.Used_Blocks,0)*t.Block_Size/1048576)/NVL(f.MBTotal,0)*100 PctUsed,
             t.Allocation_Type,
             t.Segment_Space_Management,
             f.AutoExtensible
      FROM  DBA_Tablespaces t
      LEFT OUTER JOIN (SELECT Tablespace_Name, SUM(Bytes)/1048576 MBTotal, SUM(Bytes)/SUM(Blocks) BlockSize,
                              CASE WHEN COUNT(DISTINCT AutoExtensible)> 1 THEN 'Partial' ELSE MIN(AutoExtensible) END AutoExtensible
                       FROM DBA_Temp_Files
                       GROUP BY Tablespace_Name
                      ) f ON f.Tablespace_Name = t.TableSpace_Name
      LEFT OUTER JOIN (SELECT Tablespace_Name, SUM(Total_Blocks) Used_Blocks
                       FROM   GV$Sort_Segment
                       GROUP BY Tablespace_Name
                      ) s ON s.Tablespace_Name = t.TableSpace_Name
      WHERE t.Contents = 'TEMPORARY'
      UNION ALL
      SELECT 'Redo Inst='||Inst_ID           Tablespace_Name,
             'Redo-Logfile'             Contents,
             #{ if session[:database].version >= "11.2"
                  "MIN(BlockSize)"
                else
                  0
                end
             }                          BlockSize,
             SUM(Bytes*Members)/1048576 MBTotal,
             0                          MBFree,
             SUM(Bytes*Members)/1048576 MBUsed,
             100                        PctUsed,
             NULL                       Allocation_Type,
             NULL                       Segment_Space_Management,
             NULL                       AutoExtensible
      FROM   gv$Log
      GROUP BY Inst_ID
      ORDER BY 4 DESC NULLS LAST
      ")

    totals = {}
    @tablespaces.each do |t|
      unless totals[t.contents]
        totals[t.contents] = {"mbtotal"=>0, "mbfree"=>0, "mbused"=>0}
      end
      totals[t.contents]["mbtotal"] += t.mbtotal
      totals[t.contents]["mbfree"]  += t.mbfree
      totals[t.contents]["mbused"] += t.mbused
    end
    @totals = []
    totals.each do |key, value|
      value["contents"] = key
      value.extend SelectHashHelper
      @totals << value
    end

    @schemas = sql_select_all("\
      SELECT /* NOA-Tools Ramm */ Owner Schema, Type Segment_Type, SUM(Bytes)/1048576 MBytes
      FROM (
        SELECT s.Owner,
               DECODE(s.Segment_Type,
                      'INDEX PARTITION', 'Index',
                      'INDEX SUBPARTITION', 'Index',
                      'INDEX'          , 'Index',
                      'TABLE'          , 'Table',
                      'NESTED TABLE'   , 'Table',
                      'TABLE PARTITION', 'Table',
                      'TABLE SUBPARTITION', 'Table',
                      'LOBSEGMENT'     , 'Table',
                      'LOB PARTITION'  , 'Table',
                      'LOBINDEX'       , 'Index',
                      Segment_Type)||
               DECODE(i.Index_Type, 'IOT - TOP', ' IOT-PKey', '') Type,
               s.Bytes
        FROM   DBA_Segments s
        LEFT OUTER JOIN DBA_Indexes i ON i.Owner = s.Owner AND i.Index_Name=s.Segment_Name
        )
      GROUP BY Owner, Type
      HAVING SUM(Bytes) > 1048576 -- nur > 1 MB selektieren
      ORDER BY 3 DESC")

    @segments = sql_select_all "SELECT /* NOA-Tools Ramm */ Segment_Type,
                                       SUM(Bytes)/1048576   MBytes
                                FROM  (SELECT s.Bytes,
                                              s.Segment_Type || DECODE(i.Index_Type, 'IOT - TOP', ' IOT-PKey', '') Segment_Type
                                       FROM   DBA_Segments s
                                       LEFT OUTER JOIN DBA_Indexes i ON i.Owner = s.Owner AND i.Index_Name=s.Segment_Name
                                      )
                                GROUP BY Segment_Type
                                ORDER BY 2 DESC"


    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "storage/tablespace_usage" }');"}
    end
  end


  # Einsprung aus show_materialzed_views
  def list_materialized_view_action
    case
      when params[:registered_mviews]      then list_registered_materialized_views
      when params[:all_mviews]             then list_all_materialized_views
      when params[:mview_logs]             then list_materialized_view_logs
      else
        raise "params missing for :mview or :mview_logs"
    end
  end

  def list_registered_materialized_views
    where_string = ""
    where_values = []

    if params[:snapshot_id]
      where_string << " AND m.MView_ID = ?"
      where_values << params[:snapshot_id]
    end

    @mvs = sql_select_all ["\
      SELECT m.Owner,
             m.Name,
             m.MView_Site,
             m.Can_use_Log,
             m.Updatable,
             m.Refresh_Method,
             m.MView_ID,
             m.Version,
             l.Snapshot_Logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.Name) MBytes,
             t.Num_Rows, t.Last_Analyzed,
             mv.Master_Link
      FROM   sys.dba_registered_mviews m
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = m.MView_ID
      LEFT OUTER JOIN All_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.Name
      LEFT OUTER JOIN DBA_MViews mv ON mv.Owner = m.Owner AND mv.MView_Name = m.Name
      WHERE 1=1 #{where_string}
    "].concat where_values

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_registered_materialized_views"}');"}
    end
  end

  def list_all_materialized_views
    where_string = ""
    where_values = []

    if params[:owner]
      where_string << " AND m.Owner = ?"
      where_values << params[:owner]
    end

    if params[:name]
      where_string << " AND m.MView_Name = ?"
      where_values << params[:name]
    end

    @mvs = sql_select_all ["\
      SELECT m.*, DECODE(r.Name, NULL, 'N', 'Y') Registered, r.MView_ID,
             l.Snapshot_logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.MView_Name) MBytes,
             t.Num_Rows, t.Last_Analyzed,
             s.Table_Name, s.Master_view, s.Master_Owner, s.Master, s.Can_Use_Log,
             s.Refresh_Method Fast_Refresh_Method, s.Error, s.fr_operations, s.cr_operations, s.Refresh_Group,
             s.Status content_status
      FROM   dba_MViews m
      LEFT OUTER JOIN DBA_Snapshots s ON s.Owner = m.Owner AND s.Name = m.MView_Name
      LEFT OUTER JOIN DBA_Registered_MViews r ON r.Owner = m.Owner AND r.Name = m.MView_Name
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = r.MView_ID
      LEFT OUTER JOIN All_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.MView_Name
      WHERE  1=1 #{where_string}
      ORDER BY m.MView_Name
    "].concat where_values

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_all_materialized_views"}');"}
    end
  end

  def list_materialized_view_logs
    where_string = ""
    where_values = []

    if params[:log_owner]
      where_string << " AND l.Log_Owner = ?"
      where_values << params[:log_owner]
    end

    if params[:log_name]
      where_string << " AND l.Log_Table = ?"
      where_values << params[:log_name]
    end

    @logs = sql_select_all ["\
      SELECT l.*, l.Object_ID Has_Object_ID,
             sl.Snapshot_count, sl.Oldest_Refresh_Date,
             t.Num_rows, t.Last_Analyzed,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=l.Log_Owner AND seg.Segment_Name=l.log_Table) MBytes
      FROM   DBA_MView_Logs l
      LEFT OUTER JOIN   (SELECT Log_Owner, Log_Table, COUNT(*) Snapshot_Count, MIN(Current_Snapshots) Oldest_Refresh_Date
                         FROM   DBA_Snapshot_Logs
                         WHERE  Snapshot_ID IS NOT NULL -- hat wirklich registrierte Snapshots
                         GROUP BY Log_Owner, Log_Table
                        ) sl ON sl.Log_Owner = l.Log_Owner AND sl.Log_Table = l.Log_Table
      LEFT OUTER JOIN All_Tables t ON t.Owner = l.Log_Owner AND t.Table_Name = l.Log_Table
      WHERE 1=1 #{where_string}
      "].concat where_values

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_materialized_view_logs"}');"}
    end
  end


  # Anzeige der n:m zwischen MV und MV-Log
  def list_snapshot_logs
    where_string = ""
    where_values = []

    if params[:snapshot_id]
      where_string << " AND l.Snapshot_ID = ?"
      where_values << params[:snapshot_id]
    end

    if params[:log_owner]
      where_string << " AND l.Log_Owner = ?"
      where_values << params[:log_owner]
    end

    if params[:log_table]
      where_string << " AND l.Log_Table = ?"
      where_values << params[:log_table]
    end

    @snaps = sql_select_all ["\
      SELECT l.*, l.object_id contains_object_id,
             m.Owner mv_Owner, m.Name MV_Name, m.MView_Site
      FROM   DBA_Snapshot_Logs l
      LEFT OUTER JOIN DBA_Registered_MViews m ON m.MView_ID = l.Snapshot_ID
      WHERE  1=1 #{where_string}
      "].concat where_values

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_snapshot_logs"}');"}
    end
  end

  def list_registered_mview_query_text
    @mview_id = params[:mview_id]

    text = sql_select_one ["\
      SELECT m.query_txt
      FROM   sys.dba_registered_mviews m
      WHERE  MView_ID = ?
      ", @mview_id]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j "<pre>#{my_html_escape text}</pre>"}');"}
    end
  end

  def list_mview_query_text
    text = sql_select_one ["\
      SELECT m.query
      FROM   sys.dba_mviews m
      WHERE  Owner      = ?
      AND    MView_Name = ?
      ", params[:owner], params[:name]]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j "<pre>#{my_html_escape text}</pre>"}');"}
    end
  end

  # Ermittlung und Anzeige der realen Größe
  def list_real_num_rows
    num_rows = sql_select_one ["\
      SELECT /*+ PARALLEL_INDEX(l,2) */ COUNT(*)
      FROM   #{params[:owner]}.#{params[:name]}"]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j "real: #{fn num_rows}"}');"}
    end
  end

end

