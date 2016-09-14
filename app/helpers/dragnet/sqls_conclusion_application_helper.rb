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
            :sql=>  "
             SELECT /* Panorama-Tool Ramm: Fachliche Schluessel*/ p.Owner||'.'||p.Table_Name \"Referenced Table\",
                    MIN(pr.Num_Rows) \"Rows in referenced table\",
                    p.Constraint_Name \"Primary Key\", r.Owner||'.'||r.Table_Name \"Referencing Table\",
                    MIN(tr.Num_Rows) \"Rows in referencing table\",
                    COUNT(*) \"Number of PKey rows\",
                    MIN(c.Column_Name) \"One PKey-Column\",
                    MAX(c.Column_Name) \"Other PKey-Column\"
             FROM   DBA_Constraints r
             JOIN   DBA_Constraints p  ON p.Owner = r.R_Owner AND p.Constraint_Name = r.r_Constraint_Name
             JOIN   DBA_Cons_Columns c ON c.Owner = p.Owner   AND c.Constraint_Name = p.Constraint_Name
             JOIN   DBA_Tables pr ON pr.Owner = p.Owner AND pr.Table_Name = p.Table_Name
             JOIN   DBA_Tables tr ON tr.Owner = r.Owner AND tr.Table_Name = r.Table_Name
             WHERE  r.Constraint_Type = 'R'
             AND    c.Owner NOT IN ('SYS', 'SYSTEM')
             GROUP BY p.Owner, p.Table_Name, p.Constraint_Name, r.Owner, r.Table_Name, r.Constraint_Name
             HAVING COUNT(*) > 1
             ORDER BY MIN(tr.Num_Rows+pr.Num_Rows) * COUNT(*) DESC NULLS LAST
           ",
            :parameter=>[
            ]
        },
        {
            :name  => t(:dragnet_helper_52_name, :default=> 'Missing suggested AUDIT-options'),
            :desc  => t(:dragnet_helper_52_desc, :default=> 'You should have some minimal audit of DDL operations for traceability of problematic DDL.
Audit trail will usually be recorded in table sys.Aud$.'),
            :sql=>  "
              SELECT /* Panorama-Tool Ramm: Auditing */
                     '\"AUDIT '||NVL(a.Message, a.Name)||'\" suggested!'  Problem
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
              SELECT 'VIEW'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SELECT TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'SELECT TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'INSERT TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'INSERT TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'UPDATE TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'UPDATE TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'DELETE TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'DELETE TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL
              )a
              LEFT OUTER JOIN DBA_Stmt_Audit_Opts d ON  d.Audit_Option = a.Name
                                                    AND (d.Success = a.Success OR a.Success = 'NOT SET')
                                                    AND d.Failure = a.Failure  OR a.Failure = 'NOT SET'
              WHERE d.Audit_Option IS NULL
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
                             MIN(Session_Type)              \"Session-Type\",
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
                             MIN(Session_Type)              \"Session-Type\",
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
                   l.Request, l.LMode, lo.Owner, lo.Object_Name, l.ID1, l.ID2
            FROM   Sessions s
            JOIN   Locks l ON l.Inst_ID = s.Inst_ID AND l.SID = s.SID
            LEFT OUTER JOIN DBA_Objects lo ON lo.Object_ID = l.ID1
            WHERE  s.UserName NOT IN ('SYS')
            AND    l.Type NOT IN ('AE', 'PS', 'TO')
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
              SELECT Inst_ID, Timestamp, SUM(Connects) Connects_Total,
                     MAX(Client_Host  ||' ('||Connects_Client_Host||')')   KEEP (DENSE_RANK LAST ORDER BY Connects_Client_Host)  Top_Client_Host,
                     MAX(Client_IP    ||' ('||Connects_Client_IP||')')     KEEP (DENSE_RANK LAST ORDER BY Connects_Client_IP)    Top_Client_IP,
                     MAX(Client_User  ||' ('||Connects_Client_User||')')   KEEP (DENSE_RANK LAST ORDER BY Connects_Client_User)  Top_Client_User,
                     MAX(Service_Name ||' ('||Connects_Service_Name||')')  KEEP (DENSE_RANK LAST ORDER BY Connects_Service_Name) Top_Service_Name,
                     MAX(Connects) Connects_by_Top_Combination
              FROM   (
                      SELECT Inst_ID, TRUNC(Originating_Timestamp, 'MI') Timestamp, Client_IP, Client_User, Client_Host, Service_Name, COUNT(*) Connects,
                             MAX(Connects_Client_IP)    Connects_Client_IP,
                             MAX(Connects_Client_User)  Connects_Client_User,
                             MAX(Connects_Client_Host)  Connects_Client_Host,
                             MAX(Connects_Service_Name) Connects_Service_Name
                      FROM   (
                              SELECT Inst_ID, Originating_Timestamp, Client_IP, Client_User, Client_Host, Service_Name,
                                     SUM(DECODE(Client_IP,    NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_IP)    Connects_Client_IP,
                                     SUM(DECODE(Client_User,  NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_User)  Connects_Client_User,
                                     SUM(DECODE(Client_Host,  NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Client_Host)  Connects_Client_Host,
                                     SUM(DECODE(Service_Name, NULL, 0, 1)) OVER (PARTITION BY TRUNC(Originating_Timestamp, 'MI'), Service_Name) Connects_Service_Name
                              FROM   (
                                      SELECT Inst_ID, Originating_Timestamp,
                                             SUBSTR(SUBSTR(Address, INSTR(Address, 'HOST=')+5), 1, INSTR(SUBSTR(Address, INSTR(Address, 'HOST=')+5), ')')-1) Client_IP,
                                             SUBSTR(UserName, 1, INSTR(UserName, ')')-1)        Client_User,
                                             SUBSTR(ClientHost, 1, INSTR(ClientHost, ')')-1)    Client_Host,
                                             SUBSTR(ServiceName, 1, INSTR(ServiceName, ')')-1)  Service_Name
                                      FROM   (
                                              SELECT Inst_ID, Originating_Timestamp, Message_Text,
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
                      GROUP BY Inst_ID, TRUNC(Originating_Timestamp, 'MI'), Client_IP, Client_User, Client_Host, Service_Name
                     )
              GROUP BY Inst_ID, Timestamp
              ORDER BY Inst_ID, Timestamp
           ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>1, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            ]
        },
    ]
  end

end