# encoding: utf-8
module Dragnet::OptimalIndexStorageHelper

  private
  def optimal_index_storage
    [
        {
            :name  => t(:dragnet_helper_1_name, :default=> 'Ensure PCTFree >= 10'),
            :desc  => t(:dragnet_helper_1_desc, :default=> 'Ensure that indexes are used with PCTFree >= 10 (minimum from my experience).
  With PCTFree < 10 (especially = 0) problems with automatic balancing are expected, especially during insert of sorted data'),
            :sql=> "SELECT /* DB-Tools Ramm Index-PCTFree */* FROM (
                          SELECT Owner, Table_Name, Index_Name, NULL Partition_Name, PCT_Free, Num_Rows
                          FROM DBA_Indexes
                          WHERE PCT_FREE < ?
                          UNION ALL
                          SELECT Index_Owner Owner,
                                 (SELECT Table_Name FROM DBA_Indexes i WHERE i.Owner=p.Index_Owner AND i.Index_Name=p.Index_Name
                                 ) Table_Name,
                                 Index_Name, Partition_Name, PCT_Free, Num_Rows
                          FROM   DBA_Ind_Partitions p
                          WHERE  PCT_FREE < ?
                          )
                      WHERE Num_Rows > ?
                      AND   Owner NOT IN ('SYS', 'SYSTEM', 'SYSMAN')
                      ORDER BY Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_1_param_1_name, :default=> 'Threshold for pctfree of index'), :size=>8, :default=>10, :title=>t(:dragnet_helper_1_param_1_hint, :default=> 'Selection of indexes underrunning this value for PctFree')},
                         {:name=>t(:dragnet_helper_1_param_2_name, :default=> 'Threshold for pctfree of index partition'), :size=>8, :default=>10, :title=>t(:dragnet_helper_1_param_2_hint, :default=> 'Selection of index partitions underrunning this value for PctFree') },
                         {:name=>t(:dragnet_helper_1_param_3_name, :default=> 'Minumum number of rows'), :size=>15, :default=>100000, :title=>t(:dragnet_helper_1_param_3_hint, :default=> 'Minimum number of rows for index') },
            ]
        },
        {
            :name  => t(:dragnet_helper_2_name, :default=> 'Recommendations for index-compression, test by selectivity'),
            :desc  => t(:dragnet_helper_2_desc, :default=> 'Index-compression (COMPRESS) is usefull by reduction of physical footprint for OLTP-indexes with poor selectivity (column level).
  For poor selective indexes reduction of size by 1/4 to 1/3 is possible.'),
            :sql=> "SELECT /* DB-Tools Ramm Komprimierung Indizes */  *
                      FROM (
                                  SELECT ROUND(i.Num_Rows/i.Distinct_Keys) Rows_Per_Key, i.Num_Rows, i.Owner, i.Index_Name, i.Index_Type, i.Table_Owner, i.Table_Name,
                                         t.IOT_Type,
                                  (   SELECT  ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                       FROM   DBA_SEGMENTS s
                                       WHERE s.SEGMENT_NAME = i.Index_Name
                                       AND     s.Owner                = i.Owner
                                  ) MBytes, Distinct_Keys,
                                  (SELECT SUM(tc.Avg_Col_Len)
                                   FROM   DBA_Ind_Columns ic,
                                          DBA_Tab_Columns tc
                                   WHERE  ic.Index_Owner      = i.Owner
                                   AND    ic.Index_Name = i.Index_Name
                                   AND tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
                                  ) Avg_Col_Len
                                  FROM   DBA_Indexes i
                                  JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                                  WHERE  i.Compression='DISABLED'
                                  AND    i.Distinct_Keys > 0
                                  AND    i.Table_Owner NOT IN ('SYS')
                                  AND i.Num_Rows/DECODE(i.Distinct_Keys,0,1,i.Distinct_Keys) > ?
                                ) i
                      WHERE MBytes > ?
                      AND   Index_Type NOT IN ('BITMAP')
                      ORDER BY NVL(Avg_Col_Len, 5) * Num_Rows * Num_Rows/Distinct_Keys DESC NULLS LAST",
            :parameter=>[{:name=> 'Min. rows/key', :size=>8, :default=>10, :title=>t(:dragnet_helper_2_param_1_hint, :default=> 'Minimum number of index rows per DISTINCT Key') },
                         {:name=>t(:dragnet_helper_2_param_2_name, :default=> 'Threshold for index size (MB)'), :size=>8, :default=>10, :title=>t(:dragnet_helper_2_param_2_hint, :default=> 'Selection of indexes excessing given size limit in MB') },
            ]
        },
        {
            :name  => t(:dragnet_helper_3_name, :default=> 'Recommendations for index-compression, test by leaf-block count'),
            :desc  => t(:dragnet_helper_3_desc, :default=> 'Index-compression (COMPRESS) allows reduction of physical size for OLTP-indexes with low selectivity.
  For indexes with low selectivity reduction of index-size by compression can be 1/4 to 1/3.
  For compressed index for one indexed value all links to data blocks should normally fit into one leaf block'),
            :sql=> "SELECT /* DB-Tools Ramm Komprimierung Indizes */ i.Owner \"Owner\", i.Table_Name, Index_Name, Index_Type, BLevel, Distinct_Keys,
                             ROUND(i.Num_Rows/i.Distinct_Keys) Rows_Per_Key,
                             Avg_Leaf_Blocks_Per_Key, Avg_Data_Blocks_Per_Key, i.Num_Rows, t.IOT_Type
                      FROM   DBA_Indexes i
                      JOIN   DBA_Tables t ON t.Owner=i.Table_Owner AND t.Table_Name=i.Table_Name
                      WHERE  Avg_Leaf_Blocks_Per_Key > ?
                      AND    i.Compression = 'DISABLED'
                      ORDER BY Avg_Leaf_Blocks_Per_Key*Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=> 'Min. Leaf-Blocks/Key', :size=>8, :default=>1, :title=>t(:dragnet_helper_3_param_1_hint, :default=> 'Minimum number of leaf-blocks / key') },
            ]
        },
        {
            :name  => t(:dragnet_helper_2_name, :default=> 'Recommendations for index-compression, test by selectivity of single columns from multicolumn index'),
            :desc  => t(:dragnet_helper_2_desc, :default=> 'For multicolumn-indexes compression of single index columns (beginning from left) may be useful even if this multicolumn-index has overall Num_Rows=Distinct_Keys (selectivity=1).
Partial index-compression (COMPRESS x) assumes that index-column to be compressed has position 1 in index or all columns before are also compressed.
This selections shows recommendations for compression of single columns of multicolumn indexes beginning with column-position 1.'),
            :sql=> "SELECT *
                    FROM   (
                            SELECT i.Owner, i.Table_Name, i.Index_Name, i.Index_Type, i.Compression, i.Prefix_Length, i.Num_Rows, i.Last_Analyzed, i.Partitioned,
                                   (SELECT COUNT(*)
                                    FROM   DBA_Ind_Partitions ip
                                    WHERE  ip.Index_Owner = i.Owner
                                    AND    ip.Index_Name = i.Index_Name
                                   ) Partitions,
                                   ica.Columns, ic.Column_Name, ic.Column_Position,
                                   tc.Num_Distinct, tc.Avg_Col_Len, ROUND(i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct)) Rows_per_Key,
                                   (SELECT  ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                    FROM   DBA_SEGMENTS s
                                    WHERE s.SEGMENT_NAME = i.Index_Name
                                    AND     s.Owner      = i.Owner
                                   ) MBytes
                            FROM   DBA_Indexes i
                            JOIN   (SELECT Index_Owner, Index_Name, COUNT(*) Columns
                                    FROM   DBA_Ind_Columns
                                    GROUP BY Index_Owner, Index_Name
                                    HAVING COUNT(*) > 1
                                   ) ica ON ica.Index_Owner = i.Owner AND ica.Index_Name = i.Index_Name
                            JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                            JOIN   DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
                            WHERE  i.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'DBSNMP', 'WMSYS', 'CTXSYS', 'XDB')
                            AND    i.Index_Type NOT IN ('BITMAP')
                            AND    i.Num_Rows > ?
                            AND    i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct) > ?
                            AND    (i.Compression = 'DISABLED' OR i.Prefix_Length < ic.Column_Position)
                           )
                    ORDER BY Column_Position, NVL(Avg_Col_Len, 5) * NVL(Avg_Col_Len, 5) * Num_Rows * Num_Rows/DECODE(Num_Distinct,0,1,Num_Distinct)/DECODE(Partitions, 0, 1, Partitions) DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_130_param_1_name, :default=>'Min. number of rows of index'), :size=>10, :default=>1000000, :title=>t(:dragnet_helper_130_param_1_hint, :default=> 'Minimum number of rows of index to be considered in this selection') },
                         {:name=> 'Min. rows/key per column', :size=>8, :default=>10, :title=>t(:dragnet_helper_130_param_2_hint, :default=> 'Minimum number of index rows per DISTINCT Key of single index column') },
            ]
        },
        {
            :name  => t(:dragnet_helper_4_name, :default=> 'Avoid data redundancy in primary key index (move to index-organized tables)'),
            :desc  => t(:dragnet_helper_4_desc, :default=>"IOT-structure for tables is recommended if following criterias outbalance to positive side:
  Positive: Saving of disk space and buffer cache space due to omission of table itself
  Positive: Omission of 'table-access by row-id' while accessing data by index, because PKey-index already contains all table data
  Negative: Enlargement of secondary indexes because of redundant saving of PKey-values in every secondary index
  Negative: Enlargement of primary key because it contains whole table data"),
            :sql=> "SELECT /* DB-Tools Ramm IOT-Empfehlung */ *
                      FROM   (
                              SELECT
                                     (SELECT Count(*) FROM DBA_Tab_Columns c WHERE c.Owner=t.Owner AND c.Table_Name=t.Table_Name) Anzahl_Columns,
                                     (SELECT Count(*) FROM DBA_Indexes i WHERE i.Owner=t.Owner AND i.Table_Name=t.Table_Name) Anzahl_Indizes,
                                     (SELECT Count(*) FROM DBA_Indexes i WHERE i.Owner=t.Owner AND i.Table_Name=t.Table_Name AND i.Uniqueness='UNIQUE') Anzahl_Unique_Indizes,
                                     (SELECT Count(*)
                                      FROM DBA_Constraints ac, DBA_Ind_Columns aic
                                      WHERE ac.Owner = t.Owner
                                      AND   ac.Table_Name = t.Table_Name
                                      AND   Constraint_Type='P'
                                      AND   aic.Index_Owner = ac.Owner
                                      AND   aic.Index_Name = ac.Index_Name
                                     ) Anzahl_PKey_Columns,
                                     t.Owner, t.Table_Name,
                                     t.Num_Rows,
                                     t.Avg_Row_Len
                              FROM   DBA_Tables t
                              WHERE  t.IOT_Type Is NULL
                              AND    t.Num_Rows Is NOT NULL AND t.Num_Rows>0 /* nur analysierte Tabellen betrachten */
                              AND    (SELECT Count(*) FROM DBA_Tab_Columns c WHERE c.Owner=t.Owner AND c.Table_Name=t.Table_Name)<6
                             )
                      WHERE Anzahl_Unique_Indizes > 0
                      AND   Num_Rows > ?
                      AND   Owner NOT IN ('SYS')
                      --AND   Anzahl_PKey_Columns>0 /* Wenn Fehlen des PKeys nicht in Frage gestellt werden darf */
                      ORDER BY 1/Num_Rows*(Anzahl_Columns-Anzahl_PKey_Columns+1)*Anzahl_Indizes",
            :parameter=>[{:name=> 'Min. number of rows', :size=>8, :default=>100000, :title=>t(:dragnet_helper_4_param_1_hint, :default=> 'Minimum number of rows of index') },]
        },

    ]
  end # optimal_index_storage

end
