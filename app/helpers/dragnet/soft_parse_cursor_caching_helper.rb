# encoding: utf-8
module Dragnet::SoftParseCursorCachingHelper

  private

  def soft_parse_cursor_caching
    [
      { # TODO: Distinguish between hard and soft parses
        name: t(:dragnet_helper_113_name, :default=>'Parse activity'),
        desc: t(:dragnet_helper_113_desc, :default=>'Consideration of ratio parses vs. executes.
                                    For highly frequent parses you should look for alternatives like:
                                    - reuse of already parsed statements in application
                                    - usage of statement caches in application server or JDBC-driver
                                    - usage of DB-feature "session cached cursor"
              '),
        sql:  "SELECT /* DB-Tools Ramm Parse-Ratio single values */ s.*, ROUND(Executions/DECODE(Parses, 0, 1, Parses),2) \"Execs/Parse\"
                      FROM   (
                              SELECT s.SQL_ID, s.Instance_Number, Parsing_schema_Name, SUM(s.Executions_Delta) Executions,
                                     SUM(s.Parse_Calls_Delta) Parses
                              FROM   DBA_Hist_SQLStat s
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.SQL_ID, s.Instance_Number, Parsing_schema_Name
                             ) s
                      ORDER BY Parses DESC NULLS LAST",
        parameter: [{name: t(:dragnet_helper_param_history_backward_name, default: 'Consideration of history backward in days'), size: 8, default: 8, title: t(:dragnet_helper_param_history_backward_hint, default: 'Number of days in history backward from now for consideration') }]
      },
      {
        name: t(:dragnet_helper_156_name, :default=>'JDBC client statement cache probably not used (Evaluation of SGA)'),
        desc: t(:dragnet_helper_156_desc, default: jdbc_statement_cache_desc_default),
        sql:  "\
SELECT SUM(x.Parse_Calls)       Parse_Calls_Total,
       SUM(x.Executions)        Executions_Total,
       ROUND(SUM(x.Parse_Calls) * 100 / SUM(x.Executions), 1) \"Parse pct. of execs\",
       u.UserName, x.Max_ASH_Module, x.Max_ASH_Machine, sv.Name Max_ASH_Service_Name,
       SUM(x.Samples)           ASH_Samples,
       COUNT(DISTINCT SQL_ID)   Distinct_SQL_Statements,
       MAX(Max_Parses_SQL_ID)   Max_Parses_SQL_ID
FROM   (SELECT s.Inst_ID, s.SQL_ID, h.Samples, h.Max_ASH_User_ID, h.Max_ASH_Module, h.Max_ASH_Machine, h.Max_ASH_Service_Hash,
               s.Executions, s.Parse_Calls,
               MAX(s.SQL_ID)  OVER (PARTITION BY h.Max_ASH_User_ID, h.Max_ASH_Module, h.Max_ASH_Machine, h.Max_Ash_Service_Hash ORDER BY s.Parse_Calls DESC) Max_Parses_SQL_ID
        FROM   gv$SQLArea s
        JOIN   (SELECT Inst_ID, SQL_ID, SUM(Samples) Samples,
                        MAX(Max_ASH_User_ID)      Max_ASH_User_ID,
                        MAX(Max_ASH_Module)       Max_ASH_Module,
                        MAX(Max_ASH_Machine)      Max_ASH_Machine,
                        MAX(Max_ASH_Service_Hash) Max_ASH_Service_Hash
                FROM   (
                        SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Module, Action, Machine, Service_Hash, COUNT(*) Samples,
                               MAX(User_ID)      OVER (PARTITION BY Inst_ID, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_User_ID,
                               MAX(Module)       OVER (PARTITION BY Inst_ID, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Module,
                               MAX(Machine)      OVER (PARTITION BY Inst_ID, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Machine,
                               MAX(Service_Hash) OVER (PARTITION BY Inst_ID, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Service_Hash
                        FROM   gv$Active_Session_History h
                        WHERE  SQL_ID IS NOT NULL
                        AND    Program = ?
                        GROUP BY Inst_ID, SQL_ID, User_ID, Module, Action, Machine, Service_Hash
                       )
                GROUP BY Inst_ID, SQL_ID
               ) h ON h.Inst_ID = s.Inst_ID AND h.SQL_ID = s.SQL_ID
       ) x
JOIN   gv$Services sv ON sv.Inst_ID = x.Inst_ID AND sv.Name_Hash = x.Max_ASH_Service_Hash
JOIN   All_Users u    ON u.User_ID = x.Max_ASH_User_ID
GROUP BY u.UserName, x.Max_ASH_Module, x.Max_ASH_Machine, sv.Name
HAVING SUM(x.Parse_Calls) * 100 / SUM(x.Executions) > ?
ORDER BY Parse_Calls_Total DESC
        ",
        parameter: [
          {name: t(:dragnet_helper_156_param2_name, default: 'Program name in ASH'), size: 30, default: 'JDBC Thin Client', title: t(:dragnet_helper_156_param2_hint, default: 'The recorded program name in Active Session History. If not explicitely set the default is "JDBC Thin Client"') },
          {name: t(:dragnet_helper_156_param1_name, default: 'Min. parse count % of execution count'), size: 8, default: 10, title: t(:dragnet_helper_156_param1_hint, default: 'Minimum number of parse counts in % compared to the execution count') },
        ]
      },
      {
        name: t(:dragnet_helper_157_name, :default=>'JDBC client statement cache probably not used (Evaluation of AWR history)'),
        desc: t(:dragnet_helper_156_desc, default: jdbc_statement_cache_desc_default),
        sql:  "\
SELECT SUM(x.Parse_Calls_Delta)       Parse_Calls_Total,
       SUM(x.Executions_Delta)        Executions_Total,
       ROUND(SUM(x.Parse_Calls_Delta) * 100 / SUM(x.Executions_Delta), 1) \"Parse pct. of execs\",
       x.DBID, u.UserName, x.Max_ASH_Module, x.Max_ASH_Machine, sv.Name Max_ASH_Service_Name,
       SUM(x.Samples)           ASH_Samples,
       COUNT(DISTINCT SQL_ID)   Distinct_SQL_IDs,
       MAX(Max_Parses_SQL_ID)   Max_Parses_SQL_ID
FROM   (SELECT s.DBID, s.Instance_Number, s.SQL_ID, h.Samples, h.Max_ASH_User_ID, h.Max_ASH_Module, h.Max_ASH_Machine, h.Max_ASH_Service_Hash,
               s.Executions_Delta, s.Parse_Calls_Delta,
               MAX(s.SQL_ID)  OVER (PARTITION BY h.DBID, h.Max_ASH_User_ID, h.Max_ASH_Module, h.Max_ASH_Machine, h.Max_Ash_Service_Hash ORDER BY s.Parse_Calls_Delta DESC) Max_Parses_SQL_ID
        FROM   DBA_Hist_SQLStat s
        JOIN   (SELECT DBID, Instance_Number, SQL_ID, SUM(Samples) Samples,
                        MAX(Max_ASH_User_ID)      Max_ASH_User_ID,
                        MAX(Max_ASH_Module)       Max_ASH_Module,
                        MAX(Max_ASH_Machine)      Max_ASH_Machine,
                        MAX(Max_ASH_Service_Hash) Max_ASH_Service_Hash
                FROM   (
                        SELECT /*+ NO_MERGE */ h.DBID, h.Instance_Number, SQL_ID, Module, Action, Machine, Service_Hash, COUNT(*) Samples,
                               MAX(User_ID)      OVER (PARTITION BY h.DBID, h.Instance_Number, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_User_ID,
                               MAX(Module)       OVER (PARTITION BY h.DBID, h.Instance_Number, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Module,
                               MAX(Machine)      OVER (PARTITION BY h.DBID, h.Instance_Number, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Machine,
                               MAX(Service_Hash) OVER (PARTITION BY h.DBID, h.Instance_Number, SQL_ID ORDER BY COUNT(*) DESC) Max_ASH_Service_Hash
                        FROM   DBA_Hist_Active_Sess_History h
                        JOIN   DBA_Hist_Snapshot ss ON ss.DBID = h.DBID AND ss.Instance_Number = h.Instance_Number AND ss.Snap_ID = h.Snap_ID
                        WHERE  SQL_ID IS NOT NULL
                        AND    ss.Begin_Interval_Time > SYSDATE - ?
                        AND    Program = ?
                        AND    h.DBID = #{get_dbid}  /* do not count multiple times for multiple different DBIDs/ConIDs */
                        GROUP BY h.DBID, h.Instance_Number, SQL_ID, User_ID, Module, Action, Machine, Service_Hash
                       )
                GROUP BY DBID, Instance_Number, SQL_ID
               ) h ON h.DBID = s.DBID AND h.Instance_Number = s.Instance_Number AND h.SQL_ID = s.SQL_ID
       ) x
LEFT OUTER JOIN   gv$Services sv ON sv.Inst_ID = x.Instance_Number AND sv.Name_Hash = x.Max_ASH_Service_Hash
LEFT OUTER JOIN   All_Users u    ON u.User_ID = x.Max_ASH_User_ID
GROUP BY x.DBID, u.UserName, x.Max_ASH_Module, x.Max_ASH_Machine, sv.Name
HAVING SUM(Parse_Calls_Delta)*100 / SUM(Executions_Delta) > ?
ORDER BY Parse_Calls_Total DESC
        ",
        parameter: [
          {name: t(:dragnet_helper_param_history_backward_name, default: 'Consideration of history backward in days'), size: 8, default: 8, title: t(:dragnet_helper_param_history_backward_hint, default: 'Number of days in history backward from now for consideration') },
          {name: t(:dragnet_helper_156_param2_name, default: 'Program name in ASH'), size: 30, default: 'JDBC Thin Client', title: t(:dragnet_helper_156_param2_hint, default: 'The recorded program name in Active Session History. If not explicitely set the default is "JDBC Thin Client"') },
          {name: t(:dragnet_helper_156_param1_name, default: 'Min. parse count % of execution count'), size: 8, default: 10, title: t(:dragnet_helper_156_param1_hint, default: 'Minumum number of parse counts in % compared to the execution count') }
        ]
      },
    ]
  end

  def jdbc_statement_cache_desc_default
    'High soft parse rate on JDBC Thin connections suggests JDBC client-side statement caching is disabled or undersized.
     Enabling it keeps frequently used cursors open on the connection even after the application closes its statement handles.
     Especially relevant for applications using OR-mapper frameworks, which typically cannot keep cursors open themselves.

     The JDBC statement cache is disabled per default in Oracle\'s JDBC driver.
     There are two ways to activate JDBC client-side statement caching and set cache size (to 100 for example):

     1. Enable on JDBC connection:
     ((OracleConnection)conn).setImplicitCachingEnabled(true));
     ((OracleConnection)conn).setStatementCacheSize(100));

     2. Enable via JDBC URL (starting with DB release 19c):
     jdbc:oracle:thin:@tcp://myorclhostname:1521/myorclservicename?oracle.jdbc.implicitStatementCacheSize=100
    '
  end

end
