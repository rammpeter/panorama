# encoding: utf-8
module Dragnet::SqlsWrongExecutionPlanHelper

  private

  def sqls_wrong_execution_plan
    [
        {
            :name  => t(:dragnet_helper_92_name, :default=>'Identification of statements with alternating execution plans in history'),
            :desc  => t(:dragnet_helper_92_desc, :default=>'With this select alternating execution plans for unchanged SQLs can be detetcted in AWR-history.'),
            :sql=>  "SELECT SQL_ID, Plan_Variationen \"Plan count\",
                             ROUND(Elapsed_Time_Secs_First_Plan) \"Elapsed time (sec.) first plan\",
                             Executions_First_Plan \"Execs. first plan\",
                             ROUND(Elapsed_Time_Secs_First_Plan/DECODE(Executions_First_Plan, 0, 1, Executions_First_Plan), 4) \"Secs. per exec first plan\",
                             ROUND(Elapsed_Time_Secs_Last_Plan) \"Elapsed time (sec.) last plan\",
                             Executions_Last_Plan \"Execs. last plan\",
                             ROUND(Elapsed_Time_Secs_Last_Plan/DECODE(Executions_Last_Plan, 0, 1, Executions_Last_Plan), 4) \"Secs. per exec last plan\",
                             First_Occurence_SQL \"First occurrence of SQL\", Last_Occurence_SQL \"Last Occurrence of SQL\",
                             Last_Occurrence_First_Plan \"Last occurrence of first plan\", First_Occurence_Last_Plan \"First occurrence of last plan\",
                             SUBSTR(SQL_Text,1, 200) \"SQL-Text\"
                      FROM   (
                              SELECT SQL_ID,
                                     (SELECT SQL_TExt FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID
                                     ) SQL_Text,
                                     COUNT(*) Plan_Variationen,
                                     MIN(Elapsed_Time_Secs) KEEP (DENSE_RANK FIRST ORDER BY First_Occurence)  Elapsed_Time_Secs_First_Plan,
                                     MIN(Executions) KEEP (DENSE_RANK FIRST ORDER BY First_Occurence)         Executions_First_Plan,
                                     MAX(Elapsed_Time_Secs) KEEP (DENSE_RANK LAST ORDER BY First_Occurence)   Elapsed_Time_Secs_Last_Plan,
                                     MAX(Executions) KEEP (DENSE_RANK LAST ORDER BY First_Occurence)          Executions_Last_Plan,
                                     MIN(First_Occurence)                                                     First_Occurence_SQL,
                                     MAX(Last_Occurence)                                                      Last_Occurence_SQL,
                                     MIN(Last_Occurence)                                                      Last_Occurrence_First_Plan,
                                     MAX(First_Occurence)                                                     First_Occurence_Last_Plan
                              FROM   (
                                      SELECT s.DBID, s.Instance_Number, s.SQL_ID,
                                             MIN(ss.Begin_Interval_Time) First_Occurence,
                                             MAX(ss.End_Interval_Time) Last_Occurence,
                                             SUM(Elapsed_Time_Delta)/1000000 Elapsed_Time_Secs,
                                             SUM(Executions_Delta) Executions
                                      FROM   DBA_Hist_SQLStat s
                                      JOIN   DBA_Hist_SnapShot ss ON ss.DBID=ss.DBID AND ss.Instance_number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                      WHERE ss.Begin_Interval_Time > SYSDATE-?
                                      AND    s.Plan_Hash_Value != 0   -- count only real execution plans
                                      GROUP BY s.DBID, s.Instance_Number, s.SQL_ID, s.Plan_Hash_Value
                                     ) s
                              GROUP BY DBID, Instance_Number, SQL_ID
                              HAVING COUNT(*) > 1
                             )
                      ORDER BY \"Secs. per exec last plan\"  * (Executions_First_Plan+Executions_Last_Plan) -
                               \"Secs. per exec first plan\" * (Executions_First_Plan+Executions_Last_Plan) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_93_name, :default=>'Nested loop join on large tables with large result of SQL (consideration of current SGA)'),
            :desc  => t(:dragnet_helper_93_desc, :default=>'Frequently executed nested loop operations on large (not fitting into DB-cache) tables may cause large runtime of SQL.
Listed statements should be checked for use of hash join instead.
This statement executes only for current (login) RAC-instance. Please execute separate for every RAC-instance (due to extremly large runtimes accessing GV$-tables).'),
            :sql=>  "SELECT /* DB-Tools Ramm Nested Loop auf grossen Tabellen */ * FROM (
                      SELECT /*+ PARALLEL(p,2) PARALLEL(s,2) */
                             s.SQL_FullText, p.SQL_ID, p.Plan_Hash_Value, p.operation, p.Object_Type,  p.options, p.Object_Name,
                             ROUND(s.Elapsed_Time/1000000) Elapsed_Secs, s.Executions, s.Rows_Processed,
                             ROUND(s.Rows_Processed/DECODE(s.Executions,0,1,s.Executions),2) Rows_Per_Execution,
                             CASE WHEN p.Object_Type = 'TABLE' THEN (SELECT /*+ NO_MERGE */ Num_Rows FROM DBA_Tables t WHERE t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name)
                                  WHEN p.Object_Type LIKE 'INDEX%' THEN (SELECT /*+ NO_MERGE */ Num_Rows FROM DBA_Indexes i WHERE i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name)
                             END Num_Rows
                      FROM   (
                              WITH Plan AS (SELECT /*+ MATERIALIZE  */
                                                   p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.ID, p.Parent_ID
                                            FROM   V$SQL_Plan p
                                           )
                              SELECT /*+ NO_MERGE PARALLEL(pnl,4) PARALLEL(pt1,4) PARALLEL(pf,4) PARALLEL(pt2,4)*/ DISTINCT pnl.SQL_ID, pnl.Plan_Hash_Value,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Operation    ELSE pt2.Operation    END Operation,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Type  ELSE pt2.Object_Type  END Object_Type,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Options      ELSE pt2.Options      END Options,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Owner ELSE pt2.Object_Owner END Object_Owner,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Name  ELSE pt2.Object_Name  END Object_Name
                              FROM   Plan pnl -- Nested Loop-Zeile
                              JOIN   Plan pt1  ON  pt1.SQL_ID          = pnl.SQL_ID       -- zweite Zeile unter Nested Loop (iterativer Zugriff)
                                               AND pt1.Plan_Hash_Value = pnl.Plan_Hash_Value
                                               AND pt1.Parent_ID       = pnl.ID
                              JOIN   Plan pf  ON  pf.SQL_ID          = pt1.SQL_ID         -- erste Zeile unter Nested Loop (Datenherkunft)
                                              AND pf.Plan_Hash_Value = pt1.Plan_Hash_Value
                                              AND pf.Parent_ID       = pnl.ID
                                              AND pf.ID              < pt1.ID        -- 1. ID ist Herkunft, 2. ID ist Iteration
                              LEFT OUTER JOIN Plan pt2  ON  pt2.SQL_ID          = pnl.SQL_ID -- zweite Ebene der zweiten Zeile unter nested Loop
                                                        AND pt2.Plan_Hash_Value = pnl.Plan_Hash_Value
                                                        AND pt2.Parent_ID       = pt1.ID
                              WHERE  pnl.Operation = 'NESTED LOOPS'
                              AND    (    pt1.Operation IN ('TABLE ACCESS', 'INDEX')
                                      OR  pt2.Operation IN ('TABLE ACCESS', 'INDEX')
                                     )
                              AND    pt1.Operation NOT IN ('HASH JOIN', 'NESTED LOOPS', 'VIEW', 'MERGE JOIN', 'PX BLOCK')
                             ) p
                      JOIN   v$SQL s         ON  s.SQL_ID             = p.SQL_ID
                                             AND s.Plan_Hash_Value    = p.Plan_Hash_Value
                                             AND s.Rows_Processed/DECODE(s.Executions,0,1,s.Executions) > ? -- Schwellwert fuer mgl. Ineffizienz NestedLoop
                      )
                      ORDER BY Rows_Per_Execution*Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_93_param_1_name, :default=>'Minimum number of rows processed / execution'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_93_param_1_hint, :default=>'Minimum number of rows processed / execution as threshold for possible inefficieny of nested loop')}]
        },
        {
            :name  => t(:dragnet_helper_94_name, :default=>'Iteration in nested-loop join against full scan operation'),
            :desc  => t(:dragnet_helper_94_desc, :default=>'Frequent execution of full scan operation by iteration in nested loop join may result in exorbitant number of block access massive contention of CPU and I/O-ressources.
It may also activate cache buffers chains latch-waits.
This access my be acceptable, if controlling result for nested loop has only one or less records.
Statement executes only for current connected RAC-Instance (due to runtime prblem otherwise), so it must be executed separately for every instance.'),
            :sql=>  "SELECT p.Inst_ID, p.SQL_ID, s.Executions, s.Elapsed_Time/1000000 Elapsed_time_Secs, p.Child_Number, p.Plan_Hash_Value,
                             p.Operation, p.Options, p.Object_Owner, Object_Name, p.ID, s.SQL_FullText
                      FROM   (
                              WITH Plan AS (SELECT /*+ MATERIALIZE  */
                                                   p.Inst_ID, p.SQL_ID, p.Child_Number, p.Plan_Hash_Value,
                                                   p.Inst_ID||'|'||p.SQL_ID||'|'||p.Child_Number||'|'||p.Plan_Hash_Value SQL_Ident,
                                                   p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.ID, p.Parent_ID
                                            FROM   gV$SQL_Plan p
                                           )
                              SELECT pnl2.*    -- Daten der zweiten Zeile unter Nested Loop (ueber die iteriert wird)
                              FROM   Plan pnl -- Nested Loop-Zeile
                              JOIN   Plan pnl1 ON  pnl1.SQL_Ident      = pnl.SQL_Ident      -- erste Zeile unter Nested Loop (Datenherkunft)
                                               AND pnl1.Parent_ID      = pnl.ID
                              JOIN   Plan pnl2 ON  pnl2.SQL_Ident      = pnl1.SQL_Ident       -- zweite Zeile unter Nested Loop (iterativer Zugriff)
                                               AND pnl2.Parent_ID      = pnl.ID
                                               AND pnl1.ID             < pnl2.ID             -- 1. ID ist Herkunft, 2. ID ist Iteration des NL
                              LEFT OUTER JOIN   Plan sub1 ON sub1.SQL_Ident = pnl2.SQL_Ident AND sub1.Parent_ID = pnl2.ID
                              LEFT OUTER JOIN   Plan sub2 ON sub2.SQL_Ident = pnl2.SQL_Ident AND sub2.Parent_ID = sub1.ID
                              LEFT OUTER JOIN   Plan sub3 ON sub3.SQL_Ident = pnl2.SQL_Ident AND sub3.Parent_ID = sub2.ID
                              LEFT OUTER JOIN   Plan sub4 ON sub4.SQL_Ident = pnl2.SQL_Ident AND sub4.Parent_ID = sub3.ID
                              LEFT OUTER JOIN   Plan sub5 ON sub5.SQL_Ident = pnl2.SQL_Ident AND sub5.Parent_ID = sub4.ID
                              WHERE  pnl.Operation = 'NESTED LOOPS'
                              AND  (    pnl2.Options LIKE '%FULL%'
                                     OR sub1.Options LIKE '%FULL%'
                                     OR sub2.Options LIKE '%FULL%'
                                     OR sub3.Options LIKE '%FULL%'
                                     OR sub4.Options LIKE '%FULL%'
                                     OR sub5.Options LIKE '%FULL%'
                                   )
                             ) p
                      JOIN   gv$SQL s ON  s.Inst_ID         = p.Inst_ID
                                      AND s.SQL_ID          = p.SQL_ID
                                      AND s.Child_Number    = p.Child_Number
                                      AND s.Plan_Hash_Value = p.Plan_Hash_Value
                      WHERE  p.Object_Owner NOT IN ('SYS')
                      ORDER BY Elapsed_Time DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_95_name, :default=>'Implicit conversion by TO_NUMBER or INTERNAL_FUNCTION (prevented usage of indexes)'),
            :desc  => t(:dragnet_helper_95_desc, :default=>'Implicit type conversions are often accidentially due to wrong type of bind variable.
This conversion may lead to missing usage of existing indizes and cause unnecessary I/O and CPU load.
Especially implicit conversion by TO_NUMBER while accessing VARCHAR2-columns with number bind type prevents usage of existing indizes.
For this cases data type according to column type should be used for bind variable.'),
            :sql=>  "SELECT /*+ ORDERED USE_HASH(p s) */
                              p.Inst_ID                     \"Inst.\",
                              s.SQL_ID                      \"SQL-ID\",
                              p.Child_Number                \"Child number\",
                              s.Parsing_Schema_Name         \"Parsing schema name\",
                              s.Plan_Hash_Value             \"Plan hash value\",
                              ROUND(s.Elapsed_Time/1000000) \"Elapsed secs.\",
                              ROUND(CPU_Time/1000000)       \"CPU secs.\",
                              Executions                    \"Execs.\",
                              Rows_Processed                \"Rows processed\",
                              p.ID                          \"SQL plan line ID\",
                              p.Reason                      \"Reason for selection\",
                              p.Operation                   \"Operation\",
                              p.Options                     \"Options\",
                              p.Object_Type                 \"Object type\",
                              p.Object_Owner                \"Owner\",
                              p.Object_Name                 \"Object name\",
                              p.Object_Alias                \"Alias in SQL\",
                              t.Num_Rows                    \"Num rows of table\",
                              p.Column_Name                 \"Affected column name\",
                              ic.Index_Name                 \"Existing index for aff. column\",
                              ic.Column_Position            \"Position of column in index\",
                              CASE WHEN tc.Num_Distinct > 0 THEN ROUND((t.Num_Rows-tc.Num_Nulls) / tc.Num_Distinct,1) ELSE NULL END \"Rows per key of column\",
                              p.Access_Predicates,
                              p.Filter_Predicates,
                              s.SQL_Text
                       FROM   (SELECT /*+ NO_MERGE */ pi.*,
                                              SUBSTR(Hit_Fragment,
                                                      INSTR(Hit_Fragment, '.')+2,
                                                      INSTR(Hit_Fragment, ')')-INSTR(Hit_Fragment, '.')-3
                                             )  Column_Name
                               FROM   (SELECT Inst_ID, SQL_ID, Child_Number, Plan_Hash_Value, ID, Access_Predicates, Filter_Predicates,
                                              Object_Owner, Object_Name, object_Alias, Object_Type, Operation, Options,
                                              CASE WHEN Filter_Predicates LIKE '%TO_NUMBER(\"%\".\"%\")=%' THEN 'TO_NUMBER' ELSE 'INTERNAL_FUNCTION' END Reason,
                                              CASE WHEN Filter_Predicates LIKE '%TO_NUMBER(\"%\".\"%\")=%' THEN
                                                SUBSTR(Filter_Predicates, INSTR(Filter_Predicates, 'TO_NUMBER(\"')+11)
                                              ELSE
                                                SUBSTR(Filter_Predicates, INSTR(Filter_Predicates, 'INTERNAL_FUNCTION(\"')+11)
                                              END Hit_Fragment
                                       FROM   gv$SQL_PLan pi
                                       WHERE  (    Filter_Predicates like '%TO_NUMBER(\"%\".\"%\")=%'
                                               OR  Filter_Predicates LIKE '%INTERNAL_FUNCTION%'
                                              )
                                       AND    Object_Owner IS NOT NULL AND Object_Name IS NOT NULL  /* Dont show conditions on filter or view */
                                      ) pi
                              ) p
                       JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Child_Number, Plan_Hash_Value, Executions, Elapsed_Time, Rows_Processed, CPU_Time,
                                      Parsing_Schema_Name, SQL_Text
                               FROM   gv$SQL
                               WHERE  Parsing_Schema_Name NOT IN ('SYS')
                               AND    Elapsed_Time/1000000 > ?
                              ) s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number AND s.Plan_Hash_Value = p.Plan_Hash_Value
                       LEFT OUTER JOIN DBA_Ind_Columns ic ON ((p.Object_Type = 'INDEX' AND ic.Index_Owner = p.Object_Owner AND ic.Index_Name = p.Object_Name) OR (p.Object_Type = 'TABLE' AND ic.Table_Owner = p.Object_Owner AND ic.Table_Name = p.Object_Name))
                                                          AND ic.Column_Name = p.Column_Name
                       LEFT OUTER JOIN DBA_Tables t ON t.Owner = ic.Table_Owner AND t.Table_Name = ic.Table_Name
                       LEFT OUTER JOIN DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = p.Column_Name
                       ORDER BY ic.Column_Position NULLS LAST, Elapsed_Time DESC NULLS LAST
             ",
            :parameter=>[
                {:name=>t(:dragnet_helper_95_param1_name, :default=>'Min. elapsed time of SQL in sec.'), :size=>30, :default=>100, :title=>t(:dragnet_helper_95_param1_desc, :default=>'Minimum elapsed time of SQL in gv$SQLArea for consideration in result') },
            ]
        },
        {
            :name  => t(:dragnet_helper_55_name, :default => 'Problematic usage of cartesian joins (from current SGA)'),
            :desc  => t(:dragnet_helper_55_desc, :default => 'Cartesian joins may be problematic in case of joining two large results without join condition.
Problems may be targeted by execution time of SQL or size of affected tables.
Results are from GV$SQL_Plan'),
            :sql=>  "SELECT /*+ USE_HASH(p s i t) LEADING(p) */ p.Inst_ID, p.SQL_ID, p.Child_Number, p.Operation, p.Options, p.Object_Owner, p.Object_Name, NVL(i.Num_Rows, t.Num_Rows) Num_Rows,
                             s.Executions, s.Elapsed_Time/1000000 Elapsed_Time_Secs,
                             p.ID Line_ID, p.Parent_ID
                      FROM   (WITH plans AS (SELECT /*+ NO_MERGE */ *
                                             FROM   gv$SQL_Plan
                                             WHERE  (Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number) IN (SELECT Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number
                                                                                                         FROM gv$SQL_Plan
                                                                                                         WHERE  options = 'CARTESIAN'
                                                                                                        )
                                            )
                              SELECT /*+ NO_MERGE */ Level, plans.*
                              FROM   plans
                              CONNECT BY PRIOR Inst_ID = Inst_ID AND PRIOR SQL_ID=SQL_ID AND  PRIOR Plan_Hash_Value = Plan_Hash_Value AND  PRIOR child_number = child_number AND PRIOR  id = parent_id AND PRIOR Object_Name IS NULL -- Nur Nachfolger suchen so lange Vorgänger kein Object_Name hat
                              START WITH options = 'CARTESIAN'
                             ) p
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Child_Number, Executions, Elapsed_Time
                              FROM gv$SQL
                             ) s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number
                      LEFT OUTER JOIN DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name
                      LEFT OUTER JOIN DBA_Tables t  ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                      WHERE Object_Name IS NOT NULL  -- Erstes Vorkommen von ObjectName in der Parent-Hierarchie nutzen
                      AND   Object_Owner != NVL(?, 'Hugo')
                      AND   Elapsed_Time/1000000 > ?
                      ORDER BY s.Elapsed_Time DESC, s.SQL_ID, s.Child_Number
            ",
            :parameter=>[
                {:name=>t(:dragnet_helper_55_param1_name, :default=>'Exclusion of object owners'), :size=>30, :default=>'SYS', :title=>t(:dragnet_helper_55_param1_desc, :default=>'Exclusion of single object owners from result') },
                {:name=>t(:dragnet_helper_55_param2_name, :default=>'Minimum total execution time of SQL (sec.)'), :size=>10, :default=>100, :title=>t(:dragnet_helper_55_param2_desc, :default=>'Minimum total execution time of SQL in SGA in seconds') },
            ]
        },
        {
            :name  => t(:dragnet_helper_56_name, :default => 'Problematic usage of cartesian joins (from AWR history)'),
            :desc  => t(:dragnet_helper_56_desc, :default => 'Cartesian joins may be problematic in case of joining two large results without join condition.
Problems may be targeted by execution time of SQL or size of affected tables.
Results are from DBA_Hist_SQL_Plan'),
            :sql=>  "SELECT ps.*,
                             (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner = ps.Object_Owner AND i.Index_Name = ps.Object_Name) Num_Rows_Index,
                             (SELECT Num_Rows FROM  DBA_Tables t WHERE t.Owner = ps.Object_Owner AND t.Table_Name = ps.Object_Name) Num_Rows_Table
                      FROM   (
                              SELECT /*+ LEADING(p) */ s.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.ID Line_ID, p.Parent_ID,
                                     SUM(s.Executions_Delta) Executions, SUM(s.Elapsed_Time_Delta/1000000) Elapsed_Time_Secs
                              FROM   (WITH plans AS (SELECT /*+ NO_MERGE LEADING(i) USE_NL(i o) */ o.*
                                                     FROM   (SELECT /*+ PARALLEL(i,2) */ DISTINCT DBID, SQL_ID, Plan_Hash_Value FROM DBA_Hist_SQL_Plan i WHERE options = 'CARTESIAN') i
                                                     JOIN   DBA_Hist_SQL_Plan o ON o.DBID=i.DBID AND o.SQL_ID=I.SQL_ID AND o.Plan_Hash_Value = i.Plan_Hash_Value
                                                    )
                                      SELECT /*+ NO_MERGE */ Level, plans.*
                                      FROM   plans
                                      CONNECT BY PRIOR DBID = DBID AND PRIOR SQL_ID=SQL_ID AND  PRIOR Plan_Hash_Value = Plan_Hash_Value AND PRIOR  id = parent_id AND PRIOR Object_Name IS NULL  -- Nur Nachfolger suchen so lange Vorgänger kein Object_Name hat
                                      START WITH options = 'CARTESIAN'
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = p.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE Object_Name IS NOT NULL -- Erstes Vorkommen von ObjectName in der Parent-Hierarchie nutzen
                              AND   ss.Begin_Interval_Time > SYSDATE - ?
                              AND   p.Object_Owner != NVL(?, 'Hugo')
                              GROUP BY s.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.ID, p.ID, p.Parent_ID
                             ) ps
                      WHERE   Elapsed_Time_Secs > ?
                      ORDER BY Elapsed_Time_Secs DESC, SQL_ID, Plan_Hash_Value
                      ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=>t(:dragnet_helper_56_param1_name, :default=>'Exclusion of object owners'), :size=>30, :default=>'SYS', :title=>t(:dragnet_helper_56_param1_desc, :default=>'Exclusion of single object owners from result') },
                {:name=>t(:dragnet_helper_56_param2_name, :default=>'Minimum total execution time of SQL (sec.)'), :size=>10, :default=>100, :title=>t(:dragnet_helper_56_param2_desc, :default=>'Minimum total execution time of SQL in SGA in seconds') },
            ]
        },
        {
            :name  => t(:dragnet_helper_100_name, :default => 'DELETE-operations replaceable by TRUNCATE'),
            :desc  => t(:dragnet_helper_100_desc, :default => 'Delete-operations on tables without filter should be replaced by TRUNCATE TABLE.
This reduces runtime, redo-contention and ensures reset of high water mark'),
            :sql=>  " SELECT *
                      FROM   (
                              SELECT 'SGA' Source, inst_ID, SQL_ID, TO_CHAR(SUBSTR(SQL_FullText, 1, 1000)) SQL_Text, ROUND(Elapsed_Time/1000000,2) Elapsed_Time_Secs, Executions
                              FROM   gv$SQLArea
                              WHERE /*+ ORDERED_PREDICATED */
                                    Command_Type = 7  -- DELETE
                              AND   (    REGEXP_LIKE(SQL_FullText, 'FROM+ [[:alpha:]_]+$', 'i')
                                    )
                              UNION ALL
                              SELECT 'AWR' Source, s.Instance_Number,  t.SQL_ID, t.SQL_Text, ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs, SUM(Executions_Delta) Executions
                              FROM   (
                                      SELECT DBID, SQL_ID, TO_CHAR(SUBSTR(t.SQL_Text, 1, 1000)) SQL_Text
                                      FROM   DBA_Hist_SQLText t
                                      WHERE /*+ ORDERED_PREDICATED */
                                            Command_Type = 7  -- DELETE
                                      AND   (    REGEXP_LIKE(t.SQL_Text, 'FROM+ [[:alpha:]_]+$', 'i')
                                            )
                                    ) t
                              JOIN  DBA_Hist_SQLStat s ON s.DBID = t.DBID AND s.SQL_ID=t.SQL_ID
                              JOIN  DBA_Hist_Snapshot ss ON ss.DBID=t.DBID AND ss.Snap_ID=s.Snap_ID AND ss.Instance_Number = s.Instance_Number
                              WHERE ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.Instance_Number, t.SQL_ID, t.SQL_Text
                             )
                      ORDER BY Elapsed_Time_Secs DESC
                    ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            ]
        },
    ]
  end


end