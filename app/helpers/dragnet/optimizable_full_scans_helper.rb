# encoding: utf-8
module Dragnet::OptimizableFullScansHelper

  private

  def optimizable_full_scans
    [
        {
            :name  => t(:dragnet_helper_70_name, :default=>'Optimizable index full scan operations'),
            :desc  => t(:dragnet_helper_70_desc, :default=>'Index full scan operations on large indexes often may be successfully switched to parallel direct path read per index fast full, if sort order of result does not matter.
If optimizer does not decide to do so himself, you can use hints /*+ PARALLEL_INDEX(Alias, Degree) INDEX_FFS(Alias) */.
'),
            :sql=> "SELECT /* DB-Tools Ramm IndexFullScan */ * FROM (
                      SELECT p.SQL_ID, s.Parsing_Schema_Name, p.Object_Owner, p.Object_Name,
                             (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name
                             ) Num_Rows_Index, s.Instance_Number,
                             (SELECT MAX(Begin_Interval_Time) FROM DBA_Hist_SnapShot ss
                              WHERE ss.DBID=p.DBID AND ss.Snap_ID=s.MaxSnapID AND ss.Instance_Number=s.Instance_Number ) MaxIntervalTime,
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID) SQLText,
                             s.Elapsed_Secs, s.Executions, s.Disk_Reads, s.Buffer_Gets
                      FROM  (
                              SELECT DISTINCT p.DBID, p.Plan_Hash_Value, p.SQL_ID, p.Object_Owner, p.Object_Name
                              FROM  DBA_Hist_SQL_Plan p
                              WHERE Operation = 'INDEX'
                              AND   Options   = 'FULL SCAN'
                            ) p,
                            (SELECT s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number,
                                    MIN(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                    SUM(Elapsed_Time_Delta)/1000000 Elapsed_Secs,
                                    SUM(Executions_Delta)           Executions,
                                    SUM(Disk_Reads_Delta)           Disk_Reads,
                                    SUM(Buffer_Gets_Delta)          Buffer_Gets,
                                    MAX(s.Snap_ID)                     MaxSnapID
                             FROM   DBA_Hist_SQLStat s,
                                    (SELECT DBID, Instance_Number, MIN(Snap_ID) Snap_ID
                                     FROM   DBA_Hist_SnapShot ss
                                     WHERE  Begin_Interval_Time>SYSDATE-?
                                     /* Nur Snap_ID groesser der hier ermittelten auswerten */
                                     GROUP BY DBID, Instance_Number
                                    ) MaxSnap
                             WHERE MaxSnap.DBID            = s.DBID
                             AND   MaxSnap.Instance_Number = s.Instance_Number
                             AND   s.Snap_ID               > MaxSnap.Snap_ID
                             GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number) s
                      WHERE s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                      ) ORDER BY Num_Rows_Index DESC NULLS LAST, Elapsed_Secs DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_71_name, :default=>'Optimizable full table scan operations by executions'),
            :desc  => t(:dragnet_helper_71_desc, :default=>'Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
'),
            :sql=> "WITH Backward AS (SELECT ? Days FROM Dual)
                     SELECT /* DB-Tools Ramm FullTableScan */ p.SQL_ID, p.Object_Owner, p.Object_Name,
                              (SELECT Num_Rows FROM DBA_Tables t WHERE t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name) Num_Rows,
                              s.Elapsed_Secs, s.Executions, s.Disk_Reads, s.Buffer_Gets, s.Rows_Processed,
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID) SQLText
                      FROM  (
                              SELECT /*+ NO_MERGE */ DISTINCT p.DBID, p.Plan_Hash_Value, p.SQL_ID, p.Object_Owner, p.Object_Name /*, p.Access_Predicates, p.Filter_Predicates */
                              FROM  DBA_Hist_SQL_Plan p
                              WHERE Operation = 'TABLE ACCESS'
                              AND   Options LIKE '%FULL'            /* Auch STORAGE FULL der Exadata mit inkludieren */
                              AND   Object_Owner NOT IN ('SYS')
                              AND   Timestamp > SYSDATE-(SELECT Days FROM Backward)
                            ) p
                      JOIN  (SELECT s.DBID, s.SQL_ID, s.Plan_Hash_Value,
                                    ROUND(SUM(Elapsed_Time_Delta)/1000000,2) Elapsed_Secs,
                                    SUM(Executions_Delta)           Executions,
                                    SUM(Disk_Reads_Delta)           Disk_Reads,
                                    SUM(Buffer_Gets_Delta)          Buffer_Gets,
                                    SUM(Rows_Processed_Delta)       Rows_Processed
                             FROM   DBA_Hist_SQLStat s
                             JOIN   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, MIN(Snap_ID) Snap_ID
                                     FROM   DBA_Hist_SnapShot ss
                                     WHERE  Begin_Interval_Time > SYSDATE-(SELECT Days FROM Backward)
                                     GROUP BY DBID, Instance_Number
                                    ) MaxSnap ON MaxSnap.DBID            = s.DBID
                                             AND   MaxSnap.Instance_Number = s.Instance_Number
                                             AND   s.Snap_ID               > MaxSnap.Snap_ID
                             GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value
                             HAVING SUM(Executions_Delta) > ?  -- Nur vielfache Ausfuehrung mit Full Scan stellt Problem dar
                            ) s ON s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                      ORDER BY Executions*Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time period for consideration in result')},
            ]
        },
        {
            :name  => t(:dragnet_helper_72_name, :default=>'Optimizable full table scans operations by executions and rows processed'),
            :desc  => t(:dragnet_helper_72_desc, :default=>'Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
'),
            :sql=> "SELECT /* DB-Tools Ramm FullTableScans */ * FROM (
                            SELECT i.SQL_ID, i.Object_Owner, i.Object_Name, ROUND(i.Rows_Processed/i.Executions,2) Rows_per_Exec,
                                   i.Num_Rows, i.Elapsed_Time_Secs, i.Executions, i.Disk_Reads, i.Buffer_Gets, i.Rows_Processed,
                                   (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=i.DBID AND t.SQL_ID=i.SQL_ID) SQL_Text
                            FROM
                                   (
                                    SELECT /*+ PARALLEL(p,4) PARALLEL(s,4) PARALLEL(ss.4) */
                                           s.DBID, s.SQL_ID, p.Object_Owner, p.Object_Name,
                                           SUM(Executions_Delta)     Executions,
                                           SUM(Disk_Reads_Delta)     Disk_Reads,
                                           SUM(Buffer_Gets_Delta)    Buffer_Gets,
                                           SUM(Rows_Processed_Delta) Rows_Processed,
                                           MIN(t.Num_Rows) Num_Rows,
                                           ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs
                                    FROM   DBA_Hist_SQL_Plan p
                                    JOIN   DBA_Hist_SQLStat s   ON s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                                    JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                    JOIN   DBA_Tables t         ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name
                                    WHERE  p.Operation = 'TABLE ACCESS'
                                    AND    p.Options LIKE '%FULL'           /* Auch STORAGE FULL der Exadata mit inkludieren */
                                    AND    ss.Begin_Interval_Time > SYSDATE - ?
                                    AND    p.Object_Owner NOT IN ('SYS')
                                    AND    t.Num_Rows > ?
                                    GROUP BY s.DBID, s.SQL_ID, p.Object_Owner, p.Object_Name
                                   ) i
                            WHERE  Rows_Processed > 0
                            AND    Executions > ?
                     )
                     WHERE  SQL_Text NOT LIKE '%dbms_stats%'
                     ORDER BY Rows_per_Exec/Num_Rows/Executions",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')},
                         {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time period for consideration in result')},
            ]
        },
        {
            :name  => t(:dragnet_helper_73_name, :default=>'Optimizable full table scan operations at long running foreign key checks by deletes'),
            :desc  => t(:dragnet_helper_73_desc, :default=>'Long running foreign key checks at deletes are often caused by missing indexes at referencing table.'),
            :sql=>  "SELECT /*+ USE_NL(s t) */ t.SQL_Text Full_SQL_Text,
                             TO_CHAR(SUBSTR(t.SQL_Text, 1, 40)) SQL_Text,
                             s.*
                             FROM (
                                   SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Instance_number \"Instance\",
                                           NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') UserName, /* sollte immer gleich sein in Gruppe */
                                           SUM(Executions_Delta)                                              Executions,
                                           SUM(Elapsed_Time_Delta)/1000000                                    \"Elapsed Time (Sec.)\",
                                           ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),5) \"Elapsed Time (s) per Execute\",
                                           SUM(CPU_Time_Delta)/1000000                                        \"CPU Time (Sec.)\",
                                           SUM(Disk_Reads_Delta)                                              \"Disk Reads\",
                                           ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),2) \"Disk Reads per Execute\",
                                           ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)),4) \"Executions per Disk Read\",
                                           SUM(Buffer_Gets_Delta)                                             \"Buffer Gets\",
                                           ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)),2) \"Buffer Gets per Execution\",
                                           ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)),2) \"Buffer Gets per Row\",
                                           SUM(Rows_Processed_Delta)                                          \"Rows Processed\",
                                           SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) \"Rows Processed per Execute\",
                                           SUM(ClWait_Delta)                                                  \"Cluster Wait Time\",
                                           MAX(s.Snap_ID) Max_Snap_ID
                                   FROM dba_hist_snapshot snap,
                                   DBA_Hist_SQLStat s
                                   WHERE snap.Snap_ID = s.Snap_ID
                                   AND snap.DBID = s.DBID
                                   AND snap.Instance_Number= s.instance_number
                                   AND snap.Begin_Interval_time >  SYSDATE - ?
                                   AND s.Parsing_Schema_Name = 'SYS'
                                   GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                             ) s
                       JOIN  DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                       WHERE UPPER(t.SQL_Text) LIKE '%SELECT%ALL_ROWS%COUNT(1)%'
                       ORDER BY \"Elapsed Time (s) per Execute\" DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_86_name, :default=>'Long running full table scans caused by IS NULL selection (from 11g)'),
            :desc  => t(:dragnet_helper_86_desc, :default=>'Selections with IS NULL in WHERE-condition often lead to fall table scan, although there are less NULL-Records to select.
Solution can be: indexing of column accessed by IS NULL with function based index which also contains records with NUL value and usage of function expression in select instead of IS NULL.
Example: Indexing with NVL(Column,0)'),
            :sql=>  "SELECT p.Inst_ID, p.SQL_ID, MIN(h.Sample_Time) First_Occurrence, MAX(h.Sample_Time) Last_Occurrence, COUNT(*) Wait_Time_Secs,
                             p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.Filter_Predicates
                      FROM   gv$SQL_Plan p
                      JOIN   gv$Active_Session_History h ON h.SQL_ID=p.SQL_ID AND h.Inst_ID=p.Inst_ID AND h.SQL_Plan_Hash_Value = p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                      WHERE  UPPER(Filter_Predicates) LIKE '%IS NULL%'
                      AND    Options LIKE '%FULL'
                      GROUP BY p.Inst_ID, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.Filter_Predicates
                      ORDER BY COUNT(*) DESC
             ",
        },


    ]
  end # optimizable_full_scans

end