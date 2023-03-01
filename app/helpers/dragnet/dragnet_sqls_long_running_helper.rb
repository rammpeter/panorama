# encoding: utf-8
module Dragnet::DragnetSqlsLongRunningHelper

  private

  def dragnet_sqls_long_running
    [
        {
            :name  => t(:dragnet_helper_151_name, :default=>'Long running single executions of SQL statements'),
            :desc  => t(:dragnet_helper_151_desc, :default=>"This selection determines long-running executions of SQL statements.\nOften there is further potential to reduce the runtime."),
            :sql=>  "\
SELECT u.UserName, x.*
FROM   (
        SELECT User_ID,
               NVL(QC_Instance_ID,     Instance_Number) Instance_Number,
               NVL(QC_Session_ID,      Session_ID)      Session_ID,
               NVL(QC_Session_Serial#, Session_Serial#) Session_Serial#,
               MIN(CASE WHEN QC_Session_ID IS NULL THEN Program END) Program,
               MIN(Module)  Module,
               MIN(Action)  Action,
               SQL_ID, SQL_Exec_ID,
               ROUND((CAST(MAX(Sample_Time) AS DATE) - CAST(MIN(Sample_Time) AS DATE)) * 86400) Duration_Secs,
               COUNT(*) * 10 Seconds_Active_in_ASH, MIN(Sample_Time) Start_Time, MAX(Sample_Time) End_Time,
               COUNT(DISTINCT Instance_Number||':'||Session_ID||':'||Session_Serial#) - 1 PQ_processes
        FROM   DBA_Hist_Active_Sess_History
        WHERE  Sample_Time > SYSDATE - ?
        AND    SQL_Exec_ID IS NOT NULL
        GROUP BY User_ID,
                 NVL(QC_Instance_ID,     Instance_Number),
                 NVL(QC_Session_ID,      Session_ID),
                 NVL(QC_Session_Serial#, Session_Serial#),
                 SQL_ID,
                 SQL_Exec_ID
        HAVING COUNT(*) * 10 > ?
       ) x
LEFT OUTER JOIN All_Users u ON u.User_ID = x.User_ID
ORDER BY x.Duration_Secs DESC
 ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>2, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=> t(:dragnet_helper_151_param_1_name, :default=>'Minimum number of seconds active in ASH'), :size=>8, :default=>900, :title=>t(:dragnet_helper_151_param_1_hint, :default=>'Minimum number of seconds an execution must be active in Active Session History for consideration in selection') }
            ]
        },
    ]
  end


end