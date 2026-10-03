# Oracle-DB: OLTP-Compression - what's true and what's wrong

Datum: 2018-09-19
URL: https://rammpeter.blogspot.com/2018/09/oracle-db-oltp-compression-whats-true.html
Labels: Analyze performance issue, Panorama How-To

---

Update 2023-05: 
Checked the above issues against Rel. 19.18
It works much better now than before in Rel. 12.x. 
Not completely without the risk of getting migrated rows and not deterministic at all. But with much smaller amount of situations resulting in increasing storage footprint and migrated rows.

Oracle states OLTP-compression as transparent way to use compressed tables in OLTP environment.

An overview you may find here: https://blogs.oracle.com/db/master-note-for-oltp-compression

This article shows what pitfalls there are and how to identify tables as  possible candidates for OLTP-compression.

Possible pitfalls

Oracle's blog note says that DB-blocks should be recompressed even if compressed columns have changed during update: 

Generally updates

involve the same operations as inserts. Like inserts, updates are not

immediately compressed. When updating an already compressed block any

columns that are not updated are not uncompressed, they continue to use

the symbol table and retain their compression. Updated columns are

stored initially as with any uncompressed block. When the block

approaches full then it compression is attempted with the same

implications as with the inserts described above.

I've never seen this really working starting from 11.2 up to 18.0.

What I recognized is:

Insert and Delete work well leaving compressed blocks in compressed state without migrated rows.

Updates on tables compressed with COMPRESS FOR OLTP lead to uncompressed contents in blocks and in consequence to chained (migrated) rows, if compressed columns are affected. 

This occurs no matter wether new updated value is already in the symbol table of this block or not. 

In consequence that means: OLTP-compression is not suitable now for tables with significant amount of update-operations because of the creation of migrated rows in large scale.

A small test should demonstrate what will happen

To check a table for chained for migrated rows I use a small function.

It checks the number of consistent gets for a table row access by rowid which should be exactly one if the record is not migrated to another block.

CREATE OR REPLACE FUNCTION Chained_Row_Test(Tab_Name VARCHAR2) RETURN NUMBER IS 
 statval NUMBER;
 statdiff NUMBER;
 Dummy NUMBER;
 StatNum NUMBER;
 Row_Count NUMBER;

 TYPE RowID_TableType IS TABLE OF URowID;
 RowID_Table RowID_TableType;

 FUNCTION Diff RETURN NUMBER IS
 oldval NUMBER;
 BEGIN
 oldval := statval;
 SELECT Value INTO statval
 FROM v$SesStat
 WHERE SID=USERENV('SID')
 AND Statistic# = StatNum -- consistent gets
 ;
 RETURN statval - oldval;
 END Diff;

 PROCEDURE RunTest IS
 BEGIN
 statdiff := Diff();
 FOR i IN 1..RowID_Table.COUNT LOOP
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT /*+ NO_MERGE */ * FROM '||Tab_Name||' WHERE RowID=:A1)' 
 INTO Dummy USING RowID_Table(i);
 END LOOP;
 statdiff := Diff();
 END RunTest;

BEGIN
 SELECT Statistic# INTO StatNum FROM v$StatName WHERE Name='consistent gets';

 EXECUTE IMMEDIATE 'SELECT RowID FROM '||Tab_Name BULK COLLECT INTO RowID_Table;
 Row_Count := SQL%ROWCOUNT;
 runTest; -- first run for warm up and parsing cursors
 runTest; -- second run for counting values
 DBMS_OUTPUT.PUT_LINE('Owner='||SYS_CONTEXT ('USERENV', 'SESSION_USER')||', Table='||Tab_Name||', num_rows='||
 Row_Count||', consistent gets='||statdiff||', pct. chained rows='||((statdiff*100/Row_Count)-100)||' %');
 RETURN ((statdiff*100/Row_Count)-100);
END;
/

Test 1: Update a column that is not compressed

CREATE TABLE COMP_TABLE (ID NUMBER, Payload VARCHAR2(100)) PCTFREE 10 COMPRESS FOR OLTP;

INSERT INTO COMP_TABLE SELECT Level, 'Identical values are good for compression'
FROM Dual CONNECT BY Level <= 100000;

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

UPDATE COMP_TABLE SET ID = ID-1;

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

SELECT Chained_Row_Test('COMP_TABLE') Pct_Chained_Rows FROM DUAL;

PCT_CHAINED_ROWS
----------------
 0

Updating a not compressed column (because all values are unique) does not lead to migrated rows.

Test 2: Update a column that is compressed

CREATE TABLE COMP_TABLE (ID NUMBER, Payload VARCHAR2(100)) PCTFREE 10 COMPRESS FOR OLTP;

INSERT INTO COMP_TABLE SELECT Level, 'Identical values are good for compression'
FROM Dual CONNECT BY Level <= 100000;

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

UPDATE COMP_TABLE SET ID = ID-1, Payload = 'Changed value after update: same length';

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 4654 82

SELECT Chained_Row_Test('COMP_TABLE') Pct_Chained_Rows FROM DUAL;

PCT_CHAINED_ROWS
----------------
 79.499

Updating a compressed column lead to chained rows for more than 3/4 of total number of rows.

Test 3: Update a compressed column with values that are already in the symbol table of a block

CREATE TABLE COMP_TABLE (ID NUMBER, Payload VARCHAR2(100)) PCTFREE 10 COMPRESS FOR OLTP;

INSERT INTO COMP_TABLE SELECT Level, CASE WHEN MOD(Level, 2) = 0 
 THEN 'Identical values are good for compression' 
 ELSE 'Changed value after update: same length' 
END FROM DUal CONNECT BY Level <= 100000;

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

UPDATE COMP_TABLE SET ID = ID-1, Payload = 'Changed value after update: same length';

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 4654 82

SELECT Chained_Row_Test('COMP_TABLE') Pct_Chained_Rows FROM DUAL;

PCT_CHAINED_ROWS
----------------
 95.687

Updating a compressed column with values already in signal table lead to chained rows for most of the rows.

Test 4: Delete on compressed table (10% of total rows, 90% remaining in block)

CREATE TABLE COMP_TABLE (ID NUMBER, Payload VARCHAR2(100)) PCTFREE 10 COMPRESS FOR OLTP;

INSERT INTO COMP_TABLE SELECT Level, 'Identical values are good for compression' 

FROM Dual CONNECT BY Level <= 100000;

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

DELETE FROM COMP_TABLE WHERE MOD(ID, 10) = 0;

10000 rows deleted.

COMMIT;

ANALYZE TABLE COMP_TABLE COMPUTE Statistics;

SELECT Num_Rows, Blocks, Empty_Blocks FROM User_Tables WHERE Table_Name = 'COMP_TABLE';

 NUM_ROWS BLOCKS EMPTY_BLOCKS
---------- ---------- ------------
 100000 244 12

SELECT Chained_Row_Test('COMP_TABLE') Pct_Chained_Rows FROM DUAL;

PCT_CHAINED_ROWS
----------------
 0

Delete on compressed table does not lead to chained rows.

How to get recommendations for OLTP-compression

Knowing now that tables are suitable for OLTP-compression if they have less or no updates DBA_Tab_Modification helps us to recognize such tables.

The following SQL lists tables that my be candidates for OLTP-compression:

- Table that are greater than 100 MB

- Tables with less than 5% updates compared to inserts + deletes

- ordered descending by size 

SELECT *
FROM (
 SELECT t.Owner, t.Table_Name, ROUND(s.Size_MB, 2) Size_MB, t.Num_Rows,
 DECODE(pc.Compression, NULL, DECODE(spc.Compression, NULL, t.Compression, spc.Compression), pc.Compression) Compression,
 pc.Partitions, spc.SubPartitions, t.Last_Analyzed,
 m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML
 FROM DBA_Tables t
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*124) Size_MB
 FROM DBA_Segments
 WHERE Segment_Type LIKE 'TABLE%'
 GROUP BY Owner, Segment_Name
 ) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, COUNT(*) Partitions,
 CASE WHEN COUNT(DISTINCT Compression) = 1 THEN MIN(Compression) ELSE COUNT(DISTINCT Compression)||' different' END Compression
 FROM DBA_Tab_Partitions
 GROUP BY Table_Owner, Table_Name
 ) pc ON pc.Table_Owner = t.Owner AND pc.Table_Name = t.Table_Name
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, COUNT(*) SubPartitions,
 CASE WHEN COUNT(DISTINCT Compression) = 1 THEN MIN(Compression) ELSE COUNT(DISTINCT Compression)||' different' END Compression
 FROM DBA_Tab_SubPartitions
 GROUP BY Table_Owner, Table_Name
 ) spc ON pc.Table_Owner = t.Owner AND spc.Table_Name = t.Table_Name
 LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
 WHERE s.Owner NOT IN ('SYS', 'SYSTEM')
 AND s.Size_MB > 100
 AND ( m.Updates IS NULL -- no DML since last analyze 
 OR m.Updates < (m.Inserts + m.Deletes)/(100/5)) -- updates less than limit
 )
WHERE Compression != 'ENABLED'
ORDER BY Size_MB DESC
;

The more comfortable way to get these recommendations and several analysis workflows too is with my performance analysis tool "Panorama".

This tool is available free of charge at https://rammpeter.github.io/panorama.html.

What are your experiences with OLTP-compression?

I would like to hear from your experiences with OLTP-compression.

Do you agree with the above conclusions?

Please leave a comment.
