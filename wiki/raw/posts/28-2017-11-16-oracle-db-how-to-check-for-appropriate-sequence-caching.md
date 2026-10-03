# Oracle-DB: How to check for appropriate sequence caching

Datum: 2017-11-16
URL: https://rammpeter.blogspot.com/2017/11/oracle-db-how-to-check-for-appropriate.html
Labels: Analyze performance issue, Panorama How-To

---

A common pitfall while using sequences in Oracle-DB is forgetting to define sequence caching.

The default for sequences is cache size = 0.

That means, every sequence.nextval operation triggers a single write operation on dictionary table sys.SEQ$.

Especially if frequently calling sequence.nextval uncached sequences may cause significant performance degradation.

Frequently calling sequence.nextval in parallel sessions may lead to ramdom lock scenarios in library cache.

Setting a cache size for a sequence may heavy increase performance of nextval-operations.

There's a minimal memory overhead for caching a sequence because all that's needed is a counter to increase in SGA memory and a upper limit. If this limit is reached with the counter, the upper limit is increased by cache size and the new upper limit is written down once to SEQ$.

The possible drawback for sequence caching is that you loose all your values between the current value and the highest cached value if you bounce the DB-instance.

Therefore suggested dimension for sequence cache should ensure:

- time delay between cache refresh should be hours instead of milliseconds 

- instance restarts should not lead to significant wastage in range of possible values

How can I evaluate if sequences does not have appropriate cache setting

1. Evaluate DBA_Sequences for high contention on SEQ$-updates per day

Lists sequences sorted by SEQ$-updates per day (not really exact for cycling sequences)

SELECT x.*,
 ROUND("Values per day"/DECODE(Cache_Size,0,1,Cache_Size)) "Cache reloads per day"
FROM (SELECT s.Sequence_Owner, s.Sequence_Name, s.Cache_size, s.Min_Value, s.Max_Value, s.Increment_By,
 s.Cycle_flag, s.Last_Number, s.Partition_Count, s.Session_Flag, s.Keep_Value,
 ROUND(s.Last_Number*100/s.Max_Value, 1) "% of max. value reached",
 ROUND((s.Last_Number-s.Min_Value)/(SYSDATE-o.Created)) "Values per day",
 o.Created, o.Last_DDL_Time
 FROM DBA_Sequences s
 LEFT OUTER JOIN DBA_Objects o ON o.Owner = s.Sequence_Owner AND o.Object_Name = s.Sequence_Name AND o.Object_Type = 'SEQUENCE'
 WHERE Sequence_Owner NOT IN ('SYS', 'SYSTEM')
 ) x
ORDER By "Values per day"/DECODE(Cache_Size,0,1,Cache_Size) DESC NULLS LAST

2. Evaluate execution count of SQLs including sequence.NEXTVAL

Lists SQLs from SGA with sequence.NEXTVAL sorted by SEQ$-updates per day

SELECT ROUND(Rows_Processed_per_Day/DECODE(Cache_Size, 0, 1, Cache_Size)) Cache_Reloads_Per_Day,
 y.*
FROM (
 SELECT ROUND(Executions/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Executions_per_Day,
 ROUND(Rows_Processed/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Rows_Processed_per_Day,
 x.*
 FROM (
 SELECT /*+ ORDERED USE_HASH(p a s) */
 p.Inst_ID, a.Executions, a.Rows_Processed,
 ROUND(a.Rows_Processed/a.Executions,2) Rows_Per_Exec,
 TO_DATE(a.First_Load_Time, 'YYYY-MM_DD/HH24:MI:SS') First_Load_Time, a.Last_Active_Time,
 p.Object_Owner, p.Object_Name, s.Cache_Size,
 a.SQL_ID, SUBSTR(a.SQL_Text, 1, 200) SQL_Text
 FROM (SELECT /*+ NO_MERGE */ * FROM gv$SQL_Plan WHERE Operation = 'SEQUENCE') p
 JOIN (SELECT /*+ NO_MERGE */ * FROM gV$SQL WHERE Executions > 0) a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID AND a.Child_Number = p.Child_Number
 JOIN (SELECT /*+ NO_MERGE */ * FROM DBA_Sequences) s ON s.Sequence_Owner = p.Object_Owner AND s.Sequence_Name = p.Object_Name
 ) x
 ) y
ORDER BY Rows_Processed_per_Day/DECODE(Cache_Size, 0, 1, Cache_Size) DESC NULLS LAST

Evaluate inappropriate sequence caches with Panorama

The free performance analysis tool Panorama also contains the above selections in Menu "Spec. additions" / "Dragnet investigation" at point 3.8 and 3.9.

You may find more about Panorama at http://rammpeter.github.io/panorama.html

1. Evaluate DBA_Sequences for high contention on SEQ$-updates per day

2. Evaluate execution count of SQLs including sequence.NEXTVAL
