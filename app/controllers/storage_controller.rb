# encoding: utf-8
class StorageController < ApplicationController


  # Groesse und Füllung der Tabelspaces
  def tablespace_usage
    @tablespaces = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
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
            SELECT /* Panorama-Tool Ramm */
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
             #{ if get_db_version >= "11.2"
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


    @fra_size_bytes = sql_select_one("SELECT Value FROM v$Parameter WHERE Name='db_recovery_file_dest_size'").to_i
    #@flashback_log = sql_select_first_row "SELECT * FROM v$Flashback_Database_Log"
    @fra_usage = sql_select_all "SELECT * FROM v$Flash_Recovery_Area_Usage WHERE Percent_Space_Used > 0 ORDER BY Percent_Space_Used DESC"

    totals = {}
    total_sum = {"contents"=>"TOTAL", "mbtotal"=>0, "mbfree"=>0, "mbused"=>0}
    total_sum.extend SelectHashHelper
    @tablespaces.each do |t|
      unless totals[t.contents]
        totals[t.contents] = {"mbtotal"=>0, "mbfree"=>0, "mbused"=>0}
      end
      totals[t.contents]["mbtotal"] += t.mbtotal
      totals[t.contents]["mbfree"]  += t.mbfree
      totals[t.contents]["mbused"] += t.mbused
      total_sum["mbtotal"] += t.mbtotal
      total_sum["mbfree"]  += t.mbfree
      total_sum["mbused"]  += t.mbused
    end

    if @fra_size_bytes > 0
      totals['Fast Recovery Area'] = {}
      totals['Fast Recovery Area']['mbtotal'] = @fra_size_bytes / (1024*1024).to_i
      totals['Fast Recovery Area']['mbused'] = 0
      @fra_usage.each do |f|
        totals['Fast Recovery Area']['mbused'] += f.percent_space_used*@fra_size_bytes/(1024*1024)/100
      end
      totals['Fast Recovery Area']['mbfree'] = totals['Fast Recovery Area']['mbtotal'] - totals['Fast Recovery Area']['mbused']

      total_sum["mbtotal"] += totals['Fast Recovery Area']['mbtotal']
      total_sum["mbfree"]  += totals['Fast Recovery Area']['mbfree']
      total_sum["mbused"]  += totals['Fast Recovery Area']['mbused']
    end

    @totals = []
    totals.each do |key, value|
      value["contents"] = key
      value.extend SelectHashHelper
      @totals << value
    end
    @totals << total_sum

    schemas = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */ Owner Schema, Type Segment_Type, SUM(Bytes)/1048576 MBytes
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

    # Menge der verwendeten Typen ermitteln
    @schema_segment_types = {}
    schemas.each do |s|
      @schema_segment_types[s.segment_type] = 0 unless @schema_segment_types[s.segment_type]                         # Type als genutzt markieren
      @schema_segment_types[s.segment_type] = @schema_segment_types[s.segment_type] + s.mbytes
    end



    temp_schemas = {}
    schemas.each do |s|
      temp_schemas[s.schema] = {} unless temp_schemas[s.schema]                             # Neuer Record wenn noch nicht existiert
      temp_schemas[s.schema][s.segment_type] = 0 unless temp_schemas[s.schema][s.segment_type]  # Initialisierung
      temp_schemas[s.schema][s.segment_type] = temp_schemas[s.schema][s.segment_type] + s.mbytes
    end

    @schemas = []
    temp_schemas.each do |key, value|
      new_rec = {'schema' => key, 'total_mbytes' => 0}

      @schema_segment_types.each do |type, dummy|
        new_rec[type] = value[type]
        new_rec['total_mbytes'] = new_rec['total_mbytes'] + value[type] if value[type]
      end

      new_rec.extend SelectHashHelper
      @schemas << new_rec
    end


    @segments = sql_select_all "SELECT /* Panorama-Tool Ramm */ Segment_Type,
                                       SUM(Bytes)/1048576   MBytes
                                FROM  (SELECT s.Bytes,
                                              s.Segment_Type || DECODE(i.Index_Type, 'IOT - TOP', ' IOT-PKey', '') Segment_Type
                                       FROM   DBA_Segments s
                                       LEFT OUTER JOIN DBA_Indexes i ON i.Owner = s.Owner AND i.Index_Name=s.Segment_Name
                                      )
                                GROUP BY Segment_Type
                                ORDER BY 2 DESC"


    render_partial
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

    global_name = sql_select_one 'SELECT Name FROM v$Database'

    @mvs = sql_select_iterator ["\
      SELECT m.Owner,
             m.Name,
             m.MView_Site,
             m.Can_use_Log,
             m.Updatable,
             m.Refresh_Method,
             m.MView_ID,
             m.Version,
             l.Snapshot_Logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.Name AND m.MView_Site = '#{global_name}') MBytes, /* Result nur wenn registered MView auf lokaler DB */
             t.Num_Rows, t.Last_Analyzed,
             mv.Master_Link
      FROM   sys.dba_registered_mviews m
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = m.MView_ID
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.Name AND m.MView_Site = '#{global_name}'     /* Table nur Joinen wenn registered MView auf lokaler DB */
      LEFT OUTER JOIN DBA_MViews mv ON mv.Owner = m.Owner AND mv.MView_Name = m.Name AND m.MView_Site = '#{global_name}'  /* Table nur Joinen wenn registered MView auf lokaler DB */
      WHERE 1=1 #{where_string}
    "].concat where_values

    render_partial :list_registered_materialized_views
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

    global_name = sql_select_one 'SELECT Name FROM v$Database'

    @mvs = sql_select_iterator ["\
      SELECT m.*, DECODE(r.Name, NULL, 'N', 'Y') Registered, r.MView_ID,
             l.Snapshot_logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.MView_Name) MBytes,
             t.Num_Rows, t.Last_Analyzed,
             s.Table_Name, s.Master_view, s.Master_Owner, s.Master, s.Can_Use_Log,
             s.Refresh_Method Fast_Refresh_Method, s.Error, s.fr_operations, s.cr_operations, s.Refresh_Group,
             s.Status content_status
      FROM   dba_MViews m
      LEFT OUTER JOIN DBA_Snapshots s ON s.Owner = m.Owner AND s.Name = m.MView_Name
      /* Lokal Registrierte MViews auf gleicher DB */
      LEFT OUTER JOIN DBA_Registered_MViews r ON r.Owner = m.Owner AND r.Name = m.MView_Name AND r.MView_Site='#{global_name}'
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = r.MView_ID
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.MView_Name
      WHERE  1=1 #{where_string}
      ORDER BY m.MView_Name
    "].concat where_values

    render_partial  :list_all_materialized_views
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

    @logs = sql_select_iterator ["\
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
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = l.Log_Owner AND t.Table_Name = l.Log_Table
      WHERE 1=1 #{where_string}
      "].concat where_values

    render_partial  :list_materialized_view_logs
  end


  # Anzeige der n:m zwischen MV und MV-Log
  def list_snapshot_logs
    where_string = ""
    where_values = []
    @grid_caption = ""

    if params[:snapshot_id]
      where_string << " AND l.Snapshot_ID = ?"
      where_values << params[:snapshot_id]
      @grid_caption << " Snapshot-ID='#{params[:snapshot_id]}'"
    end

    if params[:log_owner]
      where_string << " AND l.Log_Owner = ?"
      where_values << params[:log_owner]
      @grid_caption << " Log-Owner='#{params[:log_owner]}'"
    end

    if params[:log_table]
      where_string << " AND l.Log_Table = ?"
      where_values << params[:log_table]
      @grid_caption << " Log-Table='#{params[:log_table]}'"
    end

    @snaps = sql_select_iterator ["\
      SELECT l.*, l.object_id contains_object_id,
             m.Owner mv_Owner, m.Name MV_Name, m.MView_Site
      FROM   DBA_Snapshot_Logs l
      LEFT OUTER JOIN DBA_Registered_MViews m ON m.MView_ID = l.Snapshot_ID
      WHERE  1=1 #{where_string}
      "].concat where_values

    render_partial :list_snapshot_logs
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

  # Nutzung von Datafiles
  def datafile_usage
    @datafiles = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
             d.*,
             NVL(f.BYTES,0)/1048576            MBFree,
             (d.BYTES-NVL(f.BYTES,0))/1048576  MBUsed,
             d.BYTES/1048576                   FileSize,
             (d.Bytes-NVL(f.Bytes,0))/d.BYTES  PctUsed,
             MaxBytes/1048576                  MaxMB,
             Increment_By/1048576              Increment_ByMB
      FROM   (SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, MaxBytes, Increment_By, Online_Status
              FROM   DBA_Data_Files
              UNION ALL
              SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, MaxBytes, Increment_By, '[UNKNOWN]' Online_Status
              FROM   DBA_Temp_Files
             )d
      LEFT JOIN (SELECT File_ID, Tablespace_Name, SUM(Bytes) Bytes
                 FROM   DBA_FREE_SPACE
                 GROUP BY File_ID, Tablespace_Name
                ) f ON f.FILE_ID = d.FILE_ID AND f.Tablespace_Name = d.Tablespace_Name -- DATA und Temp verwenden File_ID redundant
      ORDER BY 1 ASC")

    if get_db_version >= "11.2"
      @file_usage = sql_select_iterator "\
        SELECT f.*,
               NVL(d.File_Name, t.File_Name) File_Name,
               NVL(d.Tablespace_Name, t.Tablespace_Name) Tablespace_Name
        FROM   gv$IOStat_File f
        LEFT JOIN DBA_Data_Files d ON d.File_ID = f.File_No AND f.FileType_Name='Data File'   -- DATA und Temp verwenden File_ID redundant
        LEFT JOIN DBA_Temp_Files t ON t.File_ID = f.File_No AND f.FileType_Name='Temp File'
        ORDER BY f.Inst_ID, f.File_No
      "
    end

    render_partial
  end

  # Nutzung von Undo-Segmenten
  def undo_usage
    @undo_tablespaces = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
             Owner, Tablespace_Name,
             SUM(Bytes)/(1024*1024) Size_MB,
             SUM(DECODE(Status, 'UNEXPIRED', Bytes, 0))/(1024*1024) Size_MB_UnExpired,
             SUM(DECODE(Status, 'EXPIRED',   Bytes, 0))/(1024*1024) Size_MB_Expired,
             SUM(DECODE(Status, 'ACTIVE',    Bytes, 0))/(1024*1024) Size_MB_Active,
             (SELECT Inst_ID FROM gv$Parameter p WHERE Name='undo_tablespace' AND p.Value = e.Tablespace_Name) Inst_ID
      FROM   DBA_UNDO_Extents e
      GROUP BY Owner, Tablespace_Name
      ORDER BY SUM(Bytes) DESC")

    @undo_segments = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */ i.*, t.Transactions, r.Segment_ID,
             (SELECT Inst_ID FROM gv$Parameter p WHERE Name='undo_tablespace' AND p.Value = i.Tablespace_Name) Inst_ID
      FROM   (SELECT
                     Owner, Segment_Name, Tablespace_Name,
                     SUM(Bytes)/(1024*1024) Size_MB,
                     SUM(DECODE(Status, 'UNEXPIRED', Bytes, 0))/(1024*1024) Size_MB_UnExpired,
                     SUM(DECODE(Status, 'EXPIRED',   Bytes, 0))/(1024*1024) Size_MB_Expired,
                     SUM(DECODE(Status, 'ACTIVE',    Bytes, 0))/(1024*1024) Size_MB_Active
              FROM   DBA_UNDO_Extents e
              GROUP BY Owner, Segment_Name, Tablespace_Name
            ) i
      LEFT OUTER JOIN DBA_Rollback_Segs r ON r.Segment_Name = i.Segment_Name
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ XidUsn, COUNT(*) Transactions FROM gv$Transaction GROUP BY XidUsn) t ON t.XidUsn = r.Segment_ID
      ORDER BY Size_MB DESC")

    render_partial
  end

  def list_undo_history
    save_session_time_selection
    @instance = prepare_param_instance
    @instance = nil if @instance == ''

    @undo_history = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             Begin_Time, End_Time, Instance_Number, UndoBlks, TxnCount, MaxQueryLen, MaxQuerySQLID,
             MaxConcurrency, UnxpStealCnt, UnxpBlkRelCnt, UnxpBlkReuCnt, ExpStealCnt, ExpBlkRelCnt, ExpBlkReuCnt,
             SSOldErrCnt, NoSpaceErrCnt, ActiveBlks, UnexpiredBlks, ExpiredBlks, Tuned_UndoRetention
      FROM   DBA_Hist_UndoStat
      WHERE  Begin_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      #{'AND Instance_Number = ?' if @instance}
      ORDER BY Begin_Time
      ", @time_selection_start, @time_selection_end].concat(@instance ? [@instance] : [])

    render_partial
  end

  def list_undo_transactions
    @segment_id = params[:segment_id]
    @segment_id = nil if @segment_id == ''

    @undo_transactions = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             s.Inst_ID, s.SID, s.Serial# SerialNo, s.UserName, s.Program, s.Status, s.OSUser, s.Client_Info, s.Module, s.Action,
             t.Start_Time, t.Recursive, t.Used_Ublk Used_Undo_Blocks, t.Used_URec Used_Undo_Records, t.Log_IO, t.Phy_IO, RawToHex(t.XID) XID,
             t.XIDUSN Segment, t.XIDSLOT Slot, t.XIDSQN Sequence, t.CR_get, t.CR_Change
      FROM   v$Transaction t
      JOIN   gv$Session s ON s.TAddr = t.Addr
      #{'WHERE  t.XIDUsn = ?' if @segment_id}
      ORDER BY t.Used_Ublk DESC
      "].concat(@segment_id ? [@segment_id] : [])

    render_partial
  end

  def temp_usage
    @sort_segs = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */ s.*,
               t.Block_Size
        FROM   gv$Sort_Segment s
        JOIN   DBA_Tablespaces t ON t.Tablespace_Name = s.Tablespace_Name"

    @temp_ts_size = sql_select_one "\
        SELECT SUM(Size_MB) Size_MB
        FROM   (
                SELECT /* Panorama-Tool Ramm */  SUM(d.Bytes)/1048576 Size_MB
                FROM DBA_Data_Files d
                WHERE d.Tablespace_Name IN (SELECT Tablespace_Name FROM gv$Sort_Segment)
                UNION ALL
                SELECT /* Panorama-Tool Ramm */  SUM(d.Bytes)/1048576 Size_MB
                FROM DBA_Temp_Files d
                WHERE d.Tablespace_Name IN (SELECT Tablespace_Name FROM gv$Sort_Segment)
               )
        "


    @data = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */ t.INST_ID,
        s.SID,
        s.Serial# SerialNo,
        s.UserName,
        s.Status,
        s.OSUser,
        s.Process,
        s.Machine,
        s.Program,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        t.Tablespace,
        t.SegType,
        t.Extents,
        t.Blocks
        FROM GV$TempSeg_Usage t,
             gv$session s
        WHERE s.Inst_ID = t.Inst_ID
        AND   s.SAddr = t.Session_Addr"

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"storage/temp_usage" }');"}
    end
  end


end

