# encoding: utf-8
module Dragnet::DragnetSqlsTuningSgaPgaHelper

  private

  def dragnet_sqls_tuning_sga_pga
    [
        {
            :name  => t(:dragnet_helper_96_name, :default=>'Identification of hot blocks in DB-cache: frequent access on small objects'),
            :desc  => t(:dragnet_helper_96_desc, :default=>"Statements with frequent read blocks in DB-cache cause risk of 'cache buffers chains' latch waits.
This selection scans for objects with high block access rate compared to size of object."),
            :sql =>  "SELECT /*+ NO_MERGE USE_HASH(o s) */ /* DB-Tools Ramm Hot-Blocks im DB-Cache */
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
                              FROM   DBA_Hist_Seg_Stat s
                              JOIN   DBA_Hist_Snapshot t ON t.DBID = s.DBID AND t.Instance_Number = s.Instance_Number AND t.Snap_ID = s.Snap_ID
                              WHERE  t.Begin_Interval_Time > SYSDATE-? /* Anzahl Tage der Betrachtung rueckwirkend */
                              GROUP BY s.Instance_Number, s.Obj#
                             )s,
                             (SELECT /*+ NO_MERGE */ o.Owner, o.Object_Name, o.SubObject_Name, o.Object_Type, o.Object_ID,
                                     CASE
                                     WHEN Object_Type = 'TABLE' THEN t.Num_Rows
                                     WHEN Object_Type = 'INDEX' THEN i.Num_Rows
                                     WHEN Object_Type = 'TABLE PARTITION' THEN tp.Num_Rows
                                     WHEN Object_Type = 'INDEX PARTITION' THEN ip.Num_Rows
                                     END Num_Rows
                              FROM   DBA_Objects o
                              LEFT OUTER JOIN DBA_Tables          t  ON t.Owner = o.Owner AND t.Table_Name = O.Object_Name AND o.Object_Type = 'TABLE'
                              LEFT OUTER JOIN DBA_Indexes         i  ON i.Owner = o.Owner AND i.Index_Name = O.Object_Name AND o.Object_Type = 'INDEX'
                              LEFT OUTER JOIN DBA_Tab_Partitions  tp ON tp.Table_Owner = o.Owner AND tp.Table_Name = O.Object_Name AND tp.Partition_Name = o.SubObject_Name AND o.Object_Type = 'TABLE PARTITION'
                              LEFT OUTER JOIN DBA_Ind_Partitions  ip ON ip.Index_Owner = o.Owner AND ip.Index_Name = O.Object_Name AND ip.Partition_Name = o.SubObject_Name AND o.Object_Type = 'INDEX PARTITION'
                             ) o
                      WHERE  o.Object_ID = s.Obj#
                      AND    o.Num_Rows IS NOT NULL
                      AND    o.Num_Rows > 0               /* gewichtete Aussage wird wertlos*/
                      AND    o.Num_Rows < ?
                      AND    s.Logical_Reads > 0
                      ORDER BY Logical_Reads/Num_Rows DESC NULLS LAST",
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
            :name  => t(:dragnet_helper_110_name, :default=>'Concurrency on memory, latches: insufficient cached sequences from DBA_Sequences'),
            :desc  => t(:dragnet_helper_110_desc, :default=>'Fetching of sequence values / filling the sequence cache causes writes in dictionary and interchange between REC-instances.
                          Highly frequent access on dictionary structures of sequences leads to unnecessary wait events, therefore you should define reasonable cache sizes for sequences.
                          Starting with Rel. 19.10 the DYNAMIC SEQUENCE CACHE feature will automatically cover this issue if you set the cache size of a sequence > 0.'),
            :sql=>  "SELECT Sequence_Owner, Sequence_Name, Cache_size,
                            ROUND(suggested, 0-LENGTH(TO_CHAR(suggested))+1) \"Suggested Cache Size\",
                            Min_Value, Max_Value, Increment_By, Cycle_flag, Last_Number,
                            \"Pct. of max. value reached\", \"Values per day\", Created, Last_DDL_Time,
                            ROUND(\"Values per day\"/DECODE(Cache_Size,0,1,Cache_Size)) \"Cache reloads per day\"
                     FROM   (SELECT
                                    s.Sequence_Owner, s.Sequence_Name, s.Cache_size,
                                    ROUND((s.Last_Number-s.Min_Value)/(SYSDATE-o.Created)/24) Suggested, /* Based on strived one reload per hour */
                                    s.Min_Value, s.Max_Value, s.Increment_By,
                                    s.Cycle_flag, s.Last_Number,
                                    ROUND(s.Last_Number*100/s.Max_Value, 1) \"Pct. of max. value reached\",
                                    ROUND((s.Last_Number-s.Min_Value)/(SYSDATE-o.Created)) \"Values per day\",
                                    o.Created, o.Last_DDL_Time
                             FROM   DBA_Sequences s
                             LEFT OUTER JOIN   DBA_Objects o ON o.Owner = s.Sequence_Owner AND o.Object_Name = s.Sequence_Name AND o.Object_Type = 'SEQUENCE'
                             WHERE  Sequence_Owner NOT IN (#{system_schema_subselect})
                            ) x
                      WHERE \"Values per day\"/DECODE(Cache_Size,0,1,Cache_Size) > ?
                      ORDER  By \"Values per day\"/DECODE(Cache_Size,0,1,Cache_Size) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_110_param_1_name, :default=>'Minimum cache reloads per day'), :size=>8, :default=>100, :title=>t(:dragnet_helper_110_param_1_hint, :default=>'Minimum reloads per day (single sequence values or cache reloads) for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_111_name, :default=>'Concurrency on memory, latches: Overview over usage of sequences by SQLs'),
            :desc  => t(:dragnet_helper_111_desc, :default=>'If sequences may be cached in application, next values must not be read from DB one by one.
                                                              This may reduce the number of roundtrips between application and database.'),
            :sql=> "SELECT ROUND(Rows_Processed_per_Day/DECODE(Cache_Size, 0, 1, Cache_Size)) Cache_Reloads_Per_Day,
                           y.*
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
                                           a.SQL_ID, SUBSTR(a.SQL_Text, 1, 200) SQL_Text
                                    FROM   (SELECT /*+ NO_MERGE */ * FROM gv$SQL_Plan WHERE Operation = 'SEQUENCE') p
                                    JOIN   (SELECT /*+ NO_MERGE */ * FROM gV$SQL WHERE Executions > 0) a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID AND a.Child_Number = p.Child_Number
                                    JOIN   (SELECT /*+ NO_MERGE */ * FROM DBA_Sequences) s ON s.Sequence_Owner = p.Object_Owner AND s.Sequence_Name = p.Object_Name
                                   ) x
                           ) y
                    ORDER BY Rows_Processed_per_Day/DECODE(Cache_Size, 0, 1, Cache_Size) DESC NULLS LAST"
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