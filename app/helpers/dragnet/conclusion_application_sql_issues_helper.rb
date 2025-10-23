# encoding: utf-8
module Dragnet::ConclusionApplicationSqlIssuesHelper

  private

  def conclusion_application_sql_issues
    [
      {
        :name  => t(:dragnet_helper_61_name, :default=> 'Possibly unnecessary update of primary key columns'),
        :desc  => t(:dragnet_helper_61_desc, :default=>'Primary key columns should normally be immutable, especially if they are referenced from foreign keys.
Setting primary key columns with identical values causes unnecessary effort for index maintenance.
Therefore primary key columns should not occur in SET-clause of UPDATE statements.
           '),
        :sql=> "
              SELECT SQL_ID, Object_Owner, Object_Name, Column_Name, Executions, Elapsed_Time_Secs, SUBSTR(SQL_FullText, 1, 200)
              FROM   (SELECT x.*, UPPER(SUBSTR(SQL_FullText, Set_Position, Where_Position - Set_Position)) Set_Klausel
                      FROM   (
                              SELECT p.Object_Owner, p.Object_Name, p.SQL_ID, cc.Column_Name, t.SQL_FullText, INSTR(UPPER(SQL_FullText), 'SET') Set_Position, INSTR(UPPER(SQL_FullText), 'WHERE') Where_Position,
                                     t.Executions, t.Elapsed_Time/(100000) Elapsed_Time_Secs
                              FROM   (SELECT Inst_ID, Object_Owner, Object_Name, SQL_ID
                                      FROM   gv$SQL_PLan
                                      WHERE  Operation = 'UPDATE'
                                      GROUP BY Inst_ID, Object_Owner, Object_Name, SQL_ID -- Gruppieren ueber Children
                                     ) p
                              JOIN   DBA_Constraints c ON c.Owner = p.Object_Owner AND c.Table_Name = p.Object_Name AND c.Constraint_Type = 'P'
                              JOIN   DBA_Cons_Columns cc ON cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name
                              JOIN   gv$SQLArea t ON t.Inst_ID = p.Inst_ID AND t.SQL_ID = p.SQL_ID
                             ) x
                     ) x
              WHERE REGEXP_INSTR(Set_Klausel, '[ ,]'||Column_Name||'[ =]') > 0
              ORDER BY Elapsed_Time_Secs DESC
          ",
      },
      {
        :name  => t(:dragnet_helper_167_name, :default=>'Possibly problematic NULL-handling in bind variables (:A1 IS NULL OR Column = :A1)'),
        :desc  => t(:dragnet_helper_167_desc, :default=>"\
To disable filtering on a certain column with NULL as bound value you often find a syntax like:

SELECT * FROM table WHERE (:A1 IS NULL OR column = :A1);

There can be huge drawbacks if using such OR-conditions.
The optimizer calculates with a cardinality of 5% in this case and chooses a full table scan.
This may be suboptimal because a possibly existing index on that column will not be used and also partition pruning cannot be used if the table is partitioned by that column.

There are several alternatives with working usage of indexing or partition pruning:
1. Use specific SQL syntax depending on the value of the bind variable and bind only the needed values.

2. If the list ouf bound variables at execution time is fixed, place a dummy line in the SQL for the NULL case like \"(1=1 OR 1=:A1)\", otherwise \"column = :A1\" .

3. Use SQL macros to get the according SQL syntax for the bound value.

4. Use UNION ALL instead of OR. This executes the full scan only if the bound value is NULL and scans the index only if the bound value is not NULL.

SELECT * FROM table WHERE :A1 IS NULL
UNION ALL
SELECT * FROM table WHERE column = :A1;
          "),
        :sql=> "\
WITH Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, ID, Plan_Hash_Value, MIN(Filter_Predicates) Filter_Predicates
               FROM   gv$SQL_Plan
               WHERE  Operation = 'TABLE ACCESS'
               AND    Options LIKE '%FULL' /* possibly STORAGE FULL */
               AND    (   REGEXP_LIKE(UPPER(Filter_Predicates), '\\( *:[a-zA-Z0-9]+ +IS +NULL +OR +')
                       OR REGEXP_LIKE(UPPER(Filter_Predicates), 'OR +:[a-zA-Z0-9]+ +IS +NULL *\\)')
                      )
               GROUP BY SQL_ID, ID, Plan_Hash_Value
              ),
     ASH AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, SQL_Plan_Line_ID, SQL_Plan_Hash_Value, COUNT(*) Seconds
             FROM   gv$Active_Session_History
             WHERE  SQL_Plan_Line_ID IS NOT NULL
             GROUP BY SQL_ID, SQL_Plan_Line_ID, SQL_Plan_Hash_Value
             HAVING COUNT(*) > ?
            )
SELECT ash.SQL_ID, p.Plan_Hash_Value, ash.SQL_Plan_Line_ID, ash.Seconds \"Runtime of line in seconds\", p.Filter_Predicates
FROM   Plans p
JOIN   ASH ON ash.SQL_ID=p.SQL_ID AND ash.SQL_Plan_Line_ID = p.ID AND ash.SQL_Plan_Hash_Value = p.Plan_Hash_Value
ORDER BY ash.Seconds DESC
           ",
        :parameter=>[
          {:name=>t(:dragnet_helper_167_param_1_name, :default=>'Minimum runtime of plan line in seconds'), :size=>8, :default=>10, :title=>t(:dragnet_helper_167_param_1_hint, :default=>'Minimum runtime of SQL on particular plan line ID in seconds to be shown in selection') },
        ]
      },
      {
        :name  => t(:dragnet_helper_171_name, :default=>"Volatile columns in result due to 'SELECT * FROM table'"),
        :desc  => t(:dragnet_helper_171_desc, :default=>"\
'SELECT * FROM table;' without specification of columns in the SELECT-list may cause volatile results if the table structure changes.
Suggestion is to specify the columns in the SELECT-list if SQL is used in applications.
Otherwise a sensible use of SELECT * instead of a fix column list could be in PL/SQL if working with %ROWTYPE.

This selection scans the current SGA and the AWR history for such SQLs.
          "),
        :sql=> "\
WITH Hist_SQL_Text AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, MIN(SQL_Text) SQL_Text
                       FROM   (SELECT SQL_ID, TO_CHAR(SUBSTR(SQL_Text, 1, 100)) SQL_Text FROM DBA_Hist_SQLText)
                       WHERE REGEXP_LIKE(UPPER(SQL_Text), '(^|\\s)SELECT\\s+\\*')
                       GROUP BY SQL_ID
                      ),
     Hist_SQLStat AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, Parsing_Schema_Name, SUM(Executions_Delta) Executions, SUM(Elapsed_Time_Delta) Elapsed_Time,
                             MAX(Module) Module, MAX(Action) Action
                      FROM   DBA_Hist_SQLStat
                      WHERE  Snap_ID > (SELECT MIN(Snap_ID) FROM DBA_Hist_Snapshot WHERE Begin_Interval_Time > SYSDATE-?)
                      GROUP BY SQL_ID, Parsing_Schema_Name
                     )
SELECT SQL_ID, Parsing_Schema_Name,
       SUM(Executions_SGA)   Executions_SGA,   SUM(Executions_AWR)   Executions_AWR,
       SUM(Elapsed_Secs_SGA) Elapsed_Secs_SGA, SUM(Elapsed_Secs_AWR) Elapsed_Secs_AWR,
       MAX(Module) Module, MAX(Action) Action,
       MIN(SQL_Text) SQL_Text
FROM   (
        SELECT SQL_ID, Parsing_Schema_Name, Executions Executions_SGA, 0 Executions_AWR,
               ROUND(Elapsed_Time/1000000, 2) Elapsed_Secs_SGA, 0 Elapsed_Secs_AWR, Module, Action,
               SUBSTR(SQL_Text, 1, 100) SQL_Text
        FROM   gv$SQLArea
        WHERE REGEXP_LIKE(UPPER(SQL_Text), '(^|\\s)SELECT\\s+\\*')
        UNION ALL
        SELECT s.SQL_ID, s.Parsing_Schema_Name, 0 Executions_SGA, s.Executions Executions_AWR, 0 Elapsed_Secs_SGA, ROUND(s.Elapsed_Time/1000000, 2) Elapsed_Secs_AWR,
               s.Module, s.Action, t.Sql_Text
        FROM   Hist_SQLStat s
        JOIN   Hist_SQL_Text t ON t.SQL_ID = s.SQL_ID
       )
WHERE  Parsing_Schema_Name NOT IN (#{system_schema_subselect})
GROUP BY SQL_ID, Parsing_Schema_Name
ORDER BY NVL(Executions_SGA,0) + NVL(Executions_AWR,0) DESC
           ",
        :parameter=>[
          {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
        ]
      },
    ]

  end
end


