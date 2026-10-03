# Generate recommendation lists for index compression on Oracle-DB

Datum: 2016-08-17
URL: https://rammpeter.blogspot.com/2016/08/generate-recommendation-lists-for-index.html
Labels: Analyze performance issue, Panorama How-To

---

An often underrated feature of Oracle databases since version 9i is key compression for indexes.

It allows reduction of index footprint until 1/2 of uncompressed size depending from key size and number of rows per key.

Compressing an index is quite simple:

ALTER INDEX MyIndex REBUILD COMPRESS;

to compress all keys of an index or

ALTER INDEX MyIndex REBUILD COMPRESS 2

to compress only the first two columns of an multicolumn index.

But how to determine which indexes of an existing database system are worth compressing?

You can generate weighted recommendation lists for index compression by executing the following SQL statements at your database with an user who has the grant SELECT ANY DICTIONARY.

Version 1: Rate indexes by selectivity

SELECT *
FROM (
 SELECT ROUND(i.Num_Rows/i.Distinct_Keys) Rows_Per_Key, i.Num_Rows, i.Owner, i.Index_Name, i.Index_Type, i.Table_Owner, i.Table_Name,
 t.IOT_Type,
 ( SELECT ROUND(SUM(bytes)/(1024*1024),1) MBytes
 FROM DBA_SEGMENTS s
 WHERE s.SEGMENT_NAME = i.Index_Name
 AND s.Owner = i.Owner
 ) MBytes, Distinct_Keys,
 (SELECT SUM(tc.Avg_Col_Len)
 FROM DBA_Ind_Columns ic,
 DBA_Tab_Columns tc
 WHERE ic.Index_Owner = i.Owner
 AND ic.Index_Name = i.Index_Name
 AND tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
 ) Avg_Col_Len
 FROM DBA_Indexes i
 JOIN DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
 WHERE i.Compression='DISABLED'
 AND i.Distinct_Keys > 0
 AND i.Table_Owner NOT IN ('SYS')
 AND i.Num_Rows/DECODE(i.Distinct_Keys,0,1,i.Distinct_Keys) > :Min_Rows_per_Key
 ) i
WHERE MBytes > :Min_MB_of_Index
AND Index_Type NOT IN ('BITMAP')
ORDER BY NVL(Avg_Col_Len, 5) * Num_Rows * Num_Rows/Distinct_Keys DESC NULLS LAST

Version 2: Rate indexes by leaf block count

SELECT /* DB-Tools Ramm Komprimierung Indizes */ i.Owner \"Owner\", i.Table_Name, Index_Name, Index_Type, BLevel, Distinct_Keys,
 ROUND(i.Num_Rows/i.Distinct_Keys) Rows_Per_Key,
 Avg_Leaf_Blocks_Per_Key, Avg_Data_Blocks_Per_Key, i.Num_Rows, t.IOT_Type
FROM DBA_Indexes i
JOIN DBA_Tables t ON t.Owner=i.Table_Owner AND t.Table_Name=i.Table_Name
WHERE Avg_Leaf_Blocks_Per_Key > :Min_Leaf_Blocks_per_Key
AND i.Compression = 'DISABLED'
ORDER BY Avg_Leaf_Blocks_Per_Key*Num_Rows DESC NULLS LAST

Version 3: Rate indexes by selectivity of single columns for multicolumn-indexes

SELECT *
FROM ( 
 SELECT i.Owner, i.Table_Name, i.Index_Name, i.Index_Type, i.Compression, i.Prefix_Length, i.Num_Rows, i.Last_Analyzed, i.Partitioned, 
 (SELECT COUNT(*)
 FROM DBA_Ind_Partitions ip 
 WHERE ip.Index_Owner = i.Owner
 AND ip.Index_Name = i.Index_Name
 ) Partitions,
 ica.Columns, ic.Column_Name, ic.Column_Position,
 tc.Num_Distinct, tc.Avg_Col_Len, ROUND(i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct)) Rows_per_Key,
 (SELECT ROUND(SUM(bytes)/(1024*1024),1) MBytes
 FROM DBA_SEGMENTS s
 WHERE s.SEGMENT_NAME = i.Index_Name
 AND s.Owner = i.Owner
 ) MBytes
 FROM DBA_Indexes i
 JOIN (SELECT Index_Owner, Index_Name, COUNT(*) Columns
 FROM DBA_Ind_Columns
 GROUP BY Index_Owner, Index_Name
 HAVING COUNT(*) > :Min_Rows_per_Key
 ) ica ON ica.Index_Owner = i.Owner AND ica.Index_Name = i.Index_Name
 JOIN DBA_Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
 JOIN DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
 WHERE i.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'DBSNMP', 'WMSYS', 'CTXSYS', 'XDB')
 AND i.Index_Type NOT IN ('BITMAP')
 AND i.Num_Rows > :Min_Rows_per_Index
 AND i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct) > 10
 AND (i.Compression = 'DISABLED' OR i.Prefix_Length < ic.Column_Position)
 ) 
ORDER BY Column_Position, NVL(Avg_Col_Len, 5) * Num_Rows * Num_Rows/DECODE(Num_Distinct,0,1,Num_Distinct)/DECODE(Partitions, 0, 1, Partitions) DESC NULLS LAST

More comfortable you can this and many other dragnet selections from within my free app Panorama for Oracle performance analysis.

You may find more about Panorama at http://rammpeter.github.io/panorama.html
