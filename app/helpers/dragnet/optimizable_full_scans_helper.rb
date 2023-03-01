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
            :sql=> "\
WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALZE */ Owner, Index_Name, Num_Rows FROM DBA_Indexes WHERE Owner NOT IN (#{system_schema_subselect}))
SELECT p.SQL_ID, s.Parsing_Schema_Name, p.Object_Owner, p.Object_Name,
       i.Num_Rows Num_Rows_Index, s.Instance_Number,
       (SELECT MAX(Begin_Interval_Time) FROM DBA_Hist_SnapShot ss
        WHERE ss.DBID=p.DBID AND ss.Snap_ID=s.MaxSnapID AND ss.Instance_Number=s.Instance_Number ) MaxIntervalTime,
       (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID AND RowNum < 2) SQLText,
       s.Elapsed_Secs, s.Executions, s.Disk_Reads, s.Buffer_Gets
FROM  (
        SELECT /*+ NO_MERGE */ DISTINCT p.DBID, p.Plan_Hash_Value, p.SQL_ID, p.Object_Owner, p.Object_Name
        FROM  DBA_Hist_SQL_Plan p
        WHERE Operation = 'INDEX'
        AND   Options   = 'FULL SCAN'
        AND   p.Object_Owner NOT IN (#{system_schema_subselect})
      ) p
JOIN  (SELECT s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number,
              MIN(s.Parsing_Schema_Name) Parsing_Schema_Name,
              SUM(Elapsed_Time_Delta)/1000000 Elapsed_Secs,
              SUM(Executions_Delta)           Executions,
              SUM(Disk_Reads_Delta)           Disk_Reads,
              SUM(Buffer_Gets_Delta)          Buffer_Gets,
              MAX(s.Snap_ID)                     MaxSnapID
       FROM   DBA_Hist_SQLStat s
       JOIN   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, MIN(Snap_ID) Snap_ID
               FROM   DBA_Hist_SnapShot ss
               WHERE  Begin_Interval_Time>SYSDATE-?
               /* Nur Snap_ID groesser der hier ermittelten auswerten */
               GROUP BY DBID, Instance_Number
              ) MaxSnap ON MaxSnap.DBID = s.DBID AND MaxSnap.Instance_Number = s.Instance_Number
       WHERE s.Snap_ID               > MaxSnap.Snap_ID
       GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number
      ) s ON s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
JOIN  Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name=p.Object_Name
ORDER BY i.Num_Rows DESC NULLS LAST, s.Elapsed_Secs DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_72_name, :default=>'Full table scans  with less result records: possibly missing indexes '),
            :desc  => t(:dragnet_helper_72_desc, :default=>'Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
Placing an index may reduce runtime significant.
Calculated by high runtime and less result records.
'),
            :sql=> "\
WITH Backward AS (SELECT ? Days FROM Dual)
SELECT /* DB-Tools Ramm FullTableScans */
       SQL_ID, Object_Owner, Object_Name, Num_Rows,
       Executions,
       ROUND(Elapsed_Time_Secs)                   \"Elapsed secs for SQL total\",
       Seconds_Active                             \"ASH secs for table total\",
       ROUND(Rows_per_Exec, 1)                    \"Rows per Exec\",
       ROUND(Elapsed_Time_Secs/Executions,2)      \"Elapsed Secs per Exec\",
       ROUND(Seconds_Active/Executions, 2)        \"ASH secs for table per Exec\",
       ROUND(Disk_Reads/Executions,1)             \"Disk reads per Exec\",
       ROUND(Buffer_Gets/Executions)              \"Buffer gets per Exec\",
       SQL_Text
FROM   (
        SELECT i.*, h.Seconds_Active, i.Rows_Processed/i.Executions Rows_per_Exec,
               (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=i.DBID AND t.SQL_ID=i.SQL_ID AND RowNum < 2) SQL_Text
        FROM   (
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
                AND    ss.Begin_Interval_Time > SYSDATE - (SELECT Days FROM Backward)
                AND    p.Object_Owner NOT IN (#{system_schema_subselect})
                AND    t.Num_Rows >= ?
                GROUP BY s.DBID, s.SQL_ID, p.Object_Owner, p.Object_Name
               ) i
        LEFT OUTER JOIN  (SELECT /*+ NO_MERGE */ h.DBID, h.SQL_ID, o.Owner, o.Object_Name, SUM(Seconds_Active) Seconds_Active
                          FROM   (SELECT /*+ PARALLEL(2) NO_MERGE */ h.DBID, h.SQL_ID, h.Current_Obj#, COUNT(*) * 10 Seconds_Active
                                  FROM   DBA_Hist_Active_Sess_History h
                                  JOIN   DBA_Hist_Snapshot ss ON ss.DBID = h.DBID AND ss.Instance_Number = h.Instance_Number AND ss.Snap_ID = h.Snap_ID
                                  WHERE  ss.Begin_Interval_Time > SYSDATE - (SELECT Days FROM Backward)
                                  AND    h.SQL_Plan_Operation = 'TABLE ACCESS'
                                  AND    h.SQL_Plan_Options LIKE '%FULL'  /* also include Exadata variants */
                                  AND    h.User_ID NOT IN (#{system_userid_subselect})
                                  AND    h.Current_Obj# != -1
                                  GROUP BY h.DBID, h.SQL_ID, h.Current_Obj#
                                 ) h
                          JOIN   DBA_Objects o ON o.Object_ID = h.Current_Obj#
                          GROUP BY h.DBID, h.SQL_ID, o.Owner, o.Object_Name
                         ) h ON h.DBID = i.DBID AND h.SQL_ID = i.SQL_ID AND h.Owner = i.Object_Owner AND h.Object_Name = i.Object_Name
        WHERE  i.Rows_Processed > 0
        AND    i.Executions >= ?
       )
WHERE  SQL_Text NOT LIKE '%dbms_stats%'
--ORDER BY Rows_per_Exec/Num_Rows/Executions/Elapsed_Time_Secs
ORDER BY Elapsed_Time_Secs * Num_Rows * NVL(Seconds_Active, 1)/DECODE(Rows_per_Exec, 0, 1, Rows_per_Exec)  DESC
              ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')},
                         {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>1, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time period for consideration in result')},
            ]
        },
        {
            :name  => t(:dragnet_helper_154_name, :default=>'Full table scans  with small cardinality: possibly missing indexes '),
            :desc  => t(:dragnet_helper_154_desc, :default=>"Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
Placing an index may reduce runtime significant.
Calculated by high runtime of full scan and small expected number of records from full scan (by optimizer's cardinality).
Thie selection requires usage of AWR history with Diagnostics Pack.
"),
            :sql=> "\
SELECT h.Instance_Number \"Inst.\", u.UserName \"SQL User\", h.SQL_ID, p.Object_Owner Owner, p.Object_Name, p.Object_Type \"Object Type\", h.SQL_Plan_Line_ID \"Plan Line ID\",
       p.Operation, p.Options, h.Elapsed_Secs \"Elapsed Secs.\", p.Cardinality, t.Num_Rows \"Num Rows Table\", t.Partitioned,
       NVL(gp.Access_Predicates, '< no plan in SGA >') Access_Predicates,
       NVL(gp.Filter_Predicates, '< no plan in SGA >') Filter_Predicates
FROM   (SELECT /*+ NO_MERGE */ ss.DBID, ss.Instance_Number, h.User_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID, COUNT(*) * 10 Elapsed_Secs
        FROM   DBA_Hist_Snapshot ss
        JOIN   DBA_Hist_Active_Sess_History h ON h.DBID = ss.DBID AND h.Instance_Number = ss.Instance_Number AND h.Snap_ID = ss.Snap_ID
        WHERE  ss.Begin_Interval_Time > SYSDATE - ?
        AND    h.SQL_Plan_Operation = 'TABLE ACCESS'
        AND    h.SQL_Plan_Options LIKE '%FULL'  /* also include Exadata variants */
        AND    h.User_ID NOT IN (#{system_userid_subselect})
        GROUP BY ss.DBID, ss.Instance_Number, h.User_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID
       ) h
JOIN   DBA_Hist_SQL_Plan p ON p.DBID = h.DBID AND p.SQL_ID = h.SQL_ID AND p.Plan_Hash_Value = h.SQL_Plan_Hash_Value AND p.ID = h.SQL_Plan_Line_ID
LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
LEFT OUTER JOIN (SELECT SQL_ID, Plan_Hash_Value, ID, MIN(Access_Predicates) Access_Predicates, MIN(Filter_Predicates) Filter_Predicates
                 FROM   gv$SQL_Plan gp
                 WHERE  Operation = 'TABLE ACCESS'
                 AND    Options LIKE '%FULL'  /* also include Exadata variants */
                 AND    (Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL)
                 GROUP BY SQL_ID, Plan_Hash_Value, ID
                ) gp ON gp.SQL_ID = h.SQL_ID AND gp.Plan_Hash_Value = p.Plan_Hash_Value AND gp.ID = p.ID
LEFT OUTER JOIN All_Users u ON u.User_ID = h.User_ID
WHERE  h.Elapsed_Secs > ?
AND    p.Operation = 'TABLE ACCESS'
AND    p.Options LIKE '%FULL'  /* also include Exadata variants */
ORDER BY h.Elapsed_Secs/p.Cardinality DESC              ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_154_param_1_name, :default=>'Min. elapsed seconds for full table scan'), :size=>8, :default=>100, :title=>t(:dragnet_helper_154_param_1_hint, :default=>'Minimum number of total elapsed seconds in considered period for full table scans on object')},
            ]
        },
        {
            :name  => t(:dragnet_helper_73_name, :default=>'Optimizable full table scan operations at long running foreign key checks by deletes'),
            :desc  => t(:dragnet_helper_73_desc, :default=>'Long running foreign key checks at deletes are often caused by missing indexes at referencing table.'),
            :sql=>  "\
WITH SQLText AS (SELECT /*+ NO_MERGE MATERIALIZE */ DBID, SQL_ID, SQL_Text FROM DBA_Hist_SQLText WHERE UPPER(SQL_Text) LIKE '%SELECT%ALL_ROWS%COUNT(1)%'),
     SQLStat AS (SELECT /*+ NO_MERGE MATERIALIZE */ s.DBID, s.SQL_ID, s.Instance_number Instance,
                        NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') UserName, /* sollte immer gleich sein in Gruppe */
                        SUM(Executions_Delta)                                              Executions,
                        SUM(Elapsed_Time_Delta)/1000000                                    \"Elapsed Time (Sec.)\",
                        ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),2) \"Elapsed Time (s) per Execute\",
                        SUM(CPU_Time_Delta)/1000000                                        \"CPU Time (Sec.)\",
                        SUM(Disk_Reads_Delta)                                              \"Disk Reads\",
                        ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),2) \"Disk Reads per Execute\",
                        ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)),4) \"Executions per Disk Read\",
                        SUM(Buffer_Gets_Delta)                                             \"Buffer Gets\",
                        ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)),2) \"Buffer Gets per Execution\",
                        ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)),2) \"Buffer Gets per Row\",
                        SUM(Rows_Processed_Delta)                                          \"Rows Processed\",
                        ROUND(SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)), 2) \"Rows Processed per Execute\",
                        SUM(ClWait_Delta)                                                  \"Cluster Wait Time\"
                 FROM   DBA_Hist_Snapshot snap
                 JOIN   DBA_Hist_SQLStat s ON snap.Snap_ID = s.Snap_ID AND snap.DBID = s.DBID AND snap.Instance_Number= s.instance_number
                 WHERE  snap.Begin_Interval_time >  SYSDATE - ?
                 AND    s.Parsing_Schema_Name = 'SYS'
                 GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                )
SELECT t.SQL_Text Full_SQL_Text,
       s.*
FROM   SQLstat s
JOIN  SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
ORDER BY \"Elapsed Time (s) per Execute\" DESC NULLS LAST
             ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_86_name, :default=>'Long running full table scans caused by IS NULL selection'),
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