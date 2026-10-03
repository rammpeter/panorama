# Oracle-DB: Identify non-relevant indexes for secure deletion

Datum: 2019-12-27
URL: https://rammpeter.blogspot.com/2019/12/oracle-db-identification-of-non.html
Labels: Analyze performance issue, Panorama How-To

---

A sensitive issue for DBAs and developers is often the detection and removal of indexes in Oracle databases that are not or no longer needed.

In practice systems can be found that allocate more than 50% of the storage with indexes without any productive relevance.

Nevertheless, this potential for a simple reduction of storage requirements and system load is regularly not used, freely after "never touch a running system" or "why should I burn my fingers here and then this index is still needed somewhere". 

This article demonstrates how to securely determine irrelevant indexes using the freely available analysis tool "Panorama".

Why define indexes on tables

- Optimizing accesses from User-SQL
- Reduction of access to the result-relevant records when reading table data

- Guarantee of uniqueness
- Declaration of unique indexes or use of the index for primary key or unique constraints

- Protection of Foreign Key Constraints
- Preventing full table scans when deleting or updating on the referenced tables
- Prevent propagation of DML locks of the referenced table via Foreign Key Constraints

- Ensure structural identity for Partition Exchange
- Table for partition exchange must be indexed identically to the partitioned target table

Conversely to the above list, the following applies: 

If an existing index does not fulfill any of the four roles mentioned, it can actually be removed.

What is the benefit of removing unnecessary indexes?

- Reduction of storage requirements of the database

- Reduction of the effort for index maintenance in DML operations

- More efficient use of the DB cache 

- Improvement of the runtime and response time behavior of applications

Why is there nevertheless often no active evaluation and removal of unnecessary indexes?

- There is no role in the project/product that performs this task

- The DBAs have only limited insight into the function of the software

- Developers lack the skills and technical means for reliable evaluation

- Never touch a running system: removing indexes has a latent risk of burning your fingers and causing malfunctions

Can an index be removed? Requires evaluation of the four possible roles.

Role 1: Optimization of accesses from User-SQL

- Clearly exclude the use of an index in User-SQL for a longer period of time

Role 2 Ensuring uniqueness

- Make sure that Index is NonUnique and is not used for Primary Key or Unique Constraint

Role 3: Securing Foreign Key Constraints

- Exclude that index is used to hedge a foreign key or

- Ensure that no index hedging is required for the specific foreign key

Role 4 Identical indexing for Partition Exchange

- Test for structure-identical tables that could potentially be used for partition exchange

This article shows how, for all four criteria mentioned, it can be clearly determined whether or not an index fulfills one of these roles. 

Role 1: Identification of index usage by user SQL

Using ALTER INDEX <IndexName> MONITORING USAGE, the monitoring of the usage of an index in SQL statements is activated. The start of the monitoring and the status of the usage (YES/NO) are logged, but not the time of usage. The usage status can be evaluated using the system views V$OBJECT_USAGE (only for the current schema) or sys.OBJECT_USAGE (for the entire DB).

MONITORING USAGE only logs the use of the index in direct SQLs. The use of an index in recursive SQLs of the DB itself is not logged. This means that the implicit use of an index for checking a foreign key constraint (for example, lookup when deleting on a referenced table) is not recorded.

Activating MONITORING USAGE on an index does not result in a measurable performance impact, but: Executing ALTER INDEX ... MONITORING USAGE as DDL causes all SQL cursors using this index to be parsed again the next time it is executed.

The next execution of ALTER INDEX ... MONITORING USAGE resets the start time of the monitoring and the usage status to NO.

For permanent monitoring of a system, it is essential that you regularly reset the usage status of indexes marked as used, so that you can also recognize indexes that were used once in the past but not for a long time.

Scripts for permanent tracking of the usage status

-- Set or reset the usage status for the current schema
DECLARE
 DAYS_BACK_BEFORE_RESET CONSTANT NUMBER := 8;
 v_Table_Name User_Indexes.Table_Name%TYPE := '-';
BEGIN
 FOR Rec IN (
 WITH Plan_Objects AS (SELECT /*+ NO_MERGE MATERIALIZE */ DISTINCT Object_Name 
 FROM gv$SQL_Plan 
 WHERE Object_Owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') 
 AND Object_Name IS NOT NULL
 AND Options != 'SAMPLE FAST FULL SCAN' /* Don't rely on SQLs from DBMS_STATS */
 ),
 Object_Usage AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Name, Index_Name, Start_Monitoring, Used, Monitoring
 FROM v$Object_Usage
 ) 
 SELECT i.Table_Name, i.Index_Name
 FROM User_Indexes i
 LEFT OUTER JOIN Object_Usage u ON i.Table_Name = u.Table_Name AND i.Index_Name = u.Index_Name
 LEFT OUTER JOIN Plan_Objects p ON p.Object_Name = i.Index_Name
 WHERE i.Index_Type NOT IN ('IOT - TOP', 'LOB')
 /* Index never monitored or last monioring start before limit */
 AND (u.Used IS NULL OR u.Monitoring = 'NO' OR (u.Used = 'YES' AND TO_DATE(u.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE - DAYS_BACK_BEFORE_RESET))
 /* Index not in any current SQL plan for repeated resetting usage status */
 AND (u.Used IS NULL OR p.Object_Name IS NULL) 
 ORDER BY i.Table_Name /* Ensure all indexes of a table are touched at once */
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

-- Set or reset the usage status for all user schemas
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

The above scripts are used to reset the usage status only for indexes that:

- are already marked as used

- have not been reset for more than x days

- do not occur in current execution plans in the SGA (except when MONITORING USAGE is activated for the first time). 
This eliminates the risk of reparse bursts of existing SQL cursors by executing these scripts.

Evaluation of the usage status of indexes via SQL

-- Determination of unused indexes of the current schema
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

-- Determination of unused indexes of the entire DB
SELECT u.*, i.Num_Rows, i.Distinct_Keys,
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

Evaluation of the usage status of indexes via Panorama

Based on sys.OBJECT_USAGE, the analysis tool Panorama offers an evaluation of the index usage in role 1 combined with statements on:

- Role 2: Use of indexes for securing uniqueness

- Role 3: Use of indexes for hedging foreign keys

- Role 4: Use of indexes for partition exchange

The above screenshot shows an example with statements on:

- the number of days without using the index in User-SQL

- the possible use of the index as a unique index or for the enforcement of unique or primary constraints

- the existence of foreign key constraints that are hedged by this index

- the number of rows in the table referenced by the foreign key constraint

- The time of the last analysis of the table referenced by the foreign key constraint and the number of its DML operations (insert/update/delete) since the last analysis

- etc. ...

From this list of unused indexes, you can call up the structure definition of the table of the index as well as the table possibly referenced via Foreign Key Constraint with one click.

Alternative identification of index usage by User-SQL starting with Release 12.2

The view DBA_Index_Usage contains more detailed information on index usage starting with Rel. 12.2:

- Does not have to be activated separately, logs the usage of indexes by default

- Contains time of last use and quantity distribution of accesses and result sets

Limitations on the usability of this feature:

- If the data is only sampled cyclically, there is a latent risk that actual use of an index is not logged.

- Switching to hard logging of each access brings significant performance restriction 
ALTER SESSION SET "_iut_stat_collection_type"=ALL; instead of SAMPLED

- The memory data is flushed to disk every 15 minutes and then visible in DBA_Index_Usage

- Only use of the index in direct SQLs is logged. 
The use of an index in recursive SQLs of the DB itself is not logged (analogous to ALTER INDEX .. MONITORING USAGE ).

- An analysis of the index (for example, dbms_stats.gather_index_stats) also counts as usage

Therefore this feature does not allow to safely exclude index usage, but gives helpful support in identifying the detailed usage of an index.

Role 2: Relevance of an index for securing uniqueness

In the list of unused indexes in the above screenshot, the UNIQUENESS column shows whether an index is declared unique or serves as the basis of unique or primary key constraints and therefore has a right to exist even if it is not used in SQLs.

As a special case, however, it is possible to remove a multi-column unused unique index without any problems in such a scenario, if the uniqueness of a single column of this index is already ensured with another unique index/constraint.

Role 3: Relevance of an index for protecting foreign key constraints

Reasons for an index on the referencing table of a foreign key constraint can be

- Preventing a full table scan on the referencing table when deleting or updating the reference

- Prevent lock propagation of DML locks for DML on the referenced table

This means that even if a foreign key constraint exists, it is not necessary to secure it with an index if no DML takes place on the referenced table.

This is regularly the case, for example, with foreign key constraints against static master data tables.

Tolerability of DML on referenced table

Even if the referenced table has a small DML, index hedging is often not necessary:

- A full table scan on the referencing table when deleting on the reference may be acceptable for sporadic DML activities. For example, a one-time full table scan every x weeks is often less time-consuming than keeping an index permanently.

- Lock propagation is only a problem in special constellations.
Especially when updates are made to primary key columns, which is not necessary when technical primary keys (IDs) are used.

In this blog post the relevance of lock propagation via foreign key constraints is examined in more detail:

- A list of different competing DML operations on two tables

- The respective relevance of an index on the Foreign Key Constraint to prevent blocking locks

Evaluation of DML operations on referenced table

The existence and size of DML on a table can be traced using the view DBA_TAB_MODIFICATIONS.

This view logs the number of inserts, updates and deletes since the last analysis. According to Oracle documentation up to 19c, the prerequisite for logging in DBA_TAB_MODIFICATIONS is the status MONITORING=YES at table level. In reality, however, as of Rel.11, DML operations are also recorded with status NOMONITORING.

This number of DML operations since the last analysis allows you to assess whether the frequency and frequency of the DML operations on the referenced table require that a foreign key constraint on the referencing table be hedged by index.

Steps in Panorama for evaluating DML on referenced table

One part of the table structure display is the above list of indexes for a table. Column "FK" shows the protection of a Foreign Key constraint by this index, column "Use" shows the usage status of the index since the last activation of MONITORING USAGE. Further details are displayed by mouseover hint, e.g. the time of the last activation of MONITORING USAGE.

A click in the column "FK" of the index details leads to the details of the Foreign Key constraint. The number of records (column "Num. rows") of the referenced table allows a first evaluation of the possible relevance of the index.

A click in column "Referenced table name" of the Foreign Key constraint leads to the above structure description of the referenced table. Here, the number of DML operations since the last analysis (columns "Inserts"/"Updates"/"Deletes") allows a more precise assessment of whether an index on the Foreign Key Constraint is relevant for preventing lock propagation from the referenced table. 

Role 4: Relevance of an index for securing structural identity for Partition Exchange

Column "Partition Exchange Possible" of the list in the first image of this post shows if there are possible partner for partition exchange existing.

This post also shows how to scan the whole database for tables valid for partition exchange.

Removability of currently actually used indexes

Despite proven usage by User-SQL, it can still be useful to remove an index. Some possible constellations for this are:

- Columns of an index are already indexed elsewhere by the leading columns of a multi-column index. After removing an index, the other index with the leading columns of the first one takes over its function.

- The partitioning of the table has the same filter effect as the index. A reduction of the hit list through partitioning is more effective than an index access if the partitioning criterion is unique.

- Changing the order of the columns of another multi-column index makes an index with the identical leading columns unnecessary

- An access via Index Fast Full Scan can also be executed via another index of the table. If the relevant column(s) are also indexed elsewhere, or if only the number itself is relevant (for example, for COUNT(*) ), you can also use another index.

For the identification of further possibly dispensable indexes, Panorama offers various other "dragnet search" queries.

About the Panorama analysis tool used

Panorama is the author's Swiss Army Knife, a freely usable tool for Oracle-DB performance analysis. It is based on read-only SQL-accessible information of the DB, including data from the AWR.

For use with Standard Edition or without licensing the Diagnostics Pack, Panorama has its own function for sampling historical data.

Conclusion

The presented procedure shows how simple and low-risk to risk-free often a drastic reduction of the storage requirement and the system load of Oracle-DB is possible.

 Addition 2026-07: Check for use of index in optimizer hint or SQL Plan Management directives
