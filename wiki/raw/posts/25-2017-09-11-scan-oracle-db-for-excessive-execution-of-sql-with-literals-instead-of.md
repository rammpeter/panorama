# Scan Oracle-DB for excessive execution of SQL with literals instead of bind variables

Datum: 2017-09-11
URL: https://rammpeter.blogspot.com/2017/09/panorama-scan-your-system-for-excessive.html
Labels: Analyze performance issue, Panorama How-To

---

Using literals instead of bind variables in SQLs may have several drawbacks:

- Performance slows down because of:

- worse cache hit ratio

- higher parse effort

- Growing SQL-area in shared pool pushes other major memory objects outside, especially DB-cache

- Each executed SQL has to be hard parsed separately

- Risk of SQL-injection may exist (depending from source of literal)

Methods to find heavy executed SQLs with missing bind variables

1. Scan active session history for different SQL-ID but same execution plan

WITH Ret AS (SELECT :Consider_Days_Back Days FROM DUAL)
SELECT x.SQL_Plan_Hash_Value, x.Different_SQL_IDs, x.Last_Used_SQL_ID, u.UserName, x.First_Occurrence, x.Last_Occurrence, x.Elapsed_Secs
FROM (
 SELECT h.SQL_Plan_Hash_Value,
 COUNT(DISTINCT h.SQL_ID) Different_SQL_IDs,
 MAX(h.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY h.Sample_Time) Last_Used_SQL_ID,
 User_ID,
 MIN(h.Sample_Time) First_Occurrence,
 MAX(h.Sample_Time) Last_Occurrence,
 SUM(CASE WHEN h.Sample=1 OR d.Min_Sample_Time IS NULL OR h.Sample_Time < d.Min_Sample_Time THEN h.Sample END) Elapsed_Secs /* dont count twice in SGA and AWR */
 FROM (SELECT Inst_ID Instance_Number, Sample_Time, SQL_Plan_Hash_Value, SQL_ID, 1 Sample, User_ID,
 MIN(Sample_Time) OVER (PARTITION BY SQL_Plan_Hash_Value) Delimiter
 FROM gv$Active_Session_History
 CROSS JOIN Ret
 WHERE Sample_Time > SYSDATE-Ret.Days
 UNION ALL
 SELECT Instance_Number, Sample_Time, SQL_Plan_Hash_Value, SQL_ID, 10 Sample, User_ID,NULL Delimiter
 FROM DBA_Hist_Active_Sess_History
 CROSS JOIN Ret
 WHERE Sample_Time > SYSDATE-Ret.Days
 ) h
 LEFT OUTER JOIN (SELECT Inst_ID Instance_Number, SQL_Plan_Hash_Value, MIN(Sample_Time) Min_Sample_Time /* limit Values in AWR-table from SGA*/
 FROM gv$Active_Session_History
 GROUP BY Inst_ID, SQL_Plan_Hash_Value
 ) d ON d.Instance_Number = h.Instance_Number AND d.SQL_Plan_Hash_Value = h.SQL_Plan_Hash_Value
 WHERE h.SQL_Plan_Hash_Value != 0
 GROUP BY h.SQL_Plan_Hash_Value, h.User_ID
 ) x
JOIN DBA_Users u ON u.User_ID = x.User_ID
WHERE Different_SQL_IDs > :Min_Different_SQLs
ORDER BY Different_SQL_IDs DESC
; 

2. Scan SGA for different SQL-ID but same execution plan

SELECT a.Inst_ID "Instance",
 a.Plan_Hash_Value "Plan hash value",
 a.Parsing_Schema_Name "Parsing schema",
 COUNT(*) "No. of entries in gv$SQLArea",
 COUNT(DISTINCT a.SQL_ID) "No. of different SQL-IDs",
 MIN(a.Last_Active_Time) "Oldest active time",
 MAX(a.Last_Active_Time) "Youngest active time",
 MAX(a.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Last_Active_Time) "SQL_ID",
 ROUND(SUM(a.Sharable_Mem) /(1024*1024), 2) "Sharable memory (MB)",
 ROUND(SUM(a.Persistent_Mem)/(1024*1024), 2) "Persistent memory (MB)",
 ROUND(SUM(a.Runtime_Mem) /(1024*1024), 2) "Runtime memory (MB)",
 SUBSTR(MAX(a.SQL_Text) KEEP (DENSE_RANK LAST ORDER BY Last_Active_Time), 1, 400) "SQL text"
FROM gv$SQLArea a
WHERE a.Plan_Hash_Value != 0
GROUP BY a.Inst_ID, a.Plan_Hash_Value, a.Parsing_Schema_Name
HAVING COUNT(*) > :Min_Different_SQLs
ORDER BY 4 DESC
;

3. Scan the SGA for different SQLs with same leading characters in statement

WITH Len AS (SELECT :Num_Chars_to_Compare Substr_Len FROM DUAL)
SELECT g.*, s.SQL_Text "Beispiel SQL-Text"
FROM (
 SELECT COUNT(*) Variationen, Inst_ID, MIN(Parsing_Schema_Name) UserName, COUNT(DISTINCT Parsing_Schema_Name) Anzahl_User,
 SUBSTR(s.SQL_Text, 1, Len.Substr_Len) SubSQL_Text,
 ROUND(SUM(Sharable_Mem+Persistent_Mem+Runtime_Mem)/(1024*1024),3) "Memory (MB)",
 MIN(s.SQL_ID) SQL_ID,
 MIN(TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS')) Min_First_Load,
 MIN(Last_Load_Time) Min_Last_Load,
 MAX(Last_Load_Time) Max_Last_Load,
 MAX(Last_Active_Time) Max_Last_Active,
 MIN(Parsing_Schema_Name) Parsing_Schema_Name,
 COUNT(DISTINCT Parsing_Schema_Name) "Different pars. schema names"
 FROM gv$SQLArea s, Len
 GROUP BY Inst_ID, SUBSTR(s.SQL_Text, 1, Len.Substr_Len)
 HAVING COUNT(*) > 10
 ) g
JOIN gv$SQLArea s ON s.Inst_ID = g.Inst_ID AND s.SQL_ID = g.SQL_ID
ORDER BY "Memory (MB)" DESC NULLS LAST
;

Panorama offers methods to quantify the impact of missing bind variables more comfortable and drill down into SQLs:

1. Check your system for SQL with missing bind variables sorted by number of occurrences

You can scan your system for SQLs with missing bind variables by two ways at menu „Spec. additions“ / „Dragnet investigation“, point 4.1 until 4.3

- List SQLs with multiple SQL-ID but same execution plan from SGA and also from Active Session History

- List SQLs with multiple SQL-ID but same fist n characters

2. Quantify memory consumption due to excessive SQLs flooding SQL-area 

One obstacle is: If you don’t set limits for db_cache_size in initialization than excessive execution of SQLs with different literals instead of bind variables leads to growing SQL-area in shared pool, thereby reducing the buffer cache.

This may dramatically reduce your cache hit rate and enlarge execution times all over your database.

Common sizes for shared pool are between 0.5 and 2 GB for larger database systems, the greater part of SGA should be available for buffer cache.

If you consider a SQL-area that is much greater than the buffer cache, this is often a signal for massive problem with missing bind variables.

 Even if you drive your database with cursor_sharing=FORCE to fix the missing bind variables issue, than full SQL text before translation by cursor_sharing=FORCE is stored in KHLH0-area of shared pool and may also consume gigabytes.

You can recognize your memory dividing by Panorama at menu „SGA/PGA-Details“ / „SGA components“ like shown here:

You can find more about Panorama at http://rammpeter.github.io/panorama.html
