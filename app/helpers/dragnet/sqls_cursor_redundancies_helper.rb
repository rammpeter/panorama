# encoding: utf-8
module Dragnet::SqlsCursorRedundanciesHelper

  private

  def sqls_cursor_redundancies
    [
        {
            :name  => t(:dragnet_helper_133_name, :default=>'Missing usage of bind variables: Detection by identical plan-hash-value from Active Session History (SGA and AWR)'),
            :desc  => t(:dragnet_helper_133_desc, :default=>"Usage of literals instead of bind variables with high number of different literals leads to high parse counts and flooding of SQL-Area in SGA.
You may reduce the problem by setting cursor_sharing != EXACT, but you still need large amount of SGA-memory to match your SQL with the corresponding SQL with replaced bind variables.
So strong suggestion is: Use bind variables!
This selection looks for statements with identical execution plans by plan-hash-value from Active Session History.
Using force-matching-signature instead of plan-hash-value for detection is risky because ASH often samples inaccurate values for force-matching-signature."),
            :sql=>  "WITH Ret AS (SELECT ? Days FROM DUAL)
                      SELECT x.SQL_Plan_Hash_Value, x.Different_SQL_IDs, x.Last_Used_SQL_ID, u.UserName, x.First_Occurrence, x.Last_Occurrence, x.Elapsed_Secs
                      FROM   (
                              SELECT h.SQL_Plan_Hash_Value,
                                     COUNT(DISTINCT h.SQL_ID) Different_SQL_IDs,
                                     MAX(h.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY CASE WHEN text_exists.SQL_ID IS NULL THEN 0 ELSE 1 END, h.Sample_Time) Last_Used_SQL_ID,
                                     User_ID,
                                     MIN(h.Sample_Time) First_Occurrence,
                                     MAX(h.Sample_Time) Last_Occurrence,
                                     SUM(CASE WHEN h.Sample=1 OR d.Min_Sample_Time IS NULL OR h.Sample_Time < d.Min_Sample_Time THEN h.Sample END) Elapsed_Secs   /* dont count twice in SGA and AWR */
                              FROM   (SELECT Inst_ID Instance_Number, Sample_Time, SQL_Plan_Hash_Value, SQL_ID, 1 Sample, User_ID,
                                             MIN(Sample_Time) OVER (PARTITION BY SQL_Plan_Hash_Value) Delimiter
                                      FROM   gv$Active_Session_History
                                      CROSS JOIN Ret
                                      WHERE  Sample_Time > SYSDATE-Ret.Days
                                      UNION ALL
                                      SELECT Instance_Number, Sample_Time, SQL_Plan_Hash_Value, SQL_ID, 10 Sample, User_ID,NULL Delimiter
                                      FROM   DBA_Hist_Active_Sess_History
                                      CROSS JOIN Ret
                                      WHERE  Sample_Time > SYSDATE-Ret.Days
                                     ) h
                              LEFT OUTER JOIN (SELECT Inst_ID Instance_Number, SQL_Plan_Hash_Value, MIN(Sample_Time) Min_Sample_Time   /* limit Values in AWR-table from SGA*/
                                               FROM   gv$Active_Session_History
                                               GROUP BY  Inst_ID, SQL_Plan_Hash_Value
                                              ) d ON d.Instance_Number = h.Instance_Number AND d.SQL_Plan_Hash_Value = h.SQL_Plan_Hash_Value
                              LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT SQL_ID FROM gv$SQL
                                               UNION
                                               SELECT SQL_ID FROM DBA_Hist_SQLText
                                              ) text_exists ON text_exists.SQL_ID = h.SQL_ID
                              WHERE  h.SQL_Plan_Hash_Value != 0
                              GROUP BY h.SQL_Plan_Hash_Value, h.User_ID
                             ) x
                      JOIN   DBA_Users u ON u.User_ID = x.User_ID
                      WHERE Different_SQL_IDs > ?
                      ORDER BY Different_SQL_IDs DESC",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> t(:dragnet_helper_133_param_1_name, :default=>'Minimum number of different SQL-IDs'), :size=>8, :default=>10, :title=>t(:dragnet_helper_133_param_1_hint, :default=>'Minimum number of different SQL-IDs per plan-hash-value for consideration in selection') }
            ]
        },
        {
            :name  => t(:dragnet_helper_148_name, :default=>'Missing usage of bind variables: Detection by identical plan-hash-value from SQL Area in SGA'),
            :desc  => t(:dragnet_helper_148_desc, :default=>"Usage of literals instead of bind variables with high number of different literals leads to high parse counts and flooding of SQL-Area in SGA.
You may reduce the problem by setting cursor_sharing != EXACT, but you still need large amount of SGA-memory to match your SQL with the corresponding SQL with replaced bind variables.
So strong suggestion is: Use bind variables!
This selection looks for statements with identical execution plans by plan-hash-value from gv$SQL.
"),
            :sql=>  "\
SELECT s.Inst_ID, s.Parsing_Schema_Name, s.Plan_Hash_Value, COUNT(*) Child_Cursors, COUNT(DISTINCT SQL_ID) Different_SQLs, MAX(Last_Active_Time) Max_Last_Active_Time,
       ROUND(SUM(Elapsed_Time)/1000000, 2) Elapsed_Time_Secs,
       MAX(SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Last_Active_Time) Last_Used_SQL_ID,
       COUNT(DISTINCT force_matching_signature) Different_Force_Matching_Signs
FROM   gv$SQL s
WHERE  Plan_Hash_Value > 0
GROUP BY s.Inst_ID, s.Parsing_Schema_Name, s.Plan_Hash_Value
HAVING COUNT(*) > 10
ORDER BY Child_Cursors DESC",
            :parameter=>[
                {:name=> t(:dragnet_helper_148_param_1_name, :default=>'Minimum number of different SQL-IDs'), :size=>8, :default=>10, :title=>t(:dragnet_helper_148_param_1_hint, :default=>'Minimum number of different SQL-IDs per plan-hash-value for consideration in selection') }
            ]
        },
        {
            :name  => t(:dragnet_helper_135_name, :default=>'Missing usage of bind variables: Detection by identical force matching signature from SGA'),
            :desc  => t(:dragnet_helper_135_desc, :default=>"Usage of literals instead of bind variables with high number of different literals leads to high parse counts and flooding of SQL-Area in SGA.
You may reduce the problem by setting cursor_sharing != EXACT, but you still need large amount of SGA-memory to match your SQL with the corresponding SQL with replaced bind variables.
So strong suggestion is: Use bind variables!
This selection looks for statements with identical execution plans by force-matching-signature (or plan-hash-value if force-matching-signature = 0)  from SGA."),
            :sql=>  "SELECT a.Inst_ID                                                         \"Instance\",
                            MIN(a.Force_Matching_Signature)                                   \"Force matching signature\",
                            a.Parsing_Schema_Name                                             \"Parsing schema\",
                            CASE WHEN COUNT(DISTINCT a.Plan_Hash_Value) = 1 THEN TO_CHAR(MIN(a.Plan_Hash_Value)) ELSE '< '||COUNT(DISTINCT a.Plan_Hash_Value)||' >' END \"Plan hash value or no\",
                            COUNT(*)                                                          \"No. of entries in gv$SQLArea\",
                            COUNT(DISTINCT a.SQL_ID)                                          \"No. of different SQL-IDs\",
                            MIN(a.Last_Active_Time)                                           \"Oldest active time\",
                            MAX(a.Last_Active_Time)                                           \"Youngest active time\",
                            MIN(TO_DATE(a.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS'))          \"First load time\",
                            ROUND(SUM(a.Elapsed_Time)/1000000)                                \"Elapsed time (seconds)\",
                            MAX(a.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Last_Active_Time)    \"SQL_ID\",
                            ROUND(SUM(a.Sharable_Mem)  /(1024*1024), 2)                       \"Sharable memory (MB)\",
                            ROUND(SUM(a.Persistent_Mem)/(1024*1024), 2)                       \"Persistent memory (MB)\",
                            ROUND(SUM(a.Runtime_Mem)   /(1024*1024), 2)                       \"Runtime memory (MB)\",
                            SUBSTR(MAX(a.SQL_Text) KEEP (DENSE_RANK LAST ORDER BY Last_Active_Time), 1, 400)  \"SQL text\"
                     FROM   gv$SQLArea a
                     WHERE DECODE(a.Force_Matching_Signature, 0, a.Plan_Hash_Value, a.Force_Matching_Signature) != 0   /* Include INSERTs with Force_Matching_Signature = 0 via Plan_Hash_Value */
                     GROUP BY a.Inst_ID, DECODE(a.Force_Matching_Signature, 0, a.Plan_Hash_Value, a.Force_Matching_Signature), a.Parsing_Schema_Name
                     HAVING COUNT(*) > ?
                     ORDER BY \"No. of entries in gv$SQLArea\" DESC
            ",
            :parameter=>[
                {:name=> t(:dragnet_helper_135_param_1_name, :default=>'Minimum number of different SQL-IDs'), :size=>8, :default=>10, :title=>t(:dragnet_helper_135_param_1_hint, :default=>'Minimum number of different SQL-IDs per plan-hash-value for consideration in selection') }
            ]
        },
        {
            :name  => t(:dragnet_helper_142_name, :default=>'Missing usage of bind variables: Detection by identical force matching signature from AWR history'),
            :desc  => t(:dragnet_helper_142_desc, :default=>"Usage of literals instead of bind variables with high number of different literals leads to high parse counts and flooding of SQL-Area in SGA.
You may reduce the problem by setting cursor_sharing != EXACT, but you still need large amount of SGA-memory to match your SQL with the corresponding SQL with replaced bind variables.
So strong suggestion is: Use bind variables!
This selection looks for statements with identical execution plans by force-matching-signature (or plan-hash-value if force-matching-signature = 0) from AWR history."),
            :sql=>  "\
              SELECT Force_Matching_Signature,
                     Plan_Hash_Value        \"Plan hash value or no\",
                     u.UserName             Parsing_User,
                     different_sql_IDs      \"No. of different SQL-IDs\",
                     Last_Used_SQL_ID,
                     Min_Time               \"First occurrence in AWR\",
                     Max_Time               \"Last occurrence in AWR\",
                     Executions,
                     Elapsed_Secs           \"Elapsed time (seconds)\",
                     (SELECT TO_CHAR(SUBSTR(t.SQL_Text, 1, 400)) FROM DBA_Hist_SQLText t WHERE t.DBID = x.DBID AND t.SQL_ID = x.Last_Used_SQL_ID) SQL_Text
              FROM   (SELECT ss.DBID, MIN(s.Force_Matching_Signature)                             Force_Matching_Signature,
                             CASE WHEN COUNT(DISTINCT s.Plan_Hash_Value) = 1 THEN TO_CHAR(MIN(s.Plan_Hash_Value)) ELSE '< '||COUNT(DISTINCT s.Plan_Hash_Value)||' >' END Plan_Hash_Value,
                             s.Parsing_User_ID,
                             COUNT(DISTINCT s.SQL_ID)                                             Different_SQL_IDs,
                             MAX(s.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY ss.Begin_Interval_Time) Last_Used_SQL_ID,
                             MIN(ss.Begin_Interval_Time)                                          Min_Time,
                             MAX(ss.End_Interval_Time)                                            Max_Time,
                             ROUND(SUM(s.Elapsed_Time_Delta)/1000000)                             Elapsed_Secs,
                             SUM(s.Executions_Delta)                                              Executions
                      FROM   DBA_Hist_Snapshot ss
                      JOIN   DBA_Hist_SQLStat s ON s.DBID = ss.DBID AND s.Instance_Number = ss.Instance_Number AND s.Snap_ID = ss.Snap_ID
                      WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                      AND    DECODE(s.Force_Matching_Signature, 0, s.Plan_Hash_Value, s.Force_Matching_Signature) > 0
                      GROUP BY ss.DBID, DECODE(s.Force_Matching_Signature, 0, s.Plan_Hash_Value, s.Force_Matching_Signature), s.Parsing_User_ID
                      HAVING COUNT(DISTINCT s.SQL_ID) > ?
                     ) x
                     LEFT OUTER JOIN All_Users u ON u.User_ID = x.Parsing_User_ID
              ORDER BY Different_SQL_IDs DESC
            ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> t(:dragnet_helper_142_param_1_name, :default=>'Minimum number of different SQL-IDs'), :size=>8, :default=>10, :title=>t(:dragnet_helper_142_param_1_hint, :default=>'Minimum number of different SQL-IDs per plan-hash-value for consideration in selection') }
            ]
        },
        {
            :name  => t(:dragnet_helper_114_name, :default=>'Missing usage of bind variables: Detection by identical part of SQL-text'),
            :desc  => t(:dragnet_helper_114_desc, :default=>"Usage of literals instead of bind variables with high number of different literals leads to high parse counts and flooding of SQL-Area in SGA.
You may reduce the problem by setting cursor_sharing != EXACT, but you still need large amount of SGA-memory to match your SQL with the corresponding SQL with replaced bind variables.
So strong suggestion is: Use bind variables!
This selection looks for statements in SGA which differentiate themself only by literals. It compares the first x characters of SQL to identify similar statements.
The length of the compared substring may be varied."),
            :sql=>  "WITH Len AS (SELECT ? Substr_Len FROM DUAL)
                       SELECT g.*, s.SQL_Text \"Beispiel SQL-Text\"
                       FROM   (
                               SELECT COUNT(*) Variationen, Inst_ID, MIN(Parsing_Schema_Name) UserName, COUNT(DISTINCT Parsing_Schema_Name) Anzahl_User,
                                      SUBSTR(s.SQL_Text, 1, Len.Substr_Len) SubSQL_Text,
                                      ROUND(SUM(Sharable_Mem+Persistent_Mem+Runtime_Mem)/(1024*1024),3) \"Memory (MB)\",
                                      MIN(s.SQL_ID) SQL_ID,
                                      MIN(TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS')) Min_First_Load,
                                      MIN(Last_Load_Time) Min_Last_Load,
                                      MAX(Last_Load_Time) Max_Last_Load,
                                      MAX(Last_Active_Time) Max_Last_Active,
                                      MIN(Parsing_Schema_Name) Parsing_Schema_Name,
                                      COUNT(DISTINCT Parsing_Schema_Name) \"Different pars. schema names\"
                               FROM   gv$SQLArea s, Len
                               GROUP BY Inst_ID, SUBSTR(s.SQL_Text, 1, Len.Substr_Len)
                               HAVING COUNT(*) > 10
                              ) g
                       JOIN gv$SQLArea s ON s.Inst_ID = g.Inst_ID AND s.SQL_ID = g.SQL_ID
                       ORDER BY \"Memory (MB)\" DESC NULLS LAST
             ",
            :parameter=>[{:name=> t(:dragnet_helper_114_param_1_name, :default=>'Number of characters for comparison of SQLs'), :size=>8, :default=>60, :title=>t(:dragnet_helper_114_param_1_hint, :default=>'Number of characters for comparison of SQLs (beginning at left side of statement)') }]
        },
        {
            :name  => t(:dragnet_helper_125_name, :default=>'Number of distinct SQL-IDs per time in time line'),
            :desc  => t(:dragnet_helper_125_desc, :default=>"The number of dictinct SQL-IDs in time line allows you to identify times where multiple statements with missing bind variables are executed.
You can refine your search using Panorama's view on single samples per time of active session history at menu 'Session waits / Historic'.
Remind the diagram view via context menu 'Show column in diagram'."),
            :sql=>  "
              SELECT Start_Time \"Start Time\", COUNT(*) \"Number of ASH-Samples\", COUNT(DISTINCT SQL_ID) \"Number of different SQLs\"
              FROM   (SELECT TRUNC(Sample_Time, ?) Start_Time, SQL_ID
                      FROM   (#{ash_select(global_filter: "Sample_Time > SYSDATE - ?")})
                     )s
              GROUP BY Start_Time
              ORDER BY 1
             ",
            :parameter=>[
                {:name=> t(:dragnet_helper_125_param_1_name, :default=>'TRUNC-expression for grouping by time unit'), :size=>8, :default=>'MI', :title=>t(:dragnet_helper_125_param_1_hint, :default=>"Expression for TRUNC(Timestamp, 'xx') as grouping criteria ('MI' = minute, 'HH24' = hour etc.) ") },
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }
            ]
        },
        {
            :name  => t(:dragnet_helper_121_name, :default=>'Multiple open cursor: overview over SQL'),
            :desc  => t(:dragnet_helper_121_desc, :default=>'Normally there should be only one open cursor per SQL statement and session.
SQLs with multiple open cursors withon one session my flood session cursor cache and PGA
'),
            :sql=>  "SELECT /* Panorama: Number of open cursor grouped by SQL */
                             oc.*
                      FROM   (
                              SELECT Inst_ID, SQL_ID,
                                     COUNT(*) \"Number of open cursor\",
                                     COUNT(DISTINCT SID) \"Number of sessions\",
                                     ROUND(Count(*) / COUNT(DISTINCT SID),2) \"Open cursors per session\",
                                     MIN(SQL_Text) SQL_Text
                              FROM   gv$Open_Cursor
                              GROUP BY Inst_ID, SQL_ID
                              HAVING Count(*) / COUNT(DISTINCT SID) > 1
                             ) oc
                      ORDER BY 3 DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_122_name, :default=>'Multiple open cursor: SQLs opened multiple in session'),
            :desc  => t(:dragnet_helper_122_desc, :default=>'Normally there should be only one open cursor per SQL statement and session.
SQLs with multiple open cursors withon one session my flood session cursor cache and PGA
'),
            :sql=>  "SELECT /* SQLs mehrfach als Cursor geoeffnet je Session */
                             sq.*, cu.SID \"Session-ID\", s.UserName, cu.Anz_Open_Cursor \"Number of open cursor\", cu.Anz_Sql \"Number of SQLs\",
                             s.Client_Info, s.Machine, s.Program, s.Module, s.Action, cu.SQL_Text
                      FROM   (
                              SELECT oc.Inst_ID, oc.SID, oc.SQL_ID, COUNT(*) Anz_Open_Cursor, COUNT(DISTINCT oc.SQL_ID) Anz_Sql, MIN(oc.SQL_Text) SQL_Text
                              FROM   gv$Open_Cursor oc
                              GROUP BY oc.Inst_ID, oc.SID, oc.SQL_ID
                              HAVING count(*) > COUNT(DISTINCT oc.SQL_ID)
                             ) cu
                      JOIN   gv$Session s ON s.Inst_ID=cu.Inst_ID AND s.SID=cu.SID
                      JOIN   (SELECT Inst_ID, SQL_ID, COUNT(*) \"Number of childs\", MIN(Parsing_schema_name) Parsing_schema_Name
                              FROM gv$SQL
                              GROUP BY Inst_ID, SQL_ID
                             )sq ON sq.Inst_ID = cu.Inst_ID AND sq.SQL_ID = cu.SQL_ID
                      WHERE sq.Parsing_Schema_Name NOT IN (#{system_schema_subselect})
                      ORDER BY cu.Anz_Open_Cursor-cu.Anz_Sql DESC NULLS LAST"
        },
        {
            :name  => t(:dragnet_helper_123_name, :default=>'Concurrency on memory: sqeezing out in shared pool'),
            :desc  => t(:dragnet_helper_123_desc, :default=>"This view lists objects which squeezed out others from shared pool to get place.
While selecting this view it's contents in SGA will be deleted. That means, this view shows replacement since the last execution of this view (only one time).
Value for 'No. Items flushed from shared pool' from 7..8 is normal, higher values indicate problems to find place in shared pool.
Role DBA is required to execute this selection.
"),
            :sql=>  "SELECT /* DB-Tools Ramm  Verdreaengung Shared Pool */
                         RAWTOHEX(Addr)         \"row-address in array or SGA\",
                         Indx         \"index in fixed table array\",
                         Inst_ID      \"Instance\",
                         KsmLrIdx,
                         KsmLrDur,
                         KsmLrShrPool,
                         KsmLrCom     \"Type of allocation\",
                         KsmLrSiz     \"Size of Allocation in Bytes\",
                         KsmLrNum     \"No. items flushed from sh.pool\",
                         KsmLrHon     \"Name of object beeing loaded\",
                         KsmLrOHV     \"HashValue of object\",
                         RAWTOHEX(KsmLrSes)     \"Session Raw (V$Session.SAddr)\",
                         KsmLrADU,
                         KsmLRNID,
                         KSMLRNsd,
                         KSMLRNcd,
                         KsmLRNed
                  FROM   x$ksmlru
                  WHERE  ksmlrnum>0
                  ORDER BY KsmLrNum DESC NULLS LAST",
            exclude_from_test: true,
        },
        {
            :name  => t(:dragnet_helper_124_name, :default=>'Problems with function based index if cursor_sharing != EXACT'),
            :desc  => t(:dragnet_helper_124_desc, :default=>'If setting parameter cursor_sharing=FORCE or SIMILAR at session or instance level function based indexes with literals may not be considered for use,
because this literals become replaced by bind variables.
Solution: Transfer literals into PL/SQL-functions and call this function in function based index instead.
This view selects potential hits for function based indexes no more used for SQL execution.
'),
            :sql=>   "SELECT /* Panorama-Tool Ramm  */
                         i.Owner, i.Index_Name, i.Index_type, i.Table_Name, i.Num_Rows,
                         e.Column_Position, e.Column_Expression
                  FROM   DBA_Indexes i
                  JOIN   DBA_Ind_Expressions e ON e.Index_Owner = i.Owner AND e.Index_Name = i.Index_Name
                  WHERE  Index_Type LIKE 'FUNCTION-BASED%'
                  AND    Owner NOT IN (#{system_schema_subselect})",
            :filter_proc => proc{|rec|
              rec['column_expression'].match(/['0123456789]/)
            },
        },
        {
            :name  => t(:dragnet_helper_57_name, :default => 'Critical amount of child cursors per SQL-ID'),
            :desc  => t(:dragnet_helper_57_desc, :default=>'Large amount of child cursors per SQL-ID (> 500) show risk of latch waits and heavy CPU-usage for parse and execute.
Following counter columns show reasons why parsing SQL results in new child cursor.
Documentation is available here: http://docs.oracle.com/cd/E16655_01/server.121/e17615/refrn30254.htm#REFRN30254'),
            :sql=>   "SELECT /* Panorama-Tool Ramm  */
                         Inst_ID, SQL_ID, COUNT(*) Child_Count
                        #{result = ''
            recs = sql_select_all("SELECT Column_Name FROM DBA_Tab_Columns WHERE Table_Name = 'V_$SQL_SHARED_CURSOR' AND Data_Type = 'VARCHAR2' AND Data_Length = 1 ORDER BY Column_ID")
            recs.each do |rec|
              result << ", SUM(DECODE(#{rec.column_name}, 'Y', 1, 0)) \"#{rec.column_name.gsub('_', ' ')}\"\n"
            end
            result
            }
                    FROM   gv$SQL_Shared_Cursor
                    GROUP BY Inst_ID, SQL_ID
                    HAVING COUNT(*) > ?
                    ORDER BY COUNT(*) DESC",
            :parameter=>[{:name=> t(:dragnet_helper_57_param1_name, :default => 'Min. number of childs per SQL-ID'), :size=>8, :default=>5, :title=> t(:dragnet_helper_57_param1_desc, :default => 'Minimum number of child cursors per SQL-ID for display')}]
        },
    ]
  end


end