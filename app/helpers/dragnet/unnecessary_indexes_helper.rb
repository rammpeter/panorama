# encoding: utf-8
module Dragnet::UnnecessaryIndexesHelper

  private

  def unnecessary_indexes
    [
        {
            :name  => t(:dragnet_helper_7_name, :default=> 'Detection of indexes not used for access or ensurance of uniqueness'),
            :desc  => t(:dragnet_helper_7_desc, :default=>"Selection of non-unique indexes without usage in SQL statements.
Necessity of  existence of indexes may be put into question if these indexes are not used for uniqueness or access optimization.
However the index may be useful for coverage of foreign key constraints, even if there had been no usage of index in considered time period.
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
            :name  => t(:dragnet_helper_14_name, :default=> 'Detection of indexes with only one or little key values in index'),
            :desc  => t(:dragnet_helper_14_desc, :default=> 'Indexes with only one or little key values may be unnecessary.
                       Exception: Indexes with only one key value may be usefull for differentiation between NULL and NOT NULL.
                       Indexes with only one key value and no NULLs in indexed columns my be definitely removed.
                       If used for ensurance of foreign keys you can often relinquish on these index because resulting FullTableScan on referencing table
                       in case of delete on referenced table may be accepted.'),
            :sql=> "SELECT /* DB-Tools Ramm Sinnlose Indizes */
                            i.Owner \"Owner\", i.Table_Name, Index_Name, Index_Type, BLevel, Distinct_Keys,
                            ROUND(i.Num_Rows/DECODE(i.Distinct_Keys,0,1,i.Distinct_Keys)) \"Rows per Key\",
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
                     WHERE   i.Num_Rows >= ?
                     AND     i.Distinct_Keys<=?
                     ORDER BY i.Num_Rows*t.Num_Rows DESC NULLS LAST
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_14_param_1_name, :default=> 'Min. number of rows in index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_14_param_1_hint, :default=> 'Minimum number of rows in considered index') },
                         {:name=>t(:dragnet_helper_14_param_2_name, :default=> 'Max. number of key values in index'), :size=>8, :default=>10, :title=>t(:dragnet_helper_14_param_2_hint, :default=> 'Maximum number of distinct key values in considered index') }
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
                             (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = u.Owner AND t.Table_Name = u.Table_Name) IOT_Type,
                             c.Constraint_Name foreign_key_protection,
                             rc.Owner||'.'||rc.Table_Name  Referenced_Table,
                             rt.Num_Rows     Num_Rows_Referenced_Table
                      FROM   (
                              SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
                                     decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
                                     decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                                     ou.start_monitoring, ou.end_monitoring
                              FROM   sys.object_usage ou
                              JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                              JOIN   sys.obj$ io ON io.obj# = ou.obj#
                              JOIN   sys.obj$ t  ON t.obj# = i.bo#
                              JOIN   DBA_Users u ON u.User_ID = io.owner#  --
                              CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                              WHERE  TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-?
                              AND    (schema.name IS NULL OR schema.Name = u.UserName)
                             )u
                      JOIN DBA_Indexes i                    ON i.Owner = u.Owner AND i.Index_Name = u.Index_Name AND i.Table_Name=u.Table_Name
                      LEFT OUTER JOIN DBA_Ind_Columns ic    ON ic.Index_Owner = u.Owner AND ic.Index_Name = u.Index_Name AND ic.Column_Position = 1
                      LEFT OUTER JOIN DBA_Cons_Columns cc   ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name AND cc.Position = 1
                      LEFT OUTER JOIN DBA_Constraints c     ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
                      LEFT OUTER JOIN DBA_Constraints rc    ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
                      LEFT OUTER JOIN DBA_Tables rt         ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
                      WHERE u.Used='NO' AND u.Monitoring='YES'
                      AND i.Num_Rows > ?
                      ORDER BY i.Num_Rows DESC NULLS LAST
                     ",
            :parameter=>[{:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_9_param_3_hint, :default=>'List only indexes for this schema (optional)')},
                         {:name=>t(:dragnet_helper_9_param_1_name, :default=>'Number of days backwards without usage'),    :size=>8, :default=>7,   :title=>t(:dragnet_helper_9_param_1_hint, :default=>'Minumin age in days of Start-Monitoring timestamp of unused index')},
                         {:name=>t(:dragnet_helper_9_param_2_name, :default=>'Minimum number of rows of index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_9_param_2_hint, :default=>'Minimum number of rows of index for consideration in selection')}
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
            :parameter=>[{:name=>t(:dragnet_helper_10_param_1_name, :default=>'Largest selectivity of a column of index > 1/x to the number of rows'), :size=>8, :default=>4, :title=>t(:dragnet_helper_10_param_1_hint, :default=>'Number of DISTINCT-values of index column with largest selectivity is > 1/x to the number of rows on index')},
                         {:name=>t(:dragnet_helper_10_param_2_name, :default=>'Minimum number of rows of index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_10_param_2_hint, :default=>'Minimum number of rows of index for consideration in selection')}
            ]
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
            :parameter=>[{:name=> t(:dragnet_helper_6_param_1_name, :default=>'Max. number of rows in referenced table'), :size=>8, :default=>100, :title=> t(:dragnet_helper_6_param_1_hint, :default=>'Max. number of rows in referenced table')},
                         {:name=> t(:dragnet_helper_6_param_2_name, :default=>'Min. number of rows in referencing table'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_6_param_2_hint, :default=>'Minimun number of rows in referencing table')},
                         {:name=> t(:dragnet_helper_6_param_3_name, :default=>'Max. number of referencing tables'), :size=>8, :default=>20, :title=>t(:dragnet_helper_6_param_3_hint, :default=>'Max. number of referencing tables (with large number there may be problems with FullTableScan during delete on master table)')},
            ]
        },
        {
            :name  => t(:dragnet_helper_131_name, :default=> 'Indexes on partitioned tables with same columns like partition keys'),
            :desc  => t(:dragnet_helper_131_desc, :default=>"If an index on partitioned table indexes the same columns like partition key and partitioning itself is selective enough by partition pruning
than this index can be removed"),
            :sql=> "SELECT x.Owner, x.Index_Name, x.Table_Owner, x.Table_Name, x.Uniqueness, x.Index_Partitioned, x.Num_Rows, x.Distinct_Keys, x.Partition_Columns, x.Table_Partitions, x.MBytes
                    FROM   (
                            SELECT i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Uniqueness, i.Partitioned Index_Partitioned, i.Num_Rows, i.Distinct_Keys,
                                   COUNT(DISTINCT pc.Column_Name) Partition_Columns, COUNT(ic.Column_Name) Matching_Index_Columns,
                                   (SELECT COUNT(*) FROM DBA_Ind_Columns ici WHERE ici.Index_Owner = i.Owner AND ici.Index_Name = i.Index_Name) Total_Index_Columns,
                                   (SELECT COUNT(*)
                                    FROM   DBA_Tab_Partitions tp
                                    WHERE  tp.Table_Owner = i.Table_Owner
                                    AND    tp.Table_Name  = i.Table_Name
                                   ) Table_Partitions,
                                   (SELECT  ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                    FROM   DBA_SEGMENTS s
                                    WHERE  s.SEGMENT_NAME = i.Index_Name
                                    AND    s.Owner        = i.Owner
                                   ) MBytes
                            FROM   DBA_Indexes i
                            JOIN   DBA_Part_Key_Columns pc ON pc.Owner = i.Table_Owner AND pc.Name = i.Table_Name AND pc.Object_Type = 'TABLE'
                            LEFT OUTER JOIN DBA_Ind_Columns ic ON  ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name AND ic.Column_Name = pc.Column_Name AND ic.Column_Position = pc.Column_Position
                            WHERE  i.Owner NOT IN ('SYSTEM', 'SYS')
                            AND    i.Uniqueness != 'UNIQUE'
                            GROUP BY i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Uniqueness, i.Partitioned,  i.Num_Rows, i.Distinct_Keys
                           ) x
                    WHERE Partition_Columns      = Matching_Index_Columns
                    AND   Matching_Index_Columns = Total_Index_Columns      -- keine weiteren Spalten des Index
                    ORDER BY x.Distinct_Keys / DECODE(Table_Partitions, 0, 1, Table_Partitions), x.Num_Rows DESC
                    ",
        },

    ]
  end # unnecessary_indexes


end