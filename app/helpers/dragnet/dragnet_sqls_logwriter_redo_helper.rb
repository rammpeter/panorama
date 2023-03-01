# encoding: utf-8
module Dragnet::DragnetSqlsLogwriterRedoHelper

  private

  def dragnet_sqls_logwriter_redo
    [
        {
            :name  => t(:dragnet_helper_74_name, :default=>'Write access by executions (current SGA)'),
            :desc  => t(:dragnet_helper_74_desc, :default=>'Delays during log buffer write by log writer lead to „log file sync“ wait events, especially during commit.
Writing operations (Insert/Update/Delete) which cannot write into log buffer during „log file sync“ lead to „log buffer space“ wait events.
Requests for block transfer in RAC environment lead to „gc buffer busy“ wait events, if requested blocks in delivering RAC-instance are affected by simultaneous „log buffer space“ or „log file sync“ events.
The likelihood of „log buffer space“ events depends on frequency of writing operations. This selection determines heavy frequented write SQLs as candidates for deeper consideration.
Solution can be the aggregation of multiple writes (bulk-processing).'),
            :sql=>  "SELECT /* DB-Tools Ramm: Schreibende Zugriffe nach Executes */
                         Inst_ID, SQL_ID, Parsing_Schema_Name, Executions, Rows_Processed, ROUND(Rows_Processed/Executions,2) \"Rows per Exec\",
                         ROUND(Elapsed_Time/1000000) Elapsed_Time_Secs, SQL_Text
                  FROM   GV$SQLArea
                  WHERE  Command_Type IN (2,6,7)
                  AND    Executions > 0
                  AND    Rows_Processed > ?
                  ORDER BY Executions DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_74_param_1_name, :default=>'Minimum number of written rows'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_74_param_1_hint, :default=>'Minimum number of written rows for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_75_name, :default=>'Write access by executions (AWR history)'),
            :desc  => t(:dragnet_helper_75_desc, :default=>'Delays during log buffer write by log writer lead to „log file sync“ wait events, especially during commit.
Writing operations (Insert/Update/Delete) which cannot write into log buffer during „log file sync“ lead to „log buffer space“ wait events.
Requests for block transfer in RAC environment lead to „gc buffer busy“ wait events, if requested blocks in delivering RAC-instance are affected by simultaneous „log buffer space“ or „log file sync“ events.
The likelihood of „log buffer space“ events depends on frequency of writing operations. This selection determines heavy frequented write SQLs as candidates for deeper consideration.
Solution can be the aggregation of multiple writes (bulk-processing).'),
            :sql=>  "SELECT /* DB-Tools Ramm: Schreibende Zugriffe nach Executes */
                         s.Instance_Number, s.SQL_ID, s.Executions, s.Rows_Processed,
                         ROUND(s.Rows_Processed/s.Executions,2) \"Rows per Exec\", t.SQL_Text, TO_CHAR(SUBSTR(t.SQL_Text,1,100))
                  FROM   (
                          SELECT s.DBID, s.Instance_Number, s.SQL_ID, SUM(s.Executions_Delta) Executions, SUM(s.Rows_Processed_Delta) Rows_Processed
                          FROM   DBA_Hist_SQLStat s
                          JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                          WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                          GROUP BY s.DBID, s.Instance_Number, s.SQL_ID
                          HAVING  SUM(s.Executions_Delta) > 0
                         ) s
                  JOIN   DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                  WHERE  t.Command_Type IN (2,6,7)
                  AND    s.Rows_Processed > ?
                  ORDER BY Executions DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_75_param_2_name, :default=>'Minimum number of written rows'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_75_param_2_hint, :default=>'Minimum number of written rows for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_119_name, :default=>'Commit / Rollback - Emergence'),
            :desc  => t(:dragnet_helper_119_desc, :default=>'From the amount of commit and rollback operations one can conclude to possibly problematic application behaviour'),
            :sql=>  "SELECT /* DB-Tools Ramm Commits und Rollbacks in gegebenen Zeitraum */ Begin, Instance_Number, User_Commits, User_Rollbacks,
                         ROUND(User_Rollbacks/(DECODE(User_Commits+User_Rollbacks, 0, 1, User_Commits+User_Rollbacks))*100) Percent_Rollback,
                         Rollback_Changes
                  FROM   (
                          SELECT ROUND(Begin_Interval_Time, 'MI') Begin, Instance_Number,
                                 SUM(DECODE(Stat_Name, 'user commits', Value, 0)) User_Commits,
                                 SUM(DECODE(Stat_Name, 'user rollbacks', Value, 0)) User_Rollbacks,
                                 SUM(DECODE(Stat_Name, 'rollback changes - undo records applied', Value, 0)) Rollback_Changes
                          FROM   (
                                  SELECT snap.Begin_Interval_Time, st.Instance_Number, st.Stat_Name,
                                         Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY st.Snap_ID) Value
                                  FROM   (SELECT DBID, Instance_Number, Min(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                                          FROM   DBA_Hist_Snapshot ss
                                          WHERE  Begin_Interval_Time >= SYSDATE-?
                                          AND    Instance_Number = ?
                                          GROUP BY DBID, Instance_Number
                                         ) ss
                                  JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                                  JOIN   DBA_Hist_Snapshot snap ON snap.DBID=ss.DBID AND snap.Instance_Number=ss.Instance_Number AND snap.Snap_ID=st.Snap_ID
                                  WHERE  st.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorg‰nger des ersten mit auswerten f∏r Differenz per LAG */
                                  AND    Stat_Name IN ('user rollbacks', 'user commits', 'rollback changes - undo records applied')
                                 )
                          WHERE Value > 0
                          GROUP BY ROUND(Begin_Interval_Time, 'MI'), Instance_Number
                         )
                  ORDER BY 1",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}]
        },
        {
            :name  => t(:dragnet_helper_120_name, :default=>'Adjustment of recovery behaviour'),
            :desc  => t(:dragnet_helper_120_desc, :default=>'The target for recovery times (fast_start_mttr_target) influences strongly the I/O-behaviour of your database.
Short targets for recovery and therefore more aggressive DB-writer my lead to:
- many small asychroneous write requests are executed instead of instead of less requests with more blocks per request (normally until 3000 DB-blocks per async. write request)
- maximum limit of OS for simultaneous async. write requests is reached and I/O is considerably slowed down due to that
'),
            :sql=> 'SELECT /*+ DB-Tools Ramm MTTR-Historie */ r.Instance_Number, ss.Begin_Interval_Time, target_mttr, estimated_mttr, optimal_logfile_size, CKPT_BLOCK_WRITES
                  FROM   dba_hist_instance_recovery r
                  JOIN   DBA_Hist_Snapshot ss ON ss.DBID = r.DBID AND ss.Instance_Number = r.Instance_Number AND ss.Snap_ID = r.Snap_ID
                  WHERE  r.Instance_Number = ?
                  AND    ss.Begin_Interval_Time > SYSDATE-?
                  ORDER BY ss.Begin_Interval_Time',
            :parameter=>[
                {:name=> 'Instance-Number', :size=>8, :default=>1, :title=> 'RAC-Instance-Number'},
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
    ]
  end


end