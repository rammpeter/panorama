# encoding: utf-8
module Dragnet::DragnetSqlsTuningSgaPgaHelper

  private

  def dragnet_sqls_tuning_sga_pga
    [
        {
            :name  => t(:dragnet_helper_96_name, :default=>'Identification of hot blocks in DB-cache: frequent access on small objects'),
            :desc  => t(:dragnet_helper_96_desc, :default=>"Statements with frequent read blocks in DB-cache cause risk of 'cache buffers chains' latch waits.
This selection scans for objects with high block access rate compared to size of object."),
            :sql=>  "SELECT /* DB-Tools Ramm Hot-Blocks im DB-Cache */*
                             FROM
                             (
                              SELECT /*+ NO_MERGE USE_HASH(o s) */
                                     s.Instance_Number Inst, o.Owner, o.Object_Name, o.SubObject_Name,
                                     o.Object_Type,
                                     s.Logical_Reads,
                                     Num_Rows,
                                     ROUND(s.Logical_Reads/Num_Rows,2) \"LReads/Row\",
                                     Buffer_Busy_Waits \"BufBusyW\", DB_Block_Changes \"BlockChg\", Physical_Reads \"Phys.Reads\",
                                     Physical_Writes \"Phys.Writes\", Physical_Reads_Direct \"Phys.Rd.Dir\",
                                     Physical_Writes_Direct \"Phys.Wr.Dir\", ITL_Waits, Row_Lock_Waits
                              FROM   (SELECT /*+ NO_MERGE */
                                             s.Instance_Number, s.Obj#, SUM(s.Logical_Reads_Delta) Logical_Reads,
                                             SUM(Buffer_Busy_Waits_Delta) Buffer_Busy_Waits,
                                             SUM(DB_Block_Changes_Delta) DB_Block_Changes,
                                             SUM(Physical_Reads_Delta) Physical_Reads,
                                             SUM(Physical_Writes_Delta) Physical_Writes,
                                             SUM(Physical_Reads_Direct_Delta) Physical_Reads_Direct,
                                             SUM(Physical_Writes_Direct_Delta) Physical_Writes_Direct,
                                             SUM(ITL_Waits_Delta) ITL_Waits,
                                             SUM(Row_Lock_Waits_Delta) Row_Lock_Waits
                                      FROM   DBA_Hist_Seg_Stat s,
                                             DBA_Hist_Snapshot t
                                      WHERE  t.DBID            = s.DBID
                                      AND    t.Instance_Number = s.Instance_Number
                                      AND    t.Snap_ID         = s.Snap_ID
                                      AND    t.Begin_Interval_Time > SYSDATE-? /* Anzahl Tage der Betrachtung rueckwirkend */
                                      GROUP BY s.Instance_Number, s.Obj#
                                     )s,
                                     (SELECT /*+ NO_MERGE */
                                             Owner, Object_Name, SubObject_Name, Object_Type, Object_ID,
                                             CASE
                                             WHEN Object_Type = 'TABLE' THEN (SELECT Num_Rows FROM DBA_Tables a
                                                                                WHERE a.Owner=o.Owner AND a.Table_Name=o.Object_Name)
                                             WHEN Object_Type = 'INDEX' THEN (SELECT Num_Rows FROM DBA_Indexes a
                                                                                WHERE a.Owner=o.Owner AND a.Index_Name=o.Object_Name)
                                             WHEN Object_Type = 'TABLE PARTITION' THEN (SELECT Num_Rows FROM DBA_Tab_Partitions a
                                                                                WHERE a.Table_Owner=o.Owner AND a.Table_Name=o.Object_Name AND a.Partition_Name=o.SubObject_Name)
                                             WHEN Object_Type = 'INDEX PARTITION' THEN (SELECT Num_Rows FROM DBA_Ind_Partitions a
                                                                                WHERE a.Index_Owner=o.Owner AND a.Index_Name=o.Object_Name AND a.Partition_Name=o.SubObject_Name)
                                             END Num_Rows
                                      FROM   DBA_Objects o
                                      WHERE  Object_Type IN ('TABLE', 'TABLE PARTITION', 'INDEX', 'INDEX PARTITION')
                                     ) o
                              WHERE  o.Object_ID = s.Obj#
                              AND    o.Num_Rows IS NOT NULL
                              AND    o.Num_Rows > 0               /* gewichtete Aussage wird wertlos*/
                              AND    s.Logical_Reads > 0
                              ORDER BY Logical_Reads/Num_Rows DESC NULLS LAST
                             ) s
                      WHERE Num_Rows < ?",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_96_param_1_name, :default=>'Maximum number of rows of table'), :size=>8, :default=>200, :title=>t(:dragnet_helper_96_param_1_hint, :default=>'Maximum number of rows of table for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_101_name, :default=>'Identification of hot blocks in DB-cache: suboptimal indexes'),
            :desc  => t(:dragnet_helper_101_desc, :default=>'Indexes with high fluctuation of data and consecutive content are successive scanning more DB-blocks per access if rows have been deleted.
Especially problematic is access to first records in index order of such moving windows.
This indexes may need cyclic reorganisation e.g. by ALTER INDEX SHRINK SPACE COMPACT or ALTER INDEX COALESCE for running OLTP-systems or ALTER INDEX REBUILD in appliction downtimes.
This selection scans for SQL statements in current SGA with access on indexes which possibly need reorganisation.'),
            :sql=>  "SELECT * FROM (
                      SELECT /*+ NO_MERGE MATERIALIZE */ p.Inst_ID \"Inst\", p.SQL_ID, p.Child_Number \"Child Number\", s.Executions \"Executions\",
                             ROUND(s.Elapsed_Time/1000000) \"Elapsed Time (Secs)\",
                             s.Buffer_Gets \"Buffer gets\", s.Rows_Processed \"Rows processed\",
                             ROUND(s.Rows_Processed/s.Executions,2) \"Rows per Exec.\",
                             ROUND(s.Buffer_Gets/s.Rows_Processed)  \"Buffer Gets per Row\",
                             s.SQL_Text, s.SQL_FullText
                      FROM   (
                              SELECT p.Inst_ID, p.SQL_ID, p.Child_Number
                              FROM   gv$SQL_Plan p
                              WHERE  Operation NOT IN ('PARTITION HASH')
                              AND    Options NOT IN ('STOPKEY')  -- RowNum-Abgrenzung ausfiltern
                              GROUP BY p.Inst_ID, p.SQL_ID, p.Child_Number
                              HAVING
                              -- Ausfuehrungsplan hat genau einen Index-Zugriff ohne Filter
                                     SUM(CASE WHEN p.Operation = 'INDEX' AND p.Options in ('RANGE SCAN', 'UNIQUE SCAN')
                                         THEN 1 ELSE 0 END
                                        ) = 1
                              -- Keine Filter
                              AND    SUM(CASE WHEN P.FILTER_PREDICATES IS NOT NULL
                                         THEN 1 ELSE 0 END
                                        ) = 0
                            -- Keine Gruppenfunktionen
                              AND    SUM(CASE WHEN p.ID = 1 AND p.Options IN ('GROUP BY', 'AGGREGATE')
                                         THEN 1 ELSE 0 END
                                        ) = 0
                              AND    COUNT(*) < ?
                             ) p
                      JOIN   gv$SQL s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number
                      WHERE  s.Rows_Processed > 0 -- Nur dann sinnvolle Werte
                      AND    s.Executions     > ? -- Nur relevante Ausfuehrungen
                      AND    s.Rows_Processed > s.Executions/? -- Nur dann sinnvolle Werte
                      )
                      WHERE LENGTH(REGEXP_REPLACE(SQL_Text, '[^:]','')) < ?  -- Anzahl Bindevariablen < x
                      AND    \"Buffer Gets per Row\" > ?                         -- nur problematische anzeigen
                      ORDER BY \"Buffer Gets per Row\" * \"Rows processed\" DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_101_param_1_name, :default=>'Maximum number of operations in execution plan'), :size=>8, :default=>5, :title=> t(:dragnet_helper_101_param_1_hint, :default=>'Maximum number of operations in execution plan of SQL')},
                         {:name=> t(:dragnet_helper_101_param_2_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_101_param_2_hint, :default=>'Minimum number of executions for consideration in selection')},
                         {:name=> t(:dragnet_helper_101_param_3_name, :default=>'Maximum number of bind variables'), :size=>8, :default=>5, :title=> t(:dragnet_helper_101_param_3_hint, :default=>'Maximum number of bind variables in statement')},
                         {:name=> t(:dragnet_helper_101_param_4_name, :default=>'Minimum number of rows processed / execution'), :size=>8, :default=>2, :title=> t(:dragnet_helper_101_param_4_hint, :default=>'Minimum number of rows processed / execution')},
                         {:name=> t(:dragnet_helper_101_param_5_name, :default=>'Minimum number of buffer gets / row'), :size=>8, :default=>5, :title=> t(:dragnet_helper_101_param_5_hint, :default=>'Minimum number of buffer gets / row')}]
        },
        {
            :name  => t(:dragnet_helper_102_name, :default=>'Check necessity of update for indexed columns'),
            :desc  => t(:dragnet_helper_102_desc, :default=>'Update of indexed columns of a table costs effort for index maintenance (Removal of old and insertion of new index entry) even if content of column did not change.
This way it is worth to remove indexed columns from UPDATE SQL statement if their values never change.
Especially this is true for generated dynamic SQL statements (e.g. from OR-mappers), which by default contains all columns of a table.'),
            :sql=>  "SELECT * FROM (
                      SELECt /*+ ORDERED */ p.*, t.SQL_Text, i.Column_Name,
                            (SELECT SUM(Executions_Delta) FROM DBA_Hist_SQLStat st
                            WHERE st.DBID=p.DBID AND st.SQL_ID=p.SQL_ID
                            ) Executions,
                            (SELECT SUM(Rows_Processed_Delta) FROM DBA_Hist_SQLStat st
                            WHERE st.DBID=p.DBID AND st.SQL_ID=p.SQL_ID
                            ) Rows_Processed
                      FROM   (
                                  SELECT /*+ NO_MERGE PARALLEL(p) */ DBID, SQL_ID, Object_Owner, Object_Name
                                  FROM   DBA_Hist_SQL_Plan p
                                  WHERE Operation = 'UPDATE'
                                  AND     Timestamp > SYSDATE-?
                                  ) p,
                                  DBA_Hist_SQLText t,
                                  (SELECt /*+ NO_MERGE */ Table_Owner, Table_Name, Column_Name FROM DBA_Ind_Columns
                                  ) i
                      WHERE t.DBID              = p.DBID
                      AND     t.SQL_ID          = p.SQL_ID
                      AND     i.Table_Owner = p.Object_Owner
                      AND     i.Table_Name   = p.Object_Name
                      AND     REGEXP_LIKE(
                                         SUBSTR(UPPER(t.SQL_Text), INSTR(UPPER(t.SQL_Text), 'SET'), INSTR(UPPER(t.SQL_Text), 'WHERE')-INSTR(UPPER(t.SQL_Text), 'SET')),
                                         '[ ,]'||i.Column_Name||'[ =]'
                                        )
                      )
                      WHERE Rows_Processed > ?
                      ORDER BY Rows_Processed DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_102_param_1_name, :default=>'Minimum number of rows processed'), :size=>8, :default=>10000, :title=> t(:dragnet_helper_102_param_1_hint, :default=>'Minimum number of rows processed for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_103_name, :default=>'System-statistics: Check for up-to-date system analyze info'),
            :desc  => t(:dragnet_helper_103_desc, :default=>'For cost-based optimizer system statistics should be enough up-to-date and describe reality'),
            :sql=> 'SELECT * FROM sys.Aux_Stats$',
        },
        {
            :name  => t(:dragnet_helper_104_name, :default=>'Objekt statistics: Check on up-to-date analyze info (Tables)'),
            :desc  => t(:dragnet_helper_104_desc, :default=>'For cost based optimizer object statistics should be sufficient up-to-date'),
            :sql=>  "SELECT /* DB-Tools Ramm Tabellen ohne bzw. mit veralteter Statistik */ t.Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed,
                             ROUND(s.MBytes,2) MBytes
                      FROM   DBA_Tables t
                      JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
                      WHERE  (Last_Analyzed IS NULL OR Last_Analyzed < SYSDATE-?)
                      AND    t.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'PERFSTAT', 'PATCH', 'NOALYZE', 'EXFSYS', 'SERVER', 'FLAGENT',
                                           'DB_MONITORING', 'DBSNMP', 'WMSYS', 'DBMSXSTATS', 'SYSMAN', 'TOOL', 'AFARIA', 'MONITOR',
                                           'XDB', 'MDSYS', 'ORDSYS', 'DMSYS', 'CTXSYS', 'TSMSYS')
                      AND    t.Owner NOT LIKE 'DBA%'
                      AND    t.Owner NOT LIKE 'PATROL%'
                      AND    Temporary = 'N'
                      ORDER BY s.MBytes DESC",
            :parameter=>[{:name=>t(:dragnet_helper_104_param_1_name, :default=>'Minimum age of existing analyze info in days'), :size=>8, :default=>100, :title=>t(:dragnet_helper_104_param_1_hint, :default=>'If analyze info exists: minimun age for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_108_name, :default=>'Objekt statistics: Check on up-to-date analyze info (Indexes)'),
            :desc  => t(:dragnet_helper_108_desc, :default=>'For cost based optimizer object statistics should be sufficient up-to-date'),
            :sql=>  "SELECT /* DB-TOoLs Ramm Indizes without e.g. with old statistics */ i.Owner, i.Table_Name, i.Index_Name, i.Num_Rows, i.Last_Analyzed
                      FROM   DBA_Indexes i
                      JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                      JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name) s ON s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
                      WHERE  (i.Last_Analyzed IS NULL OR i.Last_Analyzed < SYSDATE-?)
                      AND    i.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'PERFSTAT', 'PATCH', 'NOALYZE', 'EXFSYS', 'SERVER', 'FLAGENT',
                                           'DB_MONITORING', 'DBSNMP', 'WMSYS', 'DBMSXSTATS', 'SYSMAN', 'TOOL', 'AFARIA', 'MONITOR', 'XDB', 'MDSYS', 'ORDSYS',
                                           'CTXSYS', 'TSMSYS')
                      AND    i.Owner NOT LIKE 'DBA%'
                      AND    i.Owner NOT LIKE 'PATROL%'
                      AND    t.Temporary = 'N'
                      ORDER BY s.MBytes DESC",
            :parameter=>[{:name=>t(:dragnet_helper_108_param_1_name, :default=>'Minimum age of existing analyze info in days'), :size=>8, :default=>100, :title=>t(:dragnet_helper_108_param_1_hint, :default=>'If analyze info exists: minimun age for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_109_name, :default=>'PGA-Usage: Historic utilization of PGA-structures'),
            :desc  => t(:dragnet_helper_109_desc, :default=>'Insufficient supply of PGA-memory for sort and hash operations leads to transfer to TEMP-tablespace with according impact on performance'),
            :sql=>  "SELECT /*+ DB-Tools Ramm - PGA-Historie*/
                             ss.Begin_Interval_Time, p.Instance_Number,
                             ROUND(MAX(DECODE(p.Name, 'aggregate PGA target parameter'      , p.Value, 0))/(1024*1024)) \"PGA Aggregate Target (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'aggregate PGA auto target'           , p.Value, 0))/(1024*1024)) \"PGA Auto Target (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'global memory bound'                 , p.Value, 0))/(1024*1024)) \"global memory bound (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA inuse'                     , p.Value, 0))/(1024*1024)) \"total PGA inuse (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA allocated'                 , p.Value, 0))/(1024*1024)) \"total PGA allocated (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total freeable PGA memory'           , p.Value, 0))/(1024*1024)) \"total freeable PGA memory (MB)\",
                             MAX(DECODE(p.Name, 'process count'                             , p.Value, 0))              \"process count\",
                             MAX(DECODE(p.Name, 'max processes count'                       , p.Value, 0))              \"max processes count\",
                             ROUND(MAX(DECODE(p.Name, 'PGA memory freed back to OS'         , p.Value, 0))/(1024*1024)) \"PGA mem freed back (MB kum.)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA used for auto workareas'   , p.Value, 0))/(1024*1024)) \"total PGA Used Auto (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA used for manual workareas' , p.Value, 0))/(1024*1024)) \"total PGA used manual (MB)\",
                             MAX(DECODE(p.Name, 'over allocation count'                     , p.Value, 0)) -            -- Subtraktion Vorgaenger fuer Delta
                             (SELECT Value FROM DBA_hist_PgaStat i WHERE i.DBID=p.DBID AND i.Snap_ID=p.Snap_ID-1 AND I.INSTANCE_NUMBER = p.Instance_Number AND i.Name =  'over allocation count') \"over allocation count\",
                             MAX(DECODE(p.Name, 'cache hit percentage'   , p.Value, 0))                                 \"cache hit pct. (since startup)\"
                      FROM   DBA_hist_PgaStat p
                      JOIN   DBA_Hist_Snapshot ss ON ss.DBID = p.DBID AND ss.Instance_Number = p.Instance_Number AND ss.Snap_ID = p.Snap_ID
                      WHERE  p.Instance_Number = 1
                      AND    ss.Begin_Interval_Time > SYSDATE-?
                      GROUP BY ss.Begin_Interval_Time, p.Instance_Number, p.DBID, p.Snap_ID
                      ORDER BY ss.Begin_Interval_Time",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_110_name, :default=>'Concurrency on memory, latches: insufficient cached sequences'),
            :desc  => t(:dragnet_helper_110_desc, :default=>'Fetching of sequence values / filling the sequence cache causes writes in dictionary and interchange between REC-instances.
                          Highly frequent access on dictionary structures of sequences leads to unnecessary wait events, therefore you should define reasonable cache sizes for sequences.'),
            :sql=>  "SELECT /* DB-Tools Ramm insufficent cached sequences */ *
                      FROM   DBA_Sequences
                      WHERE  Sequence_Owner NOT IN ('SYS', 'SYSTEM')
                      ORDER  By Last_Number/DECODE(Cache_Size,0,1,Cache_Size) DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_111_name, :default=>'Concurrency on memory, latches: Overview over usage of sequences'),
            :desc  => t(:dragnet_helper_111_desc, :default=>'If sequences may be cached in application, next values must not be read from DB one by one.
                                                              This may reduce the number of roundtrips between application and database.'),
            :sql=>  "SELECT /* DB-Tools Ramm  Overview usage of sequences */ *
                      FROM   (
                              SELECT ROUND(Executions/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Executions_per_Day,
                                     ROUND(Rows_Processed/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Rows_Processed_per_Day,
                                     x.*
                              FROM   (
                                      SELECT /*+ ORDERED USE_HASH(p a s) */
                                             p.Inst_ID, a.Executions, a.Rows_Processed,
                                             ROUND(a.Rows_Processed/a.Executions,2) Rows_Per_Exec,
                                             TO_DATE(a.First_Load_Time, 'YYYY-MM_DD/HH24:MI:SS') First_Load_Time, a.Last_Active_Time,
                                             p.Object_Owner, p.Object_Name, s.Cache_Size,
                                             a.SQL_ID, a.SQL_Text
                                      FROM   (SELECT /*+ NO_MERGE */ * FROM gv$SQL_Plan WHERE Operation = 'SEQUENCE') p
                                      JOIN   (SELECT /*+ NO_MERGE */ * FROM gV$SQL WHERE Executions > 0) a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID AND a.Child_Number = p.Child_Number
                                      JOIN   (SELECT /*+ NO_MERGE */ * FROM DBA_Sequences) s ON s.Sequence_Owner = p.Object_Owner AND s.Sequence_Name = p.Object_Name
                                     ) x
                             )
                      ORDER BY Executions_per_Day DESC NULLS LAST"
        },
        {
            :name  => t(:dragnet_helper_112_name, :default=>'Active sessions (from AWR history DBA_Hist_Active_Sess_History)'),
            :desc  => t(:dragnet_helper_112_desc, :default=>'Number of simultaneously active sessions allows conclusions on system load.
                          Peak number of simultaneously active sessions can be the base for sizing of session-pools (e.g. for application server).'),
            :sql=>  "SELECT /*+ PARALLEL(s,4) DB-Tools Ramm: active sessions */
                             Sample_Time, count(*) \"Active Sessions\"
                      FROM   DBA_hist_Active_Sess_History s
                      WHERE  Sample_Time >SYSDATE - ?
                      AND    Instance_Number = ?
                      GROUP BY Sample_Time
                      ORDER BY 1",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}
            ]
        },
        {
            :name  => t(:dragnet_helper_113_name, :default=>'Parse activity'),
            :desc  => t(:dragnet_helper_113_desc, :default=>'Consideration of ratio parses vs. executes.
                                    For highly frequent parses you should look for alternatives like:
                                    - reuse of already parsed statements in application
                                    - usage of statement caches in application server or JDBC-driver
                                    - usage of DB-feature "session cached cursor"
              '),
            :sql=>  "SELECT /* DB-Tools Ramm Parse-Ratio single values */ s.*, ROUND(Executions/DECODE(Parses, 0, 1, Parses),2) \"Execs/Parse\"
                      FROM   (
                              SELECT s.SQL_ID, s.Instance_Number, Parsing_schema_Name, SUM(s.Executions_Delta) Executions,
                                     SUM(s.Parse_Calls_Delta) Parses
                              FROM   DBA_Hist_SQLStat s
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.SQL_ID, s.Instance_Number, Parsing_schema_Name
                             ) s
                      ORDER BY Parses DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_3_12_name, :default=> 'Non-optimal database configuration parameters'),
            :desc  => t(:dragnet_helper_3_12_desc, :default=> 'Detection of non-optimal or incompatible database parameters'),
            :sql=>  "SELECT /* DB-Tools Ramm DB-Parameter */
                             Inst_ID, Name, Value, 'Value should be 0 if cursor_sharing is used because lookup to session cached cursors is done before converting literals to bind variables' Description
                      FROM   gv$Parameter p
                      WHERE  Name = 'session_cached_cursors'
                      AND    Value != '0'
                      AND    EXISTS (SELECT 1 FROM gv$Parameter pi WHERE pi.Inst_ID=p.Inst_ID AND pi.Name='cursor_sharing' AND pi.value!='EXACT' )
                     ",
        },
    ]
  end

end