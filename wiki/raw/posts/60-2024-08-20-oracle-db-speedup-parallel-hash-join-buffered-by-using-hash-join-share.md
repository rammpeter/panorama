# Oracle-DB: Speedup parallel HASH JOIN BUFFERED by using HASH JOIN SHARED

Datum: 2024-08-20
URL: https://rammpeter.blogspot.com/2024/08/oracle-db-speedup-parallel-hash-join.html
Labels: Oracle Database, Panorama, Parallel shared hash join, Shared hash join

---

Since release 18c there's an undocumented feature Parallel Shared Hash Join which introduces sharing memory between parallel query slaves.

The required memory for these shared hash tables is allocated in a new memory region known as the Managed Global Area (MGA). See also doc. ID 2638904.1.

This feature is particularly beneficial for costly HASH JOIN BUFFERED operations that spill large amounts of data into the temporary tablespace.
 
These operations may benefit from transformation into HASH JOIN SHARED operations.

By sharing hash tables between parallel query (PQ) processes, instead of each PQ server maintaining its own, runtime can be significantly reduced.

This reduces overall memory requirements, enabling more data to be processed before spilling to disk in the temporary tablespace.

There are several ways to activate the Parallel Shared Hash Join:

 - set '_px_shared_hash_join'=true; at system or session level

 - define the PQ distribution strategy for a particular table in SQL by hint /*+ PQ_DISTRIBUTE(<table alias> SHARED NONE) */

 - set '_px_shared_hash_join'=true; at SQL level by hint /*+ OPT_PARAM('_px_shared_hash_join' 'true') */

The latter option by OPT_PARAM fits best for me because behaviour can be controlled at SQL level without defining it for each table.

If this transformation works, then the HASH JOIN BUFFERED turns into HASH JOIN SHARED in the execution plan.

This feature is not officially documented yet

Respecting the unofficial state of this feature it should not be used in RAC environment if PQ operations are spread over several instances (parallel_force_local=FALSE).

It works for HASH JOIN BUFFERED, the HASH JOIN OUTER BUFFERED operation cannot be transformed yet to HASH JOIN OUTER SHARED (at least until rel. 19.24).

Many thanks to Randolf Eberle-Geist, who shared backgrounds of this feature.

See also: Blog post from Chinar Aliyev

How to identify candidates for improvement by shared hash join

The following select shows SQLs with HASH JOIN BUFFERED in the DB history ordered by the runtime they consume for this particular operation.

So this may help to identify potential candidates for testing shared hash join.

WITH Min_Ash_Sample_ID AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, MIN(Sample_ID) Min_Sample_ID
 FROM gv$Active_Session_History
 GROUP BY Inst_ID
 )
SELECT Instance_Number, SQL_ID, u.UserName User_Name, SQL_Plan_Hash_Value, SQL_Plan_Line_ID,
 SUM(Seconds_Waiting) Seconds_Waiting, MAX(Max_Temp_MB) Max_Temp_MB,
 MIN(Min_Sample_Time) First_Occurrence, MAX(Max_Sample_Time) Last__Occurrence
FROM (
 SELECT h.Instance_Number, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID,
 COUNT(*) * 10 Seconds_Waiting, MAX(h.Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
 MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, h.User_ID
 FROM DBA_Hist_Active_Sess_History h
 JOIN Min_Ash_Sample_ID m ON m.Inst_ID = h.Instance_Number
 WHERE SQL_Plan_Operation = 'HASH JOIN'
 AND SQL_Plan_Options = 'BUFFERED'
 AND h.Sample_ID < m.Min_Sample_ID
 AND h.Sample_Time > SYSDATE - :Days_Back
 AND h.DBID = :Your_DBID /* do not count multiple times for multipe different DBIDs/ConIDs */
 GROUP BY h.Instance_Number, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID, h.User_ID
 UNION ALL
 SELECT h.Inst_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID,
 COUNT(*) Seconds_Waiting, MAX(h.Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
 MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, h.User_ID
 FROM gv$Active_Session_History h
 WHERE SQL_Plan_Operation = 'HASH JOIN'
 AND SQL_Plan_Options = 'BUFFERED'
 GROUP BY h.Inst_ID, h.SQL_ID, h.SQL_Plan_Hash_Value, h.SQL_Plan_Line_ID, h.User_ID
 ) x
LEFT OUTER JOIN All_Users u ON u.User_ID = x.User_ID
GROUP BY Instance_Number, SQL_ID, u.UserName, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
ORDER BY Seconds_Waiting DESC

A bit more convenient you can run this selection using the free analysis tool Panorama.

Choose menu "Spec. additions" / "Dragnet investigation" at point 2.2.11.

Clicking the SQL-ID will show some details of this SQL:

Clicking the "Execution plan" button shows the plan with amount of time spent in particular plan lines:
