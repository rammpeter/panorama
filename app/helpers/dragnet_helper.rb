# encoding: utf-8
module DragnetHelper
  # Liste der Rasterfahndungs-SQL



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
            :name  => t(:dragnet_helper_2_name, :default=> 'Test for recommendable index-compression'),
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

  def unnecessary_indexes
    [
        {
            :name  => t(:dragnet_helper_7_name, :default=> 'Detection of indexes not used for access or ensurance of uniqueness'),
            :desc  => t(:dragnet_helper_7_desc, :default=>"Necessity of  existence of indexes may be put into question if these indexes are not used for uniqueness or access optimization.
However the index may be useful for coverage of foreign key constraints, even if there had been no usage of index in considered time range.
Ultimate knowledge about usage of index may be gained by tagging index with 'ALTER INDEX ... MONITORING USAGE' and monitoring usage via V$OBJECT_USAGE.
Additional info about usage of index can be gained by querying DBA_Hist_Seg_Stat or DBA_Hist_Active_Sess_History."),
            :sql=> "SELECT /* DB-Tools Ramm nicht genutzte Indizes */ * FROM (
                    SELECT (SELECT SUM(bytes)/(1024*1024) MBytes FROM DBA_SEGMENTS s WHERE s.SEGMENT_NAME = i.Index_Name AND s.Owner = i.Owner) MBytes,
                                i.Num_Rows, i.Owner, i.Index_Name, i.Index_Type, i.Tablespace_Name, i.Table_Owner, i.Table_Name, i.UniqueNess, i.Distinct_Keys,
                                (SELECT Column_Name FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name AND Column_Position=1) Column_1,
                                (SELECT Column_Name FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name AND Column_Position=2) Column_2,
                                (SELECT Count(*) FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name) Anzahl_Columns,
                                (SELECT MIN(f.Constraint_Name||' Table='||rf.Table_Name)
                                 FROM   DBA_Constraints f
                                 JOIN   DBA_Cons_Columns fc ON fc.Owner = f.Owner AND fc.Constraint_Name = f.Constraint_Name AND fc.Position=1
                                 JOIN   DBA_Ind_Columns ic ON ic.Column_Name=fc.Column_Name AND ic.Column_Position=1
                                 JOIN   DBA_Constraints rf ON rf.Owner=f.r_Owner AND rf.Constraint_Name=f.r_Constraint_Name
                                 WHERE  f.Owner = i.Table_Owner
                                 AND    f.Table_Name = i.Table_Name
                                 AND    f.Constraint_Type = 'R'
                                 AND    ic.Index_Owner=i.Owner AND  ic.Index_Name=i.Index_Name
                                ) Ref_Constraint
                    FROM   (SELECT /*+ NO_MERGE */ i.*
                            FROM   DBA_Indexes i
                            LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT p.Object_Owner, p.Object_Name
                                             FROM   gV$SQL_Plan p
                                             JOIN   gv$SQL t ON t.Inst_ID=p.Inst_ID AND t.SQL_ID=p.SQL_ID
                                             WHERE  t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                            ) p ON p.Object_Owner=i.Owner AND p.Object_Name=i.Index_Name
                            LEFT OUTER JOIN (SELECT /*+ NO_MERGE PARALLEL(p,2) PARALLEL(s,2) PARALLEL(ss,2) PARALLEL(t,2) */ DISTINCT p.Object_Owner, p.Object_Name
                                             FROM   DBA_Hist_SQL_Plan p
                                             JOIN   DBA_Hist_SQLStat s
                                                    ON  s.DBID            = p.DBID
                                                    AND s.SQL_ID          = p.SQL_ID
                                                    AND s.Plan_Hash_Value = p.Plan_Hash_Value
                                             JOIN   DBA_Hist_SnapShot ss
                                                    ON  ss.DBID      = s.DBID
                                                    AND ss.Snap_ID = s.Snap_ID
                                                    AND ss.Instance_Number = s.Instance_Number
                                             JOIN   (SELECT /*+ NO_MERGE PARALLEL(t,2) */ t.DBID, t.SQL_ID
                                                     FROM   DBA_Hist_SQLText t
                                                     WHERE  t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                                    ) t
                                                    ON  t.DBID   = p.DBID
                                                    AND t.SQL_ID = p.SQL_ID
                                             WHERE  ss.Begin_Interval_Time > SYSDATE-?
                                            ) hp ON hp.Object_Owner=i.Owner AND hp.Object_Name=i.Index_Name
                            WHERE   p.OBJECT_OWNER IS NULL AND p.Object_Name IS NULL  -- keine Treffer im Outer Join
                            AND     hp.OBJECT_OWNER IS NULL AND hp.Object_Name IS NULL  -- keine Treffer im Outer Join
                            AND     i.Owner NOT IN ('SYS', 'OUTLN', 'SYSTEM', 'WMSYS', 'SYSMAN', 'XDB')
                            AND     i.UNiqueness != 'UNIQUE'
                           ) i
                    ) ORDER BY MBytes DESC NULLS LAST, Num_Rows",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_14_name, :default=> 'Detection of indexes with only one ore little key values in index'),
            :desc  => t(:dragnet_helper_14_desc, :default=> 'Indexes with only one or little key values may be unnecessary.
                       Exception: Indexes with only one key value may be usefull for differentiation between NULL and NOT NULL.
                       Indexes with only one key value and no NULLs in indexed columns my be definitely removed.
                       If used for ensurance of foreign keys you can often relinquish on these index because resulting FullTableScan on referencing table
                       in case of delete on referenced table may be accepted.'),
            :sql=> "SELECT /* DB-Tools Ramm Sinnlose Indizes */ i.Owner \"Owner\", i.Table_Name, Index_Name, Index_Type, BLevel, Distinct_Keys,
                            ROUND(i.Num_Rows/i.Distinct_Keys) \"Rows per Key\",
                            i.Num_Rows \"Rows Index\", t.Num_Rows \"Rows Table\", t.Num_Rows-i.Num_Rows \"Possible NULLs\", t.IOT_Type,
                            (SELECT  /*+ NO_MERGE */ ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                     FROM   DBA_SEGMENTS s
                             WHERE s.SEGMENT_NAME = i.Index_Name
                             AND     s.Owner                = i.Owner
                            ) MBytes,
                            (SELECT CASE WHEN SUM(DECODE(Nullable, 'N', 1, 0)) = COUNT(*) THEN 'NOT NULL' ELSE 'NULLABLE' END
                             FROM DBA_Ind_Columns ic
                             JOIN DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                             WHERE  ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                            ) Nullable
                     FROM   DBA_Indexes i
                     JOIN   DBA_Tables t ON t.Owner=i.Table_Owner AND t.Table_Name=i.Table_Name
                     WHERE   i.Num_Rows > ?
                     AND     i.Distinct_Keys<=?
                     ORDER BY i.Num_Rows*t.Num_Rows DESC NULLS LAST
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_14_param_1_name, :default=> 'Min. number of rows in index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_14_param_1_hint, :default=> 'Minimum number of rows in considered index') },
                         {:name=>t(:dragnet_helper_14_param_2_name, :default=> 'Max. number of key values in index'), :size=>8, :default=>1, :title=>t(:dragnet_helper_14_param_2_hint, :default=> 'Maximum number of key values in considered index') }
            ]
        },
        {
            :name  => t(:dragnet_helper_8_name, :default=> 'Detection of indexes with multiple indexed columns'),
            :desc  => t(:dragnet_helper_8_desc, :default=> 'Multiple indexed columns are useful for data access only if additional index-columns improve selectivity of index.
             Indexing on column that is already indexed as first column of another multi-column index is often unnecessary, e.g. for coverage of foreign key.
             Otherwise multiple indexing same column in different composite indexes may be used for optimization of joins or for access on table data without accessing table itself.'),
            :sql=> "SELECT /* DB-Tools Ramm doppelt indizierte Spalten*/ d.*, i.Index_Name, ix.Num_Rows,
                                   (
                                                      SELECT Constraint_Name
                                                      FROM   DBA_Constraints c
                                                      WHERE  c.Table_Name  = d.Table_Name
                                                      AND      c.Owner  = ix.Owner
                                                      AND      c.Index_Name    = ix.Index_Name
                                                      AND      c.Constraint_Type='P'
                                   )  UsedForPKey,
                                   (SELECT SUM(bytes)/(1024*1024) MBytes
                                    FROM   DBA_SEGMENTS s
                                    WHERE  s.SEGMENT_NAME = ix.Index_Name
                                    AND    s.Owner        = ix.Owner
                                  ) MBytes
                      FROM   (
                                      SELECT Table_Owner, Table_Name, Column_Name
                                      FROM DBA_Ind_columns
                                      WHERE Column_Position=1
                                      GROUP BY Table_Owner, Table_Name, Column_Name
                                      HAVING Count(*) > 1
                                     ) d,
                                     DBA_Ind_Columns i,
                                     DBA_Indexes ix
                      WHERE    i. Table_Owner  = d.Table_Owner
                      AND         i.Table_Name    = d.Table_Name
                      AND         i.Column_Name = d.Column_Name
                      AND         i.Column_Position = 1
                      AND         NOT EXISTS (SELECT '!' FROM DBA_Ind_Columns ii
                                                           WHERE ii. Table_Owner  = d.Table_Owner
                                                           AND     ii.Table_Name     = d.Table_Name
                                                           AND     ii.Index_Name      = i.Index_Name
                                                           AND     ii.Column_Position= 2
                                                          )
                      AND        ix.Table_Owner = d.Table_Owner
                      AND        ix.Table_Name   = d.Table_Name
                      AND        ix.Index_Name   = i.Index_Name
                      AND        ix.Num_Rows > ?
                      AND        d.Table_Owner NOT IN ('SYSMAN','SYS', 'XDB', 'SYSTEM')
                      ORDER BY ix.Num_Rows DESC NULLS LAST
                      ",
            :parameter=>[{:name=> t(:dragnet_helper_8_param_1_name, :default=>'Minmum number of rows for index'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_8_param_1_hint, :default=>'Minimum number of rows of index for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_9_name, :default=> 'Detection of unused indexes by system monitoring'),
            :desc  => t(:dragnet_helper_9_desc, :default=>"DB monitors usage (access) on indexes if declared so before by 'ALTER INDEX ... MONITORING USAGE'.
Results of usage monitoring can be queried from v$Object_Usage but only for current schema.
Over all schemas usage can be monitored with following SQL.
Caution: GATHER_INDEX_STATS also counts as usage even if no other select touches this index.

Additional information about index usage can be requested from DBA_Hist_Seg_Stat and DBA_Hist_Active_Sess_History."),
            :sql=> "SELECT /* DB-Tools Ramm: unused indexes */ u.*, i.Num_Rows, i.Distinct_Keys,
                             (SELECT SUM(s.Bytes) FROM DBA_Segments s WHERE s.Owner=u.Owner AND s.Segment_Name=u.Index_Name)/(1024*1024) MBytes,
                             i.Tablespace_Name, i.Uniqueness, i.Index_Type,
                             (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = u.Owner AND t.Table_Name = u.Table_Name) IOT_Type
                      FROM   (
                              SELECT u.name Owner, io.name Index_Name, t.name Table_Name,
                                     decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
                                     decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                                     ou.start_monitoring, ou.end_monitoring
                              FROM   sys.object_usage ou
                              JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                              JOIN   sys.obj$ io ON io.obj# = ou.obj#
                              JOIN   sys.obj$ t  ON t.obj# = i.bo#
                              JOIN   sys.user$ u ON u.user# = io.owner#
                              WHERE  TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-?
                             )u
                      JOIN DBA_Indexes i ON i.Owner = u.Owner AND i.Index_Name = u.Index_Name AND i.Table_Name=u.Table_Name
                      WHere Used='NO' AND Monitoring='YES'
                      AND i.Num_Rows > ?
                      ORDER BY i.Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=> 'Tage rückwärts ohne Nutzung',    :size=>8, :default=>7,   :title=> 'Anzahl Tage, die der Start_Monitoring-Zeitstempel ungenutzter Indizes alt sein muss'},
                         {:name=> 'Minimale Anzahl Rows des Index', :size=>8, :default=>100, :title=> 'Minimale Anzahl Rows des Index für Aufnahme in Selektion'}
            ]
        },
        {
            :name  => t(:dragnet_helper_10_name, :default=> 'Detection of indexes with unnecessary columns because of pure selectivity'),
            :desc  => t(:dragnet_helper_10_desc, :default=>"For multi-column indexes with high selectivity of single columns often additional columns in index don't  improve selectivity of that index.
Additional columns with low selectivity are useful only if:
- they essentially improve selectivity of whole index
- they allow index-only data access without accessing table itself
Without these reasons additional columns with low selectivity may be removed from index.
This selection already suppresses indexes used for elimination of 'table access by rowid'."),
            :sql=> "SELECT /* DB-Tools Ramm: low selectivity */ *
                        FROM
                               (
                                SELECT /*+ NO_MERGE USE_HASH(i ms io) */
                                       i.Owner, i.Table_Name, i.Index_Name, i.Num_Rows,
                                       (SELECT SUM(s.Bytes) FROM DBA_Segments s WHERE s.Owner=i.Owner AND s.Segment_Name=i.Index_Name)/(1024*1024) \"MBytes\",
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
                                WHERE  i.Num_Rows IS NOT NULL AND i.Num_Rows > 0
                                AND    ms.Max_Num_Distinct > i.Num_Rows/?   -- Ein Feld mit gen∏gend groﬂer Selektivit‰t existiert im Index
                                AND    tc.Column_Name != ms.Column_Name     -- Spalte mit hoechster Selektivit‰t ausblenden
                                AND    i.UniqueNess = 'NONUNIQUE'
                                AND    io.Owner IS NULL AND io.Index_Name IS NULL -- keine Zugriffe, bei denen alle Felder aus Index kommen und kein TableAccess nˆtig wird
                               ) o
                        WHERE  o.Owner NOT IN ('SYS', 'OLAPSYS', 'SYSMAN', 'WMSYS', 'CTXSYS')
                        AND    Num_Rows > ?
                        ORDER BY Max_Num_Distinct / Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=> 'Größte Selektivität eines Feldes des Index > 1/x der Anzahl Rows ', :size=>8, :default=>4, :title=> 'Anzahl DISTINCT-Werte des Index-Feldes mit der größten Selektivität ist > 1/x der Anzahl Rows des Index'},
                         {:name=> 'Minimale Anzahl Rows des Index', :size=>8, :default=>100000, :title=> 'Minimale Anzahl Rows des Index für Aufnahme in Selektion'}]
        },
        {
            :name  => t(:dragnet_helper_6_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially unnecessary indexes)'),
            :desc  => t(:dragnet_helper_6_desc, :default=>"Protection of existing foreign key constraint by index on referencing column may be unnecessary if:
- there are no physical deletes on referenced table
- full table scan on referencing table is acceptable during delete on referenced table
- possible shared lock issues on referencing table due to not existing index are no problem
Especially for references from large tables to small master data tables often there's no use for the effort of indexing referencing column.
Due to the poor selectivity such indexes are mostly not useful for access optimization."),
            :sql=> "SELECT /* DB-Tools Ramm Unnoetige Indizes auf Ref-Constraint*/
                           ri.Rows_Origin, ri.Owner, ri.Table_Name, ri.Index_Name, p.Constraint_Name, ri.Column_Name,
                           pi.Num_Rows Rows_Target, ri.Position, pi.Table_Name Target_Table, pi.Index_Name Target_Index
                    FROM   (SELECT /*+ NO_MERGE */
                                   r.Owner, r.Table_Name, r.Constraint_Name, rc.Column_Name, rc.Position, ric.Index_Name,
                                   r.R_Owner, r.R_Constraint_Name, ri.Num_Rows Rows_Origin
                            FROM   DBA_Constraints r,
                                   DBA_Cons_Columns rc,         -- Spalten des Foreign Key
                                   DBA_Ind_Columns ric,         -- passende Spalten eines Index
                                   DBA_Indexes ri
                            WHERE  r.Constraint_Type  = 'R'
                            AND    rc.Owner           = r.Owner
                            AND    rc.Constraint_Name = r.Constraint_Name
                            AND    ric.Table_Owner    = r.Owner
                            AND    ric.Table_Name     = r.Table_Name
                            AND    ric.Column_Name    = rc.Column_Name
                            AND    ric.Column_Position= rc.Position
                            AND    ri.Owner           = ric.Index_Owner
                            AND    ri.Index_Name      = ric.Index_Name
                           ) ri,                      -- Indizierte Foreign Key-Constraints
                           DBA_Constraints p,         -- referenzierter PKey-Constraint
                           DBA_Indexes     pi         -- referenzierter PKey-Index
                    WHERE  p.Owner            = ri.R_Owner
                    AND    p.Constraint_Name  = ri.R_Constraint_Name
                    AND    pi.Owner           = p.Owner
                    AND    pi.Index_Name      = p.Index_Name
                    AND    pi.Num_Rows < ?                -- Begrenzung auf kleine referenzierte Tabellen
                    AND    ri.Rows_Origin > ?        -- Mindestgroesse fuer referenzierende Tabelle
                    AND    (SELECT Count(*) FROM DBA_Constraints ri
                            WHERE  ri.r_owner = p.Owner AND ri.R_Constraint_Name=p.Constraint_Name
                           ) < ?                      -- Begrenzung auf Anzahl referenzierende Tabellen
                    ORDER BY Rows_Origin DESC NULLS LAST",
            :parameter=>[{:name=> 'Max. Anzahl Rows referenzierte Tabelle', :size=>8, :default=>100, :title=> 'Max. Anzahl Rows der referenzierten Tabelle'},
                         {:name=> 'Min. Anzahl Rows referenzierende Tabelle', :size=>8, :default=>100000, :title=> 'Mindestanzahl Rows der referenzierenden Tabelle'},
                         {:name=> 'Max. Anzahl referenzierende Tabellen', :size=>8, :default=>20, :title=> 'Max. Anzahl referenzierende Tabellen (bei groesserer Anzahl FullScan-Problem bei Delete auf Master)'},
            ]
        },

    ]
  end # unnecessary_indexes

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
            :desc  => t(:dragnet_helper_12_desc, :default=>"Unique indexes may be local partitioned if partition key is in identical order leading part of index.
This way partition pruning ay be used for access on unique indexes plus possible decrease of index' BLevel."),
            :sql=> "SELECT /* DB-Tools Ramm Partitionierung Unique Indizes */
                             t.Owner, t.Table_Name, tc.Column_Name Partition_Key1, i.Index_Name, t.Num_Rows
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

  def unused_tables
    [
        {
            :name  => t(:dragnet_helper_64_name, :default => 'Detection of unused tables'),
            :desc  => t(:dragnet_helper_64_desc, :default =>'Tables never used for selections may be questioned for their right to exist.
This includes tables that were written, but never read.
'),
            :sql=> "SELECT /* DB-Tools Ramm Nicht genutzte Tabellen */ o.*, sz.MBytes
                      FROM ( SELECT /*+ NO_MERGE */ 'TABLE' Object_Type, Owner, Table_Name Object_Name
                             FROM   DBA_Tables
                             WHERE  IOT_TYPE IS NULL AND Temporary='N'
                             UNION ALL
                             SELECT /*+ NO_MERGE */ 'INDEX' Object_Type, Owner, Index_Name Object_Name
                             FROM   DBA_Indexes
                             WHERE  Index_Type = 'IOT - TOP'
                           ) o
                      LEFT OUTER JOIN
                           (
                             SELECT /*+ NO_MERGE PARALLEL(p,2) FULL(p) PARALLEL(s,2) FULL(s) PARALLEL(t,2) FULL(t)*/
                                    DISTINCT p.Object_Type, p.Object_Owner, p.Object_Name
                             FROM   DBA_Hist_SQL_Plan p
                             JOIN   DBA_Hist_SQLStat s    ON  s.DBID            = p.DBID
                                                          AND s.SQL_ID          = p.SQL_ID
                                                          AND s.Plan_Hash_Value = p.Plan_Hash_Value
                             JOIN   DBA_Hist_SnapShot ss  ON  ss.DBID      = s.DBID
                                                          AND ss.Snap_ID = s.Snap_ID
                                                          AND ss.Instance_Number = s.Instance_Number
                             JOIN   DBA_Hist_SQLText t    ON  t.DBID   = p.DBID AND t.SQL_ID = p.SQL_ID
                             WHERE  ss.Begin_Interval_Time > SYSDATE-?
                             AND    t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                             AND    (UPPER(t.SQL_Text) LIKE 'SELECT%' OR UPPER(t.SQL_Text) LIKE 'WITH%')
                             UNION
                             SELECT /*+ NO_MERGE */ DISTINCT p.Object_Type, p.Object_Owner, p.Object_Name
                             FROM   gv$SQL_Plan p
                             JOIN   gv$SQLArea s ON (s.Inst_ID=p.Inst_ID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value)
                             WHERE  s.Last_Active_Time > SYSDATE-?
                             AND    s.SQL_FullText NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                             AND    (UPPER(s.SQL_Text) LIKE 'SELECT%' OR UPPER(s.SQL_Text) LIKE 'WITH%')
                           ) used ON used.Object_Owner = o.Owner AND used.Object_Name = o.Object_Name
                      LEFT OUTER JOIN (SELECT Segment_Name, Owner, SUM(bytes)/(1024*1024) MBytes
                                       FROM   DBA_SEGMENTS
                                       GROUP BY Segment_Name, Owner
                                      ) sz ON sz.SEGMENT_NAME = o.Object_Name AND sz.Owner = o.Owner
                      WHERE  used.Object_Owner IS NULL
                      AND    used.Object_Name IS NULL
                      AND    o.Owner NOT IN ('SYS', 'SYSTEM', 'WMSYS', 'OUTLN', 'MDSYS', 'OLAPSYS', 'EXFSYS', 'DBSNMP', 'SYSMAN', 'XDB', 'CTXSYS', 'DMSYS')
                      ORDER BY sz.MBytes DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_64_param_1_name, :default=>'Number of days backward in AWR-Historie for SQL'), :size=>8, :default=>8, :title=> t(:dragnet_helper_64_param_1_hint, :default=>'Number of days backward for evaluation of AWR-history regarding match in SQL-text')},
                         {:name=> t(:dragnet_helper_64_param_2_name, :default=>'Number of days backward in AWR-Historie for Plan'), :size=>8, :default=>8, :title=> t(:dragnet_helper_64_param_2_hint, :default=>'Number of days backward for evaluation of AWR-history regarding existence in explain-plan')}]
        },
        {
            :name  => t(:dragnet_helper_65_name, :default=>'Missing housekeeping for mass data'),
            :desc  => t(:dragnet_helper_65_hint, :default=>'For many constellations it is essential to remove not productive used aged data from the system m System.
If last analyze table was far enough in history this selection may help to detect gaps in housekeeping.
Stated here are inserts and updates since last GATHER_TABLE_STATS for tables without any delete operations.
'),
            :sql=> "SELECT /* DB-Tools Ramm Housekeeping*/
                             m.Table_Owner, m.Table_Name, m.TimeStamp, t.Last_analyzed,
                             ROUND(m.Timestamp - t.Last_Analyzed, 2) Tage_nach_Analyze,
                             m.Inserts, m.Updates, m.Deletes, m.Truncated, m.Drop_Segments
                      FROM   (SELECT Table_Owner, Table_Name, MAX(Timestamp) Timestamp,
                                     SUM(Inserts) Inserts, SUM(Updates) Updates, SUM(Deletes) Deletes,
                                     MAX(Truncated) Truncated, SUM(Drop_Segments) Drop_Segments
                              FROM sys.DBA_Tab_Modifications
                              GROUP BY Table_Owner, Table_Name
                             ) m
                      JOIN   DBA_Tables t ON t.Owner = m.Table_Owner AND t.Table_Name = m.Table_Name
                      WHERE m.Deletes = 0 AND m.Truncated = 'NO'
                      ORDER BY m.Inserts+m.Updates+m.Deletes DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_66_name, :default=>'Detection of not used columns (all values = NULL)'),
            :desc  => t(:dragnet_helper_66_desc, :default=>'Unused columns with only NULL-values Spalten can possibly be removed.
Each NULL-value of a record claims one byte if not all subsequent columns of that record are also NULL.
Starting from 11g you can use virtual columns instead if this table structure is precondition (SAP etc.).
'),
            :sql=> "SELECT /* DB-Tools Ramm  Spalten mit komplett  NULL-Values */
                             c.Owner, c.Table_Name, c.Column_Name, t.Num_Rows, c.Num_Nulls, c.Num_Distinct
                      FROM   DBA_Tab_Columns c
                      JOIN   DBA_Tables t ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
                      WHERE  c.Num_Nulls = t.Num_Rows
                      AND    t.Num_Rows  > 0   -- Tabelle enthaelt auch Daten
                      AND    c.Owner NOT IN ('SYS', 'SYSTEM', 'WMSYS', 'SYSMAN', 'MDSYS')
                      ORDER BY t.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_67_name, :default=>'Detection of less informative columns'),
            :desc  => t(:dragnet_helper_67_desc, :default=>'For columns of large tables with less DISTINCT-values meaning can be questioned.
May be it their value is redundant to other columns of that table. In this case you can extract this column as separate master-data table with n:1-relation (normalization).
'),
            :sql=> "SELECT /* DB-Tools Ramm Spalten mit wenig Distinct-Values */
                             c.Owner, c.Table_Name, c.Column_Name, t.Num_Rows, c.Num_Nulls, c.Num_Distinct,
                             ROUND((c.Avg_Col_Len*(Num_Rows-Num_Nulls)+Num_Nulls)/(1024*1024),2) Megabyte
                      FROM   DBA_Tab_Columns c
                      JOIN   DBA_Tables t ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
                      WHERE  NVL(c.Num_Distinct,0) != 0
                      AND    NVL(t.Num_Rows,0) > ?
                      AND    c.Owner NOT IN ('SYS', 'SYSTEM', 'WMSYS')
                      ORDER BY c.Num_Distinct, t.Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')}]
        },
        {
            :name  => t(:dragnet_helper_68_name, :default=>'Unused marked but not physical deleted columns'),
            :desc  => t(:dragnet_helper_68_desc, :default=>'For as unused marked columns it may be worth to reorganize the table by ALTER TABLE DROP UNSED COLUMNS or recreation of table.
'),
            :sql=> 'SELECT /* DB-Tools Ramm Unused gesetzte Spalten ohne ALTER TABLE DROP UNUSED COLUMNS*/ cs.*, t.Num_Rows
                      FROM   DBA_Unused_Col_Tabs cs
                      JOIN   DBA_Tables t ON t.Owner = cs.Owner AND t.Table_Name = cs.Table_Name
                      ORDER BY t.Num_Rows*cs.Count DESC NULLS LAST',
        },
        {
            :name  => 'Dropped tables in recycle bin',
            :desc  => "Use 'PURGE RECYCLEBIN' to free space of dropped tables from recycle bin",
            :sql=> "SELECT /* Panorama-Tool Ramm */ *
                      FROM   DBA_Tables
                      WHERE  Dropped = 'YES'
                      ORDER BY Num_Rows DESC NULLS LAST",
        },

    ]
  end # unused_tables

  def sqls_potential_db_structures
    [
        {
            :name  => t(:dragnet_helper_50_name, :default=> 'Possibly useful compression of tables'),
            :desc  => t(:dragnet_helper_50_desc, :default=> 'Table compression (COMPRESS FOR xxx) reduces I/O-effort by improvement of cache hit ratio.
                Decrease in size by 1/3 to 1/2 is possible.
                Min. 20% decrease of size and relevant I/O should exist to compensate CPU overhead of compression/decompression.'),
            :sql=> "SELECT /* Panorama-Tool Ramm */
                           Owner, Object_Name, Object_Type, SUM(Samples) \"Anzahl ASH-Samples\", Compression, Compress_For
                    FROM   (SELECT o.Owner, o.Object_Name, o.Object_Type, h.Samples,
                                   CASE WHEN o.Object_Type='TABLE' THEN (SELECT Compression FROM DBA_Tables t WHERE t.Owner=o.Owner AND t.Table_Name=o.Object_Name)
                                        WHEN o.Object_Type='TABLE PARTITION' THEN (SELECT Compression FROM DBA_Tab_Partitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='TABLE SUBPARTITION' THEN (SELECT Compression FROM DBA_Tab_SubPartitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.SubPartition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='INDEX' THEN (SELECT Compression FROM DBA_Indexes i WHERE i.Owner=o.Owner AND i.Index_Name=o.Object_Name)
                                        WHEN o.Object_Type='INDEX PARTITION' THEN (SELECT Compression FROM DBA_Ind_Partitions i WHERE i.Index_Owner=o.Owner AND i.Index_Name=o.Object_Name AND i.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='INDEX SUBPARTITION' THEN (SELECT Compression FROM DBA_Ind_SubPartitions i WHERE i.Index_Owner=o.Owner AND i.Index_Name=o.Object_Name AND i.SubPartition_Name = o.SubObject_Name)
                                   ELSE 'UNKNOWN'
                                   END Compression,
                                   CASE WHEN o.Object_Type='TABLE' THEN (SELECT Compress_For FROM DBA_Tables t WHERE t.Owner=o.Owner AND t.Table_Name=o.Object_Name)
                                        WHEN o.Object_Type='TABLE PARTITION' THEN (SELECT Compress_For FROM DBA_Tab_Partitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='TABLE SUBPARTITION' THEN (SELECT Compress_For FROM DBA_Tab_SubPartitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.SubPartition_Name = o.SubObject_Name)
                                   ELSE 'UNKNOWN'
                                   END Compress_For
                            FROM   (SELECT /*+ PARALLEL(h,2) */ Current_Obj#, COUNT(*) Samples
                                    FROM   DBA_Hist_Active_Sess_History h
                                    WHERE  Sample_Time > SYSDATE-?
                                    AND    Event = 'db file sequential read'
                                    GROUP BY Current_Obj#
                                    HAVING COUNT(*) > ?
                                   ) h
                            LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = h.Current_Obj#
                           ) x
                    GROUP BY Owner, Object_Name, Object_Type, Compression, Compress_For
                    ORDER BY SUM(Samples) DESC
            ",
            :parameter=>[
                {:name=> 'Number of days in history to consider', :size=>8, :default=>2, :title=> 'Number of days in history to consider in active session history'},
                {:name=> 'Min. number of samples in ASH', :size=>8, :default=>100, :title=> 'Minimum number of samples in active session history'},
            ]
        },
        {
            :name  => t(:dragnet_helper_5_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially missing indexes)'),
            :desc  => t(:dragnet_helper_5_desc, :default=> 'Protection of colums with foreign key references by index can be necessary for:
- Ensure delete performance of referenced table (suppress FullTable-Scan)
- Supress lock propagation (shared lock on index instead of table)'),
            :sql=> "SELECT /* DB-Tools Ramm  Index fehlt fuer Foreign Key*/
                           Ref.Owner, Ref.Table_Name, refcol.Column_Name, refcol.Position, reft.Num_Rows Rows_Org,
                           Ref.R_Owner, target.Table_Name Target_Table, Ref.R_Constraint_Name, targett.Num_rows Rows_Target
                    FROM   DBA_Constraints Ref
                    JOIN   DBA_Cons_Columns refcol  ON refcol.Owner = Ref.Owner AND refcol.Constraint_Name = ref.Constraint_Name
                    JOIN   DBA_Constraints target   ON target.Owner = ref.R_Owner AND target.Constraint_Name = ref.R_Constraint_Name
                    JOIN   DBA_Tables reft          ON reft.Owner = ref.Owner AND reft.Table_Name = ref.Table_Name
                    JOIN   DBA_Tables targett       ON targett.Owner = target.Owner AND targett.Table_Name = target.Table_Name
                    WHERE  Ref.Constraint_Type='R'
                    AND    NOT EXISTS (SELECT 1 FROM DBA_Ind_Columns i
                                       WHERE  i.Table_Owner     = ref.Owner
                                       AND    i.Table_Name      = ref.Table_Name
                                       AND    i.Column_Name     = refcol.Column_Name
                                       AND    i.Column_Position = refcol.Position
                                       )
                    AND Ref.Owner NOT IN ('SYS', 'SYSTEM', 'PERFSTAT', 'MDSYS', 'SYSMAN', 'OLAPSYS')
                    AND targett.Num_rows > ?
                    ORDER BY targett.Num_rows DESC NULLS LAST, refcol.Position",
            :parameter=>[{:name=>t(:dragnet_helper_5_param_1_name, :default=> 'Min. no. of rows of referenced table'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_5_param_1_hint, :default=> 'Minimum number of rows of referenced table') },]
        },
        {
             :name  => t(:dragnet_helper_69_name, :default=>'Detection of chained rows of tables'),
             :desc  => t(:dragnet_helper_69_desc, :default=>'chained rows causes additional read of migrated rows in separate DB-blocks while accessing a record which is not completely contained in current block.
Chained rows can be avoided by adjusting PCTFREE and reorganization of affected table.

This seslection cannot be directly executed. Please copy PL/SQL-Code and execute external in SQL*Plus !!!'),
             :sql=> "
SET SERVEROUT ON;

DECLARE
  statval  NUMBER;
  statdiff NUMBER;
  Anzahl   NUMBER;
  StatNum  NUMBER;
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
    statdiff := Diff();
    FOR i IN 1..RowID_Table.COUNT LOOP
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT /*+ NO_MERGE */ * FROM '||p_Owner||'.'||p_Table_Name||' WHERE RowID=:A1)' INTO Anzahl USING RowID_Table(i);
    END LOOP;
    statdiff := Diff();
  END RunTest;

BEGIN
  DBMS_OUTPUT.PUT_LINE('===========================================');
  DBMS_OUTPUT.PUT_LINE('Ermittlung Chained rows: connected as user='||SYS_CONTEXT ('USERENV', 'SESSION_USER'));
  DBMS_OUTPUT.PUT_LINE('Sampe-size='||Sample_Size||' rows');
  SELECT Statistic# INTO StatNum FROM v$StatName WHERE Name='consistent gets';
  FOR Rec IN (SELECT Owner, Table_Name, Num_Rows
              FROM   DBA_Tables
              WHERE  IOT_Type IS NULL
              AND    Num_Rows > 10000   -- nur genügende große Tabellen testen
              AND    Owner NOT IN ('SYS','SYSTEM')
             ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'SELECT RowID FROM '||Rec.Owner||'.'||Rec.Table_Name||' WHERE RowNum <= '||Sample_Size BULK COLLECT INTO RowID_Table;
      runTest(Rec.Owner, Rec.Table_Name);  -- der erste zum Warmlaufen und übersetzen der Cursor
      runTest(Rec.Owner, Rec.Table_Name);  -- dieser zum Zaehlen
      IF statdiff > Sample_Size THEN
        DBMS_OUTPUT.PUT_LINE('Table='||Rec.Owner||'.'||Rec.Table_Name||',   num rows='||Rec.Num_Rows||',   consistent gets='||statdiff||',   Anteil chained rows='||((statdiff*100/sample_size)-100)||' %');
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
            :name  => 'Table access by rowid replaceable by index lookup (from current SGA)',
            :desc  => 'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.',
            :sql=> "SELECT x.*
                    FROM   (
                            SELECT /*+ USE_HASH(t) */
                                   p.Inst_ID, p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, h.SQL_Plan_Line_ID, p.Object_Owner, p.Object_Name,
                                   t.Num_Rows, t.Avg_Row_Len,
                                   h.Samples Seconds_per_SQL,
                                   SUM(Samples) OVER (PARTITION BY p.Object_Owner, p.Object_Name) Seconds_per_Object
                            FROM   gv$SQL_Plan p
                            JOIN   (
                                    SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, SQL_ID,
                                           SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Samples
                                    FROM   gv$Active_Session_History
                                    WHERE  SQL_Plan_Line_ID IS NOT NULL
                                    GROUP BY Inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                   ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                            LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                            WHERE  p.Operation = 'TABLE ACCESS' AND p.Options = 'BY INDEX ROWID'
                            AND    p.Object_Owner NOT IN ('SYS', 'SYSTEM')
                            AND    NVL(t.Num_Rows, 0) < ?
                           ) x
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC",
            :parameter=>[{:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>10, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        {
            :name  => 'Table access by rowid replaceable by index lookup (from AWR history)',
            :desc  => 'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.',
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
                            AND    p.Object_Owner NOT IN ('SYS', 'SYSTEM')
                            AND    NVL(t.Num_Rows, 0) < ?
                           )
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC
                    ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>100, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        ]
  end # sqls_potential_db_structures

  ####################################################################################################################

  def optimizable_full_scans
    [
        {
            :name  => t(:dragnet_helper_70_name, :default=>'Optimizable index full scan operations'),
            :desc  => t(:dragnet_helper_70_desc, :default=>'Index full scan operations on large indexes often may be successfully switched to parallel direct path read per index fast full, if sort order of result does not matter.
If optimizer does not decide to do so himself, you can use hints /*+ PARALLEL_INDEX(Alias, Degree) INDEX_FFS(Alias) */.
'),
            :sql=> "SELECT /* DB-Tools Ramm IndexFullScan */ * FROM (
                      SELECT p.SQL_ID, s.Parsing_Schema_Name, p.Object_Owner, p.Object_Name,
                             (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name
                             ) Num_Rows_Index, s.Instance_Number,
                             (SELECT MAX(Begin_Interval_Time) FROM DBA_Hist_SnapShot ss
                              WHERE ss.DBID=p.DBID AND ss.Snap_ID=s.MaxSnapID AND ss.Instance_Number=s.Instance_Number ) MaxIntervalTime,
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID) SQLText,
                             s.Elapsed_Secs, s.Executions, s.Disk_Reads, s.Buffer_Gets
                      FROM  (
                              SELECT DISTINCT p.DBID, p.Plan_Hash_Value, p.SQL_ID, p.Object_Owner, p.Object_Name
                              FROM  DBA_Hist_SQL_Plan p
                              WHERE Operation = 'INDEX'
                              AND   Options   = 'FULL SCAN'
                            ) p,
                            (SELECT s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number,
                                    MIN(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                    SUM(Elapsed_Time_Delta)/1000000 Elapsed_Secs,
                                    SUM(Executions_Delta)           Executions,
                                    SUM(Disk_Reads_Delta)           Disk_Reads,
                                    SUM(Buffer_Gets_Delta)          Buffer_Gets,
                                    MAX(s.Snap_ID)                     MaxSnapID
                             FROM   DBA_Hist_SQLStat s,
                                    (SELECT DBID, Instance_Number, MIN(Snap_ID) Snap_ID
                                     FROM   DBA_Hist_SnapShot ss
                                     WHERE  Begin_Interval_Time>SYSDATE-?
                                     /* Nur Snap_ID groesser der hier ermittelten auswerten */
                                     GROUP BY DBID, Instance_Number
                                    ) MaxSnap
                             WHERE MaxSnap.DBID            = s.DBID
                             AND   MaxSnap.Instance_Number = s.Instance_Number
                             AND   s.Snap_ID               > MaxSnap.Snap_ID
                             GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_Number) s
                      WHERE s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                      ) ORDER BY Num_Rows_Index DESC NULLS LAST, Elapsed_Secs DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_71_name, :default=>'Optimizable full table scan operations by executions'),
            :desc  => t(:dragnet_helper_71_desc, :default=>'Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
'),
            :sql=> "WITH Backward AS (SELECT ? Days FROM Dual)
                     SELECT /* DB-Tools Ramm FullTableScan */ p.SQL_ID, p.Object_Owner, p.Object_Name,
                              (SELECT Num_Rows FROM DBA_Tables t WHERE t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name) Num_Rows,
                              s.Elapsed_Secs, s.Executions, s.Disk_Reads, s.Buffer_Gets, s.Rows_Processed,
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID) SQLText
                      FROM  (
                              SELECT /*+ NO_MERGE */ DISTINCT p.DBID, p.Plan_Hash_Value, p.SQL_ID, p.Object_Owner, p.Object_Name /*, p.Access_Predicates, p.Filter_Predicates */
                              FROM  DBA_Hist_SQL_Plan p
                              WHERE Operation = 'TABLE ACCESS'
                              AND   Options LIKE '%FULL'            /* Auch STORAGE FULL der Exadata mit inkludieren */
                              AND   Object_Owner NOT IN ('SYS')
                              AND   Timestamp > SYSDATE-(SELECT Days FROM Backward)
                            ) p
                      JOIN  (SELECT s.DBID, s.SQL_ID, s.Plan_Hash_Value,
                                    ROUND(SUM(Elapsed_Time_Delta)/1000000,2) Elapsed_Secs,
                                    SUM(Executions_Delta)           Executions,
                                    SUM(Disk_Reads_Delta)           Disk_Reads,
                                    SUM(Buffer_Gets_Delta)          Buffer_Gets,
                                    SUM(Rows_Processed_Delta)       Rows_Processed
                             FROM   DBA_Hist_SQLStat s
                             JOIN   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, MIN(Snap_ID) Snap_ID
                                     FROM   DBA_Hist_SnapShot ss
                                     WHERE  Begin_Interval_Time > SYSDATE-(SELECT Days FROM Backward)
                                     GROUP BY DBID, Instance_Number
                                    ) MaxSnap ON MaxSnap.DBID            = s.DBID
                                             AND   MaxSnap.Instance_Number = s.Instance_Number
                                             AND   s.Snap_ID               > MaxSnap.Snap_ID
                             GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value
                             HAVING SUM(Executions_Delta) > ?  -- Nur vielfache Ausfuehrung mit Full Scan stellt Problem dar
                            ) s ON s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                      ORDER BY Executions*Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time range for consideration in result')},
            ]
        },
        {
            :name  => t(:dragnet_helper_72_name, :default=>'Optimizable full table scans operations by executions and rows processed'),
            :desc  => t(:dragnet_helper_72_desc, :default=>'Access by full table scan is critical if only small parts of table are relevant for selection, otherwise are adequate for processing of whole table data.
They are out of place for OLTP-like access (small access time, many executions).
'),
                        :sql=> "SELECT /* DB-Tools Ramm FullTableScans */ * FROM (
                            SELECT i.SQL_ID, i.Object_Owner, i.Object_Name, ROUND(i.Rows_Processed/i.Executions,2) Rows_per_Exec,
                                   i.Num_Rows, i.Elapsed_Time_Secs, i.Executions, i.Disk_Reads, i.Buffer_Gets, i.Rows_Processed,
                                   (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=i.DBID AND t.SQL_ID=i.SQL_ID) SQL_Text
                            FROM
                                   (
                                    SELECT /*+ PARALLEL(p,4) PARALLEL(s,4) PARALLEL(ss.4) */
                                           s.DBID, s.SQL_ID, p.Object_Owner, p.Object_Name,
                                           SUM(Executions_Delta)     Executions,
                                           SUM(Disk_Reads_Delta)     Disk_Reads,
                                           SUM(Buffer_Gets_Delta)    Buffer_Gets,
                                           SUM(Rows_Processed_Delta) Rows_Processed,
                                           MIN(t.Num_Rows) Num_Rows,
                                           ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs
                                    FROM   DBA_Hist_SQL_Plan p
                                    JOIN   DBA_Hist_SQLStat s   ON s.DBID=p.DBID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                                    JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                    JOIN   DBA_Tables t         ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name
                                    WHERE  p.Operation = 'TABLE ACCESS'
                                    AND    p.Options LIKE '%FULL'           /* Auch STORAGE FULL der Exadata mit inkludieren */
                                    AND    ss.Begin_Interval_Time > SYSDATE - ?
                                    AND    p.Object_Owner NOT IN ('SYS')
                                    AND    t.Num_Rows > ?
                                    GROUP BY s.DBID, s.SQL_ID, p.Object_Owner, p.Object_Name
                                   ) i
                            WHERE  Rows_Processed > 0
                            AND    Executions > ?
                     )
                     WHERE  SQL_Text NOT LIKE '%dbms_stats%'
                     ORDER BY Rows_per_Exec/Num_Rows/Executions",
                        :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                                     {:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')},
                                     {:name=> t(:dragnet_helper_param_executions_name, :default=>'Minimum number of executions'), :size=>8, :default=>100, :title=> t(:dragnet_helper_param_executions_hint, :default=>'Minimum number of executions within time range for consideration in result')},
                        ]
        },
        {
            :name  => t(:dragnet_helper_73_name, :default=>'Optimizable full table scan operations at long running foreign key checks by deletes'),
            :desc  => t(:dragnet_helper_73_desc, :default=>'Long running foreign key checks at deletes are often caused by missing indexes at referencing table.'),
            :sql=>  "SELECT /*+ USE_NL(s t) */ t.SQL_Text Full_SQL_Text,
                             TO_CHAR(SUBSTR(t.SQL_Text, 1, 40)) SQL_Text,
                             s.*
                             FROM (
                                   SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Instance_number \"Instance\",
                                           NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') UserName, /* sollte immer gleich sein in Gruppe */
                                           SUM(Executions_Delta)                                              Executions,
                                           SUM(Elapsed_Time_Delta)/1000000                                    \"Elapsed Time (Sec.)\",
                                           ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),5) \"Elapsed Time (s) per Execute\",
                                           SUM(CPU_Time_Delta)/1000000                                        \"CPU Time (Sec.)\",
                                           SUM(Disk_Reads_Delta)                                              \"Disk Reads\",
                                           ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)),2) \"Disk Reads per Execute\",
                                           ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)),4) \"Executions per Disk Read\",
                                           SUM(Buffer_Gets_Delta)                                             \"Buffer Gets\",
                                           ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)),2) \"Buffer Gets per Execution\",
                                           ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)),2) \"Buffer Gets per Row\",
                                           SUM(Rows_Processed_Delta)                                          \"Rows Processed\",
                                           SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) \"Rows Processed per Execute\",
                                           SUM(ClWait_Delta)                                                  \"Cluster Wait Time\",
                                           MAX(s.Snap_ID) Max_Snap_ID
                                   FROM dba_hist_snapshot snap,
                                   DBA_Hist_SQLStat s
                                   WHERE snap.Snap_ID = s.Snap_ID
                                   AND snap.DBID = s.DBID
                                   AND snap.Instance_Number= s.instance_number
                                   AND snap.Begin_Interval_time >  SYSDATE - ?
                                   AND s.Parsing_Schema_Name = 'SYS'
                                   GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                             ) s
                       JOIN  DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                       WHERE UPPER(t.SQL_Text) LIKE '%SELECT%ALL_ROWS%COUNT(1)%'
                       ORDER BY \"Elapsed Time (s) per Execute\" DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },


    ]
  end # optimizable_full_scans


  def sqls_wrong_execution_plan
    [
        {
             :name  => 'Übermäßige Anzahl Zugriffe auf Cache-Buffer',
             :desc  => "Zugriffe auf DB-Blöcke im Cache der DB (db-block-gets, consistent reads) werden dann kritisch hinsichtlich des provozierens von 'cache buffers chains'-Latchwaits wenn:
- in massiver Häufigkeit auf einige wenige Blöcke lesend oder schreibend zugegriffen wird (HotBlocks im Buffer-Cache)
- exorbitant viele Blöcke gelesen werden (kritsch selbst dann wenn diese weit verteilt im Cache liegen und keine HotBlocks bilden)
Für beide Konstellationen lassen sich problematische Statements identifizieren durch Bewertung nach der Spitze der Anzahl Blockzugriffe zwischen zwei AWR-Snapshots.
",
             :sql=> "SELECT /* DB-Tools Ramm CacheBuffer */ * FROM (
                      SELECT /*+ USE_NL(s t) */ s.*, SUBSTR(t.SQL_Text,1,600) \"SQL-Text\"
                      FROM (
                               SELECT /*+ NO_MERGE ORDERED */ s.SQL_ID, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000)                         \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Elapsed Time per Execute (Sec)\",
                                      ROUND(SUM(CPU_Time_Delta)/1000000)                             \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),8)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta),
                                          0, 1, SUM(Rows_Processed_Delta)),2)                        \"Buffer Gets per Result-Row\",
                                      SUM(Rows_Processed_Delta)                                      \"Rows Processed\",
                                      ROUND(SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Rows Processed per Execute\",
                                      SUM(ClWait_Delta)/1000000                                      \"Cluster Wait-Time (Sec)\",
                                      SUM(IOWait_Delta)/1000000                                      \"I/O Wait-Time (Sec)\",
                                      SUM(CCWait_Delta)/1000000                                      \"Concurrency Wait-Time (Sec)\",
                                      SUM(PLSExec_Time_Delta)/1000000                                \"PL/SQL Wait-Time (Sec)\",
                                      s.DBID
                               FROM   dba_hist_snapshot snap,
                                      DBA_Hist_SQLStat s
                               WHERE  snap.Snap_ID = s.Snap_ID
                               AND    snap.DBID                = s.DBID
                               AND    snap.Instance_Number     = s.instance_number
                               AND    snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                               HAVING MAX(Buffer_Gets_Delta) IS NOT NULL
                               ) s,
                               DBA_Hist_SQLText t
                      WHERE  t.DBID   = s.DBID
                      AND    t.SQL_ID = s.SQL_ID
                      ORDER BY \"max. BufferGets betw.snapshots\" DESC NULLS LAST
                      ) WHERE RowNum<?",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Maximale Anzahl Rows', :size=>8, :default=>100, :title=> 'Maximale Anzahl Rows für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Statements mit unnötig hoher Ausführungszahl: Zugriff auf kleine Objekte',
             :desc  => 'Bei oft ausgeführten Statements kann es sich lohnen, kleine Tabellen per Caching-Funktionen statt SQL zuzugreifen.
Damit reduziert sich CPU-Belastung und Gefahr von „Cache Buffers Chains“ Latch-Waits.
Ab 11g können stored functions mit function result caching für diesen Zweck genutzt werden.
',
             :sql=>  "SELECT /*+ USE_NL(t) \"DB-Tools Ramm Zugriff kleiner Objekte\" */ obj.Owner, Obj.Name, obj.Num_Rows, s.*, t.SQL_Text \"SQL-Text\"
                      FROM  (
                               SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000,4)                       \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),6)                            \"Elapsed Time per Execute (Sec)\",
                                      SUM(CPU_Time_Delta)/1000000                                    \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),6)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),6)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta),
                                          0, 1, SUM(Rows_Processed_Delta)),2)                        \"Buffer Gets per Result-Row\",
                                      SUM(Rows_Processed_Delta)                                      \"Rows Processed\",
                                      ROUND(SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Rows Processed per Execute\",
                                      ROUND(SUM(ClWait_Delta)/1000000,4)                             \"Cluster Wait-Time (Sec)\",
                                      ROUND(SUM(IOWait_Delta)/1000000,4)                             \"I/O Wait-Time (Sec)\",
                                      ROUND(SUM(CCWait_Delta)/1000000,4)                             \"Concurrency Wait-Time (Sec)\",
                                      ROUND(SUM(PLSExec_Time_Delta)/1000000,4)                       \"PL/SQL Wait-Time (Sec)\"
                               FROM   dba_hist_snapshot snap
                               JOIN   DBA_Hist_SQLStat s ON (s.Snap_ID=snap.Snap_ID AND s.DBID=snap.DBID AND s.instance_number=snap.Instance_Number)
                               WHERE  snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Plan_Hash_Value, s.Instance_number
                               HAVING SUM(Executions_Delta) > ?
                               ) s
                            JOIN   DBA_Hist_SQL_Plan p ON (p.DBID=s.DBID AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value)
                            JOIN   (SELECT Owner, Table_Name Name, Num_Rows FROM DBA_Tables WHERE Num_Rows < 100000
                                    UNION ALL
                                    SELECT Owner, Index_Name Name, Num_Rows FROM DBA_Indexes WHERE Num_Rows < 100000
                                   ) obj ON (obj.Owner = p.Object_Owner AND obj.Name = p.Object_Name)
                            JOIN   DBA_Hist_SQLText t  ON (t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)
                      WHERE Owner NOT IN ('SYS')
                      ORDER BY s.\"Executions\"/DECODE(obj.Num_Rows, 0, 1, obj.Num_Rows) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Minimale Anzahl Executions', :size=>8, :default=>100, :title=> 'Minimale Anzahl Executions für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Unnötig hohe Fetch-Anzahl wegen fehlender Array-Nutzung: Auswertung SGA',
             :desc  => 'Bei größeren Results je Execution lohnt sich der Array-Zugriff auf mehrere Records  je Fetch statt Einzelzugriff.
Damit moderate Reduktion von CPU-Belastung und Laufzeit
',
             :sql=> "SELECT * FROM (
                              SELECT Inst_ID, Parsing_Schema_Name \"Parsing schema name\",
                                     Module,
                                     SQL_ID, Executions, Fetches \"Number of fetches\",
                                     End_Of_Fetch_Count \"Number of fetches until end\",
                                     Rows_Processed \"Rows processed\",
                                     ROUND(Rows_Processed/Executions,2) \"Rows per exec\",
                                     ROUND(Fetches/Executions,2) \"Fetches per exec\",
                                     ROUND(Rows_Processed/Fetches,2) \"Rows per fetch\",
                                     ROUND(Elapsed_Time/1000000,2) \"Elapsed time (secs)\",
                                     ROUND(Executions * (MOD(Rows_Processed/Executions, 1000) / (Rows_Processed/Fetches) -1)) \"Additional Fetches\",
                                     SQL_FullText
                              FROM   GV$SQLArea s
                              WHERE  Fetches > Executions
                              AND    Fetches > 1
                              AND    Executions > 0
                              AND    Rows_Processed > 0
                              )
                              WHERE \"Fetches per exec\" > ?
                              ORDER BY \"Additional Fetches\" DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_60_param_1_name, :default=>'Min. number of fetches per execution'), :size=>8, :default=>100, :title=>t(:dragnet_helper_60_param_1_hint, :default=>'Minimum number of fetches per execution for consideration in result') },
             ]
         },
        {
             :name  => 'Unnötig hohe Fetch-Anzahl wegen fehlender Array-Nutzung: Auswertung AWR-Historie',
             :desc  => 'Bei größeren Results je Execution lohnt sich der Array-Zugriff auf mehrere Records  je Fetch statt Einzelzugriff.
Damit moderate Reduktion von CPU-Belastung und Laufzeit
',
             :sql=> "SELECT s.*, (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID ) SQL_Text
                      FROM (
                      SELECT s.Instance_Number Instance, s.DBID, Parsing_Schema_Name, Module,
                             SQL_ID, SUM(Executions_Delta) Executions, SUM(Fetches_Delta) Fetches,
                             SUM(End_Of_Fetch_Count_Delta) End_Of_Fetch_Count, SUM(Rows_Processed_Delta) \"Rows Processed\",
                             ROUND(SUM(Rows_Processed_Delta)/SUM(Executions_Delta),2) \"Rows per Exec\",
                             ROUND(SUM(Fetches_Delta)/SUM(Executions_Delta),2)        \"Fetches per exec\",
                             ROUND(SUM(Rows_Processed_Delta)/SUM(Fetches_Delta),2)    \"Rows per Fetch\",
                             ROUND(SUM(Elapsed_Time_Delta)/1000000,2)                 \"Elapsed Time (Secs)\",
                             ROUND(SUM(Executions_delta) * (MOD(SUM(Rows_Processed_Delta)/SUM(Executions_Delta), 1000) /
                               (SUM(Rows_Processed_Delta)/SUM(Fetches_Delta)) -1))    \"Additional Fetches\"
                      FROM   DBA_Hist_SQLStat s
                      JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Snap_ID=s.Snap_ID AND ss.Instance_Number=s.Instance_Number
                                                  AND ss.Begin_Interval_Time > SYSDATE - ?
                      GROUP BY s.Instance_Number, s.DBID, s.Parsing_Schema_Name, s.Module, s.SQL_ID
                      HAVING SUM(Fetches_Delta) > SUM(Executions_Delta)
                      AND    SUM(Fetches_Delta) > 1
                      AND    SUM(Executions_Delta) > 0
                      AND    SUM(Rows_Processed_Delta) > 0
                      ) s
                      WHERE \"Fetches per exec\" > ?
                      ORDER BY \"Additional Fetches\" DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=>t(:dragnet_helper_59_param_2_name, :default=>'Min. number of fetches per execution'), :size=>8, :default=>100, :title=>t(:dragnet_helper_59_param_2_hint, :default=>'Minimum number of fetches per execution for consideration in result') },
             ]
         },
        {
             :name  => 'Statements mit unnötig hoher Ausführungszahl: Unnötig hohe Execute-Anzahl wegen fehlender Array-Verarbeitung',
             :desc  => 'Bei geringer Anzahl Rows je Execution und hoher Execution-Zahl lohnt sich die Bündelung von Schreibzugriffen in Array-Operationen bzw. PL/SQL-FORALL-Operationen wenn sie in selber Transaktion stattfinden.
Damit moderate Reduktion von CPU-Belastung und Laufzeit.
',
             :sql=>  "SELECT /* DB-Tools Ramm: Buendelbare Einzeilsatz-Executes */ s.SQL_ID, s.Instance_Number Instance, Parsing_Schema_Name,
                             SUM(s.Executions_Delta) Executions,
                             ROUND(SUM(s.Elapsed_Time_Delta)/1000000) Elapsed_Time_Secs,
                             SUM(s.Rows_Processed_Delta) Rows_Processed,
                             ROUND(SUM(s.Rows_Processed_Delta)/SUM(s.Executions_Delta),2) Rows_per_Exec,
                             ROUND(SUM(s.Executions_Delta)/SUM(s.Rows_Processed_Delta),2) Execs_Per_Row,
                             MIN(TO_CHAR(SUBSTR(t.SQL_Text,1,4000))) SQL
                      FROM   DBA_Hist_SQLStat s
                      JOIN   DBA_Hist_SnapShot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                      JOIN   DBA_Hist_SQLText t ON t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID AND t.Command_Type IN (2,6,7) /* Insert, Update, Delete */
                      WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                      AND    Parsing_Schema_Name NOT IN ('SYS')
                      GROUP BY s.SQL_ID, s.Instance_Number, Parsing_Schema_Name
                      HAVING SUM(s.Executions_Delta) > ?
                      AND    SUM(s.Rows_Processed_Delta) > 0
                      ORDER BY SUM(Executions_Delta)*SUM(Executions_Delta)/SUM(Rows_Processed_Delta) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=>t(:dragnet_helper_61_param_2_name, :default=>'Min. number of executions'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_61_param_2_hint, :default=>'Minimum number of executions for consideration in result') },
             ]
         },
        {
             :name  => 'Unnötige Ausführung von Statements: Selects/Updates/Deletes ohne Treffer',
             :desc  => 'Für Select- / Update- / Delete-Statements, deren Zugriffskriterien niemals zu Treffern führen, kann evtl. die Sinnfrage gestellt werden.
Es könnte sich aber auch um seltene Prüfungen handeln, bei denen kein Treffer das erwartete und zu testende Resultat ist.
',
             :sql=>  "SELECT /*+ USE_NL(t)  “DB-Tools Ramm Ohne Result */ s.*, t.SQL_Text \"SQL-Text\"
                      FROM  (
                               SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Instance_number \"Instance\",
                                      NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]') \"UserName\", /* sollte immer gleich sein in Gruppe */
                                      MAX(Buffer_Gets_Delta)                                         \"max. BufferGets betw.snapshots\",
                                      SUM(Executions_Delta)                                          \"Executions\",
                                      ROUND(SUM(Elapsed_Time_Delta)/1000000)                         \"Elapsed Time (Sec)\",
                                      ROUND(SUM(ELAPSED_TIME_Delta/1000) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),2)                            \"Elapsed Time per Execute (ms)\",
                                      ROUND(SUM(CPU_Time_Delta)/1000000)                             \"CPU-Time (Secs)\",
                                      SUM(Disk_Reads_Delta)                                          \"Disk Reads\",
                                      ROUND(SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_Delta)),4)                            \"Disk Reads per Execute\",
                                      ROUND(SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta),
                                          0, 1, SUM(Disk_Reads_Delta)),2)                            \"Executions per Disk Read\",
                                      SUM(Buffer_Gets_Delta)                                         \"Buffer Gets\",
                                      ROUND(SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta),
                                          0, 1, SUM(EXECUTIONS_delta)),2)                            \"Buffer Gets per Execution\"
                               FROM   dba_hist_snapshot snap
                               JOIN   DBA_Hist_SQLStat s ON (s.Snap_ID=snap.Snap_ID AND s.DBID=snap.DBID AND s.instance_number=snap.Instance_Number)
                               WHERE  snap.Begin_Interval_time > SYSDATE - ?
                               GROUP BY s.DBID, s.SQL_ID, s.Instance_number
                               HAVING SUM(Executions_Delta) > ?
                                      AND SUM(Rows_Processed_Delta) = 0
                               ) s
                            JOIN   DBA_Hist_SQLText t  ON (t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)
                      WHERE (   UPPER(t.SQL_Text) LIKE 'UPDATE%'
                             OR UPPER(t.SQL_Text) LIKE 'DELETE%'
                             OR UPPER(t.SQL_Text) LIKE 'MERGE%'
                             OR UPPER(t.SQL_Text) LIKE 'SELECT%'
                             OR UPPER(t.SQL_Text) LIKE 'WITH%'
                             )
                      ORDER BY s.\"Elapsed Time (Sec)\" DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Minimale Anzahl Executions', :size=>8, :default=>100, :title=> 'Minimale Anzahl Executions für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Unnötige Ausführung von Statements: Updates mit unnötigem Filter in WHERE-Bedingung (Auswertung SGA)',
             :desc  => 'Single-Row-Update-Statements mit einschränkendem Filter in WHERE-Bedingung des Updates lassen sich oft beschleunigen durch Verlagerung des Filters in vorherige Selektion, die als Massendatenoperation effektiver ausgeführt und optional mittels ParallelQuery parallelisiert werden kann.',
             :sql=>  "SELECT Inst_ID, Parsing_Schema_Name \"Parsing Schema Name\",
                             SQL_ID, ROUND(Elapsed_Time/1000000,2) \"Elapsed Time (Secs)\",
                             Executions,
                             Rows_Processed,
                             ROUND(Elapsed_Time/1000000/DECODE(Rows_Processed,0,1,Rows_Processed),4) \"Seconds per row\",
                             SQL_FullText
                      FROM   gv$SQLArea
                      WHERE  SQL_FullText NOT LIKE '%JDBCDAO%'
                      AND    UPPER(SQL_Text) LIKE 'UPDATE%'
                      AND    INSTR(UPPER(SQL_FullText), 'WHERE') > 0 /* WHERE enthalten */
                      AND    INSTR(SUBSTR(UPPER(SQL_FullText), INSTR(UPPER(SQL_FullText), 'WHERE')), 'AND') > 0 /* mehrere Filterbedingungen */
                      AND    SQL_FullText LIKE '%:%' /* Enthaelt Host-Variable */
                      ORDER BY Elapsed_Time/DECODE(Rows_Processed,0,1,Rows_Processed) DESC NULLS LAST",
         },
        {
             :name  => 'Unnötige Ausführung von Statements: Updates mit unnötigem Filter in WHERE-Bedingung (Auswertung AWR-Historie)',
             :desc  => 'Single-Row-Update-Statements mit einschränkendem Filter in WHERE-Bedingung des Updates lassen sich oft beschleunigen durch Verlagerung des Filters in vorherige Selektion, die als Massendatenoperation effektiver ausgeführt und optional mittels ParallelQuery parallelisiert werden kann.',
             :sql=>  "SELECT SQL_ID, Parsing_Schema_Name  \"Parsing Schema Name\",
                             Executions, Elapsed_Time_Secs  \"Elapsed Time (Secs)\",
                             Rows_Processed                 \"Rows processed\",
                             ROUND(Elapsed_Time_Secs/DECODE(Rows_Processed, 0, 1, Rows_Processed),4) Secs_Per_Row, SQL_Text
                      FROM (
                              SELECT /*+ ORDERED */ t.SQL_ID, MIN(SQL_Text) SQL_Text, SUM(Executions_Delta) Executions, MAX(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                     ROUND(SUM(Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs, SUM(Rows_Processed_Delta) Rows_Processed
                              FROM   (
                                       SELECT /*+ NO_MERGE PARALLEL(t,4) */ DBID, SQL_ID, TO_CHAR(SUBSTR(SQL_Text,1,4000)) SQL_Text
                                       FROM   DBA_Hist_SQLText t
                                       WHERE  UPPER(SQL_Text) LIKE 'UPDATE%'
                                       AND    UPPER(SQL_Text) LIKE '%SET%'
                                       AND    INSTR(UPPER(SQL_Text), 'WHERE') > 0 /* WHERE enthalten */
                                       AND    INSTR(SUBSTR(UPPER(SQL_Text), INSTR(UPPER(SQL_Text), 'WHERE')), 'AND') > 0 /* mehrere Filterbedingungen */
                                       AND    UPPER(SQL_Text) NOT LIKE '%JDBCDAO%' /* kein Generator-Update */
                                       AND    SQL_Text LIKE '%:%' /* Enthaelt Host-Variable */
                                     ) t
                              JOIN DBA_Hist_SQLStat s ON (s.DBID = t.DBID AND s.SQL_ID = t.SQL_ID)
                              JOIN DBA_Hist_SnapShot ss ON (ss.DBID = t.DBID AND ss.Instance_number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID)
                              WHERE ss.Begin_Interval_Time > SYSDATE-?
                              GROUP BY t.SQL_ID
                           )
                      ORDER BY Elapsed_Time_Secs/DECODE(Rows_Processed, 0, 1, Rows_Processed) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
             :name  => 'Langlaufende Statements ohne Nutzung Parallel Query (Auswertung SGA)',
             :desc  => 'Für langlaufende Statements kann unter Umständen die Nutzung des Features Parallel Query die Laufzeit drastisch reduzieren.',
             :sql=>  "SELECT /*+ ORDERED USE_HASH(s) \"DB-Tools Ramm ohne Parallel Query\"*/
                             s.Inst_ID, s.SQL_ID,
                             s.Parsing_Schema_Name \"Parsing Schema Name\",
                             ROUND(s.Elapsed_Time/10000)/100 Elapsed_Time_Sec,
                             s.Executions,
                             ROUND(s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions)/10000)/100 Elapsed_per_Exec_Sec,
                             First_Load_Time, Last_Load_Time, Last_Active_Time,
                             s.SQL_FullText
                      FROM (
                            SELECT Inst_ID, SQL_ID
                            FROM   GV$SQL_Plan
                            GROUP BY Inst_ID, SQL_ID
                            HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) = 0
                           ) p,
                           GV$SQLArea s
                      WHERE s.Inst_ID = p.Inst_ID
                      AND   s.SQL_ID  = p.SQL_ID
                      AND   s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions) > ? * 1000000 /* > 10 Sekunden */
                      ORDER BY s.Elapsed_Time/DECODE(s.Executions,0,1,s.Executions) DESC NULLS LAST",
             :parameter=>[{:name=> 'Minimale elapsed time/Execution (Sec.)', :size=>8, :default=>20, :title=> 'Minimale elapsed time per execution in Sekunden für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Langlaufende Statements ohne Nutzung Parallel Query (Auswertung AWR-Historie)',
             :desc  => 'Für langlaufende Statements kann unter Umständen die Nutzung des Features Parallel Query die Laufzeit drastisch reduzieren.',
             :sql=>  "SELECT /*+ ORDERED USE_HASH(s) \"DB-Tools Ramm ohne Parallel Query aus Historie\"*/
                             s.*,
                             ROUND(s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions),2) \"Elapsed time per exec (secs)\",
                             (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID) Statement
                      FROM   (SELECT
                                     s.DBID, s.Instance_Number, s.SQL_ID,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/10000)/100 Elapsed_Time_Sec,
                                     SUM(s.Executions_Delta) Executions,
                                     MIN(ss.Begin_Interval_time) First_Occurrence,
                                     MAX(ss.Begin_Interval_Time) Last_Occurrence
                              FROM   (
                                      SELECT /*+ NO_MERGE */ DBID, SQL_ID, Plan_Hash_Value
                                      FROM   DBA_Hist_SQL_Plan p
                                      GROUP BY DBID, SQL_ID, Plan_Hash_Value
                                      HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) = 0
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.DBID, s.Instance_Number, s.SQL_ID
                             ) s
                      WHERE  s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions) > ? /* > 50 Sekunden */
                      ORDER BY s.Elapsed_Time_Sec/DECODE(s.Executions, 0, 1, s.Executions) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Minimale elapsed time/Execution', :size=>8, :default=>20, :title=> 'Minimale elapsed time per execution für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Probleme bei Nutzung Parallel Query: Parallelisierte Statements mit nicht parallelisierten Anteilen (Auswertung SGA)',
             :desc  => 'Bei Nutzung Parallel Query können versehentlich nicht parallelisierte Zugriffe auf größere Strukturen die Laufzeit des Statements drastisch verlängern.
Steuernde INDEX-RANGE-SCAN für NestedLoop-Kaskaden auslagern in WITH … /*+ MATERIALIZE */ und parallelisieren.
Selektion beleuchtet die aktuelle SGA.',
             :sql=>  "SELECT /*+ \"DBTools Ramm Nichtparallel Anteile bei PQ\" */ p.*,
                             s.Last_active_Time,
                             s.Executions,
                             s.Elapsed_Time/1000000 Elapsed_Secs,
                             s.SQL_FullText
                      FROM   (
                              SELECT /*+ NO_MERGE */
                                     CASE WHEN Operation = 'INDEX' THEN
                                          (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=ps.Object_Owner AND i.Index_Name = ps.Object_Name)
                                          WHEN Operation = 'TABLE ACCESS' THEN
                                          (SELECT Num_Rows FROM DBA_Tables t WHERE t.Owner=ps.Object_Owner AND t.Table_Name = ps.Object_Name)
                                     ELSE 0 END Num_Rows,
                                     ps.*
                              FROM   (
                                      SELECT Inst_ID, SQL_ID
                                      FROM   gv$SQL_PLan
                                      WHERE  Other_Tag LIKE 'PARALLEL%'
                                      AND    Object_Owner != 'SYS'
                                      GROUP BY Inst_ID, SQL_ID
                                     ) pp,
                                     (
                                      SELECT Inst_ID, SQL_ID, Operation, Options, Object_Owner, Object_Name
                                      FROM   gv$SQL_PLan
                                      WHERE  (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                      AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                      AND    Operation NOT LIKE 'UPDATE%'
                                      AND    Operation NOT LIKE 'SELECT%'
                                      AND    Object_Owner != 'SYS'
                                     ) ps
                              WHERE  ps.Inst_ID = pp.Inst_ID
                              AND    ps.SQL_ID  = pp.SQL_ID
                            ) p
                      JOIN  GV$SQLArea s ON s.Inst_ID=p.Inst_ID AND s.SQL_ID=p.SQL_ID
                      WHERE s.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%'
                      ORDER BY Num_Rows DESC NULLS LAST",
         },
        {
             :name  => 'Probleme bei Nutzung Parallel Query: Parallelisierte Statements mit nicht parallelisierten Anteilen (Auswertung AWR-Historie)',
             :desc  => 'Bei Nutzung Parallel Query können versehentlich nicht parallelisierte Zugriffe auf größere Strukturen die Laufzeit des Statements drastisch verlängern.
Steuernde INDEX-RANGE-SCAN für NestedLoop-Kaskaden auslagern in WITH … /*+ MATERIALIZE */ und parallelisieren.
Selektion beleuchtet die AWR-Historie.',
             :sql=>  "SELECT /* DB-Tools Ramm Nichparallel Anteile bei PQ */ * FROM (
                      SELECT /*+ NO_MERGE */ x.*, ps.Operation, ps.Options, ps.Object_Type, ps.Object_Owner, ps.Object_Name,
                             CASE
                             WHEN ps.Object_Type LIKE 'TABLE%' THEN (SELECT Num_Rows FROM DBA_Tables t WHERE t.Owner=ps.Object_Owner AND t.Table_Name=ps.Object_Name)
                             WHEN ps.Object_Type LIKE 'INDEX%' THEN (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=ps.Object_Owner AND i.Index_Name=ps.Object_Name)
                             ELSE NULL END Num_Rows,
                            (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=x.DBID AND t.SQL_ID=x.SQL_ID) SQLText
                      FROM
                             (
                              SELECT /*+ NO_MERGE ORDERED */
                                     p.DBID, p.SQL_ID, p.Plan_Hash_Value,
                                     MIN(s.Parsing_Schema_Name) Parsing_Schema_Name,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Secs,
                                     SUM(s.Executions_Delta) Executions,
                                     ROUND(SUM(s.Elapsed_Time_Delta)/1000000 / DECODE(SUM(s.Executions_Delta), 0, 1, SUM(s.Executions_Delta)),2) Elapsed_Secs_Per_Exec,
                                     MAX(ss.Begin_Interval_Time) Last_Occurence
                              FROM   (
                                      SELECT /*+ PARALLEL(DBA_Hist_SQL_Plan,2) */ DBID, SQL_ID, Plan_Hash_Value
                                      FROM   DBA_Hist_SQL_Plan
                                      WHERE  Object_Owner != 'SYS'
                                      GROUP BY DBID, SQL_ID, Plan_Hash_Value
                                      HAVING SUM(CASE WHEN Other_Tag LIKE 'PARALLEL%' THEN 1 ELSE 0 END) > 0  -- enthält parallele Anteile
                                      AND    SUM(CASE WHEN (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                                      AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                                      AND    Operation NOT LIKE 'UPDATE%'
                                                      AND    Operation NOT LIKE 'SELECT%'
                                                      THEN 1 ELSE 0 END) > 1 -- enthält nicht parallelisierte Zugriffe
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.Snap_ID = s.Snap_ID AND ss.DBID = p.DBID AND ss.Instance_Number = s.Instance_Number
                                                             AND ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY p.DBID, p.SQL_ID, p.Plan_Hash_Value
                             ) x
                      JOIN   DBA_Hist_SQL_Plan ps ON ps.DBID = x.DBID AND ps.SQL_ID = x.SQL_ID AND ps.Plan_Hash_Value = x.Plan_Hash_Value
                                                     AND (Other_Tag IS NULL OR Other_Tag NOT LIKE 'PARALLEL%')
                                                     AND    Operation NOT IN ('PX COORDINATOR', 'SORT', 'VIEW', 'MERGE JOIN')
                                                     AND    Operation NOT LIKE 'UPDATE%'
                                                     AND    Operation NOT LIKE 'SELECT%'
                                                     AND    ps.Object_Type IS NOT NULL
                      ) ORDER BY Elapsed_Secs_Per_Exec * Num_Rows DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
             :name  => 'Probleme bei Nutzung Parallel Query: Parallel ausgeführte SQL mit Nutzung Stored Functions ohne PARALLEL_ENABLE',
             :desc  => 'Nicht per PARALLEL_ENABLE zur parallelen Verarbeitung zugelassene stored functions führen zur Serialisierung der Verarbeitung bei Verwendung der Parallel Query-Option im Statement.
Für die angelisteten Funktionen ist Erweiterung um Attribut PARALLEL_ENABLE zu untersuchen.',
             :sql=>  "WITH /* DB-Tools Ramm Serialisierung in PQ durch Stored Functions */
                      ProcLines AS (
                            SELECT /*+ NO_MERGE MATERIALIZE */ *
                            FROM   (
                                    SELECT p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, p.Parallel, p.Object_Name SuchText
                                    FROM   DBA_Procedures p
                                    WHERE  p.Object_Type = 'FUNCTION'
                                    UNION ALL
                                    SELECT p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, p.Parallel, p.Object_Name||'.'||p.Procedure_Name SuchText
                                    FROM   DBA_Procedures p
                                    JOIN   DBA_Arguments a ON a.Owner = p.Owner AND a.Package_Name = p.Object_Name AND a.Object_Name = p.Procedure_Name AND a.Position = 0
                                    WHERE  p.Object_Type = 'PACKAGE'
                                   )
                            WHERE  Owner NOT IN ('SYS', 'WMSYS', 'PERFSTAT', 'CTXSYS', 'XDB', 'EXFSYS')
                            AND    Parallel = 'NO'
                       ),
                      SQLs AS (
                              SELECT /*+ NO_MERGE MATERIALIZE  */  *
                              FROM   (
                                      SELECT /*+ NO_MERGE */ UPPER(SQL_FullText) FullText, Elapsed_Time/1000000 Elapsed_Secs, 'SGA' Fundort, S.SQL_ID
                                      FROM gv$SQL s
                                      WHERE UPPER(s.SQL_FullText) LIKE '%PARALLEL%'   /* Hint im SQL verwendet */
                                      UNION ALL
                                      SELECT /*+ NO_MERGE MATERIALIZE PARALLEL(t,4) */ UPPER(t.SQL_Text) FullText, s.Elapsed_Secs, 'History' Fundort, s.SQL_ID
                                      FROM   (
                                              SELECT /*+ NO_MERGE PARALLEL(s,4) PARALLEL(ss,4) */
                                                     s.DBID, s.SQL_ID, Plan_Hash_Value, SUM(s.Elapsed_Time_Delta)/1000000 Elapsed_Secs
                                              FROM   DBA_Hist_SQLStat s
                                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Snap_ID = s.Snap_ID AND ss.Instance_Number = s.Instance_Number
                                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                                              GROUP BY s.DBID, s.SQL_ID, Plan_Hash_Value
                                             ) s
                                      JOIN DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                                      WHERE  UPPER(t.SQL_Text) LIKE '%PARALLEL%'     /* Hint im SQL verwendet */
                                     )
                              WHERE  NOT REGEXP_LIKE(FullText, '^[[:space:]]*BEGIN')
                              AND    NOT REGEXP_LIKE(FullText, '^[[:space:]]*DECLARE')
                              AND    NOT REGEXP_LIKE(FullText, '^[[:space:]]*EXPLAIN')
                              AND    INSTR(FullText, 'DBMS_STATS') = 0              /* Aussschluss Table-Analyse*/
                              AND    Elapsed_Secs > ?
                      )
                      SELECT /*+ PARALLEL(p,4) PARALLEL(s,4) */
                             s.FullText, s.SQL_ID, p.Owner, p.Object_Name, p.Procedure_Name, p.Object_Type, s.Elapsed_Secs, s.Fundort
                      FROM   SQLs s,
                             ProcLines p
                      -- INSTR-Test vorab, da schneller als RegExp_Like
                      -- Match auf ProcName vorangestellt und gefolgt von keinem Buchstaben
                      WHERE  INSTR(s.FullText, p.SuchText) > 0
                      -- AND REGEXP_LIKE(s.FullText,'[^A-Z_]'||p.SuchText||'[^A-Z_]')
                      ORDER BY Elapsed_Secs DESC NULLS LAST
                      ",
             :parameter=>[
                 {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                 {:name=>'Minimum sum of elapsed time in seconds', :size=>8, :default=>100, :title=>'Minimum sum of elapsed time in second for considered SQL' },
             ]
         },
        {
             :name  => 'Probleme bei Nutzung Parallel Query: Parallele Statements mit serieller Abarbeitung von Teilprozessen',
             :desc  => "Teile von parallel verarbeiteten Statements können trotzdem seriell abgearbeitet werden und die Ergebnisse des Teilschrittes werden per Broadcast parallelisiert.
Für kleinere Datenstrukturen ist dies oft so gewollt, für größere Datenstrukturen fehlen möglicherweise PARALLEL-Anweisungen.
Das SQL listet alle Statements mit 'PARALLEL_FROM_SERIAL'-Verarbeitung nach Full-Scan auf Objekten als Kandidaten für vergessene Parallelisierung.",
             :sql=>  "SELECT /* DB-Tools Ramm PARALLEL_FROM_SERIAL in PQ */ * FROM (
                      SELECT /*+ NO_MERGE */ a.*, (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=a.DBID AND t.SQL_ID=a.SQL_ID) SQLText,
                             CASE
                             WHEN Operation='TABLE ACCESS' THEN (SELECT Num_Rows FROM DBA_Tables t WHERE t.Owner=Object_Owner AND t.Table_Name=Object_Name)
                             WHEN Operation='INDEX' THEN (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner=Object_Owner AND i.Index_Name=Object_Name)
                             ELSE NULL END Num_Rows
                      FROM (
                      SELECT /*+ ORDERED NO_MERGE */ p.DBID, p.SQL_ID, MIN(p.Operation) Operation,
                              MIN(p.Options) Options, MIN(p.Object_Owner) Object_Owner, MIN(p.Object_Name) Object_Name,
                              SUM(ss.Elapsed_Time_Delta)/1000000 Elapsed_Time_Secs,
                              SUM(ss.Executions_Delta) Executions--,
                      --        (SELECT SQL_Text FROM DBA_Hist_SQLText t WHERE t.DBID=p.DBID AND t.SQL_ID=p.SQL_ID) SQLText
                      FROM   (
                              SELECT /*+ NO_MERGE MATERIALIZE FIRST_ROWS ORDERED USE_NL(p1 p2) PARALLEL(p,4)  */ p.DBID, p.SQL_ID, p.Plan_Hash_Value,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Operation ELSE p2.Operation END Operation,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Options ELSE p2.Options END Options,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Object_Owner ELSE p2.Object_Owner END Object_Owner,
                                     CASE WHEN p1.Options LIKE '%FULL%' THEN p1.Object_Name ELSE p2.Object_Name END Object_Name
                              FROM (
                                      SELECT  DBID, SQL_ID,
                                              MAX(p.Plan_Hash_Value) KEEP (DENSE_RANK LAST ORDER BY p.Timestamp) Plan_Hash_Value,
                                              MAX(p.ID) KEEP (DENSE_RANK LAST ORDER BY p.Timestamp) ID
                                      FROM DBA_Hist_SQL_Plan p
                                      WHERE   p.Other_Tag = 'PARALLEL_FROM_SERIAL'
                                      GROUP BY DBID, SQL_ID
                                   ) p
                              LEFT OUTER JOIN DBA_Hist_SQL_Plan p1 ON (    p1.DBID=p.DBID
                                                                       AND p1.SQL_ID=p.SQL_ID
                                                                       AND p1.Plan_Hash_Value=p.Plan_Hash_Value
                                                                       AND p1.Parent_ID = p.ID)
                              LEFT OUTER JOIN DBA_Hist_SQL_Plan p2 ON (    p2.DBID=p1.DBID
                                                                       AND p2.SQL_ID=p1.SQL_ID
                                                                       AND p2.Plan_Hash_Value=p1.Plan_Hash_Value
                                                                       AND p2.Parent_ID = p1.ID)
                              WHERE   (p1.Options LIKE '%FULL%' OR p2.Options LIKE '%FULL%')
                              ) p
                      JOIN   DBA_Hist_SQLStat ss ON (ss.DBID=p.DBID AND ss.SQL_ID=p.SQL_ID AND ss.Plan_Hash_Value=p.Plan_Hash_Value)
                      JOIN   DBA_Hist_SnapShot s ON (s.Snap_ID=ss.Snap_ID AND s.DBID=ss.DBID AND s.Instance_Number=ss.Instance_Number)
                      WHERE  s.Begin_Interval_Time > SYSDATE-?
                      GROUP BY p.DBID, p.SQL_ID, p.Plan_Hash_Value
                      ) a)
                      ORDER BY Elapsed_Time_Secs*NVL(Num_Rows,1) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
            :name  => t(:dragnet_helper_63_name, :default=>'Parallel Query: Degree of parallelism (number of attached PQ servers) higher than limit for single SQL execution'),
            :desc  => t(:dragnet_helper_63_desc, :default=>'Number of avilable PQ servers is a limited resource, so default degree of parallelism is often to high for production use, especially on multi-core machines.
Overallocation of PQ servers may result in serial processing og other SQLs estimated to process in parallel.'),
            :sql=>   "SELECT Instance_Number, SQL_ID, MIN(Sample_Time) First_Occurrence, MAX(Sample_Time) Last_Occurrence,
                             COUNT(DISTINCT QC_Session_ID)    Different_Coordinator_Sessions,
                             SUM(Executions)                  SQL_Executions,
                             u.UserName,
                             SUM(10)                          Active_Seconds,
                             SUM(10*DOP)                      Elapsed_PQ_Seconds_Total,
                             MIN(DOP)                         Min_Degree_of_Parallelism,
                             MAX(DOP)                         Max_Degree_of_Parallelism,
                             ROUND(AVG(DOP))                  Avg_Degree_of_Parallelism
                      FROM   (
                              SELECT Instance_Number, QC_Instance_ID, qc_session_id, QC_Session_Serial#,
                               sql_id, MIN(sample_time) Sample_Time, COUNT(*) dop, MIN(User_ID) User_ID, COUNT(DISTINCT SQL_Exec_ID) Executions
                              FROM dba_hist_active_sess_history
                              WHERE  QC_Session_ID IS NOT NULL
                              AND    Sample_Time > SYSDATE - ?
                              GROUP BY Instance_Number, QC_Instance_ID, qc_session_id, QC_Session_Serial#, Sample_ID, SQL_ID
                              HAVING count(*) > 16
                             ) g
                      LEFT OUTER JOIN DBA_Users u ON U.USER_ID = g.User_ID
                      GROUP BY Instance_Number, SQL_ID, u.UserName
                      ORDER BY MAX(DOP) DESC
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=>t(:dragnet_helper_63_param_2_name, :default=>'Limit for number of PQ servers'), :size=>8, :default=>16, :title=>t(:dragnet_helper_63_param_2_hint, :default=>'Limit for number of PQ servers: exceedings of this value are shown here') },
            ]
        },
        {
             :name  => 'Identifikation von Statements mit wechselndem Ausführungsplan aus Historie',
             :desc  => 'mit dieser Selektion lassen sich aus den AWR-Daten Wechsel der Ausführungspläne unveränderter SQL‘s ermitteln.
Betrachtet wird dabei die aufgezeichnete Historie ausgeführter Statements
',
             :sql=>  "SELECT SQL_ID, Plan_Variationen \"Plan count\",
                             ROUND(Elapsed_Time_Secs_First_Plan) \"Elapsed time (sec.) first plan\",
                             Executions_First_Plan \"Execs. first plan\",
                             ROUND(Elapsed_Time_Secs_First_Plan/DECODE(Executions_First_Plan, 0, 1, Executions_First_Plan), 4) \"Secs. per exec first plan\",
                             ROUND(Elapsed_Time_Secs_Last_Plan) \"Elapsed time (sec.) last plan\",
                             Executions_Last_Plan \"Execs. last plan\",
                             ROUND(Elapsed_Time_Secs_Last_Plan/DECODE(Executions_Last_Plan, 0, 1, Executions_Last_Plan), 4) \"Secs. per exec last plan\",
                             First_Occurence_SQL \"First occurrence of SQL\", Last_Occurence_SQL \"Last Occurrence of SQL\",
                             Last_Occurrence_First_Plan \"Last occurrence of first plan\", First_Occurence_Last_Plan \"First occurrence of last plan\",
                             SUBSTR(SQL_Text,1, 200) \"SQL-Text\"
                      FROM   (
                              SELECT SQL_ID,
                                     (SELECT SQL_TExt FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID
                                     ) SQL_Text,
                                     COUNT(*) Plan_Variationen,
                                     MIN(Elapsed_Time_Secs) KEEP (DENSE_RANK FIRST ORDER BY First_Occurence) Elapsed_Time_Secs_First_Plan,
                                     MIN(Executions) KEEP (DENSE_RANK FIRST ORDER BY First_Occurence) Executions_First_Plan,
                                     MAX(Elapsed_Time_Secs) KEEP (DENSE_RANK LAST ORDER BY First_Occurence) Elapsed_Time_Secs_Last_Plan,
                                     MAX(Executions) KEEP (DENSE_RANK LAST ORDER BY First_Occurence) Executions_Last_Plan,
                                     TO_CHAR(MIN(First_Occurence), 'DD.MM.YYYY HH24:MI') First_Occurence_SQL,
                                     TO_CHAR(MAX(Last_Occurence), 'DD.MM.YYYY HH24:MI') Last_Occurence_SQL,
                                     TO_CHAR(MIN(Last_Occurence), 'DD.MM.YYYY HH24:MI') Last_Occurrence_First_Plan,
                                     TO_CHAR(MAX(First_Occurence), 'DD.MM.YYYY HH24:MI') First_Occurence_Last_Plan
                              FROM   (
                                      SELECT s.DBID, s.Instance_Number, s.SQL_ID,
                                             MIN(ss.Begin_Interval_Time) First_Occurence,
                                             MAX(ss.End_Interval_Time) Last_Occurence,
                                             SUM(Elapsed_Time_Delta)/1000000 Elapsed_Time_Secs,
                                             SUM(Executions_Delta) Executions
                                      FROM   DBA_Hist_SQLStat s
                                      JOIN   DBA_Hist_SnapShot ss ON ss.DBID=ss.DBID AND ss.Instance_number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                      WHERE ss.Begin_Interval_Time > SYSDATE-?
                                      GROUP BY s.DBID, s.Instance_Number, s.SQL_ID, s.Plan_Hash_Value
                                     ) s
                              GROUP BY DBID, Instance_Number, SQL_ID
                              HAVING COUNT(*) > 1
                             )
                      ORDER BY \"Secs. per exec last plan\"  * (Executions_First_Plan+Executions_Last_Plan) -
                               \"Secs. per exec first plan\" * (Executions_First_Plan+Executions_Last_Plan) DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
             :name  => 'Nested-Loop-Join auf große Tabellen mit großem Result des SQL (Test per SGA-Statement-Cache)',
             :desc  => 'Oft ausgeführte Nested-Loop-Operationen auf große (schwer zu cachende) Tabellen können Laufzeit-Treiber sein.
Für die angelisteten Statements ist die Variante „Hash-Join“ zu untersuchen.
Statement für jede RAC-Instanz einzeln ausführen, da sonst utopische Laufzeit bei Zugriff auf GV$-Tabellen.',
             :sql=>  "SELECT /* DB-Tools Ramm Nested Loop auf grossen Tabellen */ * FROM (
                      SELECT /*+ PARALLEL(p,2) PARALLEL(s,2) */
                             s.SQL_FullText, p.SQL_ID, p.Plan_Hash_Value, p.operation, p.Object_Type,  p.options, p.Object_Name,
                             ROUND(s.Elapsed_Time/1000000) Elapsed_Secs, s.Executions, s.Rows_Processed,
                             ROUND(s.Rows_Processed/DECODE(s.Executions,0,1,s.Executions),2) Rows_Per_Execution,
                             CASE WHEN p.Object_Type = 'TABLE' THEN (SELECT /*+ NO_MERGE */ Num_Rows FROM DBA_Tables t WHERE t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name)
                                  WHEN p.Object_Type LIKE 'INDEX%' THEN (SELECT /*+ NO_MERGE */ Num_Rows FROM DBA_Indexes i WHERE i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name)
                             END Num_Rows
                      FROM   (
                              WITH Plan AS (SELECT /*+ MATERIALIZE  */
                                                   p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.ID, p.Parent_ID
                                            FROM   V$SQL_Plan p
                                           )
                              SELECT /*+ NO_MERGE PARALLEL(pnl,4) PARALLEL(pt1,4) PARALLEL(pf,4) PARALLEL(pt2,4)*/ DISTINCT pnl.SQL_ID, pnl.Plan_Hash_Value,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Operation    ELSE pt2.Operation    END Operation,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Type  ELSE pt2.Object_Type  END Object_Type,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Options      ELSE pt2.Options      END Options,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Owner ELSE pt2.Object_Owner END Object_Owner,
                                     CASE WHEN pt1.Operation IN ('TABLE ACCESS', 'INDEX') THEN pt1.Object_Name  ELSE pt2.Object_Name  END Object_Name
                              FROM   Plan pnl -- Nested Loop-Zeile
                              JOIN   Plan pt1  ON  pt1.SQL_ID          = pnl.SQL_ID       -- zweite Zeile unter Nested Loop (iterativer Zugriff)
                                               AND pt1.Plan_Hash_Value = pnl.Plan_Hash_Value
                                               AND pt1.Parent_ID       = pnl.ID
                              JOIN   Plan pf  ON  pf.SQL_ID          = pt1.SQL_ID         -- erste Zeile unter Nested Loop (Datenherkunft)
                                              AND pf.Plan_Hash_Value = pt1.Plan_Hash_Value
                                              AND pf.Parent_ID       = pnl.ID
                                              AND pf.ID              < pt1.ID        -- 1. ID ist Herkunft, 2. ID ist Iteration
                              LEFT OUTER JOIN Plan pt2  ON  pt2.SQL_ID          = pnl.SQL_ID -- zweite Ebene der zweiten Zeile unter nested Loop
                                                        AND pt2.Plan_Hash_Value = pnl.Plan_Hash_Value
                                                        AND pt2.Parent_ID       = pt1.ID
                              WHERE  pnl.Operation = 'NESTED LOOPS'
                              AND    (    pt1.Operation IN ('TABLE ACCESS', 'INDEX')
                                      OR  pt2.Operation IN ('TABLE ACCESS', 'INDEX')
                                     )
                              AND    pt1.Operation NOT IN ('HASH JOIN', 'NESTED LOOPS', 'VIEW', 'MERGE JOIN', 'PX BLOCK')
                             ) p
                      JOIN   v$SQL s         ON  s.SQL_ID             = p.SQL_ID
                                             AND s.Plan_Hash_Value    = p.Plan_Hash_Value
                                             AND s.Rows_Processed/DECODE(s.Executions,0,1,s.Executions) > ? -- Schwellwert fuer mgl. Ineffizienz NestedLoop
                      )
                      ORDER BY Rows_Per_Execution*Num_Rows DESC NULLS LAST",
             :parameter=>[{:name=> 'Minimale Anzahl Rows processed / Execution', :size=>8, :default=>100000, :title=> 'Minimale Anzahl Rows processed / Execution als Schwellwert fuer mgl. Ineffizienz NestedLoop'}]
         },
        {
             :name  => 'Iteration im Nested-Loop-Join gegen Full-Scan-Operation',
             :desc  => 'Vielfache Ausführung von Full-Scan Operationen per Iteration in Nested Loop Join kann zu exorbitanten Blockzugriffen führen und damit  massiv CPU und I/O-Ressourcen beanspruchen sowie Cache Buffers Chains Latch-Waits provozieren.
Legitim ist ein solcher Zugriff allerdings, wenn steuerndes Result des Nested Loop einen oder wenige Records liefert.
Statement muss für jede RAC-Instanz separat angewandt werden, da wegen akzeptabler akzeptabler Laufzeit nur die aktuell angemeldete Instanz geprüft wird.',
             :sql=>  "SELECT p.Inst_ID, p.SQL_ID, s.Executions, s.Elapsed_Time/1000000 Elapsed_time_Secs, p.Child_Number, p.Plan_Hash_Value,
                             p.Operation, p.Options, p.Object_Owner, Object_Name, p.ID, s.SQL_FullText
                      FROM   (
                              WITH Plan AS (SELECT /*+ MATERIALIZE  */
                                                   p.Inst_ID, p.SQL_ID, p.Child_Number, p.Plan_Hash_Value,
                                                   p.Inst_ID||'|'||p.SQL_ID||'|'||p.Child_Number||'|'||p.Plan_Hash_Value SQL_Ident,
                                                   p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.ID, p.Parent_ID
                                            FROM   gV$SQL_Plan p
                                           )
                              SELECT pnl2.*    -- Daten der zweiten Zeile unter Nested Loop (ueber die iteriert wird)
                              FROM   Plan pnl -- Nested Loop-Zeile
                              JOIN   Plan pnl1 ON  pnl1.SQL_Ident      = pnl.SQL_Ident      -- erste Zeile unter Nested Loop (Datenherkunft)
                                               AND pnl1.Parent_ID      = pnl.ID
                              JOIN   Plan pnl2 ON  pnl2.SQL_Ident      = pnl1.SQL_Ident       -- zweite Zeile unter Nested Loop (iterativer Zugriff)
                                               AND pnl2.Parent_ID      = pnl.ID
                                               AND pnl1.ID             < pnl2.ID             -- 1. ID ist Herkunft, 2. ID ist Iteration des NL
                              LEFT OUTER JOIN   Plan sub1 ON sub1.SQL_Ident = pnl2.SQL_Ident AND sub1.Parent_ID = pnl2.ID
                              LEFT OUTER JOIN   Plan sub2 ON sub2.SQL_Ident = pnl2.SQL_Ident AND sub2.Parent_ID = sub1.ID
                              LEFT OUTER JOIN   Plan sub3 ON sub3.SQL_Ident = pnl2.SQL_Ident AND sub3.Parent_ID = sub2.ID
                              LEFT OUTER JOIN   Plan sub4 ON sub4.SQL_Ident = pnl2.SQL_Ident AND sub4.Parent_ID = sub3.ID
                              LEFT OUTER JOIN   Plan sub5 ON sub5.SQL_Ident = pnl2.SQL_Ident AND sub5.Parent_ID = sub4.ID
                              WHERE  pnl.Operation = 'NESTED LOOPS'
                              AND  (    pnl2.Options LIKE '%FULL%'
                                     OR sub1.Options LIKE '%FULL%'
                                     OR sub2.Options LIKE '%FULL%'
                                     OR sub3.Options LIKE '%FULL%'
                                     OR sub4.Options LIKE '%FULL%'
                                     OR sub5.Options LIKE '%FULL%'
                                   )
                             ) p
                      JOIN   gv$SQL s ON  s.Inst_ID         = p.Inst_ID
                                      AND s.SQL_ID          = p.SQL_ID
                                      AND s.Child_Number    = p.Child_Number
                                      AND s.Plan_Hash_Value = p.Plan_Hash_Value
                      ORDER BY Elapsed_Time DESC NULLS LAST",
         },
         {
             :name  => 'Implizite Konvertierungen per INTERNAL_FUNCTION',
             :desc  => 'Auslöser von impliziten Typ-Konvertierungen ist oftmals versehentlich mit falschem Typ gebundene Bindevariable.
Die Konvertierung verursacht möglicherweise unnötig CPU-Last auf der DB-Maschine.
Durch die Ansprache der Spalte per INTERNAL_FUNCTION statt direkt wird die mögliche Nutzung von Indizes für den Zugriff verhindert.
In diesen Fällen sollte tunlichst der entsprechende Datentyp für die Variablenbindung verwendet werden.
Statement muss für jede RAC-Instanz separat angewandt werden, da wegen akzeptabler akzeptabler Laufzeit nur die aktuell angemeldete Instanz geprüft wird.',
             :sql=>  "SELECT /*+ ORDERED USE_HASH(p s) */
                              SQL_FullText, s.SQL_ID,
                              s.Elapsed_Time/1000000 Elasped_Secs,
                              CPU_Time/1000000 CPU_Secs,
                              Executions, Rows_Processed,
                              p.Filter_Predicates
                       FROM   (SELECT /*+ NO_MERGE */ * FROM v$SQL_PLan WHERE Filter_Predicates LIKE '%INTERNAL_FUNCTION%') p
                       JOIN   (SELECT /*+ NO_MERGE */ * FROM v$SQLArea) s ON s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                       ORDER BY Elapsed_Time DESC NULLS LAST
             ",
         },
         {
             :name  => 'Lang laufende Full Table Scans durch IS NULL-Abfrage (ab 11g)',
             :desc  => 'Die Abfrage mit IS NULL führt oftmals zu FullTableScan obwohl evtl. nur wenige NULL-Records selektiert werden.
Lösung kann sein: Indizierung des mit IS NULL abgefragten Feldes durch speziellen Index, der auch NULL-Values enthält.
Beispiel: INDEX(Column,0)',
             :sql=>  "SELECT p.Inst_ID, p.SQL_ID, MIN(h.Sample_Time) First_Occurrence, MAX(h.Sample_Time) Last_Occurrence, COUNT(*) Wait_Time_Secs,
                             p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.Filter_Predicates
                      FROM   gv$SQL_Plan p
                      JOIN   gv$Active_Session_History h ON h.SQL_ID=p.SQL_ID AND h.Inst_ID=p.Inst_ID AND h.SQL_Plan_Hash_Value = p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                      WHERE  UPPER(Filter_Predicates) LIKE '%IS NULL%'
                      AND    Options LIKE '%FULL'
                      GROUP BY p.Inst_ID, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Type, p.Object_Owner, p.Object_Name, p.Filter_Predicates
                      ORDER BY COUNT(*) DESC
             ",
         },
         {
             :name  => t(:dragnet_helper_55_name, :default => 'Problematic usage of cartesian joins (from current SGA)'),
             :desc  => t(:dragnet_helper_55_desc, :default => 'Cartesian joins may be problematic in case of joining two large results without join condition.
Problems may be targeted by execution time of SQL or size of affected tables.
Results are from GV$SQL_Plan'),
             :sql=>  "SELECT /*+ USE_HASH(p s i t) LEADING(p) */ p.Inst_ID, p.SQL_ID, p.Child_Number, p.Operation, p.Options, p.Object_Owner, p.Object_Name, NVL(i.Num_Rows, t.Num_Rows) Num_Rows,
                             s.Executions, s.Elapsed_Time/1000000 Elapsed_Time_Secs,
                             p.ID Line_ID, p.Parent_ID
                      FROM   (WITH plans AS (SELECT /*+ NO_MERGE */ *
                                             FROM   gv$SQL_Plan
                                             WHERE  (Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number) IN (SELECT Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number
                                                                                                         FROM gv$SQL_Plan
                                                                                                         WHERE  options = 'CARTESIAN'
                                                                                                        )
                                            )
                              SELECT /*+ NO_MERGE */ Level, plans.*
                              FROM   plans
                              CONNECT BY PRIOR Inst_ID = Inst_ID AND PRIOR SQL_ID=SQL_ID AND  PRIOR Plan_Hash_Value = Plan_Hash_Value AND  PRIOR child_number = child_number AND PRIOR  id = parent_id AND PRIOR Object_Name IS NULL -- Nur Nachfolger suchen so lange Vorgänger kein Object_Name hat
                              START WITH options = 'CARTESIAN'
                             ) p
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Child_Number, Executions, Elapsed_Time
                              FROM gv$SQL
                             ) s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number
                      LEFT OUTER JOIN DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name
                      LEFT OUTER JOIN DBA_Tables t  ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                      WHERE Object_Name IS NOT NULL  -- Erstes Vorkommen von ObjectName in der Parent-Hierarchie nutzen
                      AND   Object_Owner != NVL(?, 'Hugo')
                      AND   Elapsed_Time/1000000 > ?
                      ORDER BY s.Elapsed_Time DESC, s.SQL_ID, s.Child_Number
            ",
            :parameter=>[
               {:name=>t(:dragnet_helper_55_param1_name, :default=>'Exclusion of object owners'), :size=>30, :default=>'SYS', :title=>t(:dragnet_helper_55_param1_desc, :default=>'Exclusion of single object owners from result') },
               {:name=>t(:dragnet_helper_55_param2_name, :default=>'Minimum total execution time of SQL (sec.)'), :size=>10, :default=>100, :title=>t(:dragnet_helper_55_param2_desc, :default=>'Minimum total execution time of SQL in SGA in seconds') },
            ]
         },
         {
             :name  => t(:dragnet_helper_56_name, :default => 'Problematic usage of cartesian joins (from AWR history)'),
             :desc  => t(:dragnet_helper_56_desc, :default => 'Cartesian joins may be problematic in case of joining two large results without join condition.
Problems may be targeted by execution time of SQL or size of affected tables.
Results are from DBA_Hist_SQL_Plan'),
             :sql=>  "SELECT ps.*,
                             (SELECT Num_Rows FROM DBA_Indexes i WHERE i.Owner = ps.Object_Owner AND i.Index_Name = ps.Object_Name) Num_Rows_Index,
                             (SELECT Num_Rows FROM  DBA_Tables t WHERE t.Owner = ps.Object_Owner AND t.Table_Name = ps.Object_Name) Num_Rows_Table
                      FROM   (
                              SELECT /*+ LEADING(p) */ s.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.ID Line_ID, p.Parent_ID,
                                     SUM(s.Executions_Delta) Executions, SUM(s.Elapsed_Time_Delta/1000000) Elapsed_Time_Secs
                              FROM   (WITH plans AS (SELECT /*+ NO_MERGE LEADING(i) USE_NL(i o) */ o.*
                                                     FROM   (SELECT /*+ PARALLEL(i,2) */ DISTINCT DBID, SQL_ID, Plan_Hash_Value FROM DBA_Hist_SQL_Plan i WHERE options = 'CARTESIAN') i
                                                     JOIN   DBA_Hist_SQL_Plan o ON o.DBID=i.DBID AND o.SQL_ID=I.SQL_ID AND o.Plan_Hash_Value = i.Plan_Hash_Value
                                                    )
                                      SELECT /*+ NO_MERGE */ Level, plans.*
                                      FROM   plans
                                      CONNECT BY PRIOR DBID = DBID AND PRIOR SQL_ID=SQL_ID AND  PRIOR Plan_Hash_Value = Plan_Hash_Value AND PRIOR  id = parent_id AND PRIOR Object_Name IS NULL  -- Nur Nachfolger suchen so lange Vorgänger kein Object_Name hat
                                      START WITH options = 'CARTESIAN'
                                     ) p
                              JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = p.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE Object_Name IS NOT NULL -- Erstes Vorkommen von ObjectName in der Parent-Hierarchie nutzen
                              AND   ss.Begin_Interval_Time > SYSDATE - ?
                              AND   p.Object_Owner != NVL(?, 'Hugo')
                              GROUP BY s.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.ID, p.ID, p.Parent_ID
                             ) ps
                      WHERE   Elapsed_Time_Secs > ?
                      ORDER BY Elapsed_Time_Secs DESC, SQL_ID, Plan_Hash_Value
                      ",
             :parameter=>[
                 {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                 {:name=>t(:dragnet_helper_56_param1_name, :default=>'Exclusion of object owners'), :size=>30, :default=>'SYS', :title=>t(:dragnet_helper_56_param1_desc, :default=>'Exclusion of single object owners from result') },
                 {:name=>t(:dragnet_helper_56_param2_name, :default=>'Minimum total execution time of SQL (sec.)'), :size=>10, :default=>100, :title=>t(:dragnet_helper_56_param2_desc, :default=>'Minimum total execution time of SQL in SGA in seconds') },
             ]
         },
      ]
  end

  ###################################################################################################################

  def dragnet_sqls_tuning_sga_pga
      [
        {
             :name  => 'Identifikation von HotBlocks im DB-Cache: Viele Zugriffe auf kleine Objekte',
             :desc  => "Statements mit hochfrequent gelesenen Blöcken im DB-Cache laufen Gefahr, durch 'cache buffers chains'-LatchWaits ausgebremst zu werden.
Die Abfrage ermittelt Objekte mit verdächtig hohen Block-Zugriffen im Verhältnis zur Größe (viele Zugriffe auf wenige Blöcke).",
             :sql=>  "SELECT /* DB-Tools Ramm Hot-Blocks im DB-Cache */*
                             FROM
                             (
                              SELECT /*+ NO_MERGE USE_HASH(o s) */
                                     s.Instance_Number Inst, o.Owner, o.Object_Name, o.SubObject_Name,
                                     o.Object_Type,
                                     s.Logical_Reads,
                                     Num_Rows,
                                     ROUND(s.Logical_Reads/Num_Rows,2) \"LReads/Row\",
                                     Buffer_Busy_Waits \"BufBusyW\", DB_Block_Changes \"BlockChg\", Physical_Reads \"Phys.Reads\",
                                     Physical_Writes \"Phys.Writes\", Physical_Reads_Direct \"Phys.Rd.Dir\",
                                     Physical_Writes_Direct \"Phys.Wr.Dir\", ITL_Waits, Row_Lock_Waits
                              FROM   (SELECT /*+ NO_MERGE */
                                             s.Instance_Number, s.Obj#, SUM(s.Logical_Reads_Delta) Logical_Reads,
                                             SUM(Buffer_Busy_Waits_Delta) Buffer_Busy_Waits,
                                             SUM(DB_Block_Changes_Delta) DB_Block_Changes,
                                             SUM(Physical_Reads_Delta) Physical_Reads,
                                             SUM(Physical_Writes_Delta) Physical_Writes,
                                             SUM(Physical_Reads_Direct_Delta) Physical_Reads_Direct,
                                             SUM(Physical_Writes_Direct_Delta) Physical_Writes_Direct,
                                             SUM(ITL_Waits_Delta) ITL_Waits,
                                             SUM(Row_Lock_Waits_Delta) Row_Lock_Waits
                                      FROM   DBA_Hist_Seg_Stat s,
                                             DBA_Hist_Snapshot t
                                      WHERE  t.DBID            = s.DBID
                                      AND    t.Instance_Number = s.Instance_Number
                                      AND    t.Snap_ID         = s.Snap_ID
                                      AND    t.Begin_Interval_Time > SYSDATE-? /* Anzahl Tage der Betrachtung rueckwirkend */
                                      GROUP BY s.Instance_Number, s.Obj#
                                     )s,
                                     (SELECT /*+ NO_MERGE */
                                             Owner, Object_Name, SubObject_Name, Object_Type, Object_ID,
                                             CASE
                                             WHEN Object_Type = 'TABLE' THEN (SELECT Num_Rows FROM DBA_Tables a
                                                                                WHERE a.Owner=o.Owner AND a.Table_Name=o.Object_Name)
                                             WHEN Object_Type = 'INDEX' THEN (SELECT Num_Rows FROM DBA_Indexes a
                                                                                WHERE a.Owner=o.Owner AND a.Index_Name=o.Object_Name)
                                             WHEN Object_Type = 'TABLE PARTITION' THEN (SELECT Num_Rows FROM DBA_Tab_Partitions a
                                                                                WHERE a.Table_Owner=o.Owner AND a.Table_Name=o.Object_Name AND a.Partition_Name=o.SubObject_Name)
                                             WHEN Object_Type = 'INDEX PARTITION' THEN (SELECT Num_Rows FROM DBA_Ind_Partitions a
                                                                                WHERE a.Index_Owner=o.Owner AND a.Index_Name=o.Object_Name AND a.Partition_Name=o.SubObject_Name)
                                             END Num_Rows
                                      FROM   DBA_Objects o
                                      WHERE  Object_Type IN ('TABLE', 'TABLE PARTITION', 'INDEX', 'INDEX PARTITION')
                                     ) o
                              WHERE  o.Object_ID = s.Obj#
                              AND    o.Num_Rows IS NOT NULL
                              AND    o.Num_Rows > 0               /* gewichtete Aussage wird wertlos*/
                              AND    s.Logical_Reads > 0
                              ORDER BY Logical_Reads/Num_Rows DESC NULLS LAST
                             ) s
                      WHERE Num_Rows < ?",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Maximale Anzahl Rows der Table', :size=>8, :default=>200, :title=> 'Maximale Anzahl Rows der betrachteten Table für Aufnahme in Selektion'}]
         },
        {
             :name  => 'Identifikation von HotBlocks im DB-Cache: Suboptimale Indizes',
             :desc  => 'Indizes mit hoher Datenfluktuation und Schieflage (z.B. fortlaufende Nummern) scannen nach Record-Löschungen sukzessive mehr DB-Blöcke beim Zugriff.
Problematisch ist insbesondere Zugriff auf erste Records solcher moving windows.
Evtl. notwendige Reorganisation kann z.B. per ALTER INDEX COALESCE erfolgen.',
             :sql=>  "SELECT * FROM (
                      SELECT /*+ NO_MERGE MATERIALIZE */ p.Inst_ID \"Inst\", p.SQL_ID, p.Child_Number \"Child Number\", s.Executions \"Executions\",
                             s.Buffer_Gets \"Buffer gets\", s.Rows_Processed \"Rows processed\",
                             ROUND(s.Rows_Processed/s.Executions,2) \"Rows per Exec.\",
                             ROUND(s.Buffer_Gets/s.Rows_Processed)  \"Buffer Gets per Row\",
                             s.SQL_Text, s.SQL_FullText
                      FROM   (
                              SELECT p.Inst_ID, p.SQL_ID, p.Child_Number
                              FROM   gv$SQL_Plan p
                              WHERE  Operation NOT IN ('PARTITION HASH')
                              AND    Options NOT IN ('STOPKEY')  -- RowNum-Abgrenzung ausfiltern
                              GROUP BY p.Inst_ID, p.SQL_ID, p.Child_Number
                              HAVING
                              -- Ausfuehrungsplan hat genau einen Index-Zugriff ohne Filter
                                     SUM(CASE WHEN p.Operation = 'INDEX' AND p.Options in ('RANGE SCAN', 'UNIQUE SCAN')
                                         THEN 1 ELSE 0 END
                                        ) = 1
                              -- Keine Filter
                              AND    SUM(CASE WHEN P.FILTER_PREDICATES IS NOT NULL
                                         THEN 1 ELSE 0 END
                                        ) = 0
                            -- Keine Gruppenfunktionen
                              AND    SUM(CASE WHEN p.ID = 1 AND p.Options IN ('GROUP BY', 'AGGREGATE')
                                         THEN 1 ELSE 0 END
                                        ) = 0
                              AND    COUNT(*) < ?
                             ) p
                      JOIN   gv$SQL s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number
                      WHERE  s.Rows_Processed > 0 -- Nur dann sinnvolle Werte
                      AND    s.Executions     > ? -- Nur relevante Ausfuehrungen
                      AND    s.Rows_Processed > s.Executions/? -- Nur dann sinnvolle Werte
                      )
                      WHERE LENGTH(REGEXP_REPLACE(SQL_Text, '[^:]','')) < ?  -- Anzahl Bindevariablen < x
                      AND    \"Buffer Gets per Row\" > ?                         -- nur problematische anzeigen
                      ORDER BY \"Buffer Gets per Row\" * \"Rows processed\" DESC NULLS LAST",
             :parameter=>[{:name=> 'Maximale Anzahl Operationen im Execution Plan', :size=>8, :default=>5, :title=> 'Maximale Anzahl Operationen im Execution Plan des SQL'},
                          {:name=> 'Minimale Anzahl Executions', :size=>8, :default=>100, :title=> 'Minimale Anzahl Executions für Aufnahme in Selektion'},
                          {:name=> 'Maximale Anzahl Bindevariablen', :size=>8, :default=>5, :title=> 'Maximale Anzahl Bindevariablen im Statement'},
                          {:name=> 'Minimale Anzahl Rows processed / Execution', :size=>8, :default=>2, :title=> 'Minimale Anzahl Rows processed / Execution'},
                          {:name=> 'Minimale Anzahl Buffer gets / Row', :size=>8, :default=>5, :title=> 'Minimale Anzahl Buffer gets per Row'}]
         },
        {
             :name  => 'Prüfung der Notwendigkeit des Updates indizierter Spalten',
             :desc  => 'Das Update indizierter Spalten einer Tabelle kostet Aufwand für Index-Maintenance (Entfernen und Neueinstellen des Index-Eintrages) auch wenn sich der Inhalt des Feldes gar nicht geändert hat.
Unter diesem Aspekt ist es sinnvoll, indizierte Spalten häufig upzudatender Tabellen deren Inhalte sich nie ändern sollten aus dem Update-Statement zu entfernen.
Dies gilt insbesondere für  dynamisch generierte Statements z.B. aus OR-Mappern, die per Default alle Spalten einer Tabelle enthalten.',
             :sql=>  "SELECT * FROM (
                      SELECt /*+ ORDERED */ p.*, t.SQL_Text, i.Column_Name,
                            (SELECT SUM(Executions_Delta) FROM DBA_Hist_SQLStat st
                            WHERE st.DBID=p.DBID AND st.SQL_ID=p.SQL_ID
                            ) Executions,
                            (SELECT SUM(Rows_Processed_Delta) FROM DBA_Hist_SQLStat st
                            WHERE st.DBID=p.DBID AND st.SQL_ID=p.SQL_ID
                            ) Rows_Processed
                      FROM   (
                                  SELECT /*+ NO_MERGE PARALLEL(p) */ DBID, SQL_ID, Object_Owner, Object_Name
                                  FROM   DBA_Hist_SQL_Plan p
                                  WHERE Operation = 'UPDATE'
                                  AND     Timestamp > SYSDATE-?
                                  ) p,
                                  DBA_Hist_SQLText t,
                                  (SELECt /*+ NO_MERGE */ Table_Owner, Table_Name, Column_Name FROM DBA_Ind_Columns
                                  ) i
                      WHERE t.DBID              = p.DBID
                      AND     t.SQL_ID          = p.SQL_ID
                      AND     i.Table_Owner = p.Object_Owner
                      AND     i.Table_Name   = p.Object_Name
                      AND     REGEXP_LIKE(
                                         SUBSTR(UPPER(t.SQL_Text), INSTR(UPPER(t.SQL_Text), 'SET'), INSTR(UPPER(t.SQL_Text), 'WHERE')-INSTR(UPPER(t.SQL_Text), 'SET')),
                                         '[ ,]'||i.Column_Name||'[ =]'
                                        )
                      )
                      WHERE Rows_Processed > ?
                      ORDER BY Rows_Processed DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                          {:name=> 'Minimale Anzahl Rows processed', :size=>8, :default=>10000, :title=> 'Minimale Anzah Rows processed für Aufnahme in Selektion'}]
         },
        {
             :name  => 'System- Statistiken: Prüfung auf aktuelle Analyze-Info',
             :desc  => 'Für Cost-based Optimizer sollten System-Statistiken hinreichend aktuell sein und die Realität beschreiben',
             :sql=> 'SELECT * FROM sys.Aux_Stats$',
         },
        {
             :name  => 'Objekt-Statistiken: Prüfung auf aktuelle Analyze-Info (Tables)',
             :desc  => 'Für Cost-based Optimizer sollten Objekt-Statistiken hinreichend aktuell sein',
             :sql=>  "SELECT /* DB-Tools Ramm Tabellen ohne bzw. mit veralteter Statistik */ t.Owner, t.Table_Name, t.Num_Rows, t.Last_Analyzed,
                             ROUND(s.MBytes,2) MBytes
                      FROM   DBA_Tables t
                      JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
                      WHERE  (Last_Analyzed IS NULL OR Last_Analyzed < SYSDATE-?)
                      AND    t.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'PERFSTAT', 'PATCH', 'NOALYZE', 'EXFSYS', 'SERVER', 'FLAGENT',
                                           'DB_MONITORING', 'DBSNMP', 'WMSYS', 'DBMSXSTATS', 'SYSMAN', 'TOOL', 'AFARIA', 'MONITOR',
                                           'XDB', 'MDSYS', 'ORDSYS', 'DMSYS', 'CTXSYS', 'TSMSYS')
                      AND    t.Owner NOT LIKE 'DBA%'
                      AND    t.Owner NOT LIKE 'PATROL%'
                      AND    Temporary = 'N'
                      ORDER BY s.MBytes DESC",
             :parameter=>[{:name=> 'Mindestalter existierender Analyse in Tagen', :size=>8, :default=>100, :title=> 'Falls Analyze-Info existiert, ab welchem Alter Aufnahme in Selektion'}]
         },
        {
             :name  => 'Objekt-Statistiken: Prüfung auf aktuelle Analyze-Info (Indizes)',
             :desc  => 'Für Cost-based Optimizer sollten Objekt-Statistiken hinreichend aktuell sein',
             :sql=>  "SELECT /* DB-TOoLs Ramm Indizes ohne bzw. mit veralteter Statistik */ i.Owner, i.Table_Name, i.Index_Name, i.Num_Rows, i.Last_Analyzed
                      FROM   DBA_Indexes i
                      JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                      JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name) s ON s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
                      WHERE  (i.Last_Analyzed IS NULL OR i.Last_Analyzed < SYSDATE-?)
                      AND    i.Owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'PERFSTAT', 'PATCH', 'NOALYZE', 'EXFSYS', 'SERVER', 'FLAGENT',
                                           'DB_MONITORING', 'DBSNMP', 'WMSYS', 'DBMSXSTATS', 'SYSMAN', 'TOOL', 'AFARIA', 'MONITOR', 'XDB', 'MDSYS', 'ORDSYS',
                                           'CTXSYS', 'TSMSYS')
                      AND    i.Owner NOT LIKE 'DBA%'
                      AND    i.Owner NOT LIKE 'PATROL%'
                      AND    t.Temporary = 'N'
                      ORDER BY s.MBytes DESC",
             :parameter=>[{:name=> 'Mindestalter existierender Analyse in Tagen', :size=>8, :default=>100, :title=> 'Falls Analyze-Info existiert, ab welchem Alter Aufnahme in Selektion'}]
         },
        {
             :name  => 'PGA-Auslastung: Historische Auslastung PGA-Strukturen',
             :desc  => 'Unzureichende Bereitstellung PGA für Sort-/Hash-Operationen führt zu Auslagern auf TEMP-Tablespace mit entsprechenden Performance-Auswirkungen.',
             :sql=>  "SELECT /*+ DB-Tools Ramm - PGA-Historie*/
                             ss.Begin_Interval_Time, p.Instance_Number,
                             ROUND(MAX(DECODE(p.Name, 'aggregate PGA target parameter'      , p.Value, 0))/(1024*1024)) \"PGA Aggregate Target (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'aggregate PGA auto target'           , p.Value, 0))/(1024*1024)) \"PGA Auto Target (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'global memory bound'                 , p.Value, 0))/(1024*1024)) \"global memory bound (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA inuse'                     , p.Value, 0))/(1024*1024)) \"total PGA inuse (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA allocated'                 , p.Value, 0))/(1024*1024)) \"total PGA allocated (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total freeable PGA memory'           , p.Value, 0))/(1024*1024)) \"total freeable PGA memory (MB)\",
                             MAX(DECODE(p.Name, 'process count'                             , p.Value, 0))              \"process count\",
                             MAX(DECODE(p.Name, 'max processes count'                       , p.Value, 0))              \"max processes count\",
                             ROUND(MAX(DECODE(p.Name, 'PGA memory freed back to OS'         , p.Value, 0))/(1024*1024)) \"PGA mem freed back (MB kum.)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA used for auto workareas'   , p.Value, 0))/(1024*1024)) \"total PGA Used Auto (MB)\",
                             ROUND(MAX(DECODE(p.Name, 'total PGA used for manual workareas' , p.Value, 0))/(1024*1024)) \"total PGA used manual (MB)\",
                             MAX(DECODE(p.Name, 'over allocation count'                     , p.Value, 0)) -            -- Subtraktion Vorgaenger fuer Delta
                             (SELECT Value FROM DBA_hist_PgaStat i WHERE i.DBID=p.DBID AND i.Snap_ID=p.Snap_ID-1 AND I.INSTANCE_NUMBER = p.Instance_Number AND i.Name =  'over allocation count') \"over allocation count\",
                             MAX(DECODE(p.Name, 'cache hit percentage'   , p.Value, 0))                                 \"cache hit pct. (since startup)\"
                      FROM   DBA_hist_PgaStat p
                      JOIN   DBA_Hist_Snapshot ss ON ss.DBID = p.DBID AND ss.Instance_Number = p.Instance_Number AND ss.Snap_ID = p.Snap_ID
                      WHERE  p.Instance_Number = 1
                      AND    ss.Begin_Interval_Time > SYSDATE-?
                      GROUP BY ss.Begin_Interval_Time, p.Instance_Number, p.DBID, p.Snap_ID
                      ORDER BY ss.Begin_Interval_Time",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
             :name  => 'Konkurrenz bzgl. Speicher, Latches: Unzureichend gecachte Sequences',
             :desc  => 'Das Nachlesen von Sequence-Werten / Fuellen des Sequence-Caches ist verbunden mit Schreiben in Dictionary sowie Abgleich der Strukturen zwischen RAC-Instanzen.
    Zu hochfrequenter Zugriff auf Dictionary-Strukturen der Sequences führt zu diversen unnötigen Wartesituationen, daher fachlich und technisch sinnvolle Cache-Größen definieren für Sequences.',
             :sql=>  "SELECT /* DB-Tools Ramm Unzureichend gecachte Sequences */ *
                      FROM   DBA_Sequences
                      WHERE  Sequence_Owner NOT IN ('SYS', 'SYSTEM')
                      ORDER  By Last_Number/DECODE(Cache_Size,0,1,Cache_Size) DESC NULLS LAST",
         },
        {
             :name  => 'Konkurrenz bzgl. Speicher, Latches: Überblick über Sequence-Nutzung',
             :desc  => 'Wenn in Applikation gecacht werden kann, müssen Sequences nicht einzeln von DB gelesen werden.
    Dies reduziert DB-Roundtrips der Applikation und wird hier bewertet.',
             :sql=>  "SELECT /* DB-Tools Ramm  Ueberblick Sequence-Nutzung */ *
                      FROM   (
                              SELECT ROUND(Executions/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Executions_per_Day,
                                     ROUND(Rows_Processed/CASE WHEN (Last_Active_Time - First_Load_Time) < 1 THEN 1 ELSE Last_Active_Time - First_Load_Time END) Rows_Processed_per_Day,
                                     x.*
                              FROM   (
                                      SELECT /*+ ORDERED USE_HASH(p a s) */
                                             p.Inst_ID, a.Executions, a.Rows_Processed,
                                             ROUND(a.Rows_Processed/a.Executions,2) Rows_Per_Exec,
                                             TO_DATE(a.First_Load_Time, 'YYYY-MM_DD/HH24:MI:SS') First_Load_Time, a.Last_Active_Time,
                                             p.Object_Owner, p.Object_Name, s.Cache_Size,
                                             a.SQL_ID, a.SQL_Text
                                      FROM   (SELECT /*+ NO_MERGE */ * FROM gv$SQL_Plan WHERE Operation = 'SEQUENCE') p
                                      JOIN   (SELECT /*+ NO_MERGE */ * FROM gV$SQL WHERE Executions > 0) a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID AND a.Child_Number = p.Child_Number
                                      JOIN   (SELECT /*+ NO_MERGE */ * FROM DBA_Sequences) s ON s.Sequence_Owner = p.Object_Owner AND s.Sequence_Name = p.Object_Name
                                     ) x
                             )
                      ORDER BY Executions_per_Day DESC NULLS LAST"
         },
        {
             :name  => 'Aktive Sessions (AWR-Historie)',
             :desc  => 'Die Anzahl der zu einem Zeitpunkt aktiven Sessions lässt Rückschlüsse auf Systemlast zu
    Die Peaks der gleichzeitig aktiven Sessions sollte Grundlage für die Bemessung von Session-Pools (z.B. von Application-Servern) darstellen.',
             :sql=>  "SELECT /*+ PARALLEL(s,4) DB-Tools Ramm: aktive Sessions */
                             Sample_Time, count(*) \"Active Sessions\"
                      FROM   DBA_hist_Active_Sess_History s
                      WHERE  Sample_Time >SYSDATE - ?
                      AND    Instance_Number = ?
                      GROUP BY Sample_Time
                      ORDER BY 1",
             :parameter=>[
                 {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                 {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}
             ]
         },
        {
             :name  => 'Parse-Aktivität',
             :desc  => 'Folgende Stmts. beurteilen Verhältnis von parses zu executes.
    Bei hochfrequenten Parses sollten Alternativen untersucht werden:
    - Wiederverwendung geparster Statements in Applikation
    - Nutzung von Statements-Caches auf Ebene Application-Server bzw. JDBC-Treiber
    - Nutzung session cached cursors-Feature der DB',
             :sql=>  "SELECT /* DB-Tools Ramm Parse-Ratio Einzelwerte */ s.*, ROUND(Executions/DECODE(Parses, 0, 1, Parses),2) \"Execs/Parse\"
                      FROM   (
                              SELECT s.SQL_ID, s.Instance_Number, Parsing_schema_Name, SUM(s.Executions_Delta) Executions,
                                     SUM(s.Parse_Calls_Delta) Parses
                              FROM   DBA_Hist_SQLStat s
                              JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                              WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                              GROUP BY s.SQL_ID, s.Instance_Number, Parsing_schema_Name
                             ) s
                      ORDER BY Parses DESC NULLS LAST",
             :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
         },
        {
             :name  => t(:dragnet_helper_3_12_name, :default=> 'Non-optimal database configuration parameters'),
             :desc  => t(:dragnet_helper_3_12_desc, :default=> 'Detection of non-optimal or incompatible database parameters'),
             :sql=>  "SELECT /* DB-Tools Ramm DB-Parameter */
                             Inst_ID, Name, Value, 'Value should be 0 if cursor_sharing is used because lookup to session cached cursors is done before converting literals to bind variables' Description
                      FROM   gv$Parameter p
                      WHERE  Name = 'session_cached_cursors'
                      AND    Value != '0'
                      AND    EXISTS (SELECT 1 FROM gv$Parameter pi WHERE pi.Inst_ID=p.Inst_ID AND pi.Name='cursor_sharing' AND pi.value!='EXACT' )
                     ",
         },
      ]
  end


  def sqls_cursor_redundancies
    [
        {
             :name  => 'Fehlende Nutzung von Bindevariablen',
             :desc  => 'Nutzung von Literalen statt Bindevariablen für Filterbedingungen ohne Kompensierung durch cursor_sharing-Parameter führt zu hohen Parse-Zahlen und Flutung der SQL-Area in der SGA.
Das folgende Statement sucht grob nach diesbezüglichen Ausreissern.
Optional muss die Länge des untersuchten Substrings variert werden.',
             :sql=>  "WITH Len AS (SELECT ? Substr_Len FROM DUAL)
                       SELECT g.*, s.SQL_Text \"Beispiel SQL-Text\"
                       FROM   (
                               SELECT COUNT(*) Variationen, Inst_ID, MIN(Parsing_Schema_Name) UserName, COUNT(DISTINCT Parsing_Schema_Name) Anzahl_User,
                                      SUBSTR(s.SQL_Text, 1, Len.Substr_Len) SubSQL_Text,
                                      ROUND(SUM(Sharable_Mem+Persistent_Mem+Runtime_Mem)/(1024*1024),3) \"Memory (MB)\",
                                      MIN(s.SQL_ID) SQL_ID,
                                      MIN(TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS')) Min_First_Load,
                                      MIN(Last_Load_Time) Min_Last_Load,
                                      MAX(Last_Load_Time) Max_Last_Load,
                                      MAX(Last_Active_Time) Max_Last_Active,
                                      MIN(Parsing_Schema_Name) Parsing_Schema_Name,
                                      COUNT(DISTINCT Parsing_Schema_Name) \"Different pars. schema names\"
                               FROM   gv$SQLArea s, Len
                               GROUP BY Inst_ID, SUBSTR(s.SQL_Text, 1, Len.Substr_Len)
                               HAVING COUNT(*) > 10
                              ) g
                       JOIN gv$SQLArea s ON s.Inst_ID = g.Inst_ID AND s.SQL_ID = g.SQL_ID
                       ORDER BY \"Memory (MB)\" DESC NULLS LAST
             ",
             :parameter=>[{:name=> 'Anzahl Zeichen für Vergleich der SQLs', :size=>8, :default=>60, :title=> 'Anzahl Zeichen der SQL-Statements für Vergleich (links beginnend)'}]
         },
        {
             :name  => 'Mehrfach offene Cursoren: Überblick über SQL',
             :desc  => 'Je Session sollte für ein SQL-Statement i.d.R. auch nur ein Cursor aktiv sein.
Mehrfach geöffnete Cursor auf identischen SQL fluten Session_Cached_Cursor und PGA.',
             :sql=>  "SELECT /* Anzahl Open Cursor gruppiert nach SQL */
                             oc.*
                      FROM   (
                              SELECT Inst_ID, SQL_ID,
                                     COUNT(*) Anzahl_OC,
                                     COUNT(DISTINCT SID) Anzahl_SID,
                                     ROUND(Count(*) / COUNT(DISTINCT SID),2) \"Anzahl OC je SID\",
                                     MIN(SQL_Text) SQL_Text
                              FROM   gv$Open_Cursor
                              GROUP BY Inst_ID, SQL_ID
                              HAVING Count(*) / COUNT(DISTINCT SID) > 1
                             ) oc
                      ORDER BY Anzahl_OC DESC NULLS LAST",
         },
        {
             :name  => 'Mehrfach offene Cursoren: Mehrfach in Session geöffnete SQL',
             :desc  => 'Je Session sollte für ein SQL-Statement i.d.R. auch nur ein Cursor aktiv sein.
Mehrfach geöffnete Cursor auf identischen SQL fluten Session_Cached_Cursor und PGA.',
             :sql=>  "SELECT /* SQLs mehrfach als Cursor geoeffnet je Session */
                             sq.*, cu.SID, s.UserName, cu.Anz_Open_Cursor \"Anzahl Open Cursor\", cu.Anz_Sql \"Anzahl SQL\",
                             s.Client_Info, s.Machine, s.Program, s.Module, s.Action, cu.SQL_Text
                      FROM   (
                              SELECT oc.Inst_ID, oc.SID, oc.SQL_ID, COUNT(*) Anz_Open_Cursor, COUNT(DISTINCT oc.SQL_ID) Anz_Sql, MIN(oc.SQL_Text) SQL_Text
                              FROM   gv$Open_Cursor oc
                              GROUP BY oc.Inst_ID, oc.SID, oc.SQL_ID
                              HAVING count(*) > COUNT(DISTINCT oc.SQL_ID)
                             ) cu
                      JOIN   gv$Session s ON s.Inst_ID=cu.Inst_ID AND s.SID=cu.SID
                      JOIN   (SELECT Inst_ID, SQL_ID, COUNT(*) Child_Anzahl, MIN(Parsing_schema_name) Parsing_schema_Name
                              FROM gv$SQL
                              GROUP BY Inst_ID, SQL_ID
                             )sq ON sq.Inst_ID = cu.Inst_ID AND sq.SQL_ID = cu.SQL_ID
                      WHERE sq.Parsing_Schema_Name NOT IN ('SYS')
                      ORDER BY cu.Anz_Open_Cursor-cu.Anz_Sql DESC NULLS LAST"
         },
    {
         :name  => 'Konkurrenz bzgl. Speicher: Verdrängung im Shared Pool',
         :desc  => "Dieser View listet Objekte an, die für ihre Platzierung im Shared Pool andere verdrängen mussten.
Bei der Selektion werden die Inhalte gelöscht, d.h., die Selektion zeigt die Verdrängungen seit der letzten Selektion (nur einmalig).
'No. Items flushed from shared pool' von 7..8 ist normal, höhere Werte zeigen Probleme Platz zu finden.",
         :sql=>  "SELECT /* DB-Tools Ramm  Verdreaengung Shared Pool */
                         RAWTOHEX(Addr)         \"row-address in array or SGA\",
                         Indx         \"index in fixed table array\",
                         Inst_ID      \"Instance\",
                         KsmLrIdx,
                         KsmLrDur,
                         KsmLrShrPool,
                         KsmLrCom     \"Type of allocation\",
                         KsmLrSiz     \"Size of Allocation in Bytes\",
                         KsmLrNum     \"No. items flushed from sh.pool\",
                         KsmLrHon     \"Name of object beeing loaded\",
                         KsmLrOHV     \"HashValue of object\",
                         RAWTOHEX(KsmLrSes)     \"Session Raw (V$Session.SAddr)\",
                         KsmLrADU,
                         KsmLRNID,
                         KSMLRNsd,
                         KSMLRNcd,
                         KsmLRNed
                  FROM   x$ksmlru
                  WHERE  ksmlrnum>0
                  ORDER BY KsmLrNum DESC NULLS LAST",
    },
      {
        :name  => 'Probleme mit Function-based Index bei cusor_sharing != EXACT',
        :desc  => 'Bei Setzen des Parameters cursor_sharing=FORCE oder SIMILAR auf Session- oder Instance-Ebene werden function-based Indizes mit Literalen evtl. nicht mehr erkannt,
  da diese Literale durch Bindevariablen ersetzt werden.
  Lösung: Bindevariablen in PL/SQL-Function auslagern und diese im function-based Index aufrufen.
Die Abfrage selektiert potentielle Kandidaten, bei denen Index evtl. nicht mehr für SQL-Ausführung verwendet wird
',
        :sql=>   "SELECT /* Panorama-Tool Ramm  */
                         i.Owner, i.Index_Name, i.Index_type, i.Table_Name, i.Num_Rows,
                         e.Column_Position, e.Column_Expression
                  FROM   DBA_Indexes i
                  JOIN   DBA_Ind_Expressions e ON e.Index_Owner = i.Owner AND e.Index_Name = i.Index_Name
                  WHERE  Index_Type LIKE 'FUNCTION-BASED%'
                  AND    Owner NOT IN ('SYS', 'XDB', 'SYSMAN')",
        :filter_proc => proc{|rec|
             rec['column_expression'].match(/['0123456789]/)
        },
      },
      {
          :name  => t(:dragnet_helper_57_name, :default => 'Critical amount of child cursors per SQL-ID'),
          :desc  => t(:dragnet_helper_57_desc, :default=>'Large amount of child cursors per SQL-ID (> 500) show risk of latch waits and heavy CPU-usage for parse and execute.
Following counter columns show reasons why parsing SQL results in new child cursor.
Documentation is available here: http://docs.oracle.com/cd/E16655_01/server.121/e17615/refrn30254.htm#REFRN30254'),
          :sql=>   "SELECT /* Panorama-Tool Ramm  */
                         Inst_ID, SQL_ID, COUNT(*) Child_Count
                        #{result = '';
                          recs = sql_select_all("SELECT Column_Name FROM DBA_Tab_Columns WHERE Table_Name = 'V_$SQL_SHARED_CURSOR' AND Data_Type = 'VARCHAR2' AND Data_Length = 1 ORDER BY Column_ID");
                          recs.each do |rec|
                            result << ", SUM(DECODE(#{rec.column_name}, 'Y', 1, 0)) \"#{rec.column_name.gsub('_', ' ')}\"\n"
                          end
                          result
                         }
                    FROM   gv$SQL_Shared_Cursor
                    GROUP BY Inst_ID, SQL_ID
                    HAVING COUNT(*) > ?
                    ORDER BY COUNT(*) DESC",
          :parameter=>[{:name=> t(:dragnet_helper_57_param1_name, :default => 'Min. number of childs per SQL-ID'), :size=>8, :default=>5, :title=> t(:dragnet_helper_57_param1_desc, :default => 'Minimum number of child cursors per SQL-ID for display')}]
      },
    ]
  end


  ##############################################################################################################

  def dragnet_sqls_logwriter_redo
    [
    {
         :name  => t(:dragnet_helper_74_name, :default=>'Write access by executions (current SGA)'),
         :desc  => t(:dragnet_helper_74_desc, :default=>'Delays during log buffer write by log writer lead to „log file sync“ wait events, especially during commit.
Writing operations (Insert/Update/Delete) which cannot write into log buffer during „log file sync“ lead to „log buffer space“ wait events.
Requests for block transfer in RAC environment lead to „gc buffer busy“ wait events, if requested blocks in delivering RAC-instance are affected by simultaneous „log buffer space“ or „log file sync“ events.
The likelihood of „log buffer space“ events depends from frequency of writing operations. This selection determines heavy frequented write SQLs as candidates for deeper consideration.
Solution can be the aggregation of multiple writes (bulk-processing).'),
         :sql=>  "SELECT /* DB-Tools Ramm: Schreibende Zugriffe nach Executes */
                         Inst_ID, SQL_ID, Parsing_Schema_Name, Executions, Rows_Processed, ROUND(Rows_Processed/Executions,2) \"Rows per Exec\",
                         ROUND(Elapsed_Time/1000000) Elapsed_Time_Secs, SQL_Text
                  FROM   GV$SQLArea
                  WHERE  Command_Type IN (2,6,7)
                  AND    Executions > 0
                  AND    Rows_Processed > ?
                  ORDER BY Executions DESC NULLS LAST",
         :parameter=>[{:name=> t(:dragnet_helper_74_param_1_name, :default=>'Minimum number of written rows'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_74_param_1_hint, :default=>'Minimum number of written rows for consideration in result')}]
     },
    {
         :name  => t(:dragnet_helper_75_name, :default=>'Write access by executions (AWR history)'),
         :desc  => t(:dragnet_helper_75_desc, :default=>'Delays during log buffer write by log writer lead to „log file sync“ wait events, especially during commit.
Writing operations (Insert/Update/Delete) which cannot write into log buffer during „log file sync“ lead to „log buffer space“ wait events.
Requests for block transfer in RAC environment lead to „gc buffer busy“ wait events, if requested blocks in delivering RAC-instance are affected by simultaneous „log buffer space“ or „log file sync“ events.
The likelihood of „log buffer space“ events depends from frequency of writing operations. This selection determines heavy frequented write SQLs as candidates for deeper consideration.
Solution can be the aggregation of multiple writes (bulk-processing).'),
         :sql=>  "SELECT /* DB-Tools Ramm: Schreibende Zugriffe nach Executes */
                         s.Instance_Number, s.SQL_ID, s.Executions, s.Rows_Processed,
                         ROUND(s.Rows_Processed/s.Executions,2) \"Rows per Exec\", t.SQL_Text, TO_CHAR(SUBSTR(t.SQL_Text,1,100))
                  FROM   (
                          SELECT s.DBID, s.Instance_Number, s.SQL_ID, SUM(s.Executions_Delta) Executions, SUM(s.Rows_Processed_Delta) Rows_Processed
                          FROM   DBA_Hist_SQLStat s
                          JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                          WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                          GROUP BY s.DBID, s.Instance_Number, s.SQL_ID
                          HAVING  SUM(s.Executions_Delta) > 0
                         ) s
                  JOIN   DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
                  WHERE  t.Command_Type IN (2,6,7)
                  AND    s.Rows_Processed > ?
                  ORDER BY Executions DESC NULLS LAST",
         :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                      {:name=> t(:dragnet_helper_75_param_2_name, :default=>'Minimum number of written rows'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_75_param_2_hint, :default=>'Minimum number of written rows for consideration in result')}]
    },
    {
         :name  => 'Commit / Rollback - Aufkommen',
         :desc  => 'Aus den Zahlen des Commit- und Rollback-Verhaltens lassen sich Rückschlüsse auf evtl. problematisches Applikationsverhalten ziehen.',
         :sql=>  "SELECT /* DB-Tools Ramm Commits und Rollbacks in gegebenen Zeitraum */ Begin, Instance_Number, User_Commits, User_Rollbacks,
                         ROUND(User_Rollbacks/(DECODE(User_Commits+User_Rollbacks, 0, 1, User_Commits+User_Rollbacks))*100) Percent_Rollback,
                         Rollback_Changes
                  FROM   (
                          SELECT TRUNC(Begin_Interval_Time, 'HH24') Begin, Instance_Number,
                                 SUM(DECODE(Stat_Name, 'user commits', Value, 0)) User_Commits,
                                 SUM(DECODE(Stat_Name, 'user rollbacks', Value, 0)) User_Rollbacks,
                                 SUM(DECODE(Stat_Name, 'rollback changes - undo records applied', Value, 0)) Rollback_Changes
                          FROM   (
                                  SELECT snap.Begin_Interval_Time, st.Instance_Number, st.Stat_Name,
                                         Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY st.Snap_ID) Value
                                  FROM   (SELECT DBID, Instance_Number, Min(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                                          FROM   DBA_Hist_Snapshot ss
                                          WHERE  Begin_Interval_Time >= SYSDATE-?
                                          AND    Instance_Number = ?
                                          GROUP BY DBID, Instance_Number
                                         ) ss
                                  JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                                  JOIN   DBA_Hist_Snapshot snap ON snap.DBID=ss.DBID AND snap.Instance_Number=ss.Instance_Number AND snap.Snap_ID=st.Snap_ID
                                  WHERE  st.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorg‰nger des ersten mit auswerten f∏r Differenz per LAG */
                                  AND    Stat_Name IN ('user rollbacks', 'user commits', 'rollback changes - undo records applied')
                                 )
                          WHERE Value > 0
                          GROUP BY TRUNC(Begin_Interval_Time, 'HH24'), Instance_Number
                         )
                  ORDER BY 1",
         :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                      {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}]
     },
    {
         :name  => 'Einstellung Recovery-Verhalten',
         :desc  => 'Die Vorgaben von Recovery-Zeiten (fast_start_mttr_target) beeinflussen im Extrem drastisch das I/O-Verhalten der DB.
Durch Erhöhung der Aggressivität des DB-Writers zur Einhaltung kurzer Vorgaben können:
- Viele kleine asynchrone Write-Requests erzeugt werden statt weniger Requests mit mehreren Blöcken (im Normalfall bis 3000 DB-Blöcke / async.Write-Request)
- Die max. Anzahl async. Write-Requests des OS erreicht werden und massiv Verzögerungen im I/O der DB auftreten',
         :sql=> 'SELECT /*+ DB-Tools Ramm MTTR-Historie */ r.Instance_Number, ss.Begin_Interval_Time, target_mttr, estimated_mttr, optimal_logfile_size, CKPT_BLOCK_WRITES
                  FROM   dba_hist_instance_recovery r
                  JOIN   DBA_Hist_Snapshot ss ON ss.DBID = r.DBID AND ss.Instance_Number = r.Instance_Number AND ss.Snap_ID = r.Snap_ID
                  WHERE  r.Instance_Number = ?
                  AND    ss.Begin_Interval_Time > SYSDATE-?
                  ORDER BY ss.Begin_Interval_Time',
         :parameter=>[
             {:name=> 'Instance-Number', :size=>8, :default=>1, :title=> 'RAC-Instance-Number'},
             {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
     },
    ]
  end

  ####################################################################################################



  def sqls_conclusion_application
    [
      {
           :name  => t(:dragnet_helper_76_name, :default=>'Substantial larger runtime per module compared to average over longer time range'),
           :desc  => t(:dragnet_helper_76_desc, :default=>'Based on active session history are shown outlier on databaase runtime per module je Module.
Units for time consideration are defined by date format picture of TRUNC-function (DD=day, HH24=hour etc.)'),
           :sql=>  "WITH Modules AS (
               SELECT /*+ PARALLEL(h,2) */
                      TRUNC(Sample_Time, picture)  Time_Range_Start,
                      Module,
                      MIN(Sample_Time)          First_Occurrence,
                      MAX(Sample_Time)          Last_Occurrence,
                      COUNT(*) * 10             Secs_Waiting
               FROM   DBA_Hist_Active_Sess_History h,
                      (SELECT ? picture FROM DUAL)
               WHERE  Sample_Time > SYSDATE-?
               AND    Instance_Number = ?
               AND    NVL(Event, 'Hugo') NOT IN ('PX Deq Credit: send blkd')
               GROUP BY TRUNC(Sample_Time, picture), Module
              )
           SELECT Module,
                  SUM(Secs_Waiting)        \"Waiting secs. total\",
                  ROUND(AVG(Secs_Waiting)) \"Waiting secs. avg\",
                  MIN(Secs_Waiting)        \"Waiting secs. min\",
                  MIN(Time_Range_Start) KEEP (DENSE_RANK FIRST ORDER BY Secs_Waiting) \"Time range start of min.\",
                  MAX(Secs_Waiting)        \"Waiting secs. max.\",
                  MAX(Time_Range_Start) KEEP (DENSE_RANK LAST ORDER BY Secs_Waiting) \"Time range start of max.\",
                  MIN(First_Occurrence)    \"First occurrence\",
                  MAX(Last_Occurrence)     \"Last occurrence\"
           FROM   Modules
           GROUP BY Module
           ORDER BY MAX(Secs_Waiting)-AVG(Secs_Waiting) DESC
           ",
           :parameter=>[
               {:name=> 'Format picture for TRUNC-function', :size=>8, :default=> 'DD', :title=> 'Format-picture of TRUNC function (DD=day, HH24=hour etc.)'},
               {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
               {:name=> 'Instance', :size=>8, :default=>1, :title=> 'RAC-Instance'}
           ]
      },
      {
           :name  => t(:dragnet_helper_51_name, :default=> 'Usage of multi-column primary keys as reference target (business keys instead of technical keys)'),
           :desc  => t(:dragnet_helper_51_desc, :default=>"For ensurance of referential integrity should technical id's be used instead of business expressions.
Often problematic usage of business keys can be detetcted by existence of references on multi-column primary keys"),
           :sql=>  "
             SELECT /* Panorama-Tool Ramm: Fachliche Schluessel*/ p.Owner||'.'||p.Table_Name \"Referenced Table\",
                    MIN(pr.Num_Rows) \"Rows in referenced table\",
                    p.Constraint_Name \"Primary Key\", r.Owner||'.'||r.Table_Name \"Referencing Table\",
                    MIN(tr.Num_Rows) \"Rows in referencing table\",
                    COUNT(*) \"Number of PKey rows\",
                    MIN(c.Column_Name) \"One PKey-Column\",
                    MAX(c.Column_Name) \"Other PKey-Column\"
             FROM   DBA_Constraints r
             JOIN   DBA_Constraints p  ON p.Owner = r.R_Owner AND p.Constraint_Name = r.r_Constraint_Name
             JOIN   DBA_Cons_Columns c ON c.Owner = p.Owner   AND c.Constraint_Name = p.Constraint_Name
             JOIN   DBA_Tables pr ON pr.Owner = p.Owner AND pr.Table_Name = p.Table_Name
             JOIN   DBA_Tables tr ON tr.Owner = r.Owner AND tr.Table_Name = r.Table_Name
             WHERE  r.Constraint_Type = 'R'
             AND    c.Owner NOT IN ('SYS', 'SYSTEM')
             GROUP BY p.Owner, p.Table_Name, p.Constraint_Name, r.Owner, r.Table_Name, r.Constraint_Name
             HAVING COUNT(*) > 1
             ORDER BY MIN(tr.Num_Rows+pr.Num_Rows) * COUNT(*) DESC NULLS LAST
           ",
           :parameter=>[
           ]
      },
      {
           :name  => t(:dragnet_helper_52_name, :default=> 'Missing suggested AUDIT-options'),
           :desc  => t(:dragnet_helper_52_desc, :default=> 'You should have some minimal audit of DDL operations for traceability of problematic DDL.
Audit trail will usually be recorded in table sys.Aud$.'),
           :sql=>  "
              SELECT /* Panorama-Tool Ramm: Auditing */
                     '\"AUDIT '||NVL(a.Message, a.Name)||'\" suggested!'  Problem
              FROM
              (
              SELECT 'CLUSTER'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'DATABASE LINK'          Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'DIRECTORY'              Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'INDEX'                  Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'MATERIALIZED VIEW'      Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'OUTLINE'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PROCEDURE'              Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PROFILE'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PUBLIC DATABASE LINK'   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'PUBLIC SYNONYM'         Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ROLE'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ROLLBACK SEGMENT'       Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SEQUENCE'               Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'CREATE SESSION'         Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYNONYM'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYSTEM AUDIT'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SYSTEM GRANT'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TABLE'                  Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'ALTER SYSTEM'           Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TABLESPACE'             Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TRIGGER'                Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'TYPE'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'USER'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'VIEW'                   Name, 'BY ACCESS' Success, 'BY ACCESS' Failure, NULL Message FROM DUAL UNION ALL
              SELECT 'SELECT TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'SELECT TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'INSERT TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'INSERT TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'UPDATE TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'UPDATE TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL UNION ALL
              SELECT 'DELETE TABLE'           Name, 'NOT SET'   Success, 'BY ACCESS' Failure, 'DELETE TABLE BY ACCESS WHENEVER NOT SUCCESSFUL' Message FROM DUAL
              )a
              LEFT OUTER JOIN DBA_Stmt_Audit_Opts d ON  d.Audit_Option = a.Name
                                                    AND (d.Success = a.Success OR a.Success = 'NOT SET')
                                                    AND d.Failure = a.Failure  OR a.Failure = 'NOT SET'
              WHERE d.Audit_Option IS NULL
           ",
           :parameter=>[
           ]
      },
      {
           :name  => t(:dragnet_helper_53_name, :default=> 'Long running transactions from SGA (gv$Active_Session_History)'),
           :desc  => t(:dragnet_helper_53_desc, :default=>"Long running transactions contains the risk of lock escalations in OLTP-systems.
Writing access should be suspended to the end of process transactions to keep lock time until commit as short as possible.
Transaktions in OLTP-systems should be short enough to keep potential lock wait time below user's cognition limits.
           "),
           :sql=>  "
              SELECT s.*,
                     (SELECT UserName FROM DBA_Users u WHERE u.User_ID = s.User_ID) UserName
              FROM   (
                      SELECT RAWTOHEX(XID)                  \"Transaction-ID\",
                             MIN(Min_Sample_Time)           \"Start Tx.\",
                             MAX(Max_Sample_Time)           \"End Tx.\",
                             SUM(Samples)                   \"No. of Samples\",
                             ROUND(24*60*60*(CAST(MAX(Max_Sample_Time) AS DATE)-CAST(MIN(Min_Sample_Time) AS DATE))) \"Duration (Secs.)\",
                             MIN(Min_SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Min_Sample_Time)       \"First SQL-ID\",
                             MAX(Max_SQL_ID) KEEP (DENSE_RANK LAST  ORDER BY Max_Sample_Time)       \"Last SQL-ID\",
                             MIN(Inst_ID)                   \"Instance\",
                             MIN(TO_CHAR(Session_ID))       \"SID\",
                             MIN(TO_CHAR(Session_Serial#))  \"Serial number\",
                             MIN(Session_Type)              \"Session-Type\",
                             MIN(User_ID)                   User_ID,
                             MIN(Program)                   \"Program\",
                             MIN(Module)                    \"Module\",
                             MIN(Action)                    \"Action\",
                             MIN(Client_ID)                 \"Client-ID\",
                             MAX(Event) KEEP (DENSE_RANK LAST ORDER BY Samples) \"Main Event\"
                      FROM   (SELECT XID, NVL(Event, Session_State) Event,
                                     MIN(Sample_Time)               Min_Sample_Time,
                                     MAX(Sample_Time)               Max_Sample_Time,
                                     COUNT(*)                       Samples,
                                     MIN(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Min_SQL_ID,
                                     MAX(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Max_SQL_ID,
                                     MIN(Inst_ID)                   Inst_ID,
                                     MIN(Session_ID)                Session_ID,
                                     MIN(Session_Serial#)           Session_Serial#,
                                     MIN(Session_Type)              Session_Type,
                                     MIN(User_ID)                   User_ID,
                                     MIN(User_ID)                   Program,
                                     MIN(Module)                    Module,
                                     MIN(Action)                    Action,
                                     MIN(Client_ID)                 Client_ID
                              FROM   gv$active_session_history s
                              WHERE  XID IS NOT NULL
                              GROUP BY XID, NVL(Event, Session_State)
                             )
                      GROUP BY XID
                     ) s
              WHERE  \"Duration (Secs.)\" > ?
              ORDER BY \"Duration (Secs.)\" DESC
           ",
           :parameter=>[
               {:name=> 'Minimale Transaktionsdauer in Sekunden', :size=>8, :default=>300, :title=> 'Minimale Dauer der Transaktion in Sekunden für Aufnahme in Selektion'},
           ]
      },
      {
           :name  => t(:dragnet_helper_54_name, :default=> 'Long running transactions from AWH-history (DBA_Hist_Active_Sess_History)'),
           :desc  => t(:dragnet_helper_54_desc, :default=>"Long running transactions contains the risk of lock escalations in OLTP-systems.
Writing access should be suspended to the end of process transactions to keep lock time until commit as short as possible.
Transaktions in OLTP-systems should be short enough to keep potential lock wait time below user's cognition limits.
           "),
           :sql=>  "
              SELECT s.*,
                     (SELECT UserName FROM DBA_Users u WHERE u.User_ID = s.User_ID) UserName
              FROM   (
                      SELECT RAWTOHEX(XID)                  \"Transaction-ID\",
                             MIN(Min_Sample_Time)           \"Start Tx.\",
                             MAX(Max_Sample_Time)           \"End Tx.\",
                             SUM(Samples)                   \"No. of Samples\",
                             ROUND(24*60*60*(CAST(MAX(Max_Sample_Time) AS DATE)-CAST(MIN(Min_Sample_Time) AS DATE))) \"Duration (Secs.)\",
                             MIN(Min_SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Min_Sample_Time)       \"First SQL-ID\",
                             MAX(Max_SQL_ID) KEEP (DENSE_RANK LAST  ORDER BY Max_Sample_Time)       \"Last SQL-ID\",
                             MIN(Inst_ID)                   \"Instance\",
                             MIN(TO_CHAR(Session_ID))       \"SID\",
                             MIN(TO_CHAR(Session_Serial#))  \"Serial number\",
                             MIN(Session_Type)              \"Session-Type\",
                             MIN(User_ID)                   User_ID,
                             MIN(Program)                   \"Program\",
                             MIN(Module)                    \"Module\",
                             MIN(Action)                    \"Action\",
                             MIN(Client_ID)                 \"Client-ID\",
                             MAX(Event) KEEP (DENSE_RANK LAST ORDER BY Samples) \"Main Event\"
                      FROM   (SELECT /*+ PARALLEL(s,2) */ XID, NVL(Event, Session_State) Event,
                                     MIN(Sample_Time)               Min_Sample_Time,
                                     MAX(Sample_Time)               Max_Sample_Time,
                                     COUNT(*)                       Samples,
                                     MIN(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Min_SQL_ID,
                                     MAX(SQL_ID) KEEP (DENSE_RANK FIRST ORDER BY Sample_Time)       Max_SQL_ID,
                                     MIN(Instance_Number)                   Inst_ID,
                                     MIN(Session_ID)                Session_ID,
                                     MIN(Session_Serial#)           Session_Serial#,
                                     MIN(Session_Type)              Session_Type,
                                     MIN(User_ID)                   User_ID,
                                     MIN(User_ID)                   Program,
                                     MIN(Module)                    Module,
                                     MIN(Action)                    Action,
                                     MIN(Client_ID)                 Client_ID
                              FROM   DBA_Hist_Active_Sess_History s
                              WHERE  XID IS NOT NULL
                              AND    Sample_Time > SYSDATE-?
                              GROUP BY XID, NVL(Event, Session_State)
                             )
                      GROUP BY XID
                     ) s
              WHERE  \"Duration (Secs.)\" > ?
              ORDER BY \"Duration (Secs.)\" DESC
           ",
           :parameter=>[
               {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
               {:name=> 'Minimale Transaktionsdauer in Sekunden', :size=>8, :default=>300, :title=> 'Minimale Dauer der Transaktion in Sekunden für Aufnahme in Selektion'},
           ]
      },
      {
          :name  => t(:dragnet_helper_61_name, :default=> 'Possibly unnecessary update of primary key columns'),
          :desc  => t(:dragnet_helper_61_desc, :default=>'Primary key columns should normally be immutable, especially if they are referenced from foreign keys.
Setting primary key columns with identical values causes unnecessary effort for index maintenance.
Therefore primary key columns should not occur in SET-clause of UPDATE statements.
           '),
          :sql=> "
              SELECT SQL_ID, Object_Owner, Object_Name, Column_Name, Executions, Elapsed_Time_Secs, SUBSTR(SQL_FullText, 1, 200)
              FROM   (SELECT x.*, UPPER(SUBSTR(SQL_FullText, Set_Position, Where_Position - Set_Position)) Set_Klausel
                      FROM   (
                              SELECT p.Object_Owner, p.Object_Name, p.SQL_ID, cc.Column_Name, t.SQL_FullText, INSTR(UPPER(SQL_FullText), 'SET') Set_Position, INSTR(UPPER(SQL_FullText), 'WHERE') Where_Position,
                                     t.Executions, t.Elapsed_Time/(100000) Elapsed_Time_Secs
                              FROM   (SELECT Inst_ID, Object_Owner, Object_Name, SQL_ID
                                      FROM   gv$SQL_PLan
                                      WHERE  Operation = 'UPDATE'
                                      GROUP BY Inst_ID, Object_Owner, Object_Name, SQL_ID -- Gruppieren ueber Children
                                     ) p
                              JOIN   DBA_Constraints c ON c.Owner = p.Object_Owner AND c.Table_Name = p.Object_Name AND c.Constraint_Type = 'P'
                              JOIN   DBA_Cons_Columns cc ON cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name
                              JOIN   gv$SQLArea t ON t.Inst_ID = p.Inst_ID AND t.SQL_ID = p.SQL_ID
                             ) x
                     ) x
              WHERE REGEXP_INSTR(Set_Klausel, '[ ,]'||Column_Name||'[ =]') > 0
              ORDER BY Elapsed_Time_Secs DESC
          ",
      },
      {
          :name  => t(:dragnet_helper_62_name, :default=>'Longer inactive sessions with continued active transactions'),
          :desc  => t(:dragnet_helper_62_desc, :default=>'Longer inactive sessions with continued active transactions may indicate to:
- not finished manual activities, e.g. transaction control by GUI
- sessions returned to connection pools without finished transaction
           '),
          :sql=>  "
            WITH /* Test auf nicht commitete inaktive Sessions im Connection-Pool, Ramm 25.11.14 */
                 Sessions AS (SELECT /*+ MATERIALIZE NO_MERGE FULL(s) */
                                    Inst_ID, SID, Serial#, Status, UserName, Machine, OSUser, Prev_SQL_ID,
                                    Prev_Exec_Start, Module, Action, Logon_Time, Last_Call_ET
                             FROM   gv$Session s
                             WHERE  Status = 'INACTIVE'
                             AND    Last_Call_ET > ?
                            ),
                 Locks AS (SELECT /*+ MATERIALIZE NO_MERGE FULL(l) */
                                 Inst_ID, SID, Type, Request, LMode, ID1, ID2
                          FROM   gv$Lock l
                         )
            SELECT /*+ FULL(s) FULL(l) USE_HASH(s l) */
                   s.Inst_ID, s.SID, s.Serial#, s.UserName, s.Machine, s.OSUser,
                   s.Prev_SQL_ID  \"SQL-ID of last activity\",
                   s.Prev_Exec_Start  \"Start time of last activity\",
                   s.Module, s.Action,
                   s.Logon_Time,
                   s.Last_Call_ET \"Seconds since last activity\",
                   l.Type         \"Lock type\",
                   l.Request, l.LMode, lo.Owner, lo.Object_Name, l.ID1, l.ID2
            FROM   Sessions s
            JOIN   Locks l ON l.Inst_ID = s.Inst_ID AND l.SID = s.SID
            LEFT OUTER JOIN DBA_Objects lo ON lo.Object_ID = l.ID1
            WHERE  s.UserName NOT IN ('SYS')
            AND    l.Type NOT IN ('AE', 'PS', 'TO')
           ",
          :parameter=>[
              {:name=> t(:dragnet_helper_62_param_1_name, :default=>'Minimum duration (seconds) since last activity of session'), :size=>8, :default=>60, :title=> t(:dragnet_helper_62_param_1_hint, :default=>'Minimum duration (seconds) since end of last activity of session')},
          ]
      },
    ]
  end

  ####################################################################################################



  def pl_sql_usage
    [
        {
            :name  => t(:dragnet_helper_58_name, :default=>'Usage of NVL with function call as alternative parameter'),
            :desc  => t(:dragnet_helper_58_desc, :default=>'Function NVL calculates expression in parameter 2 always, whether first parameter of NVL is NULL or not.
    For extensive calculations in expression for parameter 2 of NVL you should use COALESCE instead. This calculates expression for alternative only if decision parameter is really NULL.'),
            :sql=>  "
SELECT SQL_ID, Inst_ID, Elapsed_Secs, NVL_Level \"NVL-Occurrence in SQL\", Char_Level Open_Bracket_Position, SUBSTR(NVL_Substr, 1, Min_Ende_Pos) NVL_Parameter
FROM   (
        SELECT x.*,
               MIN(CASE WHEN Opened-Closed=1 AND Char_=',' THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Komma_Pos,
               MIN(CASE WHEN Char_Level> 3 /* Laenge von NVL */ AND Opened-Closed=0 /* Alle Klammern wieder geschlossen */ THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Min_Ende_Pos
        FROM   (
                SELECT SQL_ID, Inst_ID, Elapsed_Secs, NVL_Level, Char_Level, SUBSTR(NVL_Substr, Char_Level, 1) Char_, NVL_Substr,
                       CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN Char_Level ELSE NULL END Klammer_Open,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Opened,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = ')' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Closed
                FROM   (
                        SELECT /*+ NO_MERGE */ NVL_Level,
                               -- INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) NVL_Position,
                               TO_CHAR(SUBSTR(a.First_NVL_Substr, INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level)+3, 4000)) NVL_Substr, /* SQL-String nach dem xten NVL bis zum Ende, mit max. 4000 Zeichen als Char fuehren */
                               a.SQL_ID, a.Inst_ID, a.Elapsed_Secs
                        FROM   (
                                SELECT /*+ NO_MERGE */ a.SQL_ID, a.Inst_ID, a.Elapsed_Secs,
                                                       UPPER(SUBSTR(ai.SQL_FullText, INSTR(UPPER(ai.SQL_FullText), 'NVL'))) First_NVL_Substr
                                FROM   (
                                        SELECT SQL_ID, MIN(Inst_ID) Inst_ID,
                                               SUM(Elapsed_Time)/1000000 Elapsed_Secs
                                        FROM   gv$SQLArea
                                        WHERE  UPPER(SQL_FullText) LIKE '%NVL%'
                                        GROUP BY SQL_ID
                                       ) a
                                JOIN   gv$SQLArea ai ON ai.SQL_ID = a.SQL_ID AND ai.Inst_ID = a.Inst_ID
                                WHERE  a.Elapsed_Secs > ?
                               ) a
                        JOIN  (SELECT Level NVL_Level FROM DUAL CONNECT BY Level < 1000) Pump ON INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) != 0  /* Ein Record je Vorkommen eines NVL im SQL, limitiert mit Level */
                       ) t
                JOIN  (SELECT Level Char_Level FROM DUAL CONNECT BY Level < 100000) Pump ON SUBSTR(NVL_Substr, pump.Char_Level, 1) IN ('(', ')', ',') AND pump.Char_Level <= LENGTH(t.NVL_Substr) /* Ein Record je Zeichen des verbleibenden SQL-Strings, limitiert mit Level */
               ) x
       ) y
WHERE  Klammer_Open BETWEEN Komma_Pos AND Min_Ende_Pos
ORDER BY Elapsed_Secs DESC, SQL_ID, NVL_Level, CHAR_Level
           ",
            :parameter=>[
                {:name=> t(:dragnet_helper_58_param1_name, :default=>'Minimum runtime of SQL in seconds'), :size=>8, :default=> 1000, :title=> t(:dragnet_helper_58_param1_desc, :default=>'Minimum runtime of SQL in seconds for consideration in selection')},
            ]
        },
    ]
  end



  public
  # liefert Array von Hashes mit folgender Struktur:
  #   :name           Name des Eintrages
  #   :desc           Beschreibung
  #   :entries        Array von Hashes mit selber Struktur (rekursiv), wenn belegt, dann gilt Element als Menü-Knoten
  #   :sql            SQL-Statement zur Ausführung
  #   :parameter      Array von Hshes mit folgender Struktur
  #       :name       Name des Parameters
  #       :size       Darstellungsgröße
  #       :default    Default-Wert
  #       :title      MouseOver-Hint

  @@dragnet_sql_list = []
  def dragnet_sql_list

    if @@dragnet_sql_list.length == 0                                           # einmalige globale Belegung
      @@dragnet_sql_list = [
          {   :name     => t(:dragnet_helper_group_potential_db_structures,  :default=> 'Potential in DB-structures'),
              :entries  => [{  :name    => t(:dragnet_helper_group_optimal_index_storage, :default => 'Ensure optimal storage parameter for indexes'),
                               :entries => optimal_index_storage
                            },
                            {  :name    => t(:dragnet_helper_group_unnecessary_indexes, :default => 'Detection of possibly unnecessary indexes'),
                               :entries => unnecessary_indexes
                            },
                            {  :name    => t(:dragnet_helper_group_index_partitioning, :default => 'Recommendations for index partitioning'),
                               :entries => index_partitioning
                            },
                            {  :name    => t(:dragnet_helper_group_unused_tables, :default => 'Detection of unused tables or columns'),
                               :entries => unused_tables
                            },

              ].concat(sqls_potential_db_structures)
          },
          {
              :name     => t(:dragnet_helper_group_wrong_execution_plan,     :default=> 'Detection of SQL with problematic execution plan'),
              :entries  => [{   :name    => t(:dragnet_helper_group_optimizable_full_scans, :default=>'Optimizable full-scan operations'),
                                :entries => optimizable_full_scans
                            },
              ].concat(sqls_wrong_execution_plan)
          },
          {
              :name     => t(:dragnet_helper_group_tuning_sga_pga,           :default=> 'Tuning of / load rejection from SGA, PGA'),
              :entries  => dragnet_sqls_tuning_sga_pga
          },
          {
              :name     => t(:dragnet_helper_group_cursor_redundancies,      :default=> 'Redundant cursors / usage of bind variables'),
              :entries  => sqls_cursor_redundancies
          },
          {
              :name     => t(:dragnet_helper_group_logwriter_redo,           :default=> 'Logwriter load / redo impact'),
              :entries  => dragnet_sqls_logwriter_redo
          },
          {
              :name     => t(:dragnet_helper_group_conclusion_application,   :default=> 'Conclusions on appliction behaviour'),
              :entries  => sqls_conclusion_application
          },
          {
              :name     => t(:dragnet_helper_group_pl_sql_usage,   :default=> 'PL/SQL-usage hints'),
              :entries  => pl_sql_usage
          },
      ]
    end

    @@dragnet_sql_list

  end

end
