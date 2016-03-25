# encoding: utf-8
module Dragnet::SqlsCursorRedundanciesHelper

  private

  def sqls_cursor_redundancies
    [
        {
            :name  => t(:dragnet_helper_114_name, :default=>'Missing usage of bind variables'),
            :desc  => t(:dragnet_helper_114_desc, :default=>'Usage of literals instead of bind variables for filter without compensation by cursor_sharing-parameter leads to high parse counts and flooding of SQL-Area in SGA.
This selection looks for statements which differentiate themself only by literals. It compares the first x characters of SQL to identify similar statements.
The length of the compared substring may be varied.'),
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
                                     ROUND(Count(*) / COUNT(DISTINCT SID),2) \"open cursors per session\",
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
                      WHERE sq.Parsing_Schema_Name NOT IN ('SYS')
                      ORDER BY cu.Anz_Open_Cursor-cu.Anz_Sql DESC NULLS LAST"
        },
        {
            :name  => t(:dragnet_helper_123_name, :default=>'Concurrency on memory: sqeezing out in shared pool'),
            :desc  => t(:dragnet_helper_123_desc, :default=>"This view lists objects which squeezed out others from shared pool to get place.
While selecting this view it's contents in SGA will be deleted. That means, this view shows replacement since the last execution of this view (only one time).
Value for 'No. Items flushed from shared pool' from 7..8 is normal, higher values indicate problems to find place in shared pool.
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
                  AND    Owner NOT IN ('SYS', 'XDB', 'SYSMAN')",
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
                        #{result = '';
            recs = sql_select_all("SELECT Column_Name FROM DBA_Tab_Columns WHERE Table_Name = 'V_$SQL_SHARED_CURSOR' AND Data_Type = 'VARCHAR2' AND Data_Length = 1 ORDER BY Column_ID");
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