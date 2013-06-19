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
             l.Snapshot_Logs,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.Name) MBytes
      FROM   sys.dba_registered_mviews m
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = m.MView_ID
    "]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_registered_materialized_views"}');"}
    end
  end

  def list_all_materialized_views
    @mvs = sql_select_all ["\
      SELECT m.*, DECODE(r.Name, NULL, 'N', 'Y') Registered,
             l.Snapshot_logs,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.MView_Name) MBytes
      FROM   dba_MViews m
      LEFT OUTER JOIN DBA_Snapshots s ON s.Owner = m.Owner AND s.Name = m.MView_Name
      LEFT OUTER JOIN DBA_Registered_MViews r ON r.Owner = m.Owner AND r.Name = m.MView_Name
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = r.MView_ID
    "]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_all_materialized_views"}');"}
    end
  end

  def list_materialized_view_logs
    @logs = sql_select_all ["\
      SELECT l.*, sl.Snapshot_count, sl.Oldest_Snapshot_date,
             t.Num_rows, t.Last_Analyzed,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=l.Log_Owner AND seg.Segment_Name=l.log_Table) MBytes
      FROM   DBA_MView_Logs l
      LEFT OUTER JOIN   (SELECT Log_Owner, Log_Table, COUNT(*) Snapshot_Count, MIN(Current_Snapshots) Oldest_Snapshot_date
                         FROM   DBA_Snapshot_Logs
                         WHERE  Snapshot_ID IS NOT NULL -- hat wirklich registrierte Snapshots
                         GROUP BY Log_Owner, Log_Table
                        ) sl ON sl.Log_Owner = l.Log_Owner AND sl.Log_Table = l.Log_Table
      LEFT OUTER JOIN All_Tables t ON t.Owner = l.Log_Owner AND t.Table_Name = l.Log_Table
      "]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_materialized_view_logs"}');"}
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

