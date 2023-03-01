# encoding: utf-8
module Dragnet::UnnecessaryIndexColumnsHelper

  private

  def unnecessary_index_columns
    [
      {
        :name  => t(:dragnet_helper_10_name, :default=> 'Detection of indexes with unnecessary columns because of pure selectivity'),
        :desc  => t(:dragnet_helper_10_desc, :default=>"For multi-column indexes with high selectivity of single columns often additional columns in index don't  improve selectivity of that index.
Additional columns with low selectivity are useful only if:
- they essentially improve selectivity of whole index
- they allow index-only data access without accessing table itself
Without these reasons additional columns with low selectivity may be removed from index.
This selection already suppresses indexes used for elimination of 'table access by rowid'."),
        :sql=> "\
SELECT /* DB-Tools Ramm: low selectivity */ *
FROM
       (
        SELECT /*+ NO_MERGE USE_HASH(i ms io) */
               i.Owner, i.Table_Name, i.Index_Name, i.Num_Rows,
               seg.MBytes \"MBytes\",
               ms.Column_Name \"Max. selective column\", ms.Max_Num_Distinct,
               ROUND(ms.Max_Num_Distinct / i.Num_Rows, 2) \"Max. selectivity\",
               tc.Column_Name \"Min. selective column\", tc.Num_Distinct \"Min. num. distinct\"
        FROM   DBA_Indexes i
        JOIN   (SELECT /*+ NO_MERGE USE_HASH(ic tc ) */ /* Max. Selektivit‰t einer Spalte eines Index */
                       ic.Index_Owner, ic.Index_Name, MAX(tc.Num_Distinct) Max_Num_Distinct,
                       MAX(ic.Column_Name) KEEP (DENSE_RANK LAST ORDER BY tc.Num_Distinct) Column_Name
                FROM   (SELECT /*+ NO_MERGE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_Name FROM DBA_Ind_Columns) ic
                JOIN   (SELECT /*+ NO_MERGE */ Owner, Table_Name, Column_Name, Num_Distinct FROM DBA_Tab_Columns
                       ) tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                GROUP BY ic.Index_Owner, ic.Index_Name
               ) ms ON ms.Index_Owner = i.Owner AND ms.Index_Name = i.Index_Name
        JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
        JOIN   DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ /* SQL mit Zugriff auf Index ohne Zugriff auf Table existieren */ i.Owner, i.Index_Name
                         FROM   DBA_Indexes i
                         JOIN   GV$SQL_Plan p1 ON p1.Object_Owner = i.Owner AND p1.Object_Name = i.Index_Name
                         LEFT OUTER JOIN   GV$SQL_Plan p2 ON p2.Inst_ID = p1.Inst_ID AND p2.SQL_ID = p1.SQL_ID AND p2.Plan_Hash_Value = p1.Plan_Hash_Value
                                                          AND p2.Object_Owner = i.Table_Owner AND p2.Object_Name = i.Table_Name
                         WHERE p2.Inst_ID IS NULL AND P2.SQL_ID IS NULL AND p2.Plan_Hash_Value IS NULL
                         AND   i.UniqueNess = 'NONUNIQUE'
                         GROUP BY i.Owner, i.Index_Name
                        ) io ON io.Owner = i.Owner AND io.Index_Name = i.Index_Name
        LEFT OUTER JOIN (SELECT Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                        ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
        WHERE  i.Num_Rows IS NOT NULL AND i.Num_Rows > 0
        AND    ms.Max_Num_Distinct > i.Num_Rows/?   -- Ein Feld mit gen∏gend groﬂer Selektivit‰t existiert im Index
        AND    tc.Column_Name != ms.Column_Name     -- Spalte mit hoechster Selektivit‰t ausblenden
        AND    i.UniqueNess = 'NONUNIQUE'
        AND    io.Owner IS NULL AND io.Index_Name IS NULL -- keine Zugriffe, bei denen alle Felder aus Index kommen und kein TableAccess nˆtig wird
       ) o
WHERE  o.Owner NOT IN (#{system_schema_subselect})
AND    Num_Rows > ?
ORDER BY Max_Num_Distinct / Num_Rows DESC NULLS LAST",
        :parameter=>[{:name=>t(:dragnet_helper_10_param_1_name, :default=>'Largest selectivity of a column of index > 1/x to the number of rows'), :size=>8, :default=>4, :title=>t(:dragnet_helper_10_param_1_hint, :default=>'Number of DISTINCT-values of index column with largest selectivity is > 1/x to the number of rows on index')},
                     {:name=>t(:dragnet_helper_10_param_2_name, :default=>'Minimum number of rows of index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_10_param_2_hint, :default=>'Minimum number of rows of index for consideration in selection')}
        ]
      },
      {
        :name  => t(:dragnet_helper_163_name, :default=> 'Possibly unnecessary columns of indexes that are also partition keys'),
        :desc  => t(:dragnet_helper_163_name, :default=>"If partition keys are unique or selective enough for efficient partition pruning, than where is often no need to hold this columns in index in addition.
Partition pruning e.g. for list partitions is more efficient than B-tree access in index.
Removal of this columns from index reduces size of index and also effort for index scan.
Exception: For unique indexes this columns have to be part of index nethertheless.
"),
        :sql=> "\
SELECT i.Table_Owner, i.Table_Name, i.Owner, i.Index_Name, s.MBytes, i.Num_Rows, pc.Column_Name,
       pc.Column_Position Part_Col_Position, ic.Column_Position Ind_Col_Position, pc.Part_Type,
       pi.Partitioning_Type, pi.SubPartitioning_Type
FROM   DBA_Indexes i
JOIN   (SELECT Owner, Name, Object_Type, Column_Name, Column_Position, 'Partition' Part_Type FROM DBA_Part_Key_Columns
        UNION ALL
        SELECT Owner, Name, Object_Type, Column_Name, Column_Position, 'Sub-Partition' Part_Type FROM DBA_SubPart_Key_Columns
       ) pc ON pc.Owner = i.Owner AND pc.Name = i.Index_Name AND pc.Object_Type = 'INDEX'
JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name AND ic.Column_Name = pc.Column_Name
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                 FROM   DBA_Segments
                 WHERE  Segment_type IN ('INDEX PARTITION', 'INDEX SUBPARTITION')
                 GROUP BY Owner, Segment_Name
                ) s ON s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
LEFT OUTER JOIN DBA_Part_Indexes pi ON pi.Owner = i.Owner AND pi.Index_Name = i.Index_Name
WHERE  i.Partitioned = 'YES'
AND    i.Uniqueness != 'UNIQUE'
AND    i.Index_Type != 'IOT - TOP'
AND    i.Owner NOT IN (#{system_schema_subselect})
ORDER BY NVL(s.MBytes, i.Num_Rows) DESC NULLS LAST, ic.Column_Position
"
      },

    ]
  end # unnecessary_index_columns


end