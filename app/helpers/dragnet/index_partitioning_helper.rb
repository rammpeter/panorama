# encoding: utf-8
module Dragnet::IndexPartitioningHelper

  private

  def index_partitioning
    [
        {
            :name  => t(:dragnet_helper_11_name, :default=> 'Local-partitioning for NonUnique-indexes'),
            :desc  => t(:dragnet_helper_11_desc, :default=> 'Indexes of partitioned tables may be equal partitioned (LOCAL), especially if partitioning physically isolates different data content of table.
Partitioning of indexes may also reduce BLevel of index.
For unique indexes this is only true if partition key is equal with first column(s) of index.
Negative aspect is multiple access on every partition of index if partition key is not the same like indexed column(s) and partition key is not part of WHERE-filter.'),
            :sql=> "SELECT /* DB-Tools Local-Partitionierung*/
                             i.Owner, i.Table_Name, i.Index_Name,
                             i.Num_Rows , i.Distinct_Keys
                      FROM   DBA_Indexes i,
                             DBA_Tables t
                      WHERE  t.Owner      = i.Table_Owner
                      AND    t.Table_Name = i.Table_Name
                      AND    i.Partitioned = 'NO'
                      AND    t.Partitioned = 'YES'
                      AND    i.UniqueNess  = 'NONUNIQUE'
                      AND NOT EXISTS (
                             SELECT '!' FROM DBA_Constraints r
                             WHERE  r.Owner       = t.Owner
                             AND    r.Table_Name  = t.Table_Name
                             AND    r.Constraint_Type = 'U'
                             AND    r.Index_Name  = i.Index_Name
                             )
                      ORDER BY i.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_12_name, :default=> 'Local-partitioning of unique indexes with partition-key = index-column'),
            :desc  => t(:dragnet_helper_12_desc, :default=>"Also unique indexes may be local partitioned if partition key is in identical order leading part of index.
This way partition pruning may be used for access on unique indexes plus possible decrease of index' BLevel."),
            :sql=> "SELECT /* DB-Tools Ramm Partitionierung Unique Indizes */
                              t.Owner, t.Table_Name, i.Uniqueness, tc.Column_Name Partition_Key1, i.Index_Name, t.Num_Rows,
                              (SELECT  ROUND(SUM(bytes)/(1024*1024),1) MBytes
                               FROM   DBA_SEGMENTS s
                               WHERE s.SEGMENT_NAME = i.Index_Name
                               AND     s.Owner      = i.Owner
                              ) MBytes
                      FROM   DBA_Tables t
                             JOIN DBA_Part_Key_Columns tc
                             ON (    tc.Owner           = t.Owner
                                 AND tc.Name            = t.Table_Name
                                 AND tc.Object_Type     = 'TABLE'
                                 AND tc.Column_Position = 1
                                 /* Nur erste Spalte prüfen, danach manuell */
                                )
                             JOIN DBA_Ind_Columns ic
                             ON (    ic.Table_Owner     = t.Owner
                                 AND ic.Table_Name      = t.Table_Name
                                 AND ic.Column_Name     = tc.Column_Name
                                 AND ic.Column_Position = 1
                                )
                             JOIN DBA_Indexes i
                             ON (    i.Owner            = ic.Index_Owner
                                 AND i.Index_Name       = ic.Index_Name
                                )
                      WHERE t.Partitioned = 'YES'
                      AND   i.Partitioned = 'NO'
                      ORDER BY t.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_13_name, :default=> 'Local-partitioning with overhead in access'),
            :desc  => t(:dragnet_helper_13_desc, :default=> 'Local partitioning by not indexed columns leads to iterative access on all partitions of index during range scan or unique scan.
For frequently used indexes with high partition count this may result in unnecessary high access on database buffers.
Solution for such situations is global (not) partitioning of index.'),
            :sql=> "SELECT /* DB-Tools Ramm: mehrfach frequentierte Hash-Partitions */ i.Owner, i.Index_Name, i.Index_Type,
                             i.Table_Name, pl.Executions, pl.Rows_Processed, i.Num_Rows,
                             p.Partitioning_Type, c.Column_Position, c.Column_Name Part_Col, ic.Column_Name Ind_Col,
                             i.UniqueNess, i.Compression, i.BLevel, i.Distinct_Keys, i.Avg_Leaf_Blocks_per_Key,
                             i.Avg_Data_blocks_Per_Key, i.Clustering_factor, p.Partition_Count, p.Locality
                      FROM   DBA_Indexes i
                      JOIN   DBA_Part_Indexes p     ON p.Owner=i.Owner AND p.Index_Name=i.Index_Name
                      JOIN   DBA_Part_Key_Columns c ON c.Owner=i.Owner AND c.Name=i.Index_Name AND c.Object_Type='INDEX'
                      JOIN   DBA_Ind_columns ic     ON ic.Index_Owner=i.Owner AND ic.Index_Name=i.Index_Name AND ic.Column_Position = c.Column_Position
                      LEFT OUTER JOIN   (
                                          SELECT /*+ NO_MERGE */
                                                 p.Object_Owner, p.Object_Name, SUM(s.Executions) Executions,
                                                 SUM(s.Rows_Processed) Rows_Processed
                                          FROM   gv$SQL_Plan p
                                          JOIN   gv$SQL s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID
                                          WHERE  Object_Type LIKE 'INDEX%'
                                          AND    Options IN ('UNIQUE SCAN', 'RANGE SCAN', 'RANGE SCAN (MIN/MAX)')
                                          GROUP BY p.Object_Owner, p.Object_Name
                                        ) pl ON pl.Object_Owner = i.Owner AND pl.Object_Name = i.Index_Name
                      WHERE  p.Partitioning_Type = 'HASH'
                      AND    c.Column_Name != ic.Column_Name
                      ORDER BY pl.Rows_Processed DESC NULLS LAST, pl.Executions DESC NULLS LAST, i.Num_Rows DESC NULLS LAST",
        },

    ]
  end # index_partitioning


end

