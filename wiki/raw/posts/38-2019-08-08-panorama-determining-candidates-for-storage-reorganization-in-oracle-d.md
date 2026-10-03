# Panorama: Determining candidates for storage reorganization in Oracle-DB

Datum: 2019-08-08
URL: https://rammpeter.blogspot.com/2019/08/panorama-determining-candidates-for.html
Labels: 

---

Knowing that Oracle-DB does not automatically release storage below the high water mark it would be necessary to do it yourself.

Usually you may scan your database from time to time to identify tables, indexes or lobs where reorganization of these objects can make significant amount of storage in tablespace available for other objects.

The PL/SQL package DBMS_SPACE allows consideration of free space in DB blocks for an object.

This information can be used to forecast the effect of object reorganization.

Unfortunately DBMS_SPACE.Space_Usage takes longer time for evaluation of larger objects, so it is quite expensive to scan a whole schema or system using DBMS_SPACE.

Following I'll show how the performance analysis tool Panorama handles determining candidates for reorganization.

To determine candidates for deeper inspection Panorama uses a simple calculation based on avg. row-length, Pct_Free and Ini_Trans to list suspected objects that are worth to reorganize.

Sorting this list descending by "MBytes unused" gives you a hit-list for reorganization.

Columns "% unused" and "MBytes unused" give a fuzzy view to possible potential for reorganization (1557 MB for the selected table).

At single object level Panorama then allows detailed object evaluation with DBMS_SPACE.Space_Usage by click in one of this two columns.

The 4 slots in result of DBMS_SPACE.Space_Usage (0..25, 25..50, 50..75 and 75..100% free space in blocks) allow a more detailed forecast of possible reorganization effect.

Based on this 4 slots for free space in DB-blocks is an approximate calculation of unused space im MBytes (column "Approx. unused MBytes").

Assuming the worst case that PCT_FREE is already used for content expansion the column "Freeable MBytes" show the possible storage decrease after reorganization of this object (with renewed allocation of PCT_FREE).

This check with DBMS_SPACE is also available by click at detail views for tables, indexes and LOBs.

For Securefile-LOBs the result of DBMS_SPACE.Space_Usage is different due to their special structure.

The following SQL statement allows determination of candidates by hand in a similar way like Panorama does in the first step. Column "MB_Unused" shows the amount of storage that can be released by reorganizing objects.

 SELECT /* Panorama-Tool Ramm */
 RowNum,
 CASE WHEN Segment_Name LIKE 'SYS_LOB%' THEN
 Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 8, 10)) )||')'
 WHEN Segment_Name LIKE 'SYS_IL%' THEN
 Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 7, 10)) )||')'
 WHEN Segment_Name LIKE 'SYS_IOT_OVER%' THEN
 Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 14, 10)) )||')'
 ELSE Segment_Name
 END Segment_Name_Qual,
 x.*,
 CASE 
 WHEN Segment_Type LIKE 'TABLE%' AND x.Avg_RowLen > 0 AND x.Num_Rows > 0 AND x.MBytes > 0 AND x.Ini_Trans > 0 THEN 
 x.MBytes - (
 ( TRUNC(num_rows / ( (TRUNC((blocksize.val - ( (Type_Size.block_common_header_size + Type_Size.unsigned_byte_4_size + Type_Size.transaction_fixed_header_size + Type_Size.data_header_size
 ) /* block_header_size_without_ini_trans */ + Type_Size.transaction_var_header_size * (x.ini_trans - 1)
 ) /* block_header_size(ini_trans) */
 ) * (1 - x.pct_free/100.0) - Type_Size.table_directory_entry_size
 )
 ) /* data_size_per_block_without_row_dir */ / (x.avg_rowlen + 5) /* 2 Byte row directory + 3 byte row header */
 ) /* rows_per_block */) + 1
 )/* needed_blocks */ * blocksize.val
 )/ (1024 * 1024) 
 WHEN Segment_Type LIKE 'INDEX%' AND x.Avg_RowLen > 0 AND x.Num_Rows > 0 AND x.MBytes > 0 AND x.Ini_Trans > 0 AND leaf_blocks > 0 THEN 
 ( TRUNC((blocksize.val - ( (Type_Size.block_common_header_size + Type_Size.unsigned_byte_4_size + Type_Size.transaction_fixed_header_size + Type_Size.data_header_size
 ) /* block_header_size_without_ini_trans */ + Type_Size.transaction_var_header_size * (x.ini_trans - 1)
 ) /* block_header_size(ini_trans) */
 ) * (1 - x.pct_free/100.0) - Type_Size.table_directory_entry_size
 ) * x.leaf_blocks - (x.num_rows * (x.avg_rowlen + CASE WHEN x.avg_rowlen > 250 THEN 3 ELSE 1 END + rowid_size.val)) /* allocated size in leaf blocks by rows */
 ) / (1024.0 * 1024.0) 
 ELSE NULL 
 END MB_Unused
 FROM (
 SELECT
 Segment_Name,
 Tablespace_Name,
 Count(*) Partition_Count,
 SEGMENT_TYPE,
 Owner, 
 SUM(EXTENTS) Used_Ext, 
 SUM(bytes)/(1024*1024) MBytes,
 SUM(Blocks) Blocks,
 MIN(Initial_Extent)/1024 Min_Init_Ext_KB,
 MAX(Initial_Extent)/1024 Max_Init_Ext_KB,
 SUM(Initial_Extent)/1024 Sum_Init_Ext_KB,
 MIN(Next_Extent)/1024 Min_Next_Ext_KB,
 MAX(Next_Extent)/1024 Max_Next_Ext_KB,
 SUM(Next_Extent)/1024 Sum_Next_Ext_KB,
 MIN(Min_Extents) Min_Min_Exts,
 MAX(Min_Extents) Max_Min_Exts,
 SUM(Min_Extents) Sum_Min_Exts,
 MIN(Max_Extents) Min_Max_Exts,
 MAX(Max_Extents) Max_Max_Exts,
 SUM(Max_Extents) Sum_Max_Exts,
 CASE WHEN COUNT(DISTINCT InMemory) = 1 THEN MIN(InMemory) ELSE '<'||COUNT(DISTINCT InMemory)||'>' END InMemory,
 SUM(Num_Rows) Num_Rows,
 SUM(Blocks * PCT_Free) / SUM(Blocks) Pct_Free, /* weighted value by number of blocks of partition */
 SUM(Blocks * Ini_Trans) / SUM(Blocks) Ini_Trans, /* weighted value by number of blocks of partition */
 CASE WHEN COUNT(DISTINCT Compression) <= 1 THEN MIN(Compression) ELSE '<several>' END Compression,
 AVG(Avg_Row_Len) Avg_RowLen,
 SUM(Empty_Blocks) Empty_Blocks,
 AVG(Avg_Space) Avg_Space,
 MIN(Last_Analyzed) Last_Analyzed,
 MAX(Last_DML_Timestamp) Last_DML_Timestamp,
 MIN(Created) Created,
 MAX(Last_DDL_Time) Last_DDL_Time,
 MAX(Spec_TS) Spec_TS,
 SUM(Leaf_Blocks) Leaf_Blocks
 FROM (
 /* Views moved to with clause due to performance problems with 18.3 */
 WITH Tab_Modifications AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, SubPartition_Name, Timestamp FROM DBA_Tab_Modifications WHERE Partition_Name IS NULL),
 Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM DBA_Segments s WHERE s.SEGMENT_TYPE<>'CACHE'),
 Objects AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Object_Name, SubObject_Name, Created, Last_DDL_Time, Timestamp FROM DBA_Objects),
 Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression, Compress_For FROM DBA_Tables),
 Tab_Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression, Compress_For FROM DBA_Tab_Partitions),
 Tab_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, SubPartition_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression, Compress_For FROM DBA_Tab_SubPartitions),
 Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Index_Type, Num_Rows, Pct_Free, Ini_Trans, Compression, Last_Analyzed, Leaf_Blocks FROM DBA_Indexes),
 Ind_Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Partition_Name, Num_Rows, Pct_Free, Ini_Trans, Last_Analyzed, Compression, Leaf_Blocks FROM DBA_Ind_Partitions),
 Ind_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, SubPartition_Name, Num_Rows, Pct_Free, Ini_Trans, Last_Analyzed, Compression, Leaf_Blocks FROM DBA_Ind_SubPartitions),
 Ind_Row_Len AS (SELECT /*+ NO_MERGE MATERIALIZE */ ic.Index_Owner, ic.Index_Name, SUM(tc.Avg_Col_Len) Avg_Rows_Len
 FROM DBA_Ind_Columns ic
 JOIN DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
 GROUP BY ic.Index_Owner, ic.Index_Name ),
 Tab_Row_Len AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, SUM(Avg_Col_Len) Avg_Rows_Len
 FROM DBA_Tab_Columns
 GROUP BY Owner, Table_Name
 ),
 Lobs AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, Compression FROM DBA_Lobs),
 Lob_Partitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Lob_Name, Lob_Partition_Name, Compression FROM DBA_Lob_Partitions),
 Lob_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Lob_Name, Lob_SubPartition_Name, Compression FROM DBA_Lob_SubPartitions)
 SELECT /*+ ORDERED USE_HASH(s o t tp tsp m i ip isp im l lp lsp) */
 s.Segment_Name,
 s.Partition_Name, 
 s.Segment_Type, 
 s.Tablespace_Name,
 s.Owner, 
 s.Extents, 
 s.Bytes, s.Blocks,
 s.Initial_Extent, s.Next_Extent, s.Min_Extents, s.Max_Extents,
 o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS,
 s.InMemory,
 DECODE(s.Segment_Type, 
 'TABLE', t.Num_Rows,
 'TABLE PARTITION', tp.Num_Rows,
 'TABLE SUBPARTITION', tsp.Num_Rows,
 'INDEX', i.Num_Rows,
 'INDEX PARTITION', ip.Num_Rows,
 'INDEX SUBPARTITION', isp.Num_Rows,
 NULL) num_rows,
 DECODE(s.Segment_Type,
 'TABLE', t.Pct_Free,
 'TABLE PARTITION', tp.Pct_Free,
 'TABLE SUBPARTITION', tsp.Pct_Free,
 'INDEX', i.Pct_Free,
 'INDEX PARTITION', ip.Pct_Free,
 'INDEX SUBPARTITION', isp.Pct_Free,
 NULL) Pct_Free,
 DECODE(s.Segment_Type,
 'TABLE', t.Ini_Trans,
 'TABLE PARTITION', tp.Ini_Trans,
 'TABLE SUBPARTITION', tsp.Ini_Trans,
 'INDEX', i.Ini_Trans,
 'INDEX PARTITION', ip.Ini_Trans,
 'INDEX SUBPARTITION', isp.Ini_Trans,
 NULL) Ini_Trans,
 DECODE(s.Segment_Type,
 'TABLE', t.Compression ||CASE WHEN t.Compression != 'DISABLED' THEN ' ('|| t.Compress_For||')' END,
 'TABLE PARTITION', tp.Compression ||CASE WHEN tp.Compression != 'DISABLED' THEN ' ('|| tp.Compress_For||')' END,
 'TABLE SUBPARTITION', tsp.Compression||CASE WHEN tsp.Compression != 'DISABLED' THEN ' ('||tsp.Compress_For||')' END,
 'INDEX', i.Compression,
 'INDEX PARTITION', ip.Compression,
 'INDEX SUBPARTITION', isp.Compression,
 'LOBSEGMENT', l.Compression,
 'LOB PARTITION', lp.Compression,
 'LOB SUBPARTITION', lsp.Compression,
 NULL) Compression,
 CASE WHEN s.Segment_Type = 'TABLE' THEN t.Avg_Row_Len
 WHEN s.Segment_Type = 'TABLE PARTITION' THEN tp.Avg_Row_Len
 WHEN s.Segment_Type = 'TABLE SUBPARTITION' THEN tsp.Avg_Row_Len
 WHEN s.Segment_Type IN ('INDEX', 'INDEX PARTITION', 'INDEX_SUBPARTITION') AND i.Index_Type = 'NORMAL' THEN irl.Avg_Rows_Len
 WHEN s.Segment_Type = 'INDEX' AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
 WHEN s.Segment_Type = 'INDEX PARTITION' AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
 WHEN s.Segment_Type = 'INDEX SUBPARTITION' AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
 END avg_row_len,
 DECODE(s.Segment_Type,
 'TABLE', t.Empty_blocks,
 'TABLE PARTITION', tp.Empty_Blocks,
 'TABLE SUBPARTITION', tsp.Empty_Blocks,
 NULL) empty_blocks,
 DECODE(s.Segment_Type,
 'TABLE', t.Avg_Space,
 'TABLE PARTITION', tp.Avg_Space,
 'TABLE SUBPARTITION', tsp.Avg_Space,
 NULL) Avg_Space,
 DECODE(s.Segment_Type, 
 'TABLE', t.Last_analyzed,
 'TABLE PARTITION', tp.Last_analyzed,
 'TABLE SUBPARTITION', tsp.Last_analyzed,
 'INDEX', i.Last_analyzed,
 'INDEX PARTITION', ip.Last_analyzed,
 'INDEX SUBPARTITION', isp.Last_analyzed,
 NULL) Last_Analyzed,
 DECODE(s.Segment_Type,
 'TABLE', m.Timestamp,
 'TABLE PARTITION', m.Timestamp,
 'TABLE SUBPARTITION', m.Timestamp,
 'INDEX', im.Timestamp,
 'INDEX PARTITION', im.Timestamp,
 'INDEX SUBPARTITION', im.Timestamp,
 NULL) Last_DML_Timestamp,
 DECODE(s.Segment_Type,
 'TABLE', NULL,
 'TABLE PARTITION', NULL,
 'TABLE SUBPARTITION', NULL,
 'INDEX', i.Leaf_Blocks,
 'INDEX PARTITION', ip.Leaf_Blocks,
 'INDEX SUBPARTITION', isp.Leaf_Blocks,
 NULL) Leaf_Blocks
 FROM Segments s
 LEFT OUTER JOIN Objects o ON o.Owner = s.Owner AND o.Object_Name = s.Segment_name AND NVL(s.Partition_Name, '-1') = NVL(o.SubObject_Name, '-1')
 LEFT OUTER JOIN Tables t ON t.Owner = s.Owner AND t.Table_Name = s.segment_name
 LEFT OUTER JOIN Tab_Partitions tp ON tp.Table_Owner = s.Owner AND tp.Table_Name = s.segment_name AND tp.Partition_Name = s.Partition_Name
 LEFT OUTER JOIN Tab_SubPartitions tsp ON tsp.Table_Owner = s.Owner AND tsp.Table_Name = s.segment_name AND tsp.SubPartition_Name = s.Partition_Name
 LEFT OUTER JOIN Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
 LEFT OUTER JOIN Indexes i ON i.Owner = s.Owner AND i.Index_Name = s.segment_name
 LEFT OUTER JOIN Ind_Partitions ip ON ip.Index_Owner = s.Owner AND ip.Index_Name = s.segment_name AND ip.Partition_Name = s.Partition_Name
 LEFT OUTER JOIN Ind_SubPartitions isp ON isp.Index_Owner = s.Owner AND isp.Index_Name = s.segment_name AND isp.SubPartition_Name = s.Partition_Name
 LEFT OUTER JOIN Ind_Row_Len irl ON irl.Index_Owner = i.Owner AND irl.Index_Name = i.Index_Name
 LEFT OUTER JOIN Tab_Row_Len trl ON trl.Owner = i.Table_Owner AND trl.Table_Name = i.Table_Name /* Sum of column sizes for IOTs */
 LEFT OUTER JOIN Tables it ON it.Owner = i.Table_Owner AND it.Table_Name = i.Table_Name
 LEFT OUTER JOIN Tab_Modifications im ON im.Table_Owner = it.Owner AND im.Table_Name = it.Table_Name AND im.Partition_Name IS NULL -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
 LEFT OUTER JOIN Lobs l ON l.Owner = s.Owner AND l.Segment_Name = s.Segment_Name
 LEFT OUTER JOIN Lob_Partitions lp ON lp.Table_Owner = s.Owner AND lp.Lob_Name = s.Segment_Name AND lp.Lob_Partition_Name = s.Partition_Name
 LEFT OUTER JOIN Lob_SubPartitions lsp ON lsp.Table_Owner = s.Owner AND lsp.Lob_Name = s.Segment_Name AND lsp.Lob_SubPartition_Name = s.Partition_Name
 )
 GROUP BY Owner, Segment_Name, Tablespace_Name, Segment_Type 
 ) x
 CROSS JOIN (SELECT /*+ NO_MERGE */ TO_NUMBER(Value) Val FROM v$parameter WHERE UPPER(Name) = 'DB_BLOCK_SIZE') blocksize
 CROSS JOIN (SELECT /*+ NO_MERGE */
 MAX(CASE WHEN Type = 'KDBT' THEN Type_Size END) Table_Directory_Entry_Size,
 MAX(CASE WHEN Type = 'KTBIT' THEN Type_Size END) Transaction_Var_Header_Size /* Size of ITL entry */,
 MAX(CASE WHEN Type = 'KCBH' THEN Type_Size END) Block_Common_Header_Size,
 MAX(CASE WHEN Type = 'UB4' THEN Type_Size END) Unsigned_Byte_4_Size,
 MAX(CASE WHEN Type = 'KTBBH' THEN Type_Size END) Transaction_Fixed_Header_Size,
 MAX(CASE WHEN Type = 'KDBH' THEN Type_Size END) Data_Header_Size
 FROM v$Type_Size 
 ) Type_Size
 CROSS JOIN (SELECT VSIZE(rowid) Val FROM Dual) RowID_Size
 ORDER BY x.MBytes DESC
 ;
