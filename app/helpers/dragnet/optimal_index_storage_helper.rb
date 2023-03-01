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
                      AND   Owner NOT IN (#{system_schema_subselect})
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
            :sql=> "\
WITH Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments WHERE Owner NOT IN (#{system_schema_subselect}) GROUP BY Owner, Segment_Name)
SELECT /* DB-Tools Ramm Komprimierung Indizes */  *
FROM (
            SELECT ROUND(i.Num_Rows/i.Distinct_Keys) Rows_Per_Key, i.Num_Rows, i.Owner, i.Index_Name, i.Index_Type, i.Table_Owner, i.Table_Name,
                   t.IOT_Type, seg.MBytes, Distinct_Keys,
            (SELECT SUM(tc.Avg_Col_Len)
             FROM   DBA_Ind_Columns ic,
                    DBA_Tab_Columns tc
             WHERE  ic.Index_Owner      = i.Owner
             AND    ic.Index_Name = i.Index_Name
             AND tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
            ) Avg_Col_Len
            FROM   DBA_Indexes i
            JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
            JOIN   Segments seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
            WHERE  i.Compression='DISABLED'
            AND    i.Distinct_Keys > 0
            AND    i.Table_Owner NOT IN (#{system_schema_subselect})
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
  For compressed index number of leaf blocks should decrease, in best case all references to data blocks of one key should fit into only one leaf block'),
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
            :name  => t(:dragnet_helper_130_name, :default=> 'Recommendations for index-compression, test by selectivity of single columns from multicolumn index'),
            :desc  => t(:dragnet_helper_130_desc, :default=> 'For multicolumn-indexes compression of single index columns (beginning from left) may be useful even if this multicolumn-index has overall Num_Rows=Distinct_Keys (selectivity=1).
Partial index-compression (COMPRESS x) assumes that index-column to be compressed has position 1 in index or all columns before are also compressed.
This selections shows recommendations for compression of single columns of multicolumn indexes beginning with column-position 1.'),
            :sql=> "WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Owner, Table_Name, Index_Name, Compression, Prefix_Length,
                                            Num_Rows, Last_Analyzed, Partitioned, Index_Type
                                     FROM   DBA_Indexes
                                     WHERE  Owner NOT IN (#{system_schema_subselect})
                                     AND    Index_Type NOT IN ('BITMAP')
                                     AND    Num_Rows > ?
                                    ),
                         Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Column_Name, Column_Position
                                         FROM   DBA_Ind_Columns
                                        ),
                         Tab_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_Name, Num_Distinct, Avg_Col_Len
                                         FROM   DBA_Tab_Columns
                                        ),
                         Grouped_Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, COUNT(*) Columns
                                                 FROM   Ind_Columns
                                                 GROUP BY Index_Owner, Index_Name
                                                 HAVING COUNT(*) > 1
                                                ),
                         Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                      FROM   DBA_Segments
                                      GROUP BY Owner, Segment_Name
                                     )
                    SELECT *
                    FROM   (
                            SELECT i.Owner, i.Table_Name, i.Index_Name, i.Index_Type \"Index Type\", i.Compression, i.Prefix_Length \"Prefix Length\",
                                   i.Num_Rows, i.Last_Analyzed \"Last Analyzed\", i.Partitioned \"Part.\",
                                   (SELECT COUNT(*)
                                    FROM   DBA_Ind_Partitions ip
                                    WHERE  ip.Index_Owner = i.Owner
                                    AND    ip.Index_Name = i.Index_Name
                                   ) Partitions,
                                   ica.Columns, ic.Column_Name, ic.Column_Position \"Column Pos.\",
                                   tc.Num_Distinct \"Num. Distinct\",
                                   tc.Avg_Col_Len   \"Avg Col Len\",
                                   ROUND(i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct)) \"Rows per Key\",
                                   seg.MBytes
                            FROM   Indexes i
                            JOIN   Grouped_Ind_Columns ica ON ica.Index_Owner = i.Owner AND ica.Index_Name = i.Index_Name
                            JOIN   Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                            JOIN   Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
                            JOIN   Segments  seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                            WHERE  i.Num_Rows/DECODE(tc.Num_Distinct,0,1,tc.Num_Distinct) > ?
                            AND    (i.Compression = 'DISABLED' OR i.Prefix_Length < ic.Column_Position)
                           )
                    ORDER BY \"Column Pos.\", NVL(\"Avg Col Len\", 5) * NVL(\"Avg Col Len\", 5) * Num_Rows * Num_Rows/CASE WHEN \"Num. Distinct\" > 0 AND \"Num. Distinct\" < 1000 THEN \"Num. Distinct\" ELSE 1000 END/DECODE(Partitions, 0, 1, Partitions) DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_130_param_1_name, :default=>'Min. number of rows of index'), :size=>10, :default=>1000000, :title=>t(:dragnet_helper_130_param_1_hint, :default=> 'Minimum number of rows of index to be considered in this selection') },
                         {:name=> 'Min. rows/key per column', :size=>8, :default=>10, :title=>t(:dragnet_helper_130_param_2_hint, :default=> 'Minimum number of index rows per DISTINCT Key of single index column') },
            ]
        },
        {
          :name  => t(:dragnet_helper_168_name, :default=> 'Recommendations for ADVANCED HIGH index compression'),
          :desc  => t(:dragnet_helper_168_desc, :default=>"Introduced with Oracle 12.2 the ADVANCED HIGH index compression as part of the Oracle Advanced Compression Option allows significant better compression than the other index key deduplication functions (COMPRESS, COMPRESS ADVANCED LOW).
But the drawback is that index maintenence is more costly and index access costs more CPU effort and can become up to five times slower, especially for index scans with larger results.
Therefore COMPRESS ADVANCED HIGH is especially suggested for less frequently used indexes on tables with less DML.
This selection considers indexes with < x seconds in wait at SQLs accessing this index worth for possible COMPRESS ADVANCED HIGH.
"),
          :sql=> "\
WITH Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                  FROM   DBA_Segments
                  WHERE  Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
                  GROUP BY Owner, Segment_Name
                 ),
     Ind_Columns AS (SELECT  /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Index_Owner, Index_Name, Column_Name
                     FROM    DBA_Ind_Columns i
                     WHERE   Index_Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
                    ),
     Tab_Columns AS (SELECT  /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_Name, Avg_Col_Len
                     FROM    DBA_Tab_Columns i
                     WHERE   Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
                    ),
     Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Num_Rows, Distinct_Keys, Index_Type, Compression
                 FROM   DBA_Indexes
                 WHERE  Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
                 AND    Index_Type NOT IN ('BITMAP')
                ),
     Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, IOT_Type
                FROM   DBA_Tables
                WHERE  Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
               ),
     ASH AS ( SELECT /*+ NO_MERGE MATERIALIZE */ o.Owner, o.Object_Name, SUM(h.Seconds_In_Wait) Seconds_In_Wait
              FROM   (
                      SELECT /*+ NO_MERGE */ Current_Obj#, SUM(10) Seconds_In_Wait
                      FROM   DBA_Hist_Active_Sess_History h
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, MIN(Sample_Time) Min_Sample_Time
                              FROM gv$Active_Session_History
                              GROUP BY Inst_ID
                             ) mh ON mh.Inst_ID = h.Instance_Number
                      WHERE  h.SQL_Plan_Operation = 'INDEX'
                      AND    h.Sample_Time > SYSDATE -?
                      AND    h.Sample_Time < mh.Min_Sample_Time
                      GROUP BY Current_Obj#
                      UNION ALL
                      SELECT /*+ NO_MERGE */ Current_Obj#, COUNT(*) Seconds_In_Wait
                      FROM   gv$Active_Session_History
                      GROUP BY Current_Obj#
                     ) h
              JOIN   DBA_Objects o ON o.Object_ID = h.Current_Obj#
              WHERE  o.Owner NOT IN (SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
              GROUP BY  o.Owner, o.Object_Name
             )
SELECT /* Advanced High Compression Suggestions */ i.Owner, i.Index_Name, i.Index_Type, i.Compression, i.Table_Owner, i.Table_Name,
       ash.Seconds_In_Wait, t.IOT_Type, seg.MBytes, i.Num_Rows, Distinct_Keys, ROUND(i.Num_Rows/DECODE(i.Distinct_Keys,0,1,i.Distinct_Keys)) Rows_Per_Key, cs.Avg_Col_Len
FROM   Indexes i
JOIN   Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
JOIN   Segments seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
JOIN   (SELECT /*+ NO_MERGE */ ic.Index_Owner, ic.Index_Name, SUM(tc.Avg_Col_Len) Avg_Col_Len
        FROM   Ind_Columns ic
        JOIN   Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
        GROUP BY ic.Index_Owner, ic.Index_Name
       ) cs ON cs.Index_Owner = i.Owner AND cs.Index_Name = i.Index_Name
LEFT OUTER JOIN ash ON ash.Owner = i.Owner AND ash.Object_Name = i.Index_Name
WHERE  i.Compression != 'ADVANCED HIGH'
AND    NVL(ash.Seconds_In_Wait, 0) < ?
AND    seg.MBytes > ?
ORDER BY seg.MBytes DESC NULLS LAST
          ",
          :parameter=>[
            {name: t(:dragnet_helper_168_param_1_name, default: 'Number of last days in ASH to consider') , size: 8, default: 8, title: t(:dragnet_helper_168_param_1_hint, default: 'Number of last days in Active Session History to consider for calculation of seconds in wait for that index') },
            {name: t(:dragnet_helper_168_param_3_name, default: 'Maximum seconds in wait for index') , size: 8, default: 100, title: t(:dragnet_helper_168_param_3_hint, default: 'Maximum number of seconds Active Session History has recorded in the considered period as session activity on index') },
            {name: t(:dragnet_helper_168_param_2_name, default: 'Minimum size of index in MB to be considered') , size: 1, default: 8, title: t(:dragnet_helper_168_param_2_hint, default: 'Minimum size of index in MB to be considered in this selection') },
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
                      AND   Owner NOT IN (#{system_schema_subselect})
                      --AND   Anzahl_PKey_Columns>0 /* Wenn Fehlen des PKeys nicht in Frage gestellt werden darf */
                      ORDER BY 1/Num_Rows*(Anzahl_Columns-Anzahl_PKey_Columns+1)*Anzahl_Indizes",
            :parameter=>[{:name=> 'Min. number of rows', :size=>8, :default=>100000, :title=>t(:dragnet_helper_4_param_1_hint, :default=> 'Minimum number of rows of index') },]
        },
    ]
  end # optimal_index_storage

end
