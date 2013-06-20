# encoding: utf-8
class StorageController < ApplicationController

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
             t.Num_Rows, t.Last_Analyzed
      FROM   sys.dba_registered_mviews m
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = m.MView_ID
      LEFT OUTER JOIN All_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.Name
    "]

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
      SELECT l.*, sl.Snapshot_count, sl.Oldest_Refresh_Date,
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
    @snapshot_id = params[:snapshot_id]

    @snaps = sql_select_all ["\
      SELECT *
      FROM   DBA_Snapshot_Logs
      WHERE  Snapshot_ID = ?
      ", @snapshot_id]

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

