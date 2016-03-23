# encoding: utf-8
module Dragnet::UnnecessaryHighExecutionFrequencyHelper

  private

  def unnecessary_high_execution_frequency
    [
        {
            :name  => t(:dragnet_helper_87_name, :default=>'Excessive number of cache buffer accesses'),
            :desc  => t(:dragnet_helper_87_desc, :default=>'Access on DB-blocks in DB-cache(db-block-gets, consistent reads) may be critical by provoking "cache buffers chains"-latch waits if:
- excessive access targets to one or less DB-blocks reading or writing (Hot blocks im buffer-cache)
- excessive read access on many DB-blocks (may be critical even even if these blocks are widely spreaded in cache and are not hot blocks)
For both constellations problematic statements can be identified by number of block access between two AWR-snapshots.
'),
            :sql=> "SELECT /* DB-Tools Ramm CacheBuffer */ * FROM (
                      SELECT /*+ USE_NL(s t) */ s.*, SUBSTR(t.SQL_Text,1,600) \"SQL-Text\"
                      FROM (
                               SELECT /*+ NO_MERGE ORDERED */ s.SQL_ID, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000)                         \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Elapsed Time per Execute (Sec)\",
                                      ROUND(SUM(CPU_Time_Delta)/1000000)                             \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),8)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta),
                                          0, 1, SUM(Rows_Processed_Delta)),2)                        \"Buffer Gets per Result-Row\",
                                      SUM(Rows_Processed_Delta)                                      \"Rows Processed\",
                                      ROUND(SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Rows Processed per Execute\",
                                      SUM(ClWait_Delta)/1000000                                      \"Cluster Wait-Time (Sec)\",
                                      SUM(IOWait_Delta)/1000000                                      \"I/O Wait-Time (Sec)\",
                                      SUM(CCWait_Delta)/1000000                                      \"Concurrency Wait-Time (Sec)\",
                                      SUM(PLSExec_Time_Delta)/1000000                                \"PL/SQL Wait-Time (Sec)\",
                                      s.DBID
                               FROM   dba_hist_snapshot snap,
                                      DBA_Hist_SQLStat s
                               WHERE  snap.Snap_ID = s.Snap_ID
                               AND    snap.DBID                = s.DBID
                               AND    snap.Instance_Number     = s.instance_number
                               AND    snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                               HAVING MAX(Buffer_Gets_Delta) IS NOT NULL
                               ) s,
                               DBA_Hist_SQLText t
                      WHERE  t.DBID   = s.DBID
                      AND    t.SQL_ID = s.SQL_ID
                      ORDER BY \"max. BufferGets betw.snapshots\" DESC NULLS LAST
                      ) WHERE RowNum<?",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_87_param_1_name, :default=>'Maximum number of result rows'), :size=>8, :default=>100, :title=>t(:dragnet_helper_87_param_1_hint, :default=>'Maximum number of result rows for selection')}]
        },
        {
            :name  => t(:dragnet_helper_88_name, :default=>'Frequent access on small objects'),
            :desc  => t(:dragnet_helper_88_desc, :default=>'For frequent executed SELECT-statements on small objects it may be worth to cache this content instead of accessong by SQL.
This reduces CPU-contention and the risk of „Cache Buffers Chains“ latch-waits.
Beginning with 11g stored functions with function result caching or selects/subselects with result caching may be used for this purpose.
'),
            :sql=>  "SELECT /*+ USE_NL(t) \"DB-Tools Ramm Zugriff kleiner Objekte\" */ obj.Owner, Obj.Name, obj.Num_Rows, s.*, t.SQL_Text \"SQL-Text\"
                      FROM  (
                               SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, MIN(snap.Begin_Interval_Time) First_Occurrence, MAX(snap.End_Interval_Time) Last_Occurrence,
                                      s.Plan_Hash_Value, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000,4)                       \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),6)                            \"Elapsed Time per Execute (Sec)\",
                                      SUM(CPU_Time_Delta)/1000000                                    \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),6)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),6)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta),
                                          0, 1, SUM(Rows_Processed_Delta)),2)                        \"Buffer Gets per Result-Row\",
                                      SUM(Rows_Processed_Delta)                                      \"Rows Processed\",
                                      ROUND(SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Rows Processed per Execute\",
                                      ROUND(SUM(ClWait_Delta)/1000000,4)                             \"Cluster Wait-Time (Sec)\",
                                      ROUND(SUM(IOWait_Delta)/1000000,4)                             \"I/O Wait-Time (Sec)\",
                                      ROUND(SUM(CCWait_Delta)/1000000,4)                             \"Concurrency Wait-Time (Sec)\",
                                      ROUND(SUM(PLSExec_Time_Delta)/1000000,4)                       \"PL/SQL Wait-Time (Sec)\"
                               FROM   dba_hist_snapshot snap
                               JOIN   DBA_Hist_SQLStat s ON (s.Snap_ID=snap.Snap_ID AND s.DBID=snap.DBID AND s.instance_number=snap.Instance_Number)
                               WHERE  snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_number
                               HAVING SUM(Executions_Delta) > ?
                               ) s
                            JOIN   DBA_Hist_SQL_Plan p ON (p.DBID=s.DBID AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value)
                            JOIN   (SELECT Owner, Table_Name Name, Num_Rows FROM DBA_Tables WHERE Num_Rows < 100000
                                    UNION ALL
                                    SELECT Owner, Index_Name Name, Num_Rows FROM DBA_Indexes WHERE Num_Rows < 100000
                                   ) obj ON (obj.Owner = p.Object_Owner AND obj.Name = p.Object_Name)
                            JOIN   DBA_Hist_SQLText t  ON (t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)
                      WHERE Owner NOT IN ('SYS')
                      ORDER BY s.\"Executions\"/DECODE(obj.Num_Rows, 0, 1, obj.Num_Rows) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_88_param_1_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=>t(:dragnet_helper_88_param_1_hint, :default=>'Minimum number of executions for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_89_name, :default=>'Unnecessary high fetch count because of missing usage of array-fetch: evaluation of SGA'),
            :desc  => t(:dragnet_helper_89_desc, :default=>'For larger results per execution it is worth to access multiple records per fetch with bulk operation instead of single fetches.
This earns little reduction of CPU-contention and runtime.
'),
            :sql=> "SELECT * FROM (
                              SELECT Inst_ID, Parsing_Schema_Name \"Parsing schema name\",
                                     Module,
                                     SQL_ID, Executions, Fetches \"Number of fetches\",
                                     End_Of_Fetch_Count \"Number of fetches until end\",
                                     Rows_Processed \"Rows processed\",
                                     ROUND(Rows_Processed/Executions,2) \"Rows per exec\",
                                     ROUND(Fetches/Executions,2) \"Fetches per exec\",
                                     ROUND(Rows_Processed/Fetches,2) \"Rows per fetch\",
                                     ROUND(Elapsed_Time/1000000,2) \"Elapsed time (secs)\",
                                     ROUND(Executions * (MOD(Rows_Processed/Executions, 1000) / (Rows_Processed/Fetches) -1)) \"Additional Fetches\",
                                     SQL_FullText
                              FROM   GV$SQLArea s
                              WHERE  Fetches > Executions
                              AND    Fetches > 1
                              AND    Executions > 0
                              AND    Rows_Processed > 0
                              )
                              WHERE \"Fetches per exec\" > ?
                              ORDER BY \"Additional Fetches\" DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_60_param_1_name, :default=>'Min. number of fetches per execution'), :size=>8, :default=>100, :title=>t(:dragnet_helper_60_param_1_hint, :default=>'Minimum number of fetches per execution for consideration in result') },
            ]
        },
        {
            :name  => t(:dragnet_helper_90_name, :default=>'Unnecessary high fetch count because of missing usage of array-fetch: evaluation of AWH history'),
            :desc  => t(:dragnet_helper_90_desc, :default=>'For larger results per execution it is worth to access multiple records per fetch with bulk operation instead of single fetches.
This earns little reduction of CPU-contention and runtime.
'),
            :sql=> "SELECT s.*, (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID ) SQL_Text
                      FROM (
                      SELECT s.Instance_Number Instance, s.DBID, Parsing_Schema_Name, Module,
                             SQL_ID, SUM(Executions_Delta) Executions, SUM(Fetches_Delta) Fetches,
                             SUM(End_Of_Fetch_Count_Delta) End_Of_Fetch_Count, SUM(Rows_Processed_Delta) \"Rows Processed\",
                             ROUND(SUM(Rows_Processed_Delta)/SUM(Executions_Delta),2) \"Rows per Exec\",
                             ROUND(SUM(Fetches_Delta)/SUM(Executions_Delta),2)        \"Fetches per exec\",
                             ROUND(SUM(Rows_Processed_Delta)/SUM(Fetches_Delta),2)    \"Rows per Fetch\",
                             ROUND(SUM(Elapsed_Time_Delta)/1000000,2)                 \"Elapsed Time (Secs)\",
                             ROUND(SUM(Executions_delta) * (MOD(SUM(Rows_Processed_Delta)/SUM(Executions_Delta), 1000) /
                               (SUM(Rows_Processed_Delta)/SUM(Fetches_Delta)) -1))    \"Additional Fetches\"
                      FROM   DBA_Hist_SQLStat s
                      JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Snap_ID=s.Snap_ID AND ss.Instance_Number=s.Instance_Number
                                                  AND ss.Begin_Interval_Time > SYSDATE - ?
                      GROUP BY s.Instance_Number, s.DBID, s.Parsing_Schema_Name, s.Module, s.SQL_ID
                      HAVING SUM(Fetches_Delta) > SUM(Executions_Delta)
                      AND    SUM(Fetches_Delta) > 1
                      AND    SUM(Executions_Delta) > 0
                      AND    SUM(Rows_Processed_Delta) > 0
                      ) s
                      WHERE \"Fetches per exec\" > ?
                      ORDER BY \"Additional Fetches\" DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_59_param_2_name, :default=>'Min. number of fetches per execution'), :size=>8, :default=>100, :title=>t(:dragnet_helper_59_param_2_hint, :default=>'Minimum number of fetches per execution for consideration in result') },
            ]
        },
        {
            :name  => t(:dragnet_helper_91_name, :default=>'Writing statements with unnecessary high execution count due to missing array processing'),
            :desc  => t(:dragnet_helper_91_desc, :default=>'With less rows per execution and high execution count it is often worth to bundle processing with bulk operation or PL/SQL-FORALL-Operationen if they are processed in the same transaction.
This reduces CPU-contention and runtime.'),
            :sql=>  "SELECT /* DB-Tools Ramm: Buendelbare Einzeilsatz-Executes */ s.SQL_ID, s.Instance_Number Instance, Parsing_Schema_Name,
                             SUM(s.Executions_Delta) Executions,
                             ROUND(SUM(s.Elapsed_Time_Delta)/1000000) Elapsed_Time_Secs,
                             SUM(s.Rows_Processed_Delta) Rows_Processed,
                             ROUND(SUM(s.Rows_Processed_Delta)/SUM(s.Executions_Delta),2) Rows_per_Exec,
                             ROUND(SUM(s.Executions_Delta)/SUM(s.Rows_Processed_Delta),2) Execs_Per_Row,
                             MIN(TO_CHAR(SUBSTR(t.SQL_Text,1,3000))) SQL
                      FROM   DBA_Hist_SQLStat s
                      JOIN   DBA_Hist_SnapShot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                      JOIN   DBA_Hist_SQLText t ON t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID AND t.Command_Type IN (2,6,7) /* Insert, Update, Delete */
                      WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                      AND    Parsing_Schema_Name NOT IN ('SYS')
                      GROUP BY s.SQL_ID, s.Instance_Number, Parsing_Schema_Name
                      HAVING SUM(s.Executions_Delta) > ?
                      AND    SUM(s.Rows_Processed_Delta) > 0
                      ORDER BY SUM(Executions_Delta)*SUM(Executions_Delta)/SUM(Rows_Processed_Delta) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_61_param_1_name, :default=>'Min. number of executions'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_61_param_1_hint, :default=>'Minimum number of executions for consideration in result') },
            ]
        },
    ]

  end # unnecessary_high_execution_frequency

end