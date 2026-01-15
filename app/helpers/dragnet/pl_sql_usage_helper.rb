# encoding: utf-8
module Dragnet::PlSqlUsageHelper

  private

  def pl_sql_usage
    [
        {
            :name  => t(:dragnet_helper_58_name, :default=>'Usage of NVL with function call as alternative parameter'),
            :desc  => t(:dragnet_helper_58_desc, :default=>'Function NVL calculates expression in parameter 2 always, whether first parameter of NVL is NULL or not.
    For extensive calculations in expression for parameter 2 of NVL you should use COALESCE instead. This calculates expression for alternative only if decision parameter is really NULL.'),
            :sql=>  "
SELECT SQL_ID, Inst_ID, Parsing_Schema_Name, ROUND(Elapsed_Secs) Elapsed_Secs, Executions,
       NVL_Level \"NVL-Occurrence in SQL\", Char_Level Open_Bracket_Position, SUBSTR(NVL_Substr, 1, Min_Ende_Pos) NVL_Parameter
FROM   (
        SELECT x.*,
               MIN(CASE WHEN Opened-Closed=1 AND Char_=',' THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Komma_Pos,
               MIN(CASE WHEN Char_Level> 3 /* Laenge von NVL */ AND Opened-Closed=0 /* Alle Klammern wieder geschlossen */ THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Min_Ende_Pos
        FROM   (
                SELECT /*+ USE_MERGE(t pump100000) */ SQL_ID, Inst_ID, Parsing_Schema_Name, Elapsed_Secs, Executions, NVL_Level, Char_Level, SUBSTR(NVL_Substr, Char_Level, 1) Char_, NVL_Substr,
                       CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN Char_Level ELSE NULL END Klammer_Open,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Opened,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = ')' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Closed
                FROM   (
                        SELECT /*+ NO_MERGE USE_MERGE(a pump1000) */ NVL_Level,
                               -- INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) NVL_Position,
                               TO_CHAR(SUBSTR(a.First_NVL_Substr, INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level)+3, 3800)) NVL_Substr, /* SQL-String nach dem xten NVL bis zum Ende, mit max. 4000 Zeichen (incl. multibyte) als Char fuehren */
                               a.SQL_ID, a.Inst_ID, a.Parsing_Schema_Name, a.Elapsed_Secs, a.Executions
                        FROM   (
                                SELECT /*+ NO_MERGE */ a.SQL_ID, a.Inst_ID, a.Parsing_Schema_Name, a.Elapsed_Secs, a.Executions,
                                                       REPLACE(UPPER(SUBSTR(ai.SQL_FullText, INSTR(UPPER(ai.SQL_FullText), 'NVL'))), 'NVL2', '') First_NVL_Substr /* NVL+ nachfolgende Sequenz aber ohne NVL2 */
                                FROM   (
                                        SELECT SQL_ID, Inst_ID, Parsing_Schema_Name,
                                               SUM(Elapsed_Time)/1000000 Elapsed_Secs,
                                               SUM(Executions)           Executions
                                        FROM   gv$SQLArea
                                        WHERE  UPPER(SQL_FullText) LIKE '%NVL%'
                                        AND    Parsing_Schema_Name NOT IN (#{system_schema_subselect})
                                        GROUP BY SQL_ID, Inst_ID, Parsing_Schema_Name
                                       ) a
                                JOIN   gv$SQLArea ai ON ai.SQL_ID = a.SQL_ID AND ai.Inst_ID = a.Inst_ID AND ai.Parsing_Schema_Name = a.Parsing_Schema_Name
                                WHERE  a.Elapsed_Secs > ?
                               ) a
                        JOIN  (SELECT /*+ MATERIALIZE */ Level NVL_Level FROM DUAL CONNECT BY Level < 1000) Pump1000 ON INSTR(a.First_NVL_Substr, 'NVL', 1, Pump1000.NVL_Level) != 0  /* Ein Record je Vorkommen eines NVL im SQL, limitiert mit Level */
                       ) t
                JOIN  (SELECT /*+ MATERIALIZE */ Level Char_Level FROM DUAL CONNECT BY Level < 100000) Pump100000 ON SUBSTR(NVL_Substr, pump100000.Char_Level, 1) IN ('(', ')', ',') AND pump100000.Char_Level <= LENGTH(t.NVL_Substr) /* Ein Record je Zeichen des verbleibenden SQL-Strings, limitiert mit Level */
               ) x
       ) y
WHERE  Klammer_Open BETWEEN Komma_Pos AND Min_Ende_Pos
ORDER BY Elapsed_Secs DESC, SQL_ID, NVL_Level, CHAR_Level
           ",
            :parameter=>[
                {:name=> t(:dragnet_helper_58_param1_name, :default=>'Minimum runtime of SQL in seconds'), :size=>8, :default=> 1000, :title=> t(:dragnet_helper_58_param1_desc, :default=>'Minimum runtime of SQL in seconds for consideration in selection')},
            ]
        },
        {
            :name  => t(:dragnet_helper_129_name, :default=>'Identification of probably unused PL/SQL-objects'),
            :desc  => t(:dragnet_helper_129_desc, :default=>"PL/SQL-code may assumed to be unused and dispensable if there are no dependencies from other PL/SQL-code and no usage in SQL.
This must not be true because you need entry points to PL/SQL-processing that doesn't have dependencies from other PL/SQL-objects but are essential.
Therefore additional selection is useful, e.g. by filter based on name convention.

Unfortunately the check of usage of this PL/SQL-Objects in SQL-Statements (SGA and AWR) seams impossible in acceptabe runtime.
Therefore this check is excluded here.
"),
            :sql=> "SELECT o.*
                    FROM   (
                            SELECT /*+ NO_MERGE */ o.Owner, o.Object_Name, o.Object_Type, o.Created, o.Last_DDL_Time, o.Status
                            FROM   DBA_Objects o
                            CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                            CROSS JOIN (SELECT UPPER(?) Filter FROM DUAL) name_filter_incl
                            CROSS JOIN (SELECT UPPER(?) Filter FROM DUAL) name_filter_excl
                            WHERE  o.Object_Type IN ('PROCEDURE', 'PACKAGE', 'TYPE', 'FUNCTION', 'SYNONYM')
                            AND    o.Owner NOT IN (#{system_schema_subselect})
                            AND    o.Owner NOT IN ('PUBLIC')
                            AND    (schema.name IS NULL OR schema.Name = o.Owner)
                            AND    (name_filter_incl.Filter IS NULL OR o.Object_name LIKE '%'||name_filter_incl.Filter||'%')
                            AND    (name_filter_excl.Filter IS NULL OR o.Object_name NOT LIKE '%'||name_filter_excl.Filter||'%')
                            AND NOT EXISTS (SELECT 1
                                            FROM   DBA_Dependencies d
                                            WHERE  d.Referenced_Owner = o.Owner
                                            AND    d.Referenced_Name = o.Object_Name
                                            AND    d.Referenced_Type = o.Object_Type
                                            AND    (d.Type != 'SYNONYM' OR EXISTS (SELECT 1 FROM DBA_Dependencies di WHERE  di.Referenced_Owner = d.Owner AND di.Referenced_Name = d.Name AND di.Referenced_Type = d.Type) ) -- Synonyme ohne weitere Abhängigkeiten nicht werten
                                            AND    (   d.Type != 'PACKAGE BODY'
                                                    OR d.Name != d.Referenced_Name                          /* Referenz von anderslautendem Body zählt als Abhängigkeit */
                                                    OR EXISTS (SELECT 1 FROM DBA_Dependencies di WHERE  di.Referenced_Owner = d.Owner AND di.Referenced_Name = d.Name AND di.Referenced_Type = d.Type) /* Weitere Abhängigkeiten des Bodys eines Package zählen als Abhängigkeiten */
                                                   )
                                           )
                            AND NOT EXISTS (SELECT 1 FROM gv$SQLArea s WHERE UPPER(SQL_FullText) LIKE '%'||o.Object_Name||'%')
                            AND    o.Created < SYSDATE - ?
                            AND    o.Last_DDL_Time < SYSDATE - ?
                           ) o
           ",
            :parameter=>[
                {:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_129_param_1_hint, :default=>'Check only PL/SQL-objects for this schema (optional)')},
                {:name=>t(:dragnet_helper_129_param2_name, :default=>'Limit result to object names with this wildcard (optional)'),  :size=>30, :default=>'',   :title=>t(:dragnet_helper_129_param_2_hint, :default=>'Check only PL/SQL objects with names matching this wildcard-filter(optional)')},
                {:name=>t(:dragnet_helper_129_param3_name, :default=>'Exclude object_names with this wildcard from result (optional)'),  :size=>30, :default=>'',   :title=>t(:dragnet_helper_129_param_3_hint, :default=>'Exclude PL/SQL objects with names matching this wildcard-filter from check (optional)')},
                {:name=>t(:dragnet_helper_129_param4_name, :default=>'Minimum age of objects in days'), :size=>8, :default=> 100, :title=> t(:dragnet_helper_128_param4_desc, :default=>'Minimum number of days since creation of object')},
                {:name=>t(:dragnet_helper_129_param5_name, :default=>'Minimum days since last DDL'), :size=>8, :default=> 10, :title=> t(:dragnet_helper_128_param5_desc, :default=>'Minimum number of days since last DDL-operation on object')},
            ]
        },
        {
            :name  => t(:dragnet_helper_152_name, :default=>'Candidates for PRAGMA UDF in pure user-defined PL/SQL functions'),
            :desc  => t(:dragnet_helper_152_desc, :default=>"User-defined PL/SQL in SQL-statements may perform better without context switching with PRAGMA UDF.
This selection shows PL/SQL functions without PRAGMA UDF sorted by the time the SQL spends in executing this function (by ASH).
Elapsed time inside the function as well as top level and direct executed SQL-IDs are given for:
- The SQL which executed the named function
- The recursive execution of this function by an SQL encapsulated inside another PL/SQL code

Click on the object name to get function details including buttons for:
- syntax search for SQL statements using this function
- Dependencies of this function or package in both directions
"),
            :sql=> "\
WITH   Procs AS (SELECT /*+ NO_MERGE MATERIALIZE */ p.Object_ID, p.SubProgram_ID, p.Object_Type, p.Owner, p.Object_Name, p.Procedure_Name
                 FROM   DBA_Procedures p
                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT Owner, Package_Name, Object_Name
                                  FROM   DBA_Arguments
                                  WHERE  Position = 0 /* Function return */
                                 ) a ON a.Owner = p.Owner AND a.Package_Name = p.Object_Name AND a.Object_Name = p.Procedure_Name
                 WHERE  (p.Object_Type = 'FUNCTION' OR (p.Object_Type = 'PACKAGE' AND a.Package_Name IS NOT NULL))
                 AND    p.Owner NOT IN (#{system_schema_subselect})
                ),
       Dependencies AS (SELECT /*+ NO_MERGE MATERIALIZE*/ Referenced_Owner, Referenced_Name, Referenced_Type, COUNT(*) Dependencies
                        FROM   DBA_Dependencies
                        WHERE  TYPE IN ('FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'TRIGGER', 'TYPE', 'TYPE BODY')
                        GROUP BY Referenced_Owner, Referenced_Name, Referenced_Type
                       ),
       UDF AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Name, Type FROM DBA_Source WHERE UPPER(Text) LIKE '%PRAGMA%UDF%'),
       ASH_Time AS (SELECT /*+ NO_MERGE MATERIALIZE */ i.Inst_ID, NVL(Min_Sample_Time, SYSTIMESTAMP) Min_Sample_Time
                    FROM   gv$Instance i
                    LEFT OUTER JOIN (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time
                                     FROM gv$Active_Session_History
                                     GROUP BY Inst_ID
                                    ) ash ON ash.Inst_ID = i.Inst_ID
                   ),
       Ash AS (SELECT /*+ NO_MERGE MATERIALIZE */ SUM(Sample_Cycle) Elapsed_Secs, Top_Level_SQL_ID, SQL_ID, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID
               FROM   (
                       SELECT /*+ NO_MERGE ORDERED */
                              10 Sample_Cycle, Top_Level_SQL_ID, SQL_ID, Top_Level_SQL_OpCode, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID
                       FROM   DBA_Hist_Active_Sess_History s
                       JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                       WHERE  s.Sample_Time < (SELECT Min_Sample_Time FROM Ash_Time a WHERE a.Inst_ID = s.Instance_Number)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
                       AND    ss.Begin_Interval_Time > SYSDATE - ?
                       AND    s.DBID = #{get_dbid}  /* do not count multiple times for multiple different DBIDs/ConIDs */
                       UNION ALL
                       SELECT 1 Sample_Cycle, Top_Level_SQL_ID, SQL_ID, Top_Level_SQL_OpCode, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID
                       FROM   gv$Active_Session_History
                      )
               WHERE  PLSQL_ENTRY_OBJECT_ID IS NOT NULL
               AND    Top_Level_SQL_OpCode != 47 /* Top level SQL does not start with PL/SQL */
               GROUP BY Top_Level_SQL_ID, SQL_ID, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID
              )
SELECT p.Object_Type, p.Owner, p.Object_Name, p.Procedure_Name, d.Dependencies,
       peo.Elapsed_Secs Elapsed_Secs_Entry, peo.Top_Level_SQL_ID Top_Entry_Top_Level_SQL_ID, peo.SQL_ID Top_Entry_SQL_ID,
       po.Elapsed_Secs Elapsed_Secs_Direct, po.Top_Level_SQL_ID Top_Direct_Top_Level_SQL_ID, po.SQL_ID Top_Direct_SQL_ID
FROM   Procs p
LEFT OUTER JOIN Dependencies d ON d.Referenced_Owner = p.Owner AND d.Referenced_Name = p.Object_Name AND d.Referenced_Type = p.Object_Type
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, SUM(Elapsed_Secs) Elapsed_Secs,
                 MAX(Top_Level_SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Elapsed_Secs) Top_Level_SQL_ID,
                 MAX(SQL_ID)           KEEP (DENSE_RANK LAST ORDER BY Elapsed_Secs) SQL_ID
                 FROM   Ash
                 GROUP BY PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID
                ) peo ON peo.PLSQL_Entry_Object_ID = p.Object_ID AND peo.PLSQL_Entry_SubProgram_ID = p.SubProgram_ID
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, SUM(Elapsed_Secs) Elapsed_Secs,
                 MAX(Top_Level_SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Elapsed_Secs) Top_Level_SQL_ID,
                 MAX(SQL_ID)           KEEP (DENSE_RANK LAST ORDER BY Elapsed_Secs) SQL_ID
                 FROM   Ash
                 GROUP BY PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID
                ) po ON po.PLSQL_Object_ID = p.Object_ID AND po.PLSQL_SubProgram_ID = p.SubProgram_ID
WHERE  (p.Owner, p.Object_Name, p.Object_Type) NOT IN (SELECT /*+ NO_MERGE */ Owner, Name, DECODE(Type, 'PACKAGE BODY', 'PACKAGE', Type) FROM UDF)
ORDER BY Elapsed_Secs_Entry DESC NULLS LAST
           ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_153_name, :default=>'Candidates for DETERMINISTIC in user-defined PL/SQL functions'),
            :desc  => t(:dragnet_helper_153_desc, :default=>"User-defined PL/SQL functions may be cached in session for subsequent calls with same parameters if they are declared as deterministic.
For functions without dependencies there is a high likelihood that they are deterministic.
This selection shows PL/SQL functions not declared as DETERMINISTIC and without any dependency other than sys.STANDARD.
In addition SQLs from SGA are shown which uses this function name in their SQL syntax.

This check does not evaluate package functions, only standalone functions are considered.
"),
            :sql=> "\
WITH Procs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ p.Owner, p.Object_Name
                FROM   DBA_Procedures p
                WHERE  Object_Type = 'FUNCTION'
                AND    Owner NOT IN (#{system_schema_subselect})
                AND    Deterministic = 'NO'
                AND    (Owner, Object_Name, Object_Type) NOT IN (SELECT /*+ NO_MERGE */ DISTINCT d.Owner, d.Name, d.Type
                                                                 FROM   DBA_Dependencies d
                                                                 WHERE  (Referenced_Owner != 'SYS' OR Referenced_Name != 'STANDARD')
                                                                )
               ),
     SQLs as (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, SQL_ID, UPPER(SQL_Text) SQL_Text FROM GV$SQLTEXT_WITH_NEWLINES),
     SQL_A AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, SQL_ID, Elapsed_Time, Executions FROM gv$SQLArea)
SELECT p.Owner, p.Object_Name, p.Inst_ID,
       ROUND(SUM(a.Elapsed_Time)/1000000) \"Elapsed time (secs) in SQL\",
       SUM(a.Executions)                  \"No. of executions in SQL\",
       COUNT(DISTINCT p.SQL_ID)           \"No. of different SQLs\",
       MAX(a.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY a.Elapsed_Time NULLS FIRST) \"SQL_ID with max. elapsed time\"
FROM   (SELECT /*+ NO_MERGE */ p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
        FROM   Procs p
        LEFT OUTER JOIN   SQLs s ON s.SQL_Text LIKE '%'||p.Object_Name||'%'
        GROUP BY p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
       ) p
LEFT OUTER JOIN SQL_A a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID
GROUP BY p.Owner, p.Object_Name, p.Inst_ID
ORDER BY 4 DESC NULLS LAST
           ",
        },
        {
          :name  => t(:dragnet_helper_178_name, :default=>'Candidates for DETERMINISTIC in package and standalone PL/SQL functions'),
          :desc  => t(:dragnet_helper_178_desc, :default=>"User-defined PL/SQL functions may be cached in session for subsequent calls with same parameters if they are declared as deterministic.
This selection shows PL/SQL functions not declared as DETERMINISTIC but used in long running SQL statements.

The result should be checked if these functions could be declared DETERMINISTIC.
This could be useful even if there are SQL selections within the function that regularly prevent the deterministic state.
E.g. selections on rarely changed master data can be considered deterministic for the duration of a SQL execution.

This check evaluates also functions in packages.
"),
          plsql: true,
          min_db_version: '19',
          :sql=> "\
DECLARE
  TYPE proc_RT IS RECORD(
    Owner         VARCHAR2(128),
    Package_Name  VARCHAR2(128),
    Function_Name VARCHAR2(128)
  );
  proc_rec              proc_RT;
  TYPE Proc_TT IS TABLE OF Proc_RT INDEX BY VARCHAR2(2000);
  proc_table            Proc_TT;

  TYPE Char_Table_Type IS TABLE OF CHAR(1);
  Char_Table            Char_Table_Type := Char_Table_Type(' ', '(', '!', '=', '<', '>', '+', '-', '*', '/'); -- delimiters chars to use for tokenization of SQL
  char_table_count      INTEGER  := Char_Table.COUNT;

  Start_Pos             INTEGER;
  End_pos               INTEGER;
  Test_Pos              INTEGER;
  l_text                CLOB;
  l_match               VARCHAR2(4000);
  full_match            VARCHAR2(4000);
  l_json                VARCHAR2(4000);
  Plan_Line_ID_Access   INTEGER;
  Plan_Line_ID_Filter   INTEGER;
  Access_Text           VARCHAR2(4000);
  Filter_Text           VARCHAR2(4000);
  Search_Text          VARCHAR2(4000);       -- The text searched in access or filter criteria

  FUNCTION JSON_Esc(p_In VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(p_In, '\"', '\\\"');
  END JSON_Esc;

BEGIN
  FOR p_Rec IN (SELECT Owner, Package_Name, Function_Name, Compare_Name
                FROM   (
                        SELECT Owner, NULL Package_Name, Object_Name Function_Name, Deterministic, Object_Name Compare_Name
                        FROM   DBA_Procedures
                        WHERE  Object_Type = 'FUNCTION'
                        UNION ALL
                        SELECT p.Owner, p.Object_Name Package_Name, p.Procedure_Name Function_Name, p.Deterministic, p.Object_Name||'.'||p.Procedure_Name Compare_Name
                        FROM   DBA_Procedures p
                        JOIN   DBA_Arguments a ON a.Owner = p.Owner AND a.Package_Name = p.Object_Name AND a.Object_Name = p.Procedure_Name
                        WHERE  p.Object_Type = 'PACKAGE'
                        AND    a.Argument_Name IS NULL /* Program is a function with a return value */
                       )
                WHERE  Owner NOT IN (SELECT UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
                AND    Deterministic = 'NO'
               ) LOOP
    -- Lookup with function name only
    proc_table(p_Rec.Compare_Name) := Proc_RT(p_Rec.Owner, p_Rec.Package_Name, p_Rec.Function_Name);
    -- Lookup with function name qualified with owner
    proc_table(p_Rec.Owner||'.'||p_Rec.Compare_Name) := Proc_RT(p_Rec.Owner, p_Rec.Package_Name, p_Rec.Function_Name);
  END LOOP;

  FOR t_Rec IN (SELECT Instance_Number, SQL_ID, Parsing_Schema_Name, SQL_Text, Elapsed_Secs
                FROM   (
                        SELECT Instance_Number, SQL_ID, Parsing_Schema_Name,
                               LTRIM(SQL_Text, CHR(10) || CHR(13) || ' ' || CHR(9)) SQL_Text,  /* remove leading whitespaces from SQL */
                               SUM(Elapsed_Secs) OVER (PARTITION BY Instance_Number, SQL_ID, Parsing_Schema_Name) Elapsed_Secs,
                               ROW_NUMBER() OVER (PARTITION BY Instance_Number, SQL_ID, Parsing_Schema_Name ORDER BY 1) AS rn  /* Because of no aggregate functions on CLOB */
                        FROM   (
                                SELECT Inst_ID Instance_Number, SQL_ID, UPPER(SQL_FullText) SQL_Text, Parsing_Schema_Name, Elapsed_Time/1000000 Elapsed_Secs
                                FROM   gv$SQLArea
                                WHERE   Command_Type != 47 /* No PL/SQL */
                                UNION ALL
                                SELECT h.Instance_Number, h.SQL_ID, UPPER(t.SQL_Text) SQL_Text, h.Parsing_Schema_Name, h.Elapsed_Secs
                                FROM   (SELECT st.Instance_Number, st.SQL_ID, st.Parsing_Schema_Name, SUM(st.Elapsed_Time_Delta)/1000000 Elapsed_Secs
                                        FROM   DBA_Hist_SQLStat st
                                        JOIN   DBA_Hist_Snapshot ss ON ss.DBID = st.DBID AND ss.Snap_ID = st.Snap_ID AND ss.Instance_Number = st.Instance_Number
                                        WHERE  ss.Begin_Interval_Time > SYSDATE - ? /* The number of days back in time to consider */
                                        GROUP BY st.Instance_Number, st.SQL_ID, st.Parsing_Schema_Name
                                       ) h
                                JOIN   DBA_Hist_SQLText t ON t.SQL_ID = h.SQL_ID
                               )
                        WHERE Elapsed_Secs > ? /* The minimum runtime to be considered in query */
                       )
                WHERE  RN = 1 /* Select one occurrence of SQL text per SQL-ID only */
                AND    SQL_Text NOT LIKE 'BEGIN%' /* No command_type in DBA_Hist_SQLStat to filter PL/SQL */
                AND    SQL_Text NOT LIKE 'DECLARE%'
               ) LOOP
    Start_Pos := 1;
    l_text := t_Rec.SQL_Text;
    LOOP
      -- Look for the next delimiter
      End_pos := 0; -- start value
      FOR i IN 1..char_table_count LOOP
        Test_Pos := INSTR(l_text, Char_Table(i), Start_Pos);
        IF Test_Pos > 0 AND ( End_Pos = 0 OR Test_Pos < End_Pos) THEN
          End_Pos := Test_Pos;
        END IF;
      END LOOP;

      BEGIN
        IF End_Pos > 0 THEN
          l_match := SUBSTR(l_text, Start_Pos, End_pos-Start_Pos);
        ELSE
          l_match := SUBSTR(l_text, Start_Pos); -- The rest of the string
        END IF;

        IF proc_Table.EXISTS(l_match) -- Either owner and function name or only function name match
        THEN
          proc_rec := proc_Table(l_match);      -- For reuse of values
          -- Get the following parameter for matching function call
          -- Check if parameters follow immediately (after end_pos are only spaces up to an opening parenthesis)
          full_match := l_match; -- Default if no parameter list follows
          IF End_Pos > 0 AND REGEXP_LIKE(SUBSTR(l_text, End_Pos), '^\\s*\\(') THEN -- opening parenthesis directly after or after spaces
            End_Pos := INSTR(l_text, ')', Start_Pos);
            IF End_Pos > 0 THEN
              full_match := SUBSTR(l_text, Start_Pos, End_pos-Start_Pos + 1);
            ELSE
              full_match := SUBSTR(l_text, Start_Pos); -- The rest of the string
            END IF;
          END IF;

          -- Get the plan line id and content if used in access or filter predicates
          -- Take into account that the owner of the object is not stored in access or filter criterias if same as executor
          Search_Text := '%'||CASE WHEN proc_rec.Package_Name IS NULL THEN '' ELSE proc_rec.Package_Name||'.' END||proc_rec.Function_Name||'%';

          SELECT MIN(ID), MIN(Access_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Access, Access_Text
          FROM   gv$SQL_PLan
          WHERE  SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Access_Predicates), '\"', '') LIKE Search_Text
          ;
          IF Plan_Line_ID_Access IS NULL THEN
            SELECT MIN(ID), MIN(Access_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Access, Access_Text
            FROM   DBA_Hist_SQL_PLan
            WHERE  SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Access_Predicates), '\"', '') LIKE Search_Text
            ;
          END IF;

          SELECT MIN(ID), MIN(Filter_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Filter, Filter_Text
          FROM   gv$SQL_PLan
          WHERE  SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Filter_Predicates), '\"', '') LIKE Search_Text
          ;
          IF Plan_Line_ID_Filter IS NULL THEN
            SELECT MIN(ID), MIN(Filter_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Filter, Filter_Text
            FROM   DBA_Hist_SQL_PLan
            WHERE  SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Filter_Predicates), '\"', '') LIKE Search_Text
            ;
          END IF;

          l_json := '{' ||
                    '\"Instance\": '               || t_Rec.Instance_Number         || ', '   ||
                    '\"SQL-ID\": \"'               || JSON_Esc(t_Rec.SQL_ID)        || '\", ' ||
                    '\"Parsing Schema Name\": \"'  || t_Rec.Parsing_Schema_Name     || '\", ' ||
                    '\"Elapsed Secs\": '           || ROUND(t_Rec.Elapsed_Secs)     || ', '   ||
                    '\"Owner\": \"'                || proc_rec.Owner                || '\", ' ||
                    '\"Package Name\": \"'         || proc_rec.Package_Name         || '\", ' ||
                    '\"Function Name\": \"'        || proc_rec.Function_Name        || '\", ' ||
                    '\"Match in SQL\": \"'         || JSON_Esc(full_match)          || '\", ' ||
                    '\"Plan Line ID Access\": '    || CASE WHEN Plan_Line_ID_Access IS NULL THEN 'null' ELSE TO_CHAR(Plan_Line_ID_Access) END || ', '   ||
                    '\"Access Predicates\": \"'    || JSON_Esc(Access_Text)         || '\", ' ||
                    '\"Plan Line ID Filter\": '    || CASE WHEN Plan_Line_ID_Filter IS NULL THEN 'null' ELSE TO_CHAR(Plan_Line_ID_Filter) END || ', '   ||
                    '\"Filter Predicates\": \"'    || JSON_Esc(Filter_Text)         || '\" ' ||
                    '}';
          DBMS_OUTPUT.PUT_LINE(l_json);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLCODE != -6502 THEN -- End_Pos > 4000 raises ORA-06502: PL/SQL: numeric or value error: character string buffer too small
            RAISE;
          END IF;
      END;
      EXIT WHEN End_Pos = 0;
      Start_Pos := End_Pos + 1;
    END LOOP;
  END LOOP;
END;
           ",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            {:name=>t(:dragnet_helper_178_param_1_name, :default=>'Min. elapsed seconds for SQL execution'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_178_param_1_hint, :default=>'Minimum number of total elapsed seconds for a SQL in SGA and AWR reports to be considered in selection')},
          ]
        },
    ]
  end

end