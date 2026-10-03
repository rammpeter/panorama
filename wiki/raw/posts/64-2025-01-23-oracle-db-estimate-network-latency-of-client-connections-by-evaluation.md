# Oracle-DB: Estimate network latency of client connections by evaluation of Active Session History

Datum: 2025-01-23
URL: https://rammpeter.blogspot.com/2025/01/oracle-db-estimate-network-latency-of.html
Labels: Active Session History, Oracle Database, Panorama

---

Sometimes it is useful to know about the network latency of client connections to database.

Normally this would be done with the established network tools tnsping, ping, traceroute, tcptraceroute etc. from client or DB server side.

But what if there is only SQL access to the DB server and no access to the client?

This post shows how the network latency can be estimated using the recordings from ASH if the application uses a certain access pattern.

The network latency between client and database server can be estimated by the number of number of SQL executions of a single session between two ASH snapshots.

If an application executes the same very short running SQL against the DB over and over again in a loop, then:

 - it is a bad architecture approach for the application because the network latency will cause a significant overhead for application performance

 - however, this behavior gives a possibility for a weak estimation of the network latency between client and database server

Assuming that the processing time in the application at client side between two DB calls is very short compared to the network latency and DB execution time,

then a time delay can be estimated by the time between two SQL executions minus the average SQL execution time at the DB.

This time delay can be treated as the time for the network latency for a round trip plus the client side execution preparation (like JDBC stack, value binding etc.).

This client side execution preparation should be constant and quite small compared to the network latency, so we may assume the named values mostly as network latency.

Of course this assumption requires also a bit of knowledge about the implementation of the application.

The following SQL calculates the estimated network latency between if the follwing preconditions are fulfilled:

 - There is a minimum number of subsequent ASH snapshots for a session without gaps to be able to calculate plausible statistics at this base. This limit of 20 can be adjusted in the SQL

 - Each of this ASH snapshots for a session records the same SQL ID. This is necessary to trust the incrementing SQL_Exec_ID which is used to calculate the number of executions.

 - The execution time of the SQL is less than the one second of the ASH snapshot cycle / The SQL_Exec_ID must be incremented wat each ASH snapshot.

 The limit of 50 ms/execution can be adjusted in the SQL.

The column 'Avg_Network_and_App_Latency_ms' shows the idle time of the DB between two subsequent SQL calls from the application in milliseconds.

For a certain client machine you can now estimate, that the network latency is not greater than the smallest value you find for that column.

Otherwise ist would be impossible for the client to run this amount of remote executions in that time.

But depending on the processing time at the client machine between to calls the real network latency can be smaller than the shown values.

SELECT x.Inst_ID, u.UserName, x.Session_ID, x.Session_Serial# Serial_No, x.SQL_ID, x.Machine, x.Module, x.Action,
 x.Consecutive_ASH_Samples, x.Min_Sample_Time, x.Max_Sample_Time,
 x.Executions,
 ROUND(s.Elapsed_ms_per_Exec, 3) Avg_SQL_Elapsed_ms_per_Exec,
 ROUND(x.Consecutive_ASH_Samples*1000.0 / x.Executions, 3) Avg_ms_between_two_executions,
 /* The time between two excutions - the avg. SQL execution time of this SQL */
 ROUND(x.Consecutive_ASH_Samples*1000.0 / x.Executions - s.Elapsed_ms_per_Exec, 3) Avg_Network_and_App_Latency_ms
FROM (
 SELECT Inst_ID, Session_ID, Session_Serial#, User_ID, SQL_ID, Machine, MIN(Module) Module, MIN(Action) Action,
 COUNT(*) Consecutive_ASH_Samples,
 MIN(Sample_Time) Min_Sample_Time,
 MAX(Sample_Time) Max_Sample_Time,
 MAX(SQL_Exec_ID) - MIN(SQL_Exec_ID) Executions
 FROM (SELECT x.*,
 Sample_ID - ROW_NUMBER() OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_ID) AS grp /* Same group as long as no gaps are in sample_id */

 FROM (
 SELECT Sample_ID, Sample_Time, Inst_ID, User_ID, Session_ID, Session_Serial#, SQL_ID, SQL_Exec_ID, Machine, Module, Action,
 LAG(SQL_ID, 1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_SQL_ID,
 LAG(SQL_Exec_ID, 1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_SQL_Exec_ID,
 LAG(Sample_ID, 1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Prev_Sample_ID,
 LEAD(Sample_ID, 1, 0) OVER (PARTITION BY Inst_ID, Session_ID, Session_Serial# ORDER BY Sample_Time) Next_Sample_ID
 FROM gv$Active_Session_History
 WHERE SQL_ID IS NOT NULL
 AND PLSQL_Entry_Object_ID IS NULL /* Exclude local executions without network influence */
 AND PLSQL_Object_ID IS NULL /* Exclude local executions without network influence */
 ) x
 WHERE SQL_ID = Prev_SQL_ID /* The same SQL is executed consecutive, the same SQL_ID is neeed as precondition to count the executions by SQL_Exec_ID */
 AND SQL_Exec_ID > Prev_SQL_Exec_ID /* Each snapshot sees a new SQL execution and SQL_Exec_ID was increasing */
 AND (Sample_ID = Prev_Sample_ID + 1 OR /* No gap between the snapshots of this session */
 Sample_ID = Next_Sample_ID - 1 )
 )
 GROUP BY Inst_ID, Session_ID, Session_Serial#, User_ID, SQL_ID, Machine, grp
 HAVING COUNT(*) > 20 /* minimum result count to get valid statistic results */
 ) x
JOIN (SELECT Inst_ID, SQL_ID, Elapsed_Time/1000.0 / DECODE(Executions, 0, 1, Executions) Elapsed_ms_per_Exec
 FROM gv$SQLArea
 ) s ON s.Inst_ID = x.Inst_ID AND s.SQL_ID = x.SQL_ID
JOIN All_Users u ON u.User_ID = x.User_ID
WHERE s.Elapsed_ms_per_Exec < 50
ORDER BY Machine, Consecutive_ASH_Samples DESC
;

You'll find this selection also in the "Dragnet investigation" section of the free analysis tool Panorama.
