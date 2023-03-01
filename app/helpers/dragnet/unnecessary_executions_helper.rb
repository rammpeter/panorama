# encoding: utf-8
module Dragnet::UnnecessaryExecutionsHelper

  private

  def unnecessary_executions
    [
        {
            :name  => t(:dragnet_helper_83_name, :default=>'Possibly unnecessary SQL executions if selects/updates/deletes never hit a record'),
            :desc  => t(:dragnet_helper_83_desc, :default=>'Select- / update- or delete-statements, which due to their filter conditions never hit records, may be candidates for elimination.
Otherwise they can be treated as check statements that never expect hits in normal way.
'),
            :sql=>  "SELECT /*+ USE_NL(t)  “DB-Tools Ramm Ohne Result */ s.*, t.SQL_Text \"SQL-Text\"
                      FROM  (
                               SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000)                         \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Elapsed Time per Execute (ms)\",
                                      ROUND(SUM(CPU_Time_Delta)/1000000)                             \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),4)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),2)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\"
                               FROM   dba_hist_snapshot snap
                               JOIN   DBA_Hist_SQLStat s ON (s.Snap_ID=snap.Snap_ID AND s.DBID=snap.DBID AND s.instance_number=snap.Instance_Number)
                               WHERE  snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                               HAVING SUM(Executions_Delta) > ?
                                      AND SUM(Rows_Processed_Delta) = 0
                               ) s
                            JOIN   DBA_Hist_SQLText t  ON (t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)
                      WHERE (   UPPER(t.SQL_Text) LIKE 'UPDATE%'
                             OR UPPER(t.SQL_Text) LIKE 'DELETE%'
                             OR UPPER(t.SQL_Text) LIKE 'MERGE%'
                             OR UPPER(t.SQL_Text) LIKE 'SELECT%'
                             OR UPPER(t.SQL_Text) LIKE 'WITH%'
                             )
                      ORDER BY s.\"Elapsed Time (Sec)\" DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time period for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_84_name, :default=>'Possibly unnecessary execution of statements if updates have unnecessary filter in WHERE-condition (examination of SGA)'),
            :desc  => t(:dragnet_helper_84_desc, :default=>'Single-row update-statements with limiting filter in WHERE-condition of update often may be accelaerated by moving filter to prior data selection.
This selection can be executed more effective as mass data operation, optional with usage of parallel query.'),
            :sql=>  "SELECT Inst_ID, Parsing_Schema_Name \"Parsing Schema Name\",
                             SQL_ID, ROUND(Elapsed_Time/1000000,2) \"Elapsed Time (Secs)\",
                             Executions,
                             Rows_Processed,
                             ROUND(Elapsed_Time/1000000/DECODE(Rows_Processed,0,1,Rows_Processed),4) \"Seconds per row\",
                             SQL_FullText
                      FROM   gv$SQLArea
                      WHERE  SQL_FullText NOT LIKE '%JDBCDAO%'
                      AND    UPPER(SQL_Text) LIKE 'UPDATE%'
                      AND    INSTR(UPPER(SQL_FullText), 'WHERE') > 0 /* WHERE enthalten */
                      AND    INSTR(SUBSTR(UPPER(SQL_FullText), INSTR(UPPER(SQL_FullText), 'WHERE')), 'AND') > 0 /* mehrere Filterbedingungen */
                      AND    SQL_FullText LIKE '%:%' /* Enthaelt Host-Variable */
                      ORDER BY Elapsed_Time/DECODE(Rows_Processed,0,1,Rows_Processed) DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_85_name, :default=>'Possibly unnecessary execution of statements if updates have unnecessary filter in WHERE-condition (examination of AWH history)'),
            :desc  => t(:dragnet_helper_85_desc, :default=>'Single-row update-statements with limiting filter in WHERE-condition of update often may be accelaerated by moving filter to prior data selection.
This selection can be executed more effective as mass data operation, optional with usage of parallel query.'),
            :sql=>  "SELECT SQL_ID, Parsing_Schema_Name  \"Parsing Schema Name\",
                             Executions, Elapsed_Time_Secs  \"Elapsed Time (Secs)\",
                             Rows_Processed                 \"Rows processed\",
                             ROUND(Elapsed_Time_Secs/DECODE(Rows_Processed, 0, 1, Rows_Processed),4) Secs_Per_Row, SQL_Text
                      FROM (
                              SELECT /*+ ORDERED */ t.SQL_ID, MIN(SQL_Text) SQL_Text, SUM(Executions_Delta) Executions, MAX(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                     ROUND(SUM(Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs, SUM(Rows_Processed_Delta) Rows_Processed
                              FROM   (
                                       SELECT /*+ NO_MERGE PARALLEL(t,4) */ DBID, SQL_ID, TO_CHAR(SUBSTR(SQL_Text,1,4000)) SQL_Text
                                       FROM   DBA_Hist_SQLText t
                                       WHERE  UPPER(SQL_Text) LIKE 'UPDATE%'
                                       AND    UPPER(SQL_Text) LIKE '%SET%'
                                       AND    INSTR(UPPER(SQL_Text), 'WHERE') > 0 /* WHERE enthalten */
                                       AND    INSTR(SUBSTR(UPPER(SQL_Text), INSTR(UPPER(SQL_Text), 'WHERE')), 'AND') > 0 /* mehrere Filterbedingungen */
                                       AND    UPPER(SQL_Text) NOT LIKE '%JDBCDAO%' /* kein Generator-Update */
                                       AND    SQL_Text LIKE '%:%' /* Enthaelt Host-Variable */
                                     ) t
                              JOIN DBA_Hist_SQLStat s ON (s.DBID = t.DBID AND s.SQL_ID = t.SQL_ID)
                              JOIN DBA_Hist_SnapShot ss ON (ss.DBID = t.DBID AND ss.Instance_number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID)
                              WHERE ss.Begin_Interval_Time > SYSDATE-?
                              GROUP BY t.SQL_ID
                           )
                      ORDER BY Elapsed_Time_Secs/DECODE(Rows_Processed, 0, 1, Rows_Processed) DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },

    ]

  end # unnecessary_executions


end