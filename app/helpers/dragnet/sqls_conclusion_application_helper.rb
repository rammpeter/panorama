# encoding: utf-8
module Dragnet::SqlsConclusionApplicationHelper

  private

  def sqls_conclusion_application
    [
        {
            :name  => t(:dragnet_helper_76_name, :default=>'Substantial larger runtime per module compared to average over longer time period'),
            :desc  => t(:dragnet_helper_76_desc, :default=>'Based on active session history are shown outlier on databaase runtime per module je Module.
Units for time consideration are defined by date format picture of TRUNC-function (DD=day, HH24=hour etc.)'),
            :sql=>  "WITH Modules AS (
               SELECT /*+ PARALLEL(h,2) */
                      TRUNC(Sample_Time, picture)  Time_Range_Start,
                      Module,
                      MIN(Sample_Time)          First_Occurrence,
                      MAX(Sample_Time)          Last_Occurrence,
                      COUNT(*) * 10             Secs_Waiting
               FROM   DBA_Hist_Active_Sess_History h,
                      (SELECT ? picture FROM DUAL)
               WHERE  Sample_Time > SYSDATE-?
               AND    Instance_Number = ?
               AND    NVL(Event, 'Hugo') NOT IN ('PX Deq Credit: send blkd')
               AND    h.DBID = #{get_dbid}  /* do not count multiple times for multipe different DBIDs/ConIDs */
               GROUP BY TRUNC(Sample_Time, picture), Module
              )
           SELECT Module,
                  SUM(Secs_Waiting)        \"Waiting secs. total\",
                  ROUND(AVG(Secs_Waiting)) \"Waiting secs. avg\",
                  MIN(Secs_Waiting)        \"Waiting secs. min\",
                  MIN(Time_Range_Start) KEEP (DENSE_RANK FIRST ORDER BY Secs_Waiting) \"Time period start of min.\",
                  MAX(Secs_Waiting)        \"Waiting secs. max.\",
                  MAX(Time_Range_Start) KEEP (DENSE_RANK LAST ORDER BY Secs_Waiting) \"Time period start of max.\",
                  MIN(First_Occurrence)    \"First occurrence\",
                  MAX(Last_Occurrence)     \"Last occurrence\"
           FROM   Modules
           GROUP BY Module
           ORDER BY MAX(Secs_Waiting)-AVG(Secs_Waiting) DESC
           ",
            :parameter=>[
                {:name=> 'Format picture for TRUNC-function', :size=>8, :default=> 'DD', :title=> 'Format-picture of TRUNC function (DD=day, HH24=hour etc.)'},
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}
            ]
        },
        {
            :name  => t(:dragnet_helper_51_name, :default=> 'Usage of multi-column primary keys as reference target (business keys instead of technical keys)'),
            :desc  => t(:dragnet_helper_51_desc, :default=>"For ensurance of referential integrity should technical id's be used instead of business expressions.
Often problematic usage of business keys can be detetcted by existence of references on multi-column primary keys"),
            :sql=>  "\
             WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Table_Name, r_Owner, r_Constraint_Name, Constraint_Type
                                  FROM   DBA_Constraints
                                  WHERE  Owner NOT IN (#{system_schema_subselect})
                                 )
             SELECT /* Panorama-Tool Ramm: Fachliche Schluessel*/ p.Owner||'.'||p.Table_Name \"Referenced Table\",
                    MIN(pr.Num_Rows) \"Rows in referenced table\",
                    p.Constraint_Name \"Primary Key\", r.Owner||'.'||r.Table_Name \"Referencing Table\",
                    MIN(tr.Num_Rows) \"Rows in referencing table\",
                    COUNT(*) \"Number of PKey rows\",
                    MIN(c.Column_Name) \"One PKey-Column\",
                    MAX(c.Column_Name) \"Other PKey-Column\"
             FROM   Constraints r
             JOIN   Constraints p  ON p.Owner = r.R_Owner AND p.Constraint_Name = r.r_Constraint_Name
             JOIN   DBA_Cons_Columns c ON c.Owner = p.Owner   AND c.Constraint_Name = p.Constraint_Name
             JOIN   DBA_All_Tables pr  ON pr.Owner = p.Owner AND pr.Table_Name = p.Table_Name
             JOIN   DBA_All_Tables tr  ON tr.Owner = r.Owner AND tr.Table_Name = r.Table_Name
             WHERE  r.Constraint_Type = 'R'
             GROUP BY p.Owner, p.Table_Name, p.Constraint_Name, r.Owner, r.Table_Name, r.Constraint_Name
             HAVING COUNT(*) > 1
             ORDER BY MIN(tr.Num_Rows+pr.Num_Rows) * COUNT(*) DESC NULLS LAST
           ",
            :parameter=>[
            ]
        },
        {
            :name  => t(:dragnet_helper_52_name, :default=> 'Missing suggested AUDIT rules for standard auditing'),
            :desc  => t(:dragnet_helper_52_desc, :default=> 'You should have some minimal audit of logon and DDL operations for traceability of problematic DDL.
Please remind also to establish housekeeping on audit data e.g. table sys.AUD$.'),
            :sql=>  "
              SELECT /* Panorama-Tool Ramm: Auditing */
                     'AUDIT '||NVL(a.Message, a.Name)||';'  \"Suggested audit rule\"
              FROM
              (
              SELECT 'CLUSTER'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'DATABASE LINK'          Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'DIRECTORY'              Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'INDEX'                  Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'MATERIALIZED VIEW'      Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'OUTLINE'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PROCEDURE'              Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PROFILE'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PUBLIC DATABASE LINK'   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PUBLIC SYNONYM'         Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ROLE'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ROLLBACK SEGMENT'       Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SEQUENCE'               Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'CREATE SESSION'         Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYNONYM'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYSTEM AUDIT'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYSTEM GRANT'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TABLE'                  Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ALTER SYSTEM'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TABLESPACE'             Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TRIGGER'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TYPE'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'USER'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'VIEW'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL
              )a
              LEFT OUTER JOIN DBA_Stmt_Audit_Opts d ON  d.Audit_Option = a.Name AND d.User_Name IS NULL AND d.Proxy_Name IS NULL
                                                    AND (d.Success = a.Success OR a.Success = 'NOT SET')
                                                    AND (d.Failure = a.Failure  OR a.Failure = 'NOT SET')
              WHERE d.Audit_Option IS NULL
           ",
            :parameter=>[
            ]
        },
        {
          :name  => t(:dragnet_helper_175_name, :default=> 'Missing suggested AUDIT rules for unified auditing'),
          :desc  => t(:dragnet_helper_175_desc, :default=> 'You should have some minimal audit of logon and DDL operations for traceability of problematic DDL.
Please remind also to establish housekeeping on audit data.'),
          min_db_version: '12.2',
          :sql=>  "
WITH Policies AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM Audit_Unified_Policies),
     Enabled_Policies AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM Audit_Unified_Enabled_Policies),
     Current_Options AS (SELECT x.*,
                                CASE WHEN Enabled       = 'YES'        /* Policy should be enabled */
                                AND  Enabled_Option     = 'BY USER'    /* Option should not be restricted */
                                AND  Entity_Name        = 'ALL USERS'  /* global enabled should not be restricted */
                                AND  Object_Schema      = 'NONE'       /* Should be enabled for all schemas */
                                AND  Object_Name        = 'NONE'       /* should be enabled for all objects */
                                AND  Audit_Condition    = 'NONE'       /* there should be no filter */
                                AND  Condition_Eval_Opt = 'NONE'       /* there should be no filter */
                                AND  Success            = 'YES'        /* should be logged for success */
                                AND  Failure            = 'YES'        /* should be logged for failure */
                                THEN 'YES' ELSE 'NO' END Accepted
                         FROM   (
                                 SELECT p.Audit_option, p.Policy_Name, 'YES' Enabled, ep.Enabled_Option, ep.Entity_Name,
                                        p.Object_Schema, p.Object_Name, p.Audit_Condition, p.Condition_Eval_Opt,
                                        ep.Success, ep.Failure
                                 FROM   Policies p
                                 JOIN   Enabled_Policies ep ON ep.Policy_Name = p.Policy_Name
                                 UNION ALL
                                 SELECT Audit_Option, p.Policy_Name, 'NO' Enabled, NULL Enabled_Option, NULL Entity_Name,
                                        NULL Object_Schema, NULL Object_Name, NULL Audit_Condition, NULL Condition_Eval_Opt,
                                        NULL Success, NULL Failure
                                 FROM   Policies p
                                 WHERE  p.Policy_Name NOT IN (SELECT Policy_Name FROM Enabled_Policies)
                                ) x
                        ),
     Expected_Options AS (SELECT 'LOGON' Audit_Option FROM DUAL UNION ALL
                          SELECT 'LOGOFF' FROM DUAL UNION ALL
                          SELECT 'BECOME USER' FROM DUAL UNION ALL
                          SELECT 'ADMINISTER KEY MANAGEMENT' FROM DUAL UNION ALL
                          SELECT 'ALTER ANALYTIC VIEW' FROM DUAL UNION ALL
                          SELECT 'ALTER AUDIT POLICY' FROM DUAL UNION ALL
                          SELECT 'ALTER CLUSTER' FROM DUAL UNION ALL
                          SELECT 'ALTER DATABASE' FROM DUAL UNION ALL
                          SELECT 'ALTER DATABASE DICTIONARY' FROM DUAL UNION ALL
                          SELECT 'ALTER DATABASE LINK' FROM DUAL UNION ALL
                          SELECT 'ALTER DISK GROUP' FROM DUAL UNION ALL
                          SELECT 'ALTER FLASHBACK ARCHIVE' FROM DUAL UNION ALL
                          SELECT 'ALTER INDEX' FROM DUAL UNION ALL
                          SELECT 'ALTER INDEXTYPE' FROM DUAL UNION ALL
                          SELECT 'ALTER JAVA' FROM DUAL UNION ALL
                          SELECT 'ALTER LIBRARY' FROM DUAL UNION ALL
                          SELECT 'ALTER LOCKDOWN PROFILE' FROM DUAL UNION ALL
                          SELECT 'ALTER MATERIALIZED VIEW' FROM DUAL UNION ALL
                          SELECT 'ALTER MATERIALIZED VIEW LOG' FROM DUAL UNION ALL
                          SELECT 'ALTER MATERIALIZED ZONEMAP' FROM DUAL UNION ALL
                          SELECT 'ALTER OUTLINE' FROM DUAL UNION ALL
                          SELECT 'ALTER PACKAGE' FROM DUAL UNION ALL
                          SELECT 'ALTER PACKAGE BODY' FROM DUAL UNION ALL
                          SELECT 'ALTER PLUGGABLE DATABASE' FROM DUAL UNION ALL
                          SELECT 'ALTER PROCEDURE' FROM DUAL UNION ALL
                          SELECT 'ALTER PROFILE' FROM DUAL UNION ALL
                          SELECT 'ALTER ROLE' FROM DUAL UNION ALL
                          SELECT 'ALTER ROLLBACK SEGMENT' FROM DUAL UNION ALL
                          SELECT 'ALTER SEQUENCE' FROM DUAL UNION ALL
                          SELECT 'ALTER SYNONYM' FROM DUAL UNION ALL
                          SELECT 'ALTER SYSTEM' FROM DUAL UNION ALL
                          SELECT 'ALTER TABLE' FROM DUAL UNION ALL
                          SELECT 'ALTER TABLESPACE' FROM DUAL UNION ALL
                          SELECT 'ALTER TRACING' FROM DUAL UNION ALL
                          SELECT 'ALTER TRIGGER' FROM DUAL UNION ALL
                          SELECT 'ALTER TYPE' FROM DUAL UNION ALL
                          SELECT 'ALTER TYPE BODY' FROM DUAL UNION ALL
                          SELECT 'ALTER USER' FROM DUAL UNION ALL
                          SELECT 'ALTER VIEW' FROM DUAL UNION ALL
                          SELECT 'ANALYZE CLUSTER' FROM DUAL UNION ALL
                          SELECT 'ANALYZE INDEX' FROM DUAL UNION ALL
                          SELECT 'ANALYZE TABLE' FROM DUAL UNION ALL
                          SELECT 'AUDIT' FROM DUAL UNION ALL
                          SELECT 'CHANGE PASSWORD' FROM DUAL UNION ALL
                          SELECT 'CREATE ANALYTIC VIEW' FROM DUAL UNION ALL
                          SELECT 'CREATE AUDIT POLICY' FROM DUAL UNION ALL
                          SELECT 'CREATE CLUSTER' FROM DUAL UNION ALL
                          SELECT 'CREATE CONTEXT' FROM DUAL UNION ALL
                          SELECT 'CREATE DATABASE LINK' FROM DUAL UNION ALL
                          SELECT 'CREATE DISK GROUP' FROM DUAL UNION ALL
                          SELECT 'CREATE EDITION' FROM DUAL UNION ALL
                          SELECT 'CREATE FLASHBACK ARCHIVE' FROM DUAL UNION ALL
                          SELECT 'CREATE INDEX' FROM DUAL UNION ALL
                          SELECT 'CREATE INDEXTYPE' FROM DUAL UNION ALL
                          SELECT 'CREATE JAVA' FROM DUAL UNION ALL
                          SELECT 'CREATE LIBRARY' FROM DUAL UNION ALL
                          SELECT 'CREATE LOCKDOWN PROFILE' FROM DUAL UNION ALL
                          SELECT 'CREATE MATERIALIZED VIEW' FROM DUAL UNION ALL
                          SELECT 'CREATE MATERIALIZED VIEW LOG' FROM DUAL UNION ALL
                          SELECT 'CREATE MATERIALIZED ZONEMAP' FROM DUAL UNION ALL
                          SELECT 'CREATE OUTLINE' FROM DUAL UNION ALL
                          SELECT 'CREATE PACKAGE' FROM DUAL UNION ALL
                          SELECT 'CREATE PACKAGE BODY' FROM DUAL UNION ALL
                          SELECT 'CREATE PFILE' FROM DUAL UNION ALL
                          SELECT 'CREATE PLUGGABLE DATABASE' FROM DUAL UNION ALL
                          SELECT 'CREATE PROCEDURE' FROM DUAL UNION ALL
                          SELECT 'CREATE PROFILE' FROM DUAL UNION ALL
                          SELECT 'CREATE RESTORE POINT' FROM DUAL UNION ALL
                          SELECT 'CREATE ROLE' FROM DUAL UNION ALL
                          SELECT 'CREATE ROLLBACK SEGMENT' FROM DUAL UNION ALL
                          SELECT 'CREATE SCHEMA' FROM DUAL UNION ALL
                          SELECT 'CREATE SCHEMA SYNONYM' FROM DUAL UNION ALL
                          SELECT 'CREATE SEQUENCE' FROM DUAL UNION ALL
                          SELECT 'CREATE SPFILE' FROM DUAL UNION ALL
                          SELECT 'CREATE SYNONYM' FROM DUAL UNION ALL
                          SELECT 'CREATE TABLE' FROM DUAL UNION ALL
                          SELECT 'CREATE TABLESPACE' FROM DUAL UNION ALL
                          SELECT 'CREATE TRIGGER' FROM DUAL UNION ALL
                          SELECT 'CREATE TYPE' FROM DUAL UNION ALL
                          SELECT 'CREATE TYPE BODY' FROM DUAL UNION ALL
                          SELECT 'CREATE USER' FROM DUAL UNION ALL
                          SELECT 'CREATE VIEW' FROM DUAL UNION ALL
                          SELECT 'DEBUG CONNECT' FROM DUAL UNION ALL
                          SELECT 'DROP ANALYTIC VIEW' FROM DUAL UNION ALL
                          SELECT 'DROP AUDIT POLICY' FROM DUAL UNION ALL
                          SELECT 'DROP CLUSTER' FROM DUAL UNION ALL
                          SELECT 'DROP CONTEXT' FROM DUAL UNION ALL
                          SELECT 'DROP DATABASE LINK' FROM DUAL UNION ALL
                          SELECT 'DROP DISK GROUP' FROM DUAL UNION ALL
                          SELECT 'DROP EDITION' FROM DUAL UNION ALL
                          SELECT 'DROP FLASHBACK ARCHIVE' FROM DUAL UNION ALL
                          SELECT 'DROP INDEX' FROM DUAL UNION ALL
                          SELECT 'DROP INDEXTYPE' FROM DUAL UNION ALL
                          SELECT 'DROP JAVA' FROM DUAL UNION ALL
                          SELECT 'DROP LIBRARY' FROM DUAL UNION ALL
                          SELECT 'DROP LOCKDOWN PROFILE' FROM DUAL UNION ALL
                          SELECT 'DROP MATERIALIZED VIEW' FROM DUAL UNION ALL
                          SELECT 'DROP MATERIALIZED VIEW LOG' FROM DUAL UNION ALL
                          SELECT 'DROP MATERIALIZED ZONEMAP' FROM DUAL UNION ALL
                          SELECT 'DROP OUTLINE' FROM DUAL UNION ALL
                          SELECT 'DROP PACKAGE' FROM DUAL UNION ALL
                          SELECT 'DROP PACKAGE BODY' FROM DUAL UNION ALL
                          SELECT 'DROP PLUGGABLE DATABASE' FROM DUAL UNION ALL
                          SELECT 'DROP PROCEDURE' FROM DUAL UNION ALL
                          SELECT 'DROP PROFILE' FROM DUAL UNION ALL
                          SELECT 'DROP RESTORE POINT' FROM DUAL UNION ALL
                          SELECT 'DROP ROLE' FROM DUAL UNION ALL
                          SELECT 'DROP ROLLBACK SEGMENT' FROM DUAL UNION ALL
                          SELECT 'DROP SCHEMA SYNONYM' FROM DUAL UNION ALL
                          SELECT 'DROP SEQUENCE' FROM DUAL UNION ALL
                          SELECT 'DROP SYNONYM' FROM DUAL UNION ALL
                          SELECT 'DROP TABLE' FROM DUAL UNION ALL
                          SELECT 'DROP TABLESPACE' FROM DUAL UNION ALL
                          SELECT 'DROP TRIGGER' FROM DUAL UNION ALL
                          SELECT 'DROP TYPE' FROM DUAL UNION ALL
                          SELECT 'DROP TYPE BODY' FROM DUAL UNION ALL
                          SELECT 'DROP USER' FROM DUAL UNION ALL
                          SELECT 'DROP VIEW' FROM DUAL UNION ALL
                          SELECT 'FLASHBACK TABLE' FROM DUAL UNION ALL
                          SELECT 'GRANT' FROM DUAL UNION ALL
                          --SELECT 'LOCK TABLE' FROM DUAL UNION ALL
                          SELECT 'NOAUDIT' FROM DUAL UNION ALL
                          SELECT 'PURGE DBA_RECYCLEBIN' FROM DUAL UNION ALL
                          SELECT 'PURGE INDEX' FROM DUAL UNION ALL
                          SELECT 'PURGE RECYCLEBIN' FROM DUAL UNION ALL
                          SELECT 'PURGE TABLE' FROM DUAL UNION ALL
                          SELECT 'PURGE TABLESPACE' FROM DUAL UNION ALL
                          SELECT 'RENAME' FROM DUAL UNION ALL
                          SELECT 'REVOKE' FROM DUAL UNION ALL
                          SELECT 'SET ROLE' FROM DUAL UNION ALL
                          SELECT 'TRUNCATE CLUSTER' FROM DUAL UNION ALL
                          SELECT 'TRUNCATE TABLE' FROM DUAL
                         )
SELECT eo.Audit_Option Suggested_Audit_Action,
       CASE WHEN COUNT(DISTINCT co.Policy_Name)         > 1 THEN '< '||COUNT(DISTINCT co.Policy_Name)         ||' >' ELSE MIN(co.Policy_Name)         END Existing_Policy,
       CASE WHEN COUNT(DISTINCT co.Enabled)             > 1 THEN '< '||COUNT(DISTINCT co.Enabled)             ||' >' ELSE MIN(co.Enabled)             END Policy_Enabled,
       CASE WHEN COUNT(DISTINCT co.Enabled_Option)      > 1 THEN '< '||COUNT(DISTINCT co.Enabled_Option)      ||' >' ELSE MIN(co.Enabled_Option)      END Enabled_Option,
       CASE WHEN COUNT(DISTINCT co.Entity_Name)         > 1 THEN '< '||COUNT(DISTINCT co.Entity_Name)         ||' >' ELSE MIN(co.Entity_Name)         END Entity_Name,
       CASE WHEN COUNT(DISTINCT co.Object_Schema)       > 1 THEN '< '||COUNT(DISTINCT co.Object_Schema)       ||' >' ELSE MIN(co.Object_Schema)       END Object_Schema,
       CASE WHEN COUNT(DISTINCT co.Object_Name)         > 1 THEN '< '||COUNT(DISTINCT co.Object_Name)         ||' >' ELSE MIN(co.Object_Name)         END Object_Name,
       CASE WHEN COUNT(DISTINCT co.Audit_Condition)     > 1 THEN '< '||COUNT(DISTINCT co.Audit_Condition)     ||' >' ELSE MIN(co.Audit_Condition)     END Audit_Condition,
       CASE WHEN COUNT(DISTINCT co.Condition_Eval_Opt)  > 1 THEN '< '||COUNT(DISTINCT co.Condition_Eval_Opt)  ||' >' ELSE MIN(co.Condition_Eval_Opt)  END Condition_Eval_Opt,
       CASE WHEN COUNT(DISTINCT co.Success)             > 1 THEN '< '||COUNT(DISTINCT co.Success)             ||' >' ELSE MIN(co.Success)  END        Success,
       CASE WHEN COUNT(DISTINCT co.Failure)             > 1 THEN '< '||COUNT(DISTINCT co.Failure)             ||' >' ELSE MIN(co.Failure)  END        Failure
FROM   Expected_Options eo
LEFT OUTER JOIN Current_Options co ON co.Audit_Option = eo.Audit_Option
GROUP BY eo.Audit_Option
HAVING SUM(CASE WHEN NVL(co.Accepted, 'NO') = 'YES' THEN 1 ELSE 0 END) = 0 /* No record with accepted = 'YES' among the results */
ORDER BY eo.Audit_Option
           ",
          :parameter=>[
          ]
        },
        {
            :name  => t(:dragnet_helper_53_name, :default=> 'Long running transactions from SGA (gv$Active_Session_History)'),
            :desc  => t(:dragnet_helper_53_desc, :default=>"Long running transactions contains the risk of lock escalations in OLTP-systems.
Writing access should be suspended to the end of process transactions to keep lock time until commit as short as possible.
Transaktions in OLTP-systems should be short enough to keep potential lock wait time below user's cognition limits.
           "),
            :sql=>  "
              SELECT s.*,
                     (SELECT UserName FROM DBA_Users u WHERE u.User_ID = s.User_ID) UserName
              FROM   (
                      SELECT RAWTOHEX(XID)                  \"Transaction-ID\",
                             MIN(Min_Sample_Time)           \"Start Tx.\",
                             MAX(Max_Sample_Time)           \"End Tx.\",
                             SUM(Samples)                   \"No. of Samples\",
                             ROUND(24*60*60*(CAST(MAX(Max_Sample_Time) AS DATE)-CAST(MIN(Min_Sample_Time) AS DATE))) \"Duration (Secs.)\",
                             MIN(Min_SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Min_Sample_Time)       \"First SQL-ID\",
                             MAX(Max_SQL_ID) KEEP (DENSE_RANK LAST  ORDER BY Max_Sample_Time)       \"Last SQL-ID\",
                             MIN(Inst_ID)                   \"Instance\",
                             MIN(TO_CHAR(Session_ID))       \"SID\",
                             MIN(TO_CHAR(Session_Serial#))  \"Serial number\",
                             MIN(Session_Type)              \"Session Type\",
                             MIN(User_ID)                   User_ID,
                             MIN(Program)                   \"Program\",
                             MIN(Module)                    \"Module\",
                             MIN(Action)                    \"Action\",
                             MIN(Client_ID)                 \"Client-ID\",
                             MAX(Event) KEEP (DENSE_RANK LAST ORDER BY Samples) \"Main Event\"
                      FROM   (SELECT XID, NVL(Event, Session_State) Event,
                                     MIN(Sample_Time)               Min_Sample_Time,
                                     MAX(Sample_Time)               Max_Sample_Time,
                                     COUNT(*)                       Samples,
                                     MIN(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Min_SQL_ID,
                                     MAX(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Max_SQL_ID,
                                     MIN(Inst_ID)                   Inst_ID,
                                     MIN(Session_ID)                Session_ID,
                                     MIN(Session_Serial#)           Session_Serial#,
                                     MIN(Session_Type)              Session_Type,
                                     MIN(User_ID)                   User_ID,
                                     MIN(User_ID)                   Program,
                                     MIN(Module)                    Module,
                                     MIN(Action)                    Action,
                                     MIN(Client_ID)                 Client_ID
                              FROM   gv$active_session_history s
                              WHERE  XID IS NOT NULL
                              GROUP BY XID, NVL(Event, Session_State)
                             )
                      GROUP BY XID
                     ) s
              WHERE  \"Duration (Secs.)\" > ?
              ORDER BY \"Duration (Secs.)\" DESC
           ",
            :parameter=>[
                {:name=> 'Minimale Transaktionsdauer in Sekunden', :size=>8, :default=>300, :title=> 'Minimale Dauer der Transaktion in Sekunden für Aufnahme in Selektion'},
            ]
        },
        {
            :name  => t(:dragnet_helper_54_name, :default=> 'Long running transactions from AWH-history (DBA_Hist_Active_Sess_History)'),
            :desc  => t(:dragnet_helper_54_desc, :default=>"Long running transactions contains the risk of lock escalations in OLTP-systems.
Writing access should be suspended to the end of process transactions to keep lock time until commit as short as possible.
Transaktions in OLTP-systems should be short enough to keep potential lock wait time below user's cognition limits.
           "),
            :sql=>  "
              SELECT s.*,
                     (SELECT UserName FROM DBA_Users u WHERE u.User_ID = s.User_ID) UserName
              FROM   (
                      SELECT RAWTOHEX(XID)                  \"Transaction-ID\",
                             MIN(Min_Sample_Time)           \"Start Tx.\",
                             MAX(Max_Sample_Time)           \"End Tx.\",
                             SUM(Samples)                   \"No. of Samples\",
                             ROUND(24*60*60*(CAST(MAX(Max_Sample_Time) AS DATE)-CAST(MIN(Min_Sample_Time) AS DATE))) \"Duration (Secs.)\",
                             MIN(Min_SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Min_Sample_Time)       \"First SQL-ID\",
                             MAX(Max_SQL_ID) KEEP (DENSE_RANK LAST  ORDER BY Max_Sample_Time)       \"Last SQL-ID\",
                             MIN(Inst_ID)                   \"Instance\",
                             MIN(TO_CHAR(Session_ID))       \"SID\",
                             MIN(TO_CHAR(Session_Serial#))  \"Serial number\",
                             MIN(Session_Type)              \"Session Type\",
                             MIN(User_ID)                   User_ID,
                             MIN(Program)                   \"Program\",
                             MIN(Module)                    \"Module\",
                             MIN(Action)                    \"Action\",
                             MIN(Client_ID)                 \"Client-ID\",
                             MAX(Event) KEEP (DENSE_RANK LAST ORDER BY Samples) \"Main Event\"
                      FROM   (SELECT /*+ PARALLEL(s,2) */ XID, NVL(Event, Session_State) Event,
                                     MIN(Sample_Time)               Min_Sample_Time,
                                     MAX(Sample_Time)               Max_Sample_Time,
                                     COUNT(*)                       Samples,
                                     MIN(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Min_SQL_ID,
                                     MAX(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Max_SQL_ID,
                                     MIN(Instance_Number)                   Inst_ID,
                                     MIN(Session_ID)                Session_ID,
                                     MIN(Session_Serial#)           Session_Serial#,
                                     MIN(Session_Type)              Session_Type,
                                     MIN(User_ID)                   User_ID,
                                     MIN(User_ID)                   Program,
                                     MIN(Module)                    Module,
                                     MIN(Action)                    Action,
                                     MIN(Client_ID)                 Client_ID
                              FROM   DBA_Hist_Active_Sess_History s
                              WHERE  XID IS NOT NULL
                              AND    Sample_Time > SYSDATE-?
                              AND    s.DBID = #{get_dbid}  /* do not count multiple times for multipe different DBIDs/ConIDs */
                              GROUP BY XID, NVL(Event, Session_State)
                             )
                      GROUP BY XID
                     ) s
              WHERE  \"Duration (Secs.)\" > ?
              ORDER BY \"Duration (Secs.)\" DESC
           ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> 'Minimale Transaktionsdauer in Sekunden', :size=>8, :default=>300, :title=> 'Minimale Dauer der Transaktion in Sekunden für Aufnahme in Selektion'},
            ]
        },
        {
            :name  => t(:dragnet_helper_62_name, :default=>'Longer inactive sessions with continued active transactions'),
            :desc  => t(:dragnet_helper_62_desc, :default=>'Longer inactive sessions with continued active transactions may indicate to:
- not finished manual activities, e.g. transaction control by GUI
- sessions returned to connection pools without finished transaction
           '),
            :sql=>  "
            WITH /* Test auf nicht commitete inaktive Sessions im Connection-Pool, Ramm 25.11.14 */
                 Sessions AS (SELECT /*+ MATERIALIZE NO_MERGE FULL(s) */
                                    Inst_ID, SID, Serial#, Status, UserName, Machine, OSUser, Prev_SQL_ID,
                                    Prev_Exec_Start, Module, Action, Logon_Time, Last_Call_ET
                             FROM   gv$Session s
                             WHERE  Status = 'INACTIVE'
                             AND    Last_Call_ET > ?
                            ),
                 Locks AS (SELECT /*+ MATERIALIZE NO_MERGE FULL(l) */
                                 Inst_ID, SID, Type, Request, LMode, ID1, ID2
                          FROM   gv$Lock l
                         )
            SELECT /*+ FULL(s) FULL(l) USE_HASH(s l) */
                   s.Inst_ID, s.SID, s.Serial#, s.UserName, s.Machine, s.OSUser,
                   s.Prev_SQL_ID  \"SQL-ID of last activity\",
                   s.Prev_Exec_Start  \"Start time of last activity\",
                   s.Module, s.Action,
                   s.Logon_Time,
                   s.Last_Call_ET \"Seconds since last activity\",
                   l.Type         \"Lock type\",
                   l.Request, l.LMode, lo.Owner, lo.Object_Name, l.ID1, l.ID2, bs.Blocked_Sessions
            FROM   Sessions s
            JOIN   Locks l ON l.Inst_ID = s.Inst_ID AND l.SID = s.SID
            LEFT OUTER JOIN DBA_Objects lo ON lo.Object_ID = l.ID1
            LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Blocking_Instance, Blocking_Session, COUNT(*) Blocked_Sessions
                             FROM   gv$Session
                             WHERE  Blocking_Session IS NOT NULL
                             GROUP BY Blocking_Instance, Blocking_Session
                            ) bs ON bs.Blocking_Instance = s.Inst_ID AND bs.Blocking_Session = s.SID
            WHERE  s.UserName NOT IN (#{system_schema_subselect})
            AND    l.Type NOT IN ('AE', 'PS', 'TO')
            ORDER BY s.Last_Call_ET DESC
           ",
            :parameter=>[
                {:name=> t(:dragnet_helper_62_param_1_name, :default=>'Minimum duration (seconds) since last activity of session'), :size=>8, :default=>60, :title=> t(:dragnet_helper_62_param_1_hint, :default=>'Minimum duration (seconds) since end of last activity of session')},
            ]
        },
        {
            :name  => t(:dragnet_helper_132_name, :default=>'Excessive logon operations (by listener-log)'),
            :desc  => t(:dragnet_helper_132_desc, :default=>"An excessive number of logon operations may cause significant CPU-usage and possibly write I/O (e.g. for auditing).
It also slows down the application waiting for the connect.
Alternative solutions are usage of session pools, prevent subsequent LOGON/LOGOFF operations in loops.
This selection shows the logon operations per minute for the database instance you are connected on.
For evaluation of RAC-systems you have to execute this selection once for every considered RAC-node directly connected to this node.
Detailed information about LOGON operations is available via menu 'DBA general / Server Logs'
            "),
            :sql=>  "
              SELECT Timestamp, SUM(Connects) Connects_Total,
                     MAX(Client_Host  ||' ('||Connects_Client_Host||')')   KEEP (DENSE_RANK LAST ORDER BY Connects_Client_Host)  Top_Client_Host,
                     MAX(Client_IP    ||' ('||Connects_Client_IP||')')     KEEP (DENSE_RANK LAST ORDER BY Connects_Client_IP)    Top_Client_IP,
                     MAX(Client_User  ||' ('||Connects_Client_User||')')   KEEP (DENSE_RANK LAST ORDER BY Connects_Client_User)  Top_Client_User,
                     MAX(Service_Name ||' ('||Connects_Service_Name||')')  KEEP (DENSE_RANK LAST ORDER BY Connects_Service_Name) Top_Service_Name,
                     MAX(Connects) Connects_by_Top_Combination
              FROM   (
                      SELECT TRUNC(Originating_Timestamp, 'MI') Timestamp, Client_IP, Client_User, Client_Host, Service_Name, COUNT(*) Connects,
                             MAX(Connects_Client_IP)    Connects_Client_IP,
                             MAX(Connects_Client_User)  Connects_Client_User,
                             MAX(Connects_Client_Host)  Connects_Client_Host,
                             MAX(Connects_Service_Name) Connects_Service_Name
                      FROM   (
                              SELECT Originating_Timestamp, Client_IP, Client_User, Client_Host, Service_Name,
                                     SUM(DECODE(Client_IP,    NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_IP)    Connects_Client_IP,
                                     SUM(DECODE(Client_User,  NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_User)  Connects_Client_User,
                                     SUM(DECODE(Client_Host,  NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_Host)  Connects_Client_Host,
                                     SUM(DECODE(Service_Name, NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Service_Name) Connects_Service_Name
                              FROM   (
                                      SELECT Originating_Timestamp,
                                             SUBSTR(SUBSTR(Address, INSTR(Address, 'HOST=')+5), 1, INSTR(SUBSTR(Address, INSTR(Address, 'HOST=')+5), ')')-1) Client_IP,
                                             SUBSTR(UserName, 1, INSTR(UserName, ')')-1)        Client_User,
                                             SUBSTR(ClientHost, 1, INSTR(ClientHost, ')')-1)    Client_Host,
                                             SUBSTR(ServiceName, 1, INSTR(ServiceName, ')')-1)  Service_Name
                                      FROM   (
                                              SELECT Originating_Timestamp, Message_Text,
                                                     SUBSTR(Message_Text, INSTR(Message_Text, 'ADDRESS=')) Address,
                                                     SUBSTR(Message_Text, INSTR(Message_Text, 'USER=')+5) UserName,
                                                     CASE WHEN INSTR(Message_Text, 'SERVICE_NAME=') >0  THEN SUBSTR(Message_Text, INSTR(Message_Text, 'SERVICE_NAME=')+13) END ServiceName,
                                                     SUBSTR(Message_Text, INSTR(Message_Text, 'HOST=')+5) ClientHost
                                              FROM   V$DIAG_ALERT_EXT
                                              WHERE  TRIM(Component_ID) = 'tnslsnr'
                                              AND    Message_Text LIKE '%CONNECT_DATA%'
                                              AND    Message_Text LIKE '%* establish *%'
                                              AND    Originating_Timestamp > SYSDATE - ?
                                             )
                                     )
                             )
                      GROUP BY TRUNC(Originating_Timestamp, 'MI'), Client_IP, Client_User, Client_Host, Service_Name
                     )
              GROUP BY Timestamp
              ORDER BY Timestamp
           ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>1, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            ]
        },
        {
          :name  => t(:dragnet_helper_161_name, :default=>'Excessive logon operations (by current gv$Session)'),
          :desc  => t(:dragnet_helper_161_desc, :default=>"An excessive number of logon operations may cause significant CPU-usage and possibly write I/O (e.g. for auditing).
It also slows down the application waiting for the connect.
Alternative solutions are usage of session pools, prevent subsequent LOGON/LOGOFF operations in loops.
This selection shows sessions that were created shortly before.
            "),
          :sql=>  "\
SELECT s.Inst_ID, s.SID, s.Serial#, s.AudSID, s.UserName, s.OSUser, s.Process,
                       s.Machine, s.Port, s.Program, s.SQL_ID, s.SQL_Exec_Start, s.Module,
                       s.Action, s.Client_Info, s.Logon_Time, s.Service_Name
FROM   gv$Session s
LEFT OUTER JOIN gv$PX_Session pxs ON pxs.Inst_ID = s.Inst_ID AND pxs.SID = s.SID AND pxs.Serial#=s.Serial#
WHERE  s.Type = 'USER'
AND    pxs.SID IS NULL
    AND    Program NOT LIKE '%(PP%)'    /* Exclude own PQ processes that don't appear in gv$PX_Session while selecting from multiple RAC instances */
    AND    Logon_Time > SYSDATE-1/(86400/?) /* Session not older than x seconds */
           ",
          :parameter=>[
            {:name=>t(:dragnet_helper_161_param_1_name, :default=>'Maximum age of session in seconds'), :size=>8, :default=>1, :title=>t(:dragnet_helper_161_param_1_hint, :default=>'Maximum age of session in seconds (since v$Session.logon_time) to be considered in selection') },
          ]
        },
        {
            :name  => t(:dragnet_helper_145_name, :default=>'Possibly missing guaranty of uniqueness by unique index or unique / primary key constraint'),
            :desc  => t(:dragnet_helper_145_desc, :default=>"If an implicit expectation for uniqueness of a column exists, then this should be safeguarded by an unique index or unique constraint.
This list shows all all columns with unique values at the time of last analysis if neither unqiue index nor unique constraint exists for this column.
            "),
            :sql=>  "
WITH Constraints  AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Table_Name, Constraint_Type FROM DBA_Constraints WHERE Constraint_Type IN ('P', 'U')),
     Indexes      AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name FROM DBA_Indexes WHERE Uniqueness = 'UNIQUE'),
     Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Column_name FROM DBA_Cons_Columns WHERE Position = 1),
     Ind_Columns  AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Column_name FROM DBA_Ind_Columns WHERE Column_Position = 1)
SELECT tc.Owner, tc.Table_Name, tc.Column_Name, t.Num_Rows, tc.Num_Distinct, tc.Num_Nulls, tc.Num_Distinct+tc.Num_Nulls Distinct_and_Nulls
FROM   DBA_Tab_Columns tc
JOIN   DBA_All_Tables t ON t.Owner = tc.Owner AND t.Table_Name = tc.Table_Name
WHERE  tc.Num_Distinct + tc.Num_Nulls >= t.Num_Rows
AND    tc.Num_Distinct > 1
AND    tc.Owner NOT IN (#{system_schema_subselect})
AND    (tc.Owner, tc.Table_Name, tc.Column_Name) NOT IN (
            SELECT i.Table_Owner, i.Table_Name, ic.Column_Name
            FROM   Ind_Columns ic
            JOIN   Indexes i ON i.Owner = ic.Index_Owner AND i.Index_Name = ic.Index_Name
)
AND    (tc.Owner, tc.Table_Name, tc.Column_Name) NOT IN (
            SELECT c.Owner, c.Table_Name, cc.Column_Name
            FROM   Cons_Columns cc
            JOIN   Constraints c ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name
)
ORDER BY tc.Num_Distinct DESC
           ",
        },
        {
          :name  => t(:dragnet_helper_177_name, :default=>'Estimate network latency between client and database by evaluation of Active Session History'),
          :desc  => t(:dragnet_helper_177_desc, :default=>"\
The network latency between client and database server can be estimated by the number of number of SQL executions of one session between two ASH snapshots.
If an application executes the same very short running SQL against the DB over and over again in a loop, then:
- it is a bad architecture approach for the application because the network latency will cause a significant overhead for application performance
- however, this behavior gives a possibility for a weak estimation of the network latency between client and database server
Assuming that the processing time in the application between two DB calls is very short compared to the network latency and DB execution time,
then a time delay can be estimated by the time between two SQL executions minus the average SQL execution time at the DB.
This time delay can be treated as the time for the network latency for a round trip plus the client side execution preparation (like JDBC stack, value binding etc.).
This client side execution preparation should be constant and quite small compared to the network latency, so we may assume the named values mostly as network latency.
"),
          :sql=>  "
SELECT x.Inst_ID, u.UserName, x.Session_ID, x.Session_Serial# Serial_No, x.SQL_ID, x.Machine, x.Module, x.Action,
       x.Consecutive_ASH_Samples, x.Min_Sample_Time, x.Max_Sample_Time,
       x.Executions,
       ROUND(s.Elapsed_Time/1000.0 / DECODE(s.Executions, 0, 1, s.Executions), 3) Avg_SQL_Elapsed_ms_per_Exec,
       ROUND(x.Consecutive_ASH_Samples*1000.0 / x.Executions, 3) Avg_ms_between_two_executions,
       /* The time between two excutions - the avg. SQL execution time of this SQL */
       ROUND(x.Consecutive_ASH_Samples*1000.0 / x.Executions -  s.Elapsed_Time/1000.0 / DECODE(s.Executions, 0, 1, s.Executions), 3) Avg_Network_and_app_Latency_ms
FROM   (
        SELECT Inst_ID, Session_ID, Session_Serial#, User_ID,  SQL_ID, Machine, MIN(Module) Module, MIN(Action) Action,
               COUNT(*) Consecutive_ASH_Samples,
               MIN(Sample_Time) Min_Sample_Time,
               MAX(Sample_Time) Max_Sample_Time,
               MAX(SQL_Exec_ID) - MIN(SQL_Exec_ID) Executions
        FROM   (SELECT x.*,
                       Sample_ID - ROW_NUMBER() OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial#  ORDER BY Sample_ID) AS grp /* Same group as long as no gaps are in sample_id */

                FROM   (
                        SELECT Sample_ID, Sample_Time, Inst_ID, User_ID, Session_ID, Session_Serial#, SQL_ID, SQL_Exec_ID, Machine, Module, Action,
                               LAG(SQL_ID,        1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_SQL_ID,
                               LAG(SQL_Exec_ID,   1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_SQL_Exec_ID,
                               LEAD(SQL_Exec_ID,  1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Next_SQL_Exec_ID,
                               LAG(Sample_ID,     1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_Sample_ID,
                               LEAD(Sample_ID,    1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Next_Sample_ID
                        FROM   gv$Active_Session_History
                        WHERE  SQL_ID IS NOT NULL
                        AND    PLSQL_Entry_Object_ID IS NULL  /* Exclude local executions without network influence */
                        AND    PLSQL_Object_ID IS NULL        /* Exclude local executions without network influence */
                       ) x
                WHERE  SQL_ID = Prev_SQL_ID                   /* The same SQL is executed consecutive, the same SQL_ID is neeed as precondition to count the executions by SQL_Exec_ID */
                AND    SQL_Exec_ID > Prev_SQL_Exec_ID         /* Each snapshot sees a new SQL execution and SQL_Exec_ID was increasing */
                AND    (Sample_ID = Prev_Sample_ID + 1 OR     /* No gap between the snapshots of this session */
                        Sample_ID = Next_Sample_ID - 1 )
               )
        GROUP BY Inst_ID, Session_ID, Session_Serial#, User_ID,  SQL_ID, Machine, grp
        HAVING COUNT(*) > ? /* minimum result count to get valid statistic results */
       ) x
JOIN   gv$SQLArea s ON s.Inst_ID = x.Inst_ID AND s.SQL_ID = x.SQL_ID
JOIN   All_Users u ON u.User_ID = x.User_ID
ORDER BY Machine, Consecutive_ASH_Samples DESC
           ",
          parameter: [
            { name: t(:dragnet_helper_177_param_1_name, :default=>'Minimum number of consecutive ASH records within a session'), :size=>8, :default=>20, :title=>t(:dragnet_helper_177_param_1_hint, :default=>'The minimum number of consecutive ASH records with the same SQL_ID for a session to allow valid statistic considerations') },
          ]
        },
    ]
  end

end
