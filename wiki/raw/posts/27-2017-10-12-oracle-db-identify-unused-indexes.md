# Oracle-DB: Identify unused indexes 

Datum: 2017-10-12
URL: https://rammpeter.blogspot.com/2017/10/oracle-db-identify-unused-indexes.html
Labels: Analyze performance issue, Panorama How-To

---

A common problem with indexes is:

- creating an index is quite easy in consideration of the possible impact

- deleting an index is much more difficult because: 
Who has the heart to decide this index is really no longer needed? 

This results in:

- Nearly every database system stores and maintains indexes that are not really needed.

- In worst cases this not needed indexes are more than half of the systems total storage

Securely indentifying and deleting this unnecessary indexes may be a strong lever to improve performance and reduce resource consumption without any changes on application.

How to identify unused indexes:

1. Use Oracle's own index usage monitoring 

You can enable index usage monitoring by issueing 

ALTER INDEX <Index_Name> MONITORING USAGE;

Index usage is expressed as YES/NO-state that flips to YES if index is used by any executed SQL-statement.

Combined with start monitoring timestamp you can identify indexes that are not used by SQL since start timestamp.

Usage state can be selected from:

- v$Object_Usage.Used for the current schema

- sys.Object_Usage.Flags for all schemas (less comfortable)

2. Ensure that indexes are not needed for foreign key protection

Unfortunately Oracle's builtin monitoring usage does not recognize usage for recursive index lookup  during foreign key validation. 

So you have to ensure yourself that an index marked as unused is also not needed for foreign key protection (prevent lock propagation and full scans on detail-table during delete on master-table).

Permanently monitoring index usage

Resetting index monitoring state in interval is suggested because you may also have indexes that have been used in former times but aren't  necessary no more now.

This can be done by a simple PL/SQL-job that is executed e.g. daily.

It resets usage info after 8 days if index was marked as used.

If index was not marked as used, monitoring state remains unchanged.

Executing ALTER INDEX ... MONITORING USAGE leads to invalidation of existing query plans for the table of that index.

The resulting hard parse at the next execution can be an performance issue for frequently executed statements with a higher number of sessions executing this statement.

Therefore the usage status of used indexes is reset by ALTER INDEX ... MONITORING USAGE only, if there are no SQL plans in SGA yet using his index.

If a SQL plan using this index exists in SGA this is an sufficient indicator for index usage, so resetting ALTER INDEX ... MONITORING USAGE to restart monitoring is not necessary in this case.

Script for monitoring per schema

DECLARE
 DAYS_BACK_BEFORE_RESET CONSTANT NUMBER := 8;
 v_Table_Name User_Indexes.Table_Name%TYPE := '-';
BEGIN
 FOR Rec IN (
 SELECT i.Table_Name, i.Index_Name 
 FROM User_Indexes i
 LEFT OUTER JOIN v$Object_Usage u ON u.Index_Name = i.Index_Name AND u.Table_Name = i.Table_Name
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT Object_Name
 FROM gv$SQL_Plan
 WHERE Object_Owner = USER
 AND Object_Name IS NOT NULL 
 AND Options != 'SAMPLE FAST FULL SCAN' /* Don't rely on SQLs from DBMS_STATS */ 
 ) p ON p.Object_Name = i.Index_Name 
 WHERE (u.Used IS NULL OR
 u.Monitoring = 'NO' OR
 (u.Used = 'YES' AND TO_DATE(u.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE - DAYS_BACK_BEFORE_RESET)
 )
 AND i.Index_Type NOT IN ('IOT - TOP', 'LOB')
 AND (u.Used IS NULL OR p.Object_Name IS NULL) -- Index not in any current SQL plan for repeated resetting usage status
 ORDER BY i.Table_Name
 ) LOOP
 IF v_Table_Name != Rec.Table_Name THEN
 -- Optionally place a sleep after each tables indexes to flatten hard parse peak after invalidation of existing plans for this table 
 -- DBMS_LOCK.SLEEP(1);
 v_Table_Name := Rec.Table_Name;
 END IF;
 EXECUTE IMMEDIATE 'ALTER INDEX '||Rec.Index_Name||' MONITORING USAGE';
 END LOOP;
END;
/

Script for monitoring per database

DECLARE
 DAYS_BACK_BEFORE_RESET CONSTANT NUMBER := 8;
 v_Table_Name User_Indexes.Table_Name%TYPE := '-';
BEGIN
 FOR Rec IN (
 SELECT i.Table_Name, i.Owner, i.Index_Name 
 FROM DBA_Indexes i
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
 decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
 decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
 ou.start_monitoring, ou.end_monitoring
 FROM sys.object_usage ou
 JOIN sys.ind$ i ON i.obj# = ou.obj#
 JOIN sys.obj$ io ON io.obj# = ou.obj#
 JOIN sys.obj$ t ON t.obj# = i.bo#
 JOIN DBA_Users u ON u.User_ID = io.owner#
 ) u ON u.Owner = i.Owner AND u.Index_Name = i.Index_Name AND u.Table_Name = i.Table_Name
 JOIN DBA_Users du on du.UserName = i.Owner 
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT Object_Owner, Object_Name
 FROM gv$SQL_Plan
 WHERE Object_Name IS NOT NULL 
 AND Options != 'SAMPLE FAST FULL SCAN' /* Don't rely on SQLs from DBMS_STATS */ 
 ) p ON p.Object_Owner = i.Owner AND p.Object_Name = i.Index_Name 
 WHERE (u.Used IS NULL OR
 u.Monitoring = 'NO' OR
 (u.Used = 'YES' AND TO_DATE(u.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE - DAYS_BACK_BEFORE_RESET)
 )
 AND i.Index_Type NOT IN ('IOT - TOP', 'LOB')
 AND (u.Used IS NULL OR (p.Object_Owner IS NULL AND p.Object_Name IS NULL)) -- Index not used in current execution plans for repeated resetting usage status
 AND du.Oracle_Maintained = 'N' -- Version for starting with 12.1
 -- AND du.Default_Tablespace NOT IN ('SYSTEM', 'SYSAUX') -- Version for before 12.1
 ORDER BY i.Owner, i.Table_Name
 ) LOOP
 BEGIN
 IF v_Table_Name != Rec.Table_Name THEN
 -- Optionally place a sleep after each tables indexes to flatten hard parse peak after invalidation of existing plans for this table 
 -- DBMS_LOCK.SLEEP(1);
 v_Table_Name := Rec.Table_Name;
 END IF;
 EXECUTE IMMEDIATE 'ALTER INDEX '||Rec.Owner||'.'||Rec.Index_Name||' MONITORING USAGE';
 EXCEPTION
 WHEN OTHERS THEN
 RAISE_APPLICATION_ERROR(-20999, 'Error '||SQLERRM||' for index '||Rec.Owner||'.'||Rec.Index_Name); 
 END; 
 END LOOP;
END;
/

Evaluating index usage

Actual state of index usage maintained by the PL/SQL-snippet above allows you to always scan for indexes that are not used for a longer time.

This selections also shows possible usage of index for foreign key protection.

There are two ways to scan for unused indexes

1. v$Object_Usage contains monitoring state for indexes of your current schema

SELECT ou.*, i.Num_Rows, i.Distinct_Keys, seg.MBytes, i.Tablespace_Name, i.Uniqueness, i.Index_Type,
 (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name) IOT_Type,
 c.Constraint_Name foreign_key_protection,
 rc.Owner||'.'||rc.Table_Name Referenced_Table,
 rt.Num_Rows Num_Rows_Referenced_Table
FROM v$Object_Usage ou
JOIN User_Indexes i ON i.Index_Name = ou.Index_Name
LEFT OUTER JOIN User_Ind_Columns ic ON ic.Index_Name = i.Index_Name AND ic.Column_Position = 1
LEFT OUTER JOIN DBA_Cons_Columns cc ON cc.Owner = i.Table_Owner AND cc.Table_Name = i.Table_Name AND cc.Column_Name = ic.Column_Name AND cc.Position = 1
LEFT OUTER JOIN DBA_Constraints c ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
LEFT OUTER JOIN DBA_Constraints rc ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
LEFT OUTER JOIN DBA_Tables rt ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
LEFT OUTER JOIN (SELECT Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments WHERE Owner=USER GROUP BY Segment_Name
 ) seg ON seg.Segment_Name = ou.Index_Name
WHERE ou.Used = 'NO'
AND ou.Monitoring = 'YES'
AND TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-:Min_Ununsed_Days
ORDER BY seg.MBytes DESC
;

2. sys.Object_Usage contains monitoring state for indexes of all schemas

SELECT /* DB-Tools Ramm: unused indexes */ u.*, i.Num_Rows, i.Distinct_Keys,
 seg.MBytes,
 i.Tablespace_Name, i.Uniqueness, i.Index_Type,
 (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = u.Owner AND t.Table_Name = u.Table_Name) IOT_Type,
 c.Constraint_Name foreign_key_protection,
 rc.Owner||'.'||rc.Table_Name Referenced_Table,
 rt.Num_Rows Num_Rows_Referenced_Table
FROM (
 SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
 decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
 decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
 ou.start_monitoring, ou.end_monitoring
 FROM sys.object_usage ou
 JOIN sys.ind$ i ON i.obj# = ou.obj#
 JOIN sys.obj$ io ON io.obj# = ou.obj#
 JOIN sys.obj$ t ON t.obj# = i.bo#
 JOIN DBA_Users u ON u.User_ID = io.owner# --
 WHERE TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-:Min_unused_Days
 )u
JOIN DBA_Indexes i ON i.Owner = u.Owner AND i.Index_Name = u.Index_Name AND i.Table_Name=u.Table_Name
LEFT OUTER JOIN DBA_Ind_Columns ic ON ic.Index_Owner = u.Owner AND ic.Index_Name = u.Index_Name AND ic.Column_Position = 1
LEFT OUTER JOIN DBA_Cons_Columns cc ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name AND cc.Position = 1
LEFT OUTER JOIN DBA_Constraints c ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
LEFT OUTER JOIN DBA_Constraints rc ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
LEFT OUTER JOIN DBA_Tables rt ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
LEFT OUTER JOIN (SELECT Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
 ) seg ON seg.Owner = u.Owner AND seg.Segment_Name = u.Index_Name
WHERE u.Used='NO' AND u.Monitoring='YES'
ORDER BY seg.MBytes DESC NULLS LAST
;

Evaluating index usage state with Panorama

Panorama (available from http://rammpeter.github.io/panorama.html) has several more comfortable ways to show index usage information:

Show usage info in table/index detail view

Each time you view table / index structure usage info for index is also shown if monitoring usage is active:

Clicking the "Show"-link in column "SQLs" shows you all SQLs from SGA or AWR-history that are using this index.

List unused indexes for all schemas of database

Menu "Spec. additions" / "Dragnet investigation" allows to list all unused indexes:
