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
SELECT SQL_ID, Inst_ID, Elapsed_Secs, NVL_Level \"NVL-Occurrence in SQL\", Char_Level Open_Bracket_Position, SUBSTR(NVL_Substr, 1, Min_Ende_Pos) NVL_Parameter
FROM   (
        SELECT x.*,
               MIN(CASE WHEN Opened-Closed=1 AND Char_=',' THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Komma_Pos,
               MIN(CASE WHEN Char_Level> 3 /* Laenge von NVL */ AND Opened-Closed=0 /* Alle Klammern wieder geschlossen */ THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Min_Ende_Pos
        FROM   (
                SELECT SQL_ID, Inst_ID, Elapsed_Secs, NVL_Level, Char_Level, SUBSTR(NVL_Substr, Char_Level, 1) Char_, NVL_Substr,
                       CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN Char_Level ELSE NULL END Klammer_Open,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Opened,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = ')' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Closed
                FROM   (
                        SELECT /*+ NO_MERGE */ NVL_Level,
                               -- INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) NVL_Position,
                               TO_CHAR(SUBSTR(a.First_NVL_Substr, INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level)+3, 4000)) NVL_Substr, /* SQL-String nach dem xten NVL bis zum Ende, mit max. 4000 Zeichen als Char fuehren */
                               a.SQL_ID, a.Inst_ID, a.Elapsed_Secs
                        FROM   (
                                SELECT /*+ NO_MERGE */ a.SQL_ID, a.Inst_ID, a.Elapsed_Secs,
                                                       UPPER(SUBSTR(ai.SQL_FullText, INSTR(UPPER(ai.SQL_FullText), 'NVL'))) First_NVL_Substr
                                FROM   (
                                        SELECT SQL_ID, MIN(Inst_ID) Inst_ID,
                                               SUM(Elapsed_Time)/1000000 Elapsed_Secs
                                        FROM   gv$SQLArea
                                        WHERE  UPPER(SQL_FullText) LIKE '%NVL%'
                                        GROUP BY SQL_ID
                                       ) a
                                JOIN   gv$SQLArea ai ON ai.SQL_ID = a.SQL_ID AND ai.Inst_ID = a.Inst_ID
                                WHERE  a.Elapsed_Secs > ?
                               ) a
                        JOIN  (SELECT Level NVL_Level FROM DUAL CONNECT BY Level < 1000) Pump ON INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) != 0  /* Ein Record je Vorkommen eines NVL im SQL, limitiert mit Level */
                       ) t
                JOIN  (SELECT Level Char_Level FROM DUAL CONNECT BY Level < 100000) Pump ON SUBSTR(NVL_Substr, pump.Char_Level, 1) IN ('(', ')', ',') AND pump.Char_Level <= LENGTH(t.NVL_Substr) /* Ein Record je Zeichen des verbleibenden SQL-Strings, limitiert mit Level */
               ) x
       ) y
WHERE  Klammer_Open BETWEEN Komma_Pos AND Min_Ende_Pos
ORDER BY Elapsed_Secs DESC, SQL_ID, NVL_Level, CHAR_Level
           ",
            :parameter=>[
                {:name=> t(:dragnet_helper_58_param1_name, :default=>'Minimum runtime of SQL in seconds'), :size=>8, :default=> 1000, :title=> t(:dragnet_helper_58_param1_desc, :default=>'Minimum runtime of SQL in seconds for consideration in selection')},
            ]
        },
    ]
  end

end