# Oracle-DB: Find SQLs that are missing partition pruning even if it could be possibly used

Datum: 2023-12-19
URL: https://rammpeter.blogspot.com/2023/12/oracle-db-find-sqls-that-are-missing.html
Labels: Execution Plan, Oracle Database, Panorama How-To

---

Some times a SQL execution includes all partitions of a partitioned table or index into processing, although there are filter conditions used that contain also the partition key of that partitoned table or index.

There are several possible reasons why the optimizer does not recognize that access could be reduced to one or less partitions (a.k.a. partition pruning):

 - The partition key can be obfuscated behind a conversion function

 - The partition key can be compared to a function result that is known only at execution time

Being able to use partition pruning can make a huge difference for execution time of the SQL. Imagine you only need to scan one partition of a table instead of several thousands. 

Often only a small change in the SQL statement can drive the optimizer to use partition pruning.

A small example where all partitions are scanned due to comparison of the partition key with a function result:

Get the sum of order value for a table interval partitioned by day.

SELECT SUM(Value) FROM Orders WHERE Day = GetCurrentDay();

A simple move of the function call to a subquery allows to use partition pruning now:
SELECT SUM(Value) FROM Orders WHERE Day = (SELECT GetCurrentDay() FROM DUAL);

But how to find the possibly very low hanging fruits for performance improvement

My preferred way to do such checks is Panorama as show at the end of the post.

But this check can also be done manually. 
The following SQLs check your whole database for scans across all partitions of a partioned table or index where the partition key is also part of access or filter conditions at the same time.

There are two flavours for this scan SQLs:

 - The first one uses also the AWR history and requires the licensing of the Diagnostics Pack. 
 You can specify the number of days back where the AWR history should be considered and the DBID of the PDB (to count AWR values only once).
 For non-PDB DBs you can omit the filter on DBID.

 The result is sorted by the time the DB has spent on the lines with partition access in the execution plan.
 This selection works starting especially starting with DB release 19.20 where access and filter predicates are sampled now in AWR. 

 - 
 The second only uses data from the current SGA thus not requiring the Diagnostics Pack and is also suitable for Standard Edition.

 The result is sorted by the execution time of the whole SQL as recorded on gv$SQL.

Variant 1: Check including AWR history:
WITH Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias,
 CASE WHEN Object_Type LIKE 'INDEX%' THEN 'INDEX' ELSE Object_Type END Object_Type, /* treat 'INDEX (UNIQUE)' as 'INDEX' */
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 FROM (SELECT ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 FROM gv$SQL_Plan
 WHERE Operation NOT LIKE '%JOIN%' /* do not consider join operations for surrounding plan lines */
 GROUP BY ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 UNION /* Duplicates possible if Access_Predicates and Filter_Predicates in AWR are not set (pre 19.19) */
 SELECT ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 FROM DBA_Hist_SQL_Plan
 WHERE DBID = :DBID /* do not count multiple times for multiple different DBIDs/ConIDs */
 AND Operation NOT LIKE '%JOIN%' /* do not consider join operations for surrounding plan lines */
 GROUP BY ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 )
 WHERE Partition_Start = '1' OR Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL 
 ),
 -- get number of physical existing partitions or subpartitions for partitioned tables and indexes
 Part_Objects AS (SELECT /*+ NO_MERGE MATERIALIZE */ Object_Type, Owner, Object_Name, COUNT(*) Phys_Partition_Count
 FROM (SELECT CASE WHEN Segment_Type LIKE 'TABLE%' THEN 'TABLE'
 WHEN Segment_Type LIKE 'INDEX%' THEN 'INDEX'
 END Object_Type, Owner, Segment_Name Object_Name
 FROM DBA_Segments WHERE Segment_Type LIKE '%PARTITION%'
 )
 GROUP BY Object_Type, Owner, Object_Name
 ),
 -- get number of physical or potential (interval) partitions for partitioned tables and indexes
 Part_Max AS (SELECT /*+ NO_MERGE MATERIALIZE */ 'TABLE' Object_type, Owner, Table_Name Object_Name, Partition_Count
 FROM DBA_Part_Tables
 UNION ALL
 SELECT 'INDEX' Object_Type, Owner, Index_Name Object_Name, Partition_Count
 FROM DBA_Part_Indexes
 ),
 Part_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ p.ID, p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner, p.Object_Name, p.Object_Type,
 p.Object_Alias, p.Access_Predicates, p.Filter_Predicates, po.Phys_Partition_Count
 FROM Plans p
 JOIN Part_Objects po ON po.Owner = p.Object_Owner AND po.Object_Name = p.Object_Name AND po.Object_Type = p.Object_Type
 JOIN Part_Max pm ON pm.Owner = p.Object_Owner AND pm.Object_Name = p.Object_Name AND pm.Object_Type = p.Object_Type
 WHERE p.Partition_Start = '1'
 AND p.Partition_Stop = TO_CHAR(pm.Partition_Count)
 AND p.Object_Type IS NOT NULL
 ),
 Surrounding_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Type,
 Access_Predicates, Filter_Predicates
 FROM Plans p
 WHERE (Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL)
 ),
 Min_Ash AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID),
 ASH AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, SUM(Elapsed_Secs) Elapsed_Secs
 FROM (SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Elapsed_Secs
 FROM gv$Active_Session_History
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
 UNION ALL
 SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) * 10 Elapsed_Secs
 FROM DBA_Hist_Active_Sess_History h
 JOIN Min_Ash ma ON ma.Inst_ID = h.Instance_Number
 WHERE Sample_Time > SYSDATE - :DaysBack
 AND Sample_Time < ma.Min_Sample_Time
 AND DBID = :DBID /* do not count multiple times for multiple different DBIDs/ConIDs */
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
 )
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
 ),
 Part_Key_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Name, Object_Type, Column_Name FROM DBA_Part_Key_Columns)
SELECT /*+ LEADING(p) USE_HASH(pkc) USE_HASH(sp) USE_HASH(ash) */
 p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner Owner, p.Object_Name, p.Object_Type, p.Object_Alias, sp.Access_Predicates, sp.Filter_Predicates,
 pkc.Column_Name Partition_Criteria, p.Phys_Partition_Count, p.ID Plan_Line_ID_Partition, sp.ID Plan_Line_ID_Filter, SUM(ash.Elapsed_Secs) Elapsed_Secs_At_Plan_Lines
FROM Part_Plans p
JOIN Part_Key_Columns pkc ON pkc.Owner = p.Object_Owner AND pkc.Name = p.Object_Name AND pkc.Object_Type = p.Object_Type
JOIN Surrounding_Plans sp ON sp.SQL_ID = p.SQL_ID AND sp.Plan_Hash_Value = p.Plan_Hash_Value
 AND sp.ID <= p.ID /* only consider plan lines at or before full partition scan */
 AND p.ID - sp.ID <= 2 /* max. distance between lines of execution plan */
JOIN Ash ON ash.SQL_ID = p.SQL_ID AND ash.SQL_Plan_Hash_Value = p.Plan_Hash_Value
 AND (ash.SQL_Plan_Line_ID = p.ID OR ash.SQL_Plan_Line_ID = sp.ID)
WHERE ( sp.Access_Predicates LIKE '%'||pkc.Column_Name||'%'
 OR sp.Filter_Predicates LIKE '%'||pkc.Column_Name||'%'
 )
GROUP BY p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner, p.Object_Name, p.Object_Type, p.Object_Alias, sp.Access_Predicates, sp.Filter_Predicates,
 pkc.Column_Name, p.Phys_Partition_Count, p.ID, sp.ID
ORDER BY SUM(ash.Elapsed_Secs) DESC

Variant 2: Check only scanning with SGA data without the need for Diagnostics Pack:
WITH Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias,
 CASE WHEN Object_Type LIKE 'INDEX%' THEN 'INDEX' ELSE Object_Type END Object_Type, /* treat 'INDEX (UNIQUE)' as 'INDEX' */
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 FROM (SELECT ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 FROM gv$SQL_Plan
 WHERE Operation NOT LIKE '%JOIN%' /* do not consider join operations for surrounding plan lines */
 GROUP BY ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Alias, Object_Type,
 Access_Predicates, Filter_Predicates, Partition_Start, Partition_Stop
 )
 WHERE Partition_Start = '1' OR Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL 
 ),
 -- get number of physical existing partitions or subpartitions for partitioned tables and indexes
 Part_Objects AS (SELECT /*+ NO_MERGE MATERIALIZE */ Object_Type, Owner, Object_Name, COUNT(*) Phys_Partition_Count
 FROM (SELECT CASE WHEN Segment_Type LIKE 'TABLE%' THEN 'TABLE'
 WHEN Segment_Type LIKE 'INDEX%' THEN 'INDEX'
 END Object_Type, Owner, Segment_Name Object_Name
 FROM DBA_Segments WHERE Segment_Type LIKE '%PARTITION%'
 )
 GROUP BY Object_Type, Owner, Object_Name
 ),
 -- get number of physical or potential (interval) partitions for partitioned tables and indexes
 Part_Max AS (SELECT /*+ NO_MERGE MATERIALIZE */ 'TABLE' Object_type, Owner, Table_Name Object_Name, Partition_Count
 FROM DBA_Part_Tables
 UNION ALL
 SELECT 'INDEX' Object_Type, Owner, Index_Name Object_Name, Partition_Count
 FROM DBA_Part_Indexes
 ),
 Part_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ p.ID, p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner, p.Object_Name, p.Object_Type,
 p.Object_Alias, p.Access_Predicates, p.Filter_Predicates, po.Phys_Partition_Count
 FROM Plans p
 JOIN Part_Objects po ON po.Owner = p.Object_Owner AND po.Object_Name = p.Object_Name AND po.Object_Type = p.Object_Type
 JOIN Part_Max pm ON pm.Owner = p.Object_Owner AND pm.Object_Name = p.Object_Name AND pm.Object_Type = p.Object_Type
 WHERE p.Partition_Start = '1'
 AND p.Partition_Stop = TO_CHAR(pm.Partition_Count)
 AND p.Object_Type IS NOT NULL
 ),
 Surrounding_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ ID, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name, Object_Type,
 Access_Predicates, Filter_Predicates
 FROM Plans p
 WHERE (Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL)
 ),
 sga_sql AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, Plan_Hash_Value, SUM(Elapsed_Time)/1000000 Elapsed_Secs
 FROM gv$SQL
 GROUP BY SQL_ID, Plan_Hash_Value
 ),
 Part_Key_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Name, Object_Type, Column_Name FROM DBA_Part_Key_Columns)
SELECT /*+ LEADING(p) USE_HASH(pkc) USE_HASH(sp) USE_HASH(sga_sql) */
 p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner Owner, p.Object_Name, p.Object_Type, p.Object_Alias, sp.Access_Predicates, sp.Filter_Predicates,
 pkc.Column_Name Partition_Criteria, p.Phys_Partition_Count, p.ID Plan_Line_ID_Partition, sp.ID Plan_Line_ID_Filter, SUM(ss.Elapsed_Secs) Elapsed_Secs_Whole_SQL
FROM Part_Plans p
JOIN Part_Key_Columns pkc ON pkc.Owner = p.Object_Owner AND pkc.Name = p.Object_Name AND pkc.Object_Type = p.Object_Type
JOIN Surrounding_Plans sp ON sp.SQL_ID = p.SQL_ID AND sp.Plan_Hash_Value = p.Plan_Hash_Value
 AND sp.ID <= p.ID /* only consider plan lines at or before full partition scan */
 AND p.ID - sp.ID <= 2 /* max. distance between lines of execution plan */
JOIN sga_sql ss ON ss.SQL_ID = p.SQL_ID AND ss.Plan_Hash_Value = p.Plan_Hash_Value 
WHERE ( sp.Access_Predicates LIKE '%'||pkc.Column_Name||'%'
 OR sp.Filter_Predicates LIKE '%'||pkc.Column_Name||'%'
 )
GROUP BY p.SQL_ID, p.Plan_Hash_Value, p.Object_Owner, p.Object_Name, p.Object_Type, p.Object_Alias, sp.Access_Predicates, sp.Filter_Predicates,
 pkc.Column_Name, p.Phys_Partition_Count, p.ID, sp.ID
ORDER BY SUM(ss.Elapsed_Secs) DESC

A more convenient way to do this check is using my analysis tool Panorama.

Especially for DBs without Diagnostics Pack there is also a builtin replacement for AWR and ASH available with Panorama.
