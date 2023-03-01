# encoding: utf-8
module Dragnet::MaterializedViewsHelper

  private

  def materialized_views
    [
        {
            :name  => t(:dragnet_helper_149_name, :default=>'Orphaned materialized view logs'),
            :desc  => t(:dragnet_helper_149_desc, :default=>"\
Materialized view logs may grow unlimited under several conditions:
1. There is no materialized view registered at this MV-log that consumes the recorded changes
2. There is one ore more materialized view registered which does not consume the recorded changes by executing MV-refresh
3. There are only fragments remaining from MV registration in DBA_Snapshot_Logs (sys.slog$) but no registered MV in DBA_Registered_MViews (sys.reg_snap$)

Depending on the reason there are several solutions to fix this issue:
1. Drop the useless MV-log by issuing DROP MATERIALIZED VIEW LOG ON <master table>
2. Unregister the not responding MV by calling DMBS_MVIEW.UNREGISTER_MVIEW
3. Remove the orphaned snaphot log by issuing DBMS_MVIEW.Purge_Log or DELETE FROM sys.slog$ WHERE SnapID = x

DBMS_MVIEW.Purge_Log removes the MV Log-Records of the oldest (regarding last refresh) registered MViews und decouples the registered MView from the MV-Log.
So no MV Log records are kept for this MView in the future until next complete refresh restores complete registration at MV log.
"),
            :sql=> "\
SELECT l.Log_Owner, l.Master Master_Table, l.Log_Table, t.Tablespace_Name, t.Num_Rows, s.MBytes, l.Snapshot_ID, l.Current_Snapshots Last_Refresh,
       m.Owner MV_Owner, m.Name MV_Name, m.MView_Site
FROM   DBA_Snapshot_Logs l
LEFT OUTER JOIN DBA_MView_Logs ml       ON ml.Log_Owner = l.Log_Owner AND ml.Log_Table = l.Log_Table
LEFT OUTER JOIN DBA_Tables t            ON t.Owner = l.Log_Owner AND t.Table_Name = l.Log_Table
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(Bytes)/(1024*1024), 1) MBytes
                 FROM   DBA_Segments
                 GROUP BY Owner, Segment_Name
                ) s ON s.Owner = l.Log_Owner AND s.Segment_Name = l.Log_Table
LEFT OUTER JOIN DBA_Registered_MViews m ON m.MView_ID = l.Snapshot_ID
WHERE  m.MView_ID IS NULL OR l.Current_Snapshots < SYSDATE - ?
ORDER BY s.MBytes DESC, t.Num_Rows DESC
            ",
            :parameter=>[{:name=>t(:dragnet_helper_149_param_1_name, :default=>'Minimum days since last refresh'), :size=>8, :default=>50, :title=>t(:dragnet_helper_149_param_1_hint, :default=>'Minimum number of days since the last MV refresh (if registered MV exists)')}
            ]
        },
        {
            :name  => t(:dragnet_helper_150_name, :default=>'Registered materialized views without relation to MV-log'),
            :desc  => t(:dragnet_helper_150_desc, :default=>"\
Registered materialized views with Can_Use_Log != 'NO' should have a relation to one or more materialized view logs via DBA_Snapshot_Logs, espeacially if they are fast refreshable.
Missing of this relation can be a hint for orphaned registrations of MVs.

Possible solutions to fix this issue is deregistration of MV by calling DMBS_MVIEW.UNREGISTER_MVIEW
"),
            :sql=> "\
SELECT m.Owner, m.Name MView_Name, m.MView_Site, m.Can_Use_Log, m.Updatable, m.Refresh_Method, m.MView_ID, m.Version ,
       mv.Master_Link, mv.Refresh_Mode, mv.Refresh_Method Refresh_Method_MV, mv.Compile_State
FROM DBA_Registered_MViews m
LEFT OUTER JOIN DBA_Snapshot_Logs sl ON sl.Snapshot_ID = m.MView_ID
LEFT OUTER JOIN DBA_MViews mv        ON mv.Owner = m.Owner AND mv.MView_Name = m.Name AND m.MView_Site = (SELECT Name FROM v$Database)
WHERE Can_Use_Log != 'NO'
AND   sl.Snapshot_ID IS NULL    /* No Snapshot Log exists */
            ",
        },
    ]
  end # sqls_potential_db_structures


end
