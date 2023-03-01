# encoding: utf-8
module Dragnet::SqlsPotentialDbStructuresHelper

  private

  def sqls_potential_db_structures
    [
        {
            :name  => t(:dragnet_helper_50_name, :default=> 'Recommendations for possibly useful OLTP-compression of tables'),
            :desc  => t(:dragnet_helper_50_desc, :default=> 'Table compression (COMPRESS FOR xxx) reduces I/O-effort by improvement of cache hit ratio.
Decrease in size by 1/3 to 1/2 is possible.
Min. 20% decrease of size and relevant I/O should exist to compensate CPU overhead of compression/decompression.

OLTP-compression is well suitable for tables with insert and delete operations.
During update operations DB-blocks are decompressed with possibly creation of chained rows. Therefore for OLTP-compression there should by only less or no update operations on table.

OLTP-compression requires licensing of Advanced Compression Option.
            '),

            :sql=> "\
WITH Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, Partition_Name, ROUND(SUM(Bytes/(1024*1024)),2) Size_MB
                  FROM   DBA_Segments
                  WHERE  Owner NOT IN (#{system_schema_subselect})
                  AND    Bytes/(1024*1024) > ?
                  GROUP BY Owner, Segment_Name, Partition_Name
                 ),
     Tables AS   (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, NULL Partition_Name,
                         m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                  FROM   DBA_Tables t
                  LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL
                  AND    t.Compression = 'DISABLED'
                 ),
     Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Table_Owner Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, t.Partition_Name,
                           m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                    FROM   DBA_Tab_Partitions t
                    LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name
                    WHERE  t.Composite = 'NO'
                   ),
     SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Table_Owner Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, t.SubPartition_Name Partition_Name,
                              m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                       FROM   DBA_Tab_SubPartitions t
                       LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name AND m.SubPartition_Name = t.SubPartition_Name
                      ),
     Objects AS  (SELECT /*+ NO_MERGE MATERIALIZE */ x.*, COUNT(*) OVER (PARTITION BY Owner, Table_Name) Partitions_Total
                  FROM   (
                          SELECT * FROM Tables t
                          UNION ALL
                          SELECT * FROM Partitions
                          UNION ALL
                          SELECT * FROM SubPartitions
                         ) x
                  WHERE  x.Owner NOT IN (#{system_schema_subselect})
                  AND    x.Compression = 'DISABLED'
                  AND    (   x.Updates IS NULL                              -- no DML since last analyze
                          OR x.Updates < (x.Inserts + x.Deletes)/(100/?)    -- updates less than limit
                         )
                 )
SELECT x.Owner, x.Table_Name,
       SUM(CASE WHEN x.Partition_Name IS NULL THEN NULL ELSE 1 END) \"Partitions to Compress\",
       MAX(CASE WHEN x.Partition_Name IS NULL THEN NULL ELSE Partitions_Total END) \"Partitions Total\",
       SUM(Num_Rows) Num_Rows,
       SUM(Size_MB)  Size_MB,
       MAX(Last_Analyzed) Max_Last_analyzed,
       SUM(Inserts) Inserts,
       SUM(Updates) Updates,
       SUM(Deletes) Deletes,
       MAX(Last_DML) Last_DML
FROM   Objects x
JOIN Segments s ON s.Owner = x.Owner AND s.Segment_Name = x.Table_Name AND NVL(s.Partition_Name, '-1') = NVL(x.Partition_Name, '-1')
GROUP BY x.Owner, x.Table_Name
HAVING MAX(Last_Analyzed) < SYSDATE - ?
ORDER BY Size_MB DESC NULLS LAST
            ",
            :parameter=>[
                {:name=>t(:dragnet_helper_50_param_1_name, :default=> 'Minimum size of table or partition in MB'), :size=>8, :default=>10, :title=>t(:dragnet_helper_50_param_1_hint, :default=> 'Minimum size of table, partition or subpartition in MB for consideration in result of selection') },
                {:name=>t(:dragnet_helper_50_param_2_name, :default=> 'Maximum % of udates compared to inserts + deletes'), :size=>8, :default=>5, :title=>t(:dragnet_helper_50_param_2_hint, :default=> 'Maximum percentage of udate operations since last analyze compared to the number of inserts + deletes') },
                {:name=>t(:dragnet_helper_50_param_3_name, :default=> 'Minimum days since last analyze'), :size=>8, :default=>7, :title=>t(:dragnet_helper_50_param_3_hint, :default=> 'Minimum number of days since last analyze to ensure valid values for inserts, updates and deletes') },
            ]
        },
        {
          :name  => t(:dragnet_helper_49_name, :default=> 'Possibly suboptimal OLTP-compression of tables'),
          :desc  => t(:dragnet_helper_49_desc, :default=> 'OLTP-compression is well suitable for tables with insert and delete operations.
During update operations DB-blocks are decompressed with possibly creation of chained rows.
Therefore for OLTP-compression there should by only less or no update operations on table.
This selection shows compressed tables with percentage of update operations higher than the limit compared to inserts and deletes.

OLTP-compression requires licensing of Advanced Compression Option.
            '),

          :sql=> "\
WITH Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, Partition_Name, ROUND(SUM(Bytes/(1024*1024)),2) Size_MB
                  FROM   DBA_Segments
                  WHERE  Owner NOT IN (#{system_schema_subselect})
                  AND    Bytes/(1024*1024) > ?
                  GROUP BY Owner, Segment_Name, Partition_Name
                 ),
     Tables AS   (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, NULL Partition_Name,
                         m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                  FROM   DBA_Tables t
                  LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL
                  AND    t.Compression = 'DISABLED'
                 ),
     Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Table_Owner Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, t.Partition_Name,
                           m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                    FROM   DBA_Tab_Partitions t
                    LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name
                    WHERE  t.Composite = 'NO'
                   ),
     SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Table_Owner Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed, t.SubPartition_Name Partition_Name,
                              m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, t.Compression
                       FROM   DBA_Tab_SubPartitions t
                       LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name AND m.SubPartition_Name = t.SubPartition_Name
                      ),
     Objects AS  (SELECT /*+ NO_MERGE MATERIALIZE */ x.*, COUNT(*) OVER (PARTITION BY Owner, Table_Name) Partitions_Total
                  FROM   (
                          SELECT * FROM Tables t
                          UNION ALL
                          SELECT * FROM Partitions
                          UNION ALL
                          SELECT * FROM SubPartitions
                         ) x
                  WHERE  x.Owner NOT IN (#{system_schema_subselect})
                  AND    x.Compression != 'DISABLED'
                  AND    x.Updates > (x.Inserts + x.Deletes)/(100/?)    -- updates less than limit
                 )
SELECT x.Owner, x.Table_Name,
       SUM(CASE WHEN x.Partition_Name IS NULL THEN NULL ELSE 1 END) \"Partitions to Compress\",
       MAX(CASE WHEN x.Partition_Name IS NULL THEN NULL ELSE Partitions_Total END) \"Partitions Total\",
       SUM(Num_Rows) Num_Rows,
       SUM(Size_MB)  Size_MB,
       MAX(Last_Analyzed) Max_Last_analyzed,
       SUM(Inserts) Inserts,
       SUM(Updates) Updates,
       SUM(Deletes) Deletes,
       MAX(Last_DML) Last_DML
FROM   Objects x
JOIN Segments s ON s.Owner = x.Owner AND s.Segment_Name = x.Table_Name AND NVL(s.Partition_Name, '-1') = NVL(x.Partition_Name, '-1')
GROUP BY x.Owner, x.Table_Name
HAVING MAX(Last_Analyzed) < SYSDATE - ?
ORDER BY Size_MB DESC NULLS LAST
            ",
          :parameter=>[
            {:name=>t(:dragnet_helper_49_param_1_name, :default=> 'Minimum size of table or partition in MB'), :size=>8, :default=>10, :title=>t(:dragnet_helper_49_param_1_hint, :default=> 'Minimum size of table, partition or subpartition in MB for consideration in result of selection') },
            {:name=>t(:dragnet_helper_49_param_2_name, :default=> 'Minimum % of udates compared to inserts + deletes'), :size=>8, :default=>5, :title=>t(:dragnet_helper_49_param_2_hint, :default=> 'Minimum percentage of udate operations since last analyze compared to the number of inserts + deletes') },
            {:name=>t(:dragnet_helper_49_param_3_name, :default=> 'Minimum days since last analyze'), :size=>8, :default=>7, :title=>t(:dragnet_helper_49_param_3_hint, :default=> 'Minimum number of days since last analyze to ensure valid values for inserts, updates and deletes') },
          ]
        },
        {
            :name  => t(:dragnet_helper_140_name, :default=> 'Tables with PCT_FREE > 0 but without update-DML'),
            :desc  => t(:dragnet_helper_140_desc, :default=> "For tables without updates you may consider setting PCTFREE=0 and free this space by reorganizing this table.
Free space in DB-blocks declared by PCT_FREE may be used for:
- Reducing the risk of chained rows due to expansion of row-size by by update-statements
- Reducing the risk of ITL-waits by allowing the expansion of the ITL-list above INI_TRANS entries
This selection shows candidates without any update statements since last analyze.
If you can exclude the need for allowing concurrent transactions in ITL-list above INI_TRANS than the recommendation is to set PCT_FREE=0.
"),
            :sql=> "\
WITH Tab_Modifications AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, SubPartition_Name,
                                  Inserts, Updates, Deletes, Truncated, Drop_Segments, Timestamp Last_DML_Timestamp
                           FROM   DBA_Tab_Modifications
                           WHERE  Table_Owner NOT IN (#{system_schema_subselect})
                          ),
     Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, PCT_Free, Num_Rows, Avg_Row_Len, Last_Analyzed, Ini_Trans, Max_Trans
                FROM   DBA_Tables
                WHERE  Owner NOT IN (#{system_schema_subselect})
                AND    Num_Rows > 0
               ),
     Tab_Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, PCT_Free, Num_Rows, Avg_Row_Len, Last_Analyzed, Ini_Trans, Max_Trans
                        FROM   DBA_Tab_Partitions
                        WHERE  Table_Owner NOT IN (#{system_schema_subselect})
                        AND    Num_Rows > 0
                       ),
     Tab_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, SubPartition_Name, PCT_Free, Num_Rows, Avg_Row_Len, Last_Analyzed, Ini_Trans, Max_Trans
                           FROM   DBA_Tab_SubPartitions
                           WHERE  Table_Owner NOT IN (#{system_schema_subselect})
                           AND    Num_Rows > 0
                          )
SELECT *
FROM   (
        SELECT t.Owner, t.Table_Name, NULL Partitions, t.PCT_Free, t.Num_Rows, t.Avg_Row_Len, t.Last_Analyzed,
               ROUND(t.Num_Rows*t.Avg_Row_Len/(1024*1024), 2) Size_MB_Netto,
               ROUND(t.Num_Rows*t.Avg_Row_Len/(1024*1024)*t.PCT_Free/100, 2) Size_MB_For_PctFree, t.INI_Trans, t.Max_Trans,
               m.Inserts, m.Updates, m.Deletes, m.Truncated, m.Drop_Segments, m.Last_DML_Timestamp
        FROM   Tables t
        JOIN   Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL AND m.SubPartition_Name IS NULL
        UNION ALL
        SELECT t.Table_Owner, t.Table_Name, COUNT(*) Partitions, t.PCT_Free, SUM(t.Num_Rows) Num_Rows, ROUND(SUM(t.Avg_Row_Len*t.Num_Rows)/SUM(t.Num_Rows)) Avg_Row_Len , MAX(t.Last_Analyzed) Last_Analyzed,
               ROUND(SUM(t.Num_Rows*t.Avg_Row_Len/(1024*1024)), 2) Size_MB_Netto,
               ROUND(SUM(t.Num_Rows*t.Avg_Row_Len/(1024*1024)*t.PCT_Free/100), 2) Size_MB_For_PctFree, MAX(t.INI_Trans) Ini_Trans, MAX(t.Max_Trans) Max_Trans,
               SUM(m.Inserts) Inserts, SUM(m.Updates) Updates, SUM(m.Deletes) Deletes, MAX(m.Truncated) Truncated, SUM(m.Drop_Segments) Drop_Segments, MAX(m.Last_DML_Timestamp) Last_DML_Timestamp
        FROM   Tab_Partitions t
        JOIN   Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name AND m.SubPartition_Name IS NULL
        GROUP BY t.Table_Owner, t.Table_Name, t.PCT_Free
        UNION ALL
        SELECT t.Table_Owner, t.Table_Name, COUNT(*) Partitions, t.PCT_Free, SUM(t.Num_Rows) Num_Rows, ROUND(SUM(t.Avg_Row_Len*t.Num_Rows)/SUM(t.Num_Rows)) Avg_Row_Len , MAX(t.Last_Analyzed) Last_Analyzed,
               ROUND(SUM(t.Num_Rows*t.Avg_Row_Len/(1024*1024)), 2) Size_MB_Netto,
               ROUND(SUM(t.Num_Rows*t.Avg_Row_Len/(1024*1024)*t.PCT_Free/100), 2) Size_MB_For_PctFree, MAX(t.INI_Trans) Ini_Trans, MAX(t.Max_Trans) Max_Trans,
               SUM(m.Inserts) Inserts, SUM(m.Updates) Updates, SUM(m.Deletes) Deletes, MAX(m.Truncated) Truncated, SUM(m.Drop_Segments) Drop_Segments, MAX(m.Last_DML_Timestamp) Last_DML_Timestamp
        FROM   Tab_SubPartitions t
        JOIN   Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name AND m.SubPartition_Name = t.SubPartition_Name
        GROUP BY t.Table_Owner, t.Table_Name, t.PCT_Free
       )
WHERE  PCT_Free > 0
AND    Last_Analyzed < SYSDATE - ?
AND    Updates = 0
ORDER BY Num_Rows*Avg_Row_Len*PCT_Free DESC
            ",
            :parameter=>[{:name=>t(:dragnet_helper_140_param_1_name, :default=> 'Min. no. days since last analyze'), :size=>8, :default=>8, :title=>t(:dragnet_helper_140_param_1_hint, :default=> 'Minimum number of days since last analyze timestamp for object') },]
        },
        {
            :name  => t(:dragnet_helper_107_name, :default=> 'Relevance of access on migrated / chained rows compared to total amount of table access'),
            :desc  => t(:dragnet_helper_107_desc, :default=> "\
Chained rows causes additional reads of rows in separate DB-blocks while accessing a record which is not completely contained in current block.
There are two types:

1. true chained rows:
A record doesn't compeletely fit into one DB-block, the columns of the record are stored in several DB blocks.
Both the Full Scan and Index RowID scans read further linked DB blocks when accessing paged out columns in the linked blocks (incrementing of 'table fetch continued rows').

2. migrated rows:
A record no longer fits into the current block, is completely migrated to another block, but its RowID still references the original block.
At full scan, the linked blocks are not read separately, but with multiblock-read as part of the full scan (no increment of 'table fetch continued rows').
At RowID access e.g. during index scan, the linked blocks are read by another access (with increment of 'table fetch continued rows').

Chained rows are predominantly migrated rows (variant 2). Variant 1 only occurs if the size of a record is greater than the blocksize.

Chained rows can be avoided by adjusting PCTFREE and reorganization of affected table.
This selection shows the relevance of access on chained rows compared to total amount of table access by RowID."),
            :sql=>   "WITH Inst_Filter AS (SELECT ? Instance FROM DUAL)
                      SELECT x.*, CASE WHEN table_fetch_by_rowid > 0 THEN
                                  ROUND(table_fetch_continued_row / table_fetch_by_rowid * 100,2)
                                  ELSE 0 END \"Pct. chained rowid access\",
                                  CASE WHEN table_fetch_by_rowid + table_scan_rows_gotten > 0 THEN
                                  ROUND(table_fetch_continued_row / (table_fetch_by_rowid + table_scan_rows_gotten) * 100,2)
                                  ELSE 0 END \"Pct. chained rowid and full\"
                      FROM   (
                              SELECT /*+ NO_MERGE*/ ROUND(Begin_Interval_Time, 'MI') Start_Time,
                                     SUM(CASE WHEN Stat_Name = 'table fetch continued row' THEN Value ELSE 0 END) table_fetch_continued_row,
                                     SUM(CASE WHEN Stat_Name = 'table fetch by rowid'      THEN Value ELSE 0 END) table_fetch_by_rowid,
                                     SUM(CASE WHEN Stat_Name = 'table scan rows gotten'    THEN Value ELSE 0 END) table_scan_rows_gotten
                              FROM   (
                                      SELECT /*+ NO_MERGE*/ ss.Begin_Interval_Time, st.Stat_Id, st.Stat_Name, ss.Min_Snap_ID, st.Snap_ID,
                                             Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY st.Snap_ID) Value
                                      FROM   (SELECT /*+ NO_MERGE*/ DBID, Instance_Number, Begin_Interval_Time, Snap_ID,
                                                     MIN(Snap_ID) KEEP (DENSE_RANK FIRST ORDER BY ss.Begin_Interval_Time) OVER (PARTITION BY Instance_Number) Min_Snap_ID /* Snap_ID may start again with 1 in cloned instances */
                                              FROM   DBA_Hist_Snapshot ss
                                              WHERE  Begin_Interval_Time >= SYSDATE - ?
                                              AND    ( (SELECT Instance FROM Inst_Filter) IS NULL OR ss.Instance_Number = (SELECT Instance FROM Inst_Filter)    )
                                             ) ss
                                      JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                                      WHERE  st.Snap_ID = ss.Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
                                      AND    st.Stat_Name IN ('table fetch continued row', 'table fetch by rowid', 'table scan rows gotten')
                                    ) hist
                              WHERE  hist.Value >= 0    /* Ersten Snap nach Reboot ausblenden */
                              AND    hist.Snap_ID > hist.Min_Snap_ID /* Vorgaenger des ersten Snap fuer LAG wieder ausblenden */
                              GROUP BY ROUND(Begin_Interval_Time, 'MI')
                             ) x
                      ORDER BY 1
                      ",
            :parameter=>[
                {:name=>'RAC-Instance (optional)', :size=>8, :default=>'', :title=>t(:dragnet_helper_107_param_1_hint, :default=>'Optional filter for selection on RAC-instance') },
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }
            ]
        },
        {
            :name  => t(:dragnet_helper_69_name, :default=>'Detection of chained rows of tables'),
            :desc  => t(:dragnet_helper_69_desc, :default=>'chained rows causes additional read of migrated rows in separate DB-blocks while accessing a record which is not completely contained in current block.
Chained rows can be avoided by adjusting PCTFREE and reorganization of affected table.

This selection cannot be directly executed. Please copy PL/SQL-Code and execute external in SQL*Plus !!!'),
            not_executable: true,
            :sql=> "
SET SERVEROUT ON;

DECLARE
  statval   NUMBER;
  statdiff  NUMBER;
  Anzahl    NUMBER;
  StatNum   NUMBER;
  v_SQL_ID  VARCHAR2(20);     -- the executed select by rowid
  v_Gets    NUMBER;           -- the buffer gets by SQL
  v_Time    VARCHAR2(20);     -- the timestamp to make the SQL unique
  v_Execs   NUMBER;           -- The number of executions of SQL
  Row_Count NUMBER;           -- real number of rows found in table. Possibly below sample_size
  Sample_Size NUMBER := 1000;

  TYPE RowID_TableType IS TABLE OF URowID;
  RowID_Table RowID_TableType;

  FUNCTION Diff RETURN NUMBER IS
    oldval NUMBER;
  BEGIN
    oldval := statval;
    SELECT Value INTO statval
    FROM   v$SesStat
    WHERE  SID=USERENV('SID')
    AND    Statistic# = StatNum  -- consistent gets
    ;
    RETURN statval - oldval;
  END Diff;

  PROCEDURE RunTest(p_Owner IN VARCHAR2, p_Table_Name IN VARCHAR2) IS
  BEGIN
    v_Time := TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF');
    statdiff := Diff();
    FOR i IN 1..RowID_Table.COUNT LOOP
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT /*+ NO_MERGE '||v_Time||' */ * FROM '||p_Owner||'.'||p_Table_Name||' WHERE RowID=:A1)' INTO Anzahl USING RowID_Table(i);
    END LOOP;
    SELECT Prev_SQL_ID INTO v_SQL_ID FROM v$Session WHERE SID = SYS_CONTEXT('USERENV', 'SID');   /* Separate SQL to not catch the implicit FGA policy SQL while selecting from v$SQL */
    statdiff := Diff();
    SELECT Buffer_gets, Executions INTO v_Gets, v_Execs FROM v$SQL WHERE SQL_ID = v_SQL_ID;
  END RunTest;

BEGIN
  DBMS_OUTPUT.PUT_LINE('===========================================');
  DBMS_OUTPUT.PUT_LINE('Detection of chained rows: connected as user='||SYS_CONTEXT ('USERENV', 'SESSION_USER'));
  DBMS_OUTPUT.PUT_LINE('Sample-size='||Sample_Size||' rows');
  DBMS_OUTPUT.PUT_LINE('There might be incorrect results for partioned and/or compressed tables');
  DBMS_OUTPUT.PUT_LINE('===========================================');
  SELECT Statistic# INTO StatNum FROM v$StatName WHERE Name='consistent gets';
  FOR Rec IN (SELECT Owner, Table_Name, Num_Rows
              FROM   DBA_Tables
              WHERE  IOT_Type IS NULL
              AND    Num_Rows > 10000   -- nur genügende große Tabellen testen
              AND    Owner NOT IN (#{system_schema_subselect})
             ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'SELECT RowID FROM '||Rec.Owner||'.'||Rec.Table_Name||' WHERE RowNum <= '||Sample_Size BULK COLLECT INTO RowID_Table;
      Row_Count := SQL%ROWCOUNT;
      runTest(Rec.Owner, Rec.Table_Name);  -- der erste zum Warmlaufen und übersetzen der Cursor
      runTest(Rec.Owner, Rec.Table_Name);  -- dieser zum Zaehlen
      IF statdiff > Row_Count THEN
        DBMS_OUTPUT.PUT_LINE('Table='||RPAD(Rec.Owner||'.'||Rec.Table_Name, 61)||', num rows='||LPAD(Rec.Num_Rows, 10)||', consistent gets='||LPAD(statdiff, 6)||', buffer gets='||LPAD(v_Gets, 6)||', pct. chained rows='||LPAD(ROUND(((statdiff*100/Row_Count)-100), 2), 4)||' %');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Table='||Rec.Owner||'.'||Rec.Table_Name||',  Error: '||SQLCODE||':'||SQLERRM);
    END;
  END LOOP;
END;
/
             ",
        },
        {
            :name  => t(:dragnet_helper_117_name, :default=>'Table access by rowid replaceable by index lookup (from current SGA)'),
            :desc  => t(:dragnet_helper_117_desc, :default=>'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.'),
            :sql=> "SELECT x.*
                    FROM   (
                            SELECT /*+ USE_HASH(t) */
                                   p.Inst_ID, p.SQL_ID, p.Plan_Hash_Value, h.SQL_Plan_Line_ID, p.Object_Owner, p.Object_Name,
                                   t.Num_Rows, t.Avg_Row_Len,
                                   h.Samples Seconds_per_SQL,
                                   SUM(Samples) OVER (PARTITION BY p.Object_Owner, p.Object_Name) Seconds_per_Object
                            FROM   (
                                    SELECT DISTINCT Inst_ID, ID, Operation, Options, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name
                                    FROM   gv$SQL_Plan
                                   ) p
                            JOIN   (
                                    SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, SQL_ID,
                                           SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Samples
                                    FROM   gv$Active_Session_History
                                    WHERE  SQL_Plan_Line_ID IS NOT NULL
                                    GROUP BY Inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                   ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                            LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                            WHERE  p.Operation = 'TABLE ACCESS' AND p.Options = 'BY INDEX ROWID'
                            AND    p.Object_Owner NOT IN (#{system_schema_subselect})
                            AND    NVL(t.Num_Rows, 0) < ?
                           ) x
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC",
            :parameter=>[{:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>10, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        {
            :name  => t(:dragnet_helper_118_name, :default=>'Table access by rowid replaceable by index lookup (from AWR history)'),
            :desc  => t(:dragnet_helper_118_desc, :default=>'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.'),
            :sql=> "SELECT *
                    FROM   (
                            SELECT /*+ USE_HASH(t) */
                                   h.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, h.SQL_Plan_Line_ID, p.Object_Owner, p.Object_Name, t.Num_Rows, t.Avg_Row_Len,
                                   h.Samples*10 Seconds_per_SQL,
                                   SUM(Samples*10) OVER (PARTITION BY p.Object_Owner, p.Object_Name) Seconds_per_Object
                            FROM   DBA_Hist_SQL_Plan p
                            JOIN   (
                                    SELECT /*+ PARALLEL(h,2) */
                                           DBID, Instance_Number, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, SQL_ID,
                                           SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Samples
                                    FROM   DBA_Hist_Active_Sess_History h
                                    WHERE  SQL_Plan_Line_ID IS NOT NULL
                                    AND    Sample_Time > SYSDATE - ?
                                    GROUP BY DBID, Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                   ) h ON h.DBID = p.DBID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                            LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                            WHERE  p.Operation = 'TABLE ACCESS' AND p.Options = 'BY INDEX ROWID'
                            AND    p.Object_Owner NOT IN (#{system_schema_subselect})
                            AND    NVL(t.Num_Rows, 0) < ?
                           )
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC
                    ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>100, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        {
            :name  => t(:dragnet_helper_127_name, :default=>'Possibly expensive TABLE ACCESS BY INDEX ROWID with additional filter predicates on table'),
            :desc  => t(:dragnet_helper_127_desc, :default=>'If in a SQL a table has additional filter conditions that are not covered by the used index you may consider to extend the index by these filter conditions.
This would ensure that you do the more expensive TABLE ACCESS BY ROWID only if that table row matches all your access conditions checked by the index.
This selection considers current SGA'),
            :sql=> "
              WITH ash_all AS (SELECT /*+ NO_MERGE */ inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Child_Number, SQL_Plan_Line_ID, COUNT(*) Ash_Seconds
                               FROM   gv$Active_Session_History
                               WHERE  SQL_Plan_Hash_Value != 0 -- kein SQL
                               GROUP BY inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Child_Number, SQL_Plan_Line_ID
                              )
              SELECT Table_Owner, Table_Name, Index_Name,
(Ash_seconds_Tab - NVL(Ash_Seconds_Ind, 0)) * (Index_Cardinality-Table_Cardinality) Sort,
                     Elapsed_Secs               \"Elapsed time SQL total (sec.)\",
                     Ash_Seconds_Ind            \"Index access time ASH (sec.)\",
                     Ash_Seconds_Tab            \"Table access time ASH (sec.)\",
                     SQL_ID,
                     Index_Plan_Line_ID         \"Plan line ID of index access\",
                     Table_Plan_Line_ID         \"Plan line ID of table access\",
                     Index_Cardinality          \"Cardinality index access\",
                     Table_Cardinality          \"Cardinality table access\",
                     Index_Access               \"Access criteria on index\",
                     Table_Filter               \"Filter criteria on table\"
              FROM   (
                      SELECT ind.Inst_ID, ind.SQL_ID, ind.Plan_Hash_Value, ind.Child_Number, ind.ID Ind_ID, tab.ID tab_ID, tab.Table_Owner, tab.Table_Name, ind.Index_Name,
                             ROUND(s.Elapsed_Time/1000000) Elapsed_Secs,
                             ash_ind.ash_Seconds ash_Seconds_ind,
                             ash_tab.ash_Seconds ash_Seconds_Tab,
                             ind.Access_Predicates Index_Access, tab.Filter_Predicates Table_Filter,
                             ind.Cardinality Index_Cardinality,
                             tab.Cardinality Table_Cardinality,
                             tab.ID Table_Plan_Line_ID,
                             ind.ID Index_Plan_Line_ID
                      FROM   (
                              SELECT /*+ NO_MERGE */  Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, ID, Object_Owner Index_Owner, Object_Name Index_Name, Access_Predicates, Cardinality
                              FROM   gv$SQL_Plan
                              WHERE  Access_Predicates IS NOT NULL
                              AND    Operation LIKE 'INDEX%'
                              AND    Object_Owner NOT IN (#{system_schema_subselect})
                             ) ind
                      JOIN   DBA_Indexes i ON i.Owner = ind.Index_Owner AND i.Index_Name = ind.Index_Name
                      JOIN   (
                              SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, ID, Object_Owner Table_Owner, Object_Name Table_Name, Filter_Predicates, Cardinality
                              FROM   gv$SQL_Plan
                              WHERE  Filter_Predicates IS NOT NULL
                              AND    Operation LIKE 'TABLE ACCESS%'
                              AND    Options LIKE 'BY INDEX ROWID%'
                              AND    Object_Owner NOT IN (#{system_schema_subselect})
                             ) tab ON tab.Inst_ID = ind.Inst_ID AND tab.SQL_ID = ind.SQL_ID AND tab.Plan_Hash_Value = ind.Plan_Hash_Value AND tab.Child_Number = ind.Child_Number AND
                                      tab.Table_Owner = i.Table_Owner AND tab.Table_Name = i.Table_Name AND tab.ID < ind.ID -- Index kommt unter table beim index-Zugriff
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Elapsed_Time
                              FROM   gv$SQL
                              WHERE  Elapsed_Time > ? * 1000000
                             )s ON S.INST_ID = ind.Inst_ID AND s.SQL_ID = ind.SQL_ID AND s.Plan_Hash_Value = ind.Plan_Hash_Value AND s.Child_Number = ind.Child_Number
                      JOIN   ash_all ash_tab  ON ash_tab.INST_ID = ind.Inst_ID AND ash_tab.SQL_ID = ind.SQL_ID AND ash_tab.SQL_Plan_Hash_Value = ind.Plan_Hash_Value AND ash_tab.SQL_Child_Number = ind.Child_Number AND ash_tab.SQL_Plan_Line_ID = tab.ID
                      -- Ash may be removed after short time but SQL remains in SGA, Index access must not have ash records
                      LEFT OUTER JOIN ash_all ash_ind  ON ash_ind.INST_ID = ind.Inst_ID AND ash_ind.SQL_ID = ind.SQL_ID AND ash_ind.SQL_Plan_Hash_Value = ind.Plan_Hash_Value AND ash_ind.SQL_Child_Number = ind.Child_Number AND ash_ind.SQL_Plan_Line_ID = ind.ID
                     )
              WHERE  Elapsed_Secs >= ?
              AND    Ash_Seconds_Tab >= ?
              AND    Ash_Seconds_Tab > NVL(Ash_Seconds_Ind, 0)
              ORDER BY Ash_seconds_Tab - NVL(Ash_Seconds_Ind, 0) DESC
            ",
            :parameter=>[{:name=>t(:dragnet_helper_127_param_1_name, :default=>'Minimum elapsed seconds of SQL in SGA to be considered in selection'), :size=>8, :default=>10, :title=>t(:dragnet_helper_127_param_1_hint, :default=>'Minimum amount of elapsed seconds an SQL must have in GV$SQL to be considered in this selection') },
                         {:name=>t(:dragnet_helper_127_param_2_name, :default=>'Minimum elapsed seconds as sum over all SQLs in SGA per accessed table'), :size=>8, :default=>100, :title=>t(:dragnet_helper_127_param_2_hint, :default=>'Minimum amount of elapsed seconds of all SQLs in SGA that are accessing the considered table to be shown in this selection') },
                         {:name=>t(:dragnet_helper_127_param_3_name, :default=>'Minimum elapsed seconds in active session history for TABLE ACCESS BY ROWID'), :size=>8, :default=>0, :title=>t(:dragnet_helper_127_param_3_hint, :default=>"Minimum amount of elapsed seconds in GV$Active_Session_History of for TABLE ACCESS BY ROWID on the considered table to be shown in this selection. Value=0 means: show this table access also if there are no records in active session history for this access.") },
            ]
        },
        {
            :name  => t(:dragnet_helper_136_name, :default=>'Possibly missing NOT NULL constraint, although there are no NULL values in column'),
            :desc  => t(:dragnet_helper_136_desc, :default=>'If a column is always filled with values, it should eventually be backed up by a NOT NULL constraint.
This is especially important if the column is indexed, since without the NOT NULL constraint the index is not used for an ORDER BY (or only if in the SQL result explicitly excludes NULLs).'),
            :sql=> "
SELECT /*+ NO_MERGE */ tc.Owner, tc.Table_Name, tc.Column_Name, ic.Index_Name, tc.Num_Distinct, t.Num_Rows, t.Last_Analyzed
FROM   DBA_Tab_Columns tc
JOIN   DBA_Tables t                ON t.Owner = tc.Owner AND t.Table_Name = tc.Table_Name
LEFT OUTER JOIN DBA_Ind_Columns ic ON ic.Table_Owner = tc.Owner AND ic.Table_Name = tc.Table_Name AND ic.Column_Name = tc.Column_Name AND ic.Column_Position = 1
WHERE  tc.Nullable = 'Y'
AND    tc.Num_Nulls = 0
AND    tc.Num_Distinct > 0
AND    t.Num_Rows > ?
ORDER BY DECODE(ic.Index_Name, NULL, 1, 0), t.Num_Rows DESC
            ",
            :parameter=>[{:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')}
            ]
        },
        {
            :name  => t(:dragnet_helper_144_name, :default=>'Possibly compressable but currently uncompressed LOB-segments'),
            :desc  => t(:dragnet_helper_144_desc, :default=>"Compression of Securefile-LOBs allows decrease of storage requirement if LOB-content allows significant compression.
Activation requires recreation of table a'la CREATE TABLE NewTab LOB(ColName) STORE AS SECUREFILE (COMPRESS HIGH) AS SELECT * FROM OrgTab;
Licensing of Advanced Compression Option is required for usage of LOB-Compression."),
            :sql=> "
SELECT /*+ ORDERED */ l.Owner, l.Table_name, l.Column_Name, tc.Data_Type, l.Segment_Name, l.Tablespace_Name, s.MBytes,
       l.Encrypt, l.Compression, l.Deduplication, l.In_Row, l.Partitioned, l.Securefile, t.Num_Rows, tc.Num_Nulls, tc.Avg_Col_Len Avg_Col_Len_In_Row
FROM   DBA_Lobs l
LEFT OUTER JOIN DBA_Tables t       ON t.Owner = l.Owner AND t.Table_Name = l.Table_Name
LEFT OUTER JOIN DBA_Tab_Columns tc ON tc.Owner = l.Owner AND tc.Table_Name = l.Table_Name AND tc.Column_Name = l.Column_Name
JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, Segment_Type, SUM(Bytes)/(1024*1024) MBytes
        FROM   DBA_Segments
        GROUP BY Owner, Segment_Name, Segment_Type
       ) s ON s.Owner = l.Owner AND s.Segment_Name = l.Segment_Name
WHERE  l.Owner NOT IN (#{system_schema_subselect})
AND    l.Compression LIKE 'NO%'
ORDER BY s.MBytes DESC
            ",
        },
    ]
  end # sqls_potential_db_structures


end
