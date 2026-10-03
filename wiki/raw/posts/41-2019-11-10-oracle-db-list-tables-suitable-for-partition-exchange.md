# Oracle-DB: List tables suitable for partition exchange

Datum: 2019-11-10
URL: https://rammpeter.blogspot.com/2019/11/oracle-db-list-tables-suitable-for.html
Labels: 

---

Partition Exchange requires a partitioned and a non-partitioned table with the same column and index structure. All indexes of the partitioned table have to be local partitioned.

The following SQL lists all combinations of structure-identical partitioned and non-partitioned tables that are suitable for partition exchange.

This information may be useful before changing the structure of tables or indexes to be informed about possible partition exchange operation and to prevent from crashing such operations.

WITH Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ tc.Owner, tc.Table_Name, COUNT(*) Columns, 
 SUM(ORA_HASH(tc.Data_Type) * tc.Column_ID * tc.Data_Length * 
 NVL(tc.Data_Precision,1) * 
 NVL(DECODE(tc.Data_Scale, 0, -1, tc.Data_Scale),1)) Structure_Hash
 FROM DBA_Tab_Columns tc
 JOIN DBA_Tables t ON t.Owner = tc.Owner AND t.Table_Name = tc.Table_Name /* exclude views */ 
 WHERE tc.Owner NOT IN ('SYS', 'SYSTEM')
 GROUP BY tc.Owner, tc.Table_Name
 ),
 Part_Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name, t.Partitioned
 FROM DBA_Tables t
 WHERE t.Partitioned = 'YES'
 AND t.Owner NOT IN ('SYS', 'SYSTEM')
 AND NOT EXISTS (SELECT 1 FROM DBA_Indexes i WHERE i.Table_Owner = t.Owner 
 AND i.Table_Name = t.Table_Name AND i.Partitioned = 'NO') 
 ), 
 Indexes as (SELECT /*+ NO_MERGE MATERIALIZE */ ic.Table_Owner, ic.Table_Name, 
 COUNT(DISTINCT ic.Index_Name) Indexes, COUNT(*) Ind_Columns,
 SUM(ic.Column_Position * ic.Column_Length ) Structure_Hash
 FROM DBA_Ind_Columns ic
 GROUP BY ic.Table_Owner, ic.Table_Name
 ), 
 Result_Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name, 
 t.Structure_Hash Table_Structure_Hash,
 i.Structure_Hash Index_Structure_Hash,
 t.Columns, i.Indexes, i.Ind_Columns,
 dt.Partitioned 
 FROM Tables t
 LEFT OUTER JOIN Part_Tables dt ON dt.Owner = t.Owner AND dt.Table_Name = t.Table_Name
 LEFT OUTER JOIN Indexes i ON i.Table_Owner = t.Owner AND i.Table_Name = t.Table_Name 
 ) 
SELECT t.Table_Structure_Hash, t.Index_Structure_Hash, t.Columns, t.Indexes, t.Ind_Columns,
 t.Owner NonPart_Owner, t.Table_Name NonPart_TableName,
 pt.Owner Part_Owner, pt.Table_Name Part_TableName 
FROM Result_Tables t
JOIN Result_Tables pt ON pt.Table_Structure_Hash = t.Table_Structure_Hash
 AND pt.Index_Structure_Hash = t.Index_Structure_Hash
 AND pt.Columns = t.Columns
 AND pt.Indexes = t.Indexes
 AND pt.Ind_Columns = t.Ind_Columns
WHERE t.Partitioned IS NULL
AND pt.Partitioned = 'YES'
ORDER BY pt.Owner, pt.Table_Name, t.Owner, t.Table_Name
;
