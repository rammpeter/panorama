# encoding: utf-8
module Dragnet::ProblemsWithParallelQueryHelper

  private

  def problems_with_parallel_query
    [
        {
            :name  => t(:dragnet_helper_77_name, :default=>'Long running queries without usage of parallel query (Evaluation of SGA)'),
            :desc  => t(:dragnet_helper_77_desc, :default=>'For long running queries usage of parallel query feature may dramatically reduce runtime.'),
            :sql=>  "SELECT /*+ ORDERED USE_HASH(s) \"DB-Tools Ramm ohne Parallel Query\"*/
                             s.Inst_ID, s.SQL_ID,
                             s.Parsing_Schema_Name \"Parsing Schema Name\",
                             ROUND(s.Elapsed_Time/10000)/100 Elapsed_Time_Sec,
                             s.Executions,
                             ROUND(s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions)/10000)/100 Elapsed_per_Exec_Sec,
                             First_Load_Time, Last_Load_Time, Last_Active_Time,
                             s.SQL_FullText
                      FROM (
                            SELECT Inst_ID, SQL_ID
                            FROM   GV$SQL_Plan
                            GROUP BY Inst_ID, SQL_ID
                            HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) = 0
                           ) p,
                           GV$SQLArea s
                      WHERE s.Inst_ID = p.Inst_ID
                      AND   s.SQL_ID  = p.SQL_ID
                      AND   s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions) > ? * 1000000 /* > 10 Sekunden */
                      ORDER BY s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions) DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_param_minimal_ela_per_exec_name, :default=>'Minimum elapsed time/execution (sec.)'), :size=>8, :default=>20, :title=> t(:dragnet_helper_param_minimal_ela_per_exec_hint, :default=>'Minimum elapsed time per execution in seconds for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_141_name, :default=>'Long running queries without usage of parallel query (Evaluation of AWR history)'),
            :desc  => t(:dragnet_helper_77_desc, :default=>'For long running queries usage of parallel query feature may dramatically reduce runtime.'),
            :sql=>  "SELECT /*+ ORDERED USE_HASH(s) \"DB-Tools Ramm ohne Parallel Query aus Historie\"*/
                             s.*,
                             ROUND(s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions),2) \"Elapsed time per exec (secs)\",
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID AND RowNum < 2) Statement
                      FROM   (SELECT
                                     s.DBID, s.Instance_Number, s.SQL_ID, s.Parsing_Schema_Name,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/10000)/100 Elapsed_Time_Sec,
                                     SUM(s.Executions_Delta) Executions,
                                     MIN(ss.Begin_Interval_time) First_Occurrence,
                                     MAX(ss.Begin_Interval_Time) Last_Occurrence
                              FROM   (
                                      SELECT /*+ NO_MERGE */ DBID, SQL_ID, Plan_Hash_Value
                                      FROM   DBA_Hist_SQL_Plan p
                                      GROUP BY DBID, SQL_ID, Plan_Hash_Value
                                      HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) = 0
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.DBID, s.Instance_Number, s.SQL_ID, s.Parsing_Schema_Name
                             ) s
                      WHERE  s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions) > ? /* > 50 Sekunden */
                      ORDER BY s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_param_minimal_ela_per_exec_name, :default=>'Minimum elapsed time/execution (sec.)'), :size=>8, :default=>20, :title=> t(:dragnet_helper_param_minimal_ela_per_exec_hint, :default=>'Minimum elapsed time per execution in seconds for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_79_name, :default=>'Statements with parallel query but with not parallelized contents (evaluation of SGA)'),
            :desc  => t(:dragnet_helper_79_desc, :default=>'If using parallelel query accidentally not parallelized accesses on large structures may dramatically increase runtime of statement.
Leading INDEX-RANGE-SCAN for cascading nested loop joins should be transferred to WITH … /*+ MATERIALIZE */ and selected in main statement in parallel.
Selection considers current SGA.'),
            :sql=>  "WITH SQL_Plan AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, SQL_ID, Operation, Options, Object_Owner, Object_Name, Other_Tag FROM gv$SQL_Plan)
                     SELECT /*+ \"DBTools Ramm Nichtparallel Anteile bei PQ\" */ p.*,
                             s.Last_active_Time,
                             s.Executions,
                             s.Elapsed_Time/1000000 Elapsed_Secs,
                             s.SQL_FullText
                      FROM   (
                              SELECT /*+ NO_MERGE */
                                     CASE WHEN Operation = 'INDEX' THEN
                                          (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=ps.Object_Owner AND i.Index_Name = ps.Object_Name)
                                          WHEN Operation = 'TABLE ACCESS' THEN
                                          (SELECT Num_Rows FROM DBA_All_Tables t WHERE t.Owner=ps.Object_Owner AND t.Table_Name = ps.Object_Name)
                                     ELSE 0 END Num_Rows,
                                     ps.*
                              FROM   (
                                      SELECT Inst_ID, SQL_ID
                                      FROM   SQL_PLan
                                      WHERE  Other_Tag LIKE 'PARALLEL%'
                                      AND    Object_Owner NOT IN (#{system_schema_subselect})
                                      GROUP BY Inst_ID, SQL_ID
                                     ) pp,
                                     (
                                      SELECT Inst_ID, SQL_ID, Operation, Options, Object_Owner, Object_Name
                                      FROM   SQL_PLan
                                      WHERE  (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                      AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                      AND    Operation NOT LIKE 'UPDATE%'
                                      AND    Operation NOT LIKE 'SELECT%'
                                      AND    Object_Owner NOT IN (#{system_schema_subselect})
                                     ) ps
                              WHERE  ps.Inst_ID = pp.Inst_ID
                              AND    ps.SQL_ID  = pp.SQL_ID
                            ) p
                      JOIN  GV$SQLArea s ON s.Inst_ID=p.Inst_ID AND s.SQL_ID=p.SQL_ID
                      WHERE s.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%'
                      AND   s.Elapsed_Time/1000000 > ?
                      ORDER BY Num_Rows DESC NULLS LAST",
            parameter: [{name: t(:dragnet_helper_79_param1_name, default: 'Minimum elapsed seconds'), size: 8, default: 30, title: t(:dragnet_helper_param_history_backward_hint, default: 'Minimum number of elapsed seconds since first occurrence in SGA for consideration in selection') }]
        },
        {
            :name  => t(:dragnet_helper_80_name, :default=>'Statements with parallel query but with not parallelized contents (evaluation of AWR history)'),
            :desc  => t(:dragnet_helper_80_desc, :default=>'If using parallelel query accidentally not parallelized accesses on large structures may dramatically increase runtime of statement.
Leading INDEX-RANGE-SCAN for cascading nested loop joins should be transferred to WITH … /*+ MATERIALIZE */ and selected in main statement in parallel.
Selection considers AWR history.'),
            :sql=>  "SELECT /* DB-Tools Ramm Nichparallel Anteile bei PQ */ * FROM (
                      SELECT /*+ NO_MERGE */ x.*, ps.Operation, ps.Options, ps.Object_Type, ps.Object_Owner, ps.Object_Name,
                             CASE
                             WHEN ps.Object_Type LIKE 'TABLE%' THEN (SELECT Num_Rows FROM DBA_All_Tables t WHERE t.Owner=ps.Object_Owner AND t.Table_Name=ps.Object_Name)
                             WHEN ps.Object_Type LIKE 'INDEX%' THEN (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=ps.Object_Owner AND i.Index_Name=ps.Object_Name)
                             ELSE NULL END Num_Rows,
                            (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=x.DBID AND t.SQL_ID=x.SQL_ID AND RowNum < 2) SQLText
                      FROM
                             (
                              SELECT /*+ NO_MERGE ORDERED */
                                     p.DBID, p.SQL_ID, p.Plan_Hash_Value,
                                     MIN(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Secs,
                                     SUM(s.Executions_Delta) Executions,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/1000000 / DECODE(SUM(s.Executions_Delta), 0, 1, SUM(s.Executions_Delta)),2) Elapsed_Secs_Per_Exec,
                                     MAX(ss.Begin_Interval_Time) Last_Occurence
                              FROM   (
                                      SELECT /*+ PARALLEL(DBA_Hist_SQL_Plan,2) */ DBID, SQL_ID, Plan_Hash_Value
                                      FROM   DBA_Hist_SQL_Plan
                                      WHERE  Object_Owner NOT IN (#{system_schema_subselect})
                                      GROUP BY DBID, SQL_ID, Plan_Hash_Value
                                      HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) > 0  -- enthält parallele Anteile
                                      AND    SUM(CASE WHEN (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                                      AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                                      AND    Operation NOT LIKE 'UPDATE%'
                                                      AND    Operation NOT LIKE 'SELECT%'
                                                      THEN 1 ELSE 0 END) > 1 -- enthält nicht parallelisierte Zugriffe
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.Snap_ID = s.Snap_ID AND ss.DBID = p.DBID AND ss.Instance_Number = s.Instance_Number
                                                             AND ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY p.DBID, p.SQL_ID, p.Plan_Hash_Value
                             ) x
                      JOIN   DBA_Hist_SQL_Plan ps ON ps.DBID = x.DBID AND ps.SQL_ID = x.SQL_ID AND ps.Plan_Hash_Value = x.Plan_Hash_Value
                                                     AND (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                                     AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                                     AND    Operation NOT LIKE 'UPDATE%'
                                                     AND    Operation NOT LIKE 'SELECT%'
                                                     AND    ps.Object_Type IS NOT NULL
                      ) ORDER BY Elapsed_Secs_Per_Exec * Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_81_name, :default=>'SQLs executed in parallel but with usage of stored functions without PARALLEL_ENABLE'),
            :desc  => t(:dragnet_helper_81_desc, :default=>'Stored functions not for parallel execution per pragma PARALLEL_ENABLE lead  to serial processing if statements that should be executed in parallel.
Listed functions should be checked if they can be expanded by pragma PARALLEL_ENABLE.'),
            :sql=>  "WITH /* DB-Tools Ramm Serialisierung in PQ durch Stored Functions */
                      Arguments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Package_Name, Object_Name FROM DBA_Arguments WHERE Position = 0), /* Filter package function names from DBA_Procedures */
                      ProcLines AS (
                            SELECT /*+ NO_MERGE MATERIALIZE */ *
                            FROM   (
                                    SELECT p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, p.Parallel, p.Object_Name SuchText
                                    FROM   DBA_Procedures p
                                    WHERE  p.Object_Type = 'FUNCTION'
                                    UNION ALL
                                    SELECT /*+ USE_HASH(p a) */ p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, p.Parallel, p.Object_Name||'.'||p.Procedure_Name SuchText
                                    FROM   DBA_Procedures p
                                    JOIN   Arguments a ON a.Owner = p.Owner AND a.Package_Name = p.Object_Name AND a.Object_Name = p.Procedure_Name
                                    WHERE  p.Object_Type = 'PACKAGE'
                                   )
                            WHERE  Owner NOT IN (#{system_schema_subselect})
                            AND    Parallel = 'NO'
                       )
                      SELECT /*+ ORDERED NOPARALLEL */
                             s.FullText, s.SQL_ID, p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, ROUND(s.Elapsed_Secs), s.Fundort
                      FROM   (
                              SELECT /*+ NO_MERGE */  *
                              FROM   (
                                      SELECT /*+ NO_MERGE */ UPPER(SQL_FullText) FullText, Elapsed_Time/1000000 Elapsed_Secs, 'SGA' Fundort, S.SQL_ID
                                      FROM gv$SQL s
                                      WHERE UPPER(s.SQL_FullText) LIKE '%PARALLEL%'   /* Hint im SQL verwendet */
                                      UNION ALL
                                      SELECT /*+ NO_MERGE */ UPPER(t.SQL_Text) FullText, s.Elapsed_Secs, 'History' Fundort, s.SQL_ID
                                      FROM   (
                                              SELECT /*+ NO_MERGE */
                                                     s.DBID, s.SQL_ID, Plan_Hash_Value, SUM(s.Elapsed_Time_Delta)/1000000 Elapsed_Secs
                                              FROM   DBA_Hist_SQLStat s
                                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Snap_ID = s.Snap_ID AND ss.Instance_Number = s.Instance_Number
                                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                                              GROUP BY s.DBID, s.SQL_ID, Plan_Hash_Value
                                             ) s
                                      JOIN DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                                      WHERE  UPPER(t.SQL_Text) LIKE '%PARALLEL%'     /* Hint im SQL verwendet */
                                     )
                              WHERE  NOT REGEXP_LIKE(FullText, '^[[:space:]]*BEGIN')
                              AND    NOT REGEXP_LIKE(FullText, '^[[:space:]]*DECLARE')
                              AND    NOT REGEXP_LIKE(FullText, '^[[:space:]]*EXPLAIN')
                              AND    INSTR(FullText, 'DBMS_STATS') = 0              /* Aussschluss Table-Analyse*/
                              AND    Elapsed_Secs > ?
                             ) s,
                             ProcLines p
                      -- INSTR-Test vorab, da schneller als RegExp_Like
                      -- Match auf ProcName vorangestellt und gefolgt von keinem Buchstaben
                      WHERE /*+ ORDERED_PREDICATES */ INSTR(s.FullText, p.SuchText) > 0
                      AND REGEXP_LIKE(s.FullText,'[^A-Z_]'||p.SuchText||'[^A-Z_]')
                      ORDER BY Elapsed_Secs DESC NULLS LAST
                      ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=>'Minimum sum of elapsed time in seconds', :size=>8, :default=>100, :title=>'Minimum sum of elapsed time in second for considered SQL' },
            ]
        },
        {
            :name  => t(:dragnet_helper_82_name, :default=>'Statements with parallel query and serial processing of process parts'),
            :desc  => t(:dragnet_helper_82_desc, :default=>"Parts of parallel processed statements my be executed serially and results of these subprocesses are parallelized by broadcast.
For small data structures it is often wanted, for large data structures it may be due to missing PARALLEL-hints.
This Selection lists all statements with 'PARALLEL_FROM_SERIAL'-processing after full-scan on objects as candidates for forgotten parallelising."),
            :sql=>  "WITH SQL_Plan AS (SELECT /*+ NO_MERGE MATERIALIZE */ DBID, SQL_ID, Operation, Options, Object_Owner, Object_Name, Plan_Hash_Value, Other_Tag, Timestamp, ID, Parent_ID FROM DBA_Hist_SQL_PLan)
                     SELECT /* DB-Tools Ramm PARALLEL_FROM_SERIAL in PQ */ * FROM (
                      SELECT /*+ NO_MERGE */ a.*, (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=a.DBID AND t.SQL_ID=a.SQL_ID AND RowNum < 2) SQLText,
                             CASE
                             WHEN Operation='TABLE ACCESS' THEN (SELECT Num_Rows FROM DBA_All_Tables t WHERE t.Owner=Object_Owner AND t.Table_Name=Object_Name)
                             WHEN Operation='INDEX' THEN (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=Object_Owner AND i.Index_Name=Object_Name)
                             ELSE NULL END Num_Rows
                      FROM (
                      SELECT /*+ ORDERED NO_MERGE */ p.DBID, p.SQL_ID, MIN(p.Operation) Operation,
                              MIN(p.Options) Options, MIN(p.Object_Owner) Object_Owner, MIN(p.Object_Name) Object_Name,
                              SUM(ss.Elapsed_Time_Delta)/1000000 Elapsed_Time_Secs,
                              SUM(ss.Executions_Delta) Executions--,
                      --        (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID AND RowNum < 2) SQLText
                      FROM   (
                              SELECT /*+ NO_MERGE MATERIALIZE */ p.DBID, p.SQL_ID, p.Plan_Hash_Value,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Operation ELSE p2.Operation END Operation,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Options ELSE p2.Options END Options,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Object_Owner ELSE p2.Object_Owner END Object_Owner,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Object_Name ELSE p2.Object_Name END Object_Name
                              FROM (
                                      SELECT  DBID, SQL_ID,
                                              MAX(p.Plan_Hash_Value) KEEP (DENSE_RANK LAST ORDER BY p.Timestamp) Plan_Hash_Value,
                                              MAX(p.ID) KEEP (DENSE_RANK LAST ORDER BY p.Timestamp) ID
                                      FROM SQL_Plan p
                                      WHERE   p.Other_Tag = 'PARALLEL_FROM_SERIAL'
                                      GROUP BY DBID, SQL_ID
                                   ) p
                              LEFT OUTER JOIN SQL_Plan p1 ON (    p1.DBID=p.DBID
                                                                       AND p1.SQL_ID=p.SQL_ID
                                                                       AND p1.Plan_Hash_Value=p.Plan_Hash_Value
                                                                       AND p1.Parent_ID = p.ID)
                              LEFT OUTER JOIN SQL_Plan p2 ON (    p2.DBID=p1.DBID
                                                                       AND p2.SQL_ID=p1.SQL_ID
                                                                       AND p2.Plan_Hash_Value=p1.Plan_Hash_Value
                                                                       AND p2.Parent_ID = p1.ID)
                              WHERE   (p1.Options LIKE '%FULL%' OR p2.Options LIKE '%FULL%')
                              ) p
                      JOIN   DBA_Hist_SQLStat ss ON (ss.DBID=p.DBID AND ss.SQL_ID=p.SQL_ID AND ss.Plan_Hash_Value=p.Plan_Hash_Value)
                      JOIN   DBA_Hist_SnapShot s ON (s.Snap_ID=ss.Snap_ID AND s.DBID=ss.DBID AND s.Instance_Number=ss.Instance_Number)
                      WHERE  s.Begin_Interval_Time > SYSDATE-?
                      GROUP BY p.DBID, p.SQL_ID, p.Plan_Hash_Value
                      ) a)
                      ORDER BY Elapsed_Time_Secs*NVL(Num_Rows,1) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_63_name, :default=>'Parallel Query: Degree of parallelism (number of attached PQ servers) higher than limit for single SQL execution'),
            :desc  => t(:dragnet_helper_63_desc, :default=>'Number of avilable PQ servers is a limited resource, so default degree of parallelism is often to high for production use, especially on multi-core machines.
Overallocation of PQ servers may result in serial processing og other SQLs estimated to process in parallel.'),
            :sql=>   "SELECT Instance_Number, SQL_ID, MIN(Sample_Time) First_Occurrence, MAX(Sample_Time) Last_Occurrence,
                             COUNT(DISTINCT QC_Session_ID)    Different_Coordinator_Sessions,
                             SUM(Executions)                  SQL_Executions,
                             u.UserName,
                             SUM(10)                          Active_Seconds,
                             SUM(10*DOP)                      Elapsed_PQ_Seconds_Total,
                             MIN(DOP)                         Min_Degree_of_Parallelism,
                             MAX(DOP)                         Max_Degree_of_Parallelism,
                             ROUND(AVG(DOP))                  Avg_Degree_of_Parallelism
                      FROM   (
                              SELECT Instance_Number, QC_Instance_ID, qc_session_id, QC_Session_Serial#,
                               sql_id, MIN(sample_time) Sample_Time, COUNT(*) dop, MIN(User_ID) User_ID, COUNT(DISTINCT SQL_Exec_ID) Executions
                              FROM dba_hist_active_sess_history
                              WHERE  QC_Session_ID IS NOT NULL
                              AND    Sample_Time > SYSDATE - ?
                              AND    DBID = #{get_dbid}  /* do not count multiple times for multipe different DBIDs/ConIDs */
                              GROUP BY Instance_Number, QC_Instance_ID, qc_session_id, QC_Session_Serial#, Sample_ID, SQL_ID
                              HAVING count(*) > ?
                             ) g
                      LEFT OUTER JOIN DBA_Users u ON U.USER_ID = g.User_ID
                      GROUP BY Instance_Number, SQL_ID, u.UserName
                      ORDER BY MAX(DOP) DESC
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_63_param_2_name, :default=>'Limit for number of PQ servers'), :size=>8, :default=>16, :title=>t(:dragnet_helper_63_param_2_hint, :default=>'Limit for number of PQ servers: exceedings of this value are shown here') },
            ]
        },
        {
            :name  => t(:dragnet_helper_105_name, :default=>'Statements with planned parallel execution forced to serial'),
            :desc  => t(:dragnet_helper_105_desc, :default=>'PX COORDINATOR FORCED SERIAL in execution plan shows that optimizer assumed to process in parallel but detects reasons that prevents parallel execution (e.g. stored functions without PARALLEL_ENABLE).
The operations below that execution plan line are not really executed in parallel although the optimizer has marked them for parallel execution!'),
            :sql=>  "SELECT /* DB-Tools Ramm FORCE SERIAL in PQ */ x.* ,
                             (SELECT SUBSTR(SQL_Text,1,100) FROM DBA_Hist_SQLText t WHERE t.DBID=x.DBID AND t.SQL_ID=x.SQL_ID) SQLText
                      FROM   (SELECT p.DBID, p.SQL_ID, p.Plan_Hash_Value, MIN(Occurrences_in_Plan) Occurrences_in_Plan, s.Parsing_Schema_Name,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/1000000) Elapsed_Time_Secs,
                                     SUM(s.Executions_Delta) Executions
                              FROM   (SELECT /*+ NO_MERGE */ DBID, SQL_ID, Plan_Hash_Value, COUNT(*) Occurrences_in_Plan
                                      FROM   DBA_Hist_SQL_Plan
                                      WHERE  operation = 'PX COORDINATOR'
                                      AND    options = 'FORCED SERIAL'
                                      GROUP BY DBID, SQL_ID, Plan_Hash_Value
                                     )p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE-?
                              GROUP BY p.DBID, p.SQL_ID, p.Plan_Hash_Value, s.Parsing_Schema_Name
                             ) x
                      ORDER BY Elapsed_Time_Secs DESC
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_134_name, :default=>'Problematic usage of parallel query for short running SQLs (Current SGA)'),
            :desc  => t(:dragnet_helper_134_desc, :default=>'For short running SQL the effort for starting parallel query processes is often higher than for excuting the SQL iteself.
Additional problems may be caused by the limited amount of PQ-processes for frequently executed SQLs
as well as by the basically recording of SQL Monitor reports for each PQ execution.
Therfore for SQLs with runtime in seconds or less you should always avoid using parallel query.
This selection considers SQLs in the current SGA'),
            :sql=> "SELECT Inst_ID, SQL_ID, Parsing_Schema_Name, Executions, Elapsed_Time/1000000 Elapsed_Time_Secs,
                           CASE WHEN Executions > 0 THEN ROUND(Elapsed_Time/1000000/Executions, 5) END Elapsed_Time_Secs_per_Exec,
                           Px_Servers_Executions,
                           CASE WHEN Executions > 0 THEN ROUND(Px_Servers_Executions/Executions) END PQ_per_Exec,
                           First_Load_Time, Last_Active_Time, Elapsed_Time, SQL_Text
                    FROM   gv$SQLArea
                    WHERE  PX_Servers_Executions > 0
                    AND    Elapsed_Time / 1000000 / CASE WHEN Executions > 0 THEN Executions ELSE 1 END < ?
                    AND    UPPER(SQL_FullText) NOT LIKE '%GV$%'
                    AND    Parsing_Schema_Name NOT IN (#{system_schema_subselect})
                    ORDER BY PX_Servers_Executions DESC",
            :parameter=>[{:name=>t(:dragnet_helper_134_param_1_name, :default=>'Maximum runtime per execution in seconds'), :size=>8, :default=>5, :title=>t(:dragnet_helper_134_param_1_hint, :default=>'Maximum runtime per execution in seconds for consideration in result') }]
        },
        {
          :name  => t(:dragnet_helper_170_name, :default=>'Problematic usage of parallel query for short running SQLs (by SQL Monitor)'),
          :desc  => t(:dragnet_helper_170_desc, :default=>'For short running SQL the effort for starting parallel query processes is often higher than for excuting the SQL iteself.
Additional problems may be caused by the limited amount of PQ-processes for frequently executed SQLs
as well as by the basically recording of SQL Monitor reports for each PQ execution.
Therfore for SQLs with runtime in seconds or less you should always avoid using parallel query.
This selection considers SQLs from SQL Monitor recordings in gv$SQL_Monitor and DBA_Hist_Reports'),
          min_db_version: '12.1',
          :sql=> "\
SELECT Inst_ID, SQL_ID, Source, Count(*) Reports,
       ROUND(AVG((Last_Refresh_Time-SQL_Exec_Start)*86400), 3) \"Avg. duration Secs. per Exec.\",
       ROUND(SUM(Elapsed_Time_Secs), 3)                         \"Elapsed Secs Total\",
       ROUND(SUM(Elapsed_Time_Secs)/Count(*), 3)                \"Avg. Elapsed Secs per Exec\",
       MIN(SQL_Exec_Start) First_Occurrence, MAX(Last_Refresh_Time) Last_OCcurrence,
       MIN(UserName) Min_UserName, COUNT(DISTINCT UserName) Users,
       MIN(Module) Min_Module, COUNT(DISTINCT Module) Modules,
       MIN(SQL_Text) SQL_Text
FROM   (SELECT Inst_ID, SQL_ID, SQL_Exec_Start, Last_Refresh_Time, UserName, Module, SUBSTR(SQL_Text, 1, 100) SQL_Text,
               'gv$SQL_Monitor' Source, Elapsed_Time/1000000 Elapsed_Time_Secs
        FROM   gv$SQL_Monitor
        UNION ALL
        SELECT Instance_Number Inst_ID, Key1 SQL_ID, TO_DATE(r.Key3, 'MM:DD:YYYY HH24:MI:SS') SQL_Exec_Start, Period_End_Time Last_Refresh_Time,
               EXTRACTVALUE(XMLTYPE(REPORT_SUMMARY), '/report_repository_summary/sql/user')                     UserName,
               EXTRACTVALUE(XMLTYPE(REPORT_SUMMARY), '/report_repository_summary/sql/module')                   Module,
               SUBSTR(EXTRACTVALUE(XMLTYPE(REPORT_SUMMARY), '/report_repository_summary/sql/sql_text'),1, 100)  SQL_Text,
               'DBA_Hist_Reports' Source,
               EXTRACTVALUE(XMLTYPE(REPORT_SUMMARY), '/report_repository_summary/sql/stats/stat[@name=\"elapsed_time\"]')/1000000 Elapsed_Time_Secs
        FROM   DBA_HIST_Reports r
        WHERE  Period_End_Time > SYSDATE - ?
       )
WHERE  UserName NOT IN (#{system_schema_subselect})
GROUP BY Inst_ID, SQL_ID, Source
HAVING AVG((Last_Refresh_Time-SQL_Exec_Start)*86400) < ?
ORDER BY COUNT(*) DESC",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            {:name=>t(:dragnet_helper_170_param_1_name, :default=>'Maximum runtime per execution in seconds'), :size=>8, :default=>5, :title=>t(:dragnet_helper_170_param_1_hint, :default=>'Maximum runtime per execution in seconds for consideration in result') }
          ]
        },
        {
          :name  => t(:dragnet_helper_166_name, :default=>'Possible elimination of HASH JOIN BUFFERED by Parallel Shared Hash Join'),
          :desc  => t(:dragnet_helper_166_desc, :default=>"\
Since release 18c there's an undocumented feature Parallel Shared Hash Join which introduces sharing memory between parallel query slaves.
The needed memory is allocated in the new memory region MGA (Managed Global Area).
Especially expensive HASH JOIN BUFFERED operations with spilling a lot of data into temporary tablespace can be transformed to HASH JOIN SHARED with much less memory requirements and thus improved runtime.
This selection shows SQLs with HASH JOIN BUFFERED in the DB history ordered by the runtime they consume for this particular operation.

There are several ways to activate the Parallel Shared Hash Join:
- set '_px_shared_hash_join'=true; at system or session level
- define the PQ distribution strategy for a particular table in SQL by hint /*+ PQ_DISTRIBUTE(<table alias> SHARED NONE) */
- set '_px_shared_hash_join'=true; at SQL level by hint /*+ OPT_PARAM('_px_shared_hash_join' 'true') */
The latter option by OPT_PARAM fits best for me because behaviour can be controlled at SQL level without defining each table.

If this transformation works, then the HASH JOIN BUFFERED turns into HASH JOIN SHARED in the execution plan.

Respecting the unofficial state of this feature it should not be used in RAC environment if PQ operations are spread over several instances (parallel_force_local=FALSE).
Unfortunately, HASH JOIN OUTER BUFFERED cannot be transformed to HASH JOIN OUTER SHARED (at least until rel. 19.24).

Many thanks to Randolf Eberle-Geist, who shared backgrounds of this feature.
See also: https://chinaraliyev.wordpress.com/2019/04/29/parallel-shared-hash-join/
          "),
          :sql=> "\
WITH Min_Ash_Sample_ID AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, MIN(Sample_ID) Min_Sample_ID
                           FROM   gv$Active_Session_History
                           GROUP BY Inst_ID
                          )
SELECT Instance_Number, SQL_ID, u.UserName User_Name, SQL_Plan_Hash_Value, SQL_Plan_Line_ID,
       SUM(Seconds_Waiting) Seconds_Waiting, MAX(Max_Temp_MB) Max_Temp_MB,
       MIN(Min_Sample_Time) First_Occurrence, MAX(Max_Sample_Time) Last__Occurrence
FROM   (
        SELECT h.Instance_Number, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID,
               COUNT(*) * 10 Seconds_Waiting, MAX(h.Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
               MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, h.User_ID
        FROM   DBA_Hist_Active_Sess_History h
        JOIN   Min_Ash_Sample_ID m ON m.Inst_ID = h.Instance_Number
        WHERE  SQL_Plan_Operation = 'HASH JOIN'
        AND    SQL_Plan_Options = 'BUFFERED'
        AND    h.Sample_ID < m.Min_Sample_ID
        AND    h.Sample_Time > SYSDATE - ?
        AND    h.DBID = #{get_dbid}  /* do not count multiple times for multipe different DBIDs/ConIDs */
        GROUP BY h.Instance_Number, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID, h.User_ID
        UNION ALL
        SELECT h.Inst_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID,
               COUNT(*) Seconds_Waiting, MAX(h.Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
               MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, h.User_ID
        FROM   gv$Active_Session_History h
        WHERE  SQL_Plan_Operation = 'HASH JOIN'
        AND    SQL_Plan_Options = 'BUFFERED'
        GROUP BY h.Inst_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID, h.User_ID
       ) x
LEFT OUTER JOIN All_Users u ON u.User_ID = x.User_ID
GROUP BY Instance_Number, SQL_ID, u.UserName, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
HAVING SUM(Seconds_Waiting) > ?
ORDER BY Seconds_Waiting DESC
          ",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            {:name=>t(:dragnet_helper_param_minimal_elapsed_name, :default=>'Minimum total elapsed time (sec.)'), :size=>8, :default=>60, :title=>t(:dragnet_helper_param_minimal_elapsed_hint, :default=>'Minimum total elapsed time in seconds for consideration in selection') }
          ]
        },
        {
          :name  => t(:dragnet_helper_174_name, :default=>'Suppressed use of possibly expected parallel DML or direct load'),
          :desc  => t(:dragnet_helper_174_desc, :default=>"\
This selection shows SQL statements where parallel DML or direct load could or should be used, but is not really used.
'pdml reason' shows reason why parallel DML is not used for this statement.
'idl reason' shows reason why direct load is not used for this statement.
Parallel execution of DML is assumed to be used if PARALLEL DML is enabled in the session.
"),
          suppress_error_for_code: "ORA-06502",
          :sql=> "\
WITH Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, Plan_Hash_Value, PDML_Reason, IDL_Reason
               FROM   (SELECT SQL_ID, Plan_Hash_Value,
                              EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = \"pdml_reason\"]') PDML_Reason,
                              EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = \"idl_reason\"]') IDL_Reason
                       FROM   gv$SQL_Plan
                       WHERE  Other_XML LIKE '%pdml_reason%' OR Other_XML LIKE '%idl_reason%'
                       UNION  ALL
                       SELECT SQL_ID, Plan_Hash_Value,
                              EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = \"pdml_reason\"]') pdml_reason,
                              EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = \"idl_reason\"]') IDL_Reason
                       FROM   DBA_Hist_SQL_Plan
                       WHERE  DBID =  #{get_dbid} /* do not count multiple times for multiple different DBIDs/ConIDs */
                       AND    Other_XML LIKE '%pdml_reason%' OR Other_XML LIKE '%idl_reason%'
                      )
               WHERE  PDML_Reason IS NOT NULL OR IDL_Reason IS NOT NULL
               GROUP BY SQL_ID, Plan_Hash_Value, PDML_Reason, IDL_Reason /* DISTINCT */
              ),
     Min_Ash AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID),
     ASH AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, SUM(Elapsed_Secs) Elapsed_Secs
             FROM   (SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, COUNT(*) Elapsed_Secs
                     FROM   gv$Active_Session_History
                     GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
                     UNION ALL
                     SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, COUNT(*) * 10 Elapsed_Secs
                     FROM   DBA_Hist_Active_Sess_History h
                     JOIN   Min_Ash ma ON ma.Inst_ID = h.Instance_Number
                     WHERE  Sample_Time > SYSDATE - ?
                     AND    Sample_Time < ma.Min_Sample_Time
                     AND    DBID =  #{get_dbid} /* do not count multiple times for multiple different DBIDs/ConIDs */
                     GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
                    )
             WHERE  User_ID NOT IN (#{system_userid_subselect})
             GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
            )
SELECT /*+ LEADING(p) USE_HASH(ash) */
       p.SQL_ID, p.Plan_Hash_Value, p.PDML_Reason, p.IDL_Reason, u.UserName, SUM(ash.Elapsed_Secs) Elapsed_Secs
FROM   Plans p
JOIN   Ash ON ash.SQL_ID = p.SQL_ID AND ash.SQL_Plan_Hash_Value = p.Plan_Hash_Value
LEFT OUTER JOIN All_Users u ON u.User_ID = ash.User_ID
GROUP BY p.SQL_ID, p.Plan_Hash_Value, p.PDML_Reason, p.IDL_Reason, u.UserName
ORDER BY SUM(ash.Elapsed_Secs) DESC
          ",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
          ]
        },

    ]
  end # problems_with_parallel_query


end

