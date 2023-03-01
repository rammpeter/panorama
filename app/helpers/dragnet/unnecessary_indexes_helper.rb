# encoding: utf-8
module Dragnet::UnnecessaryIndexesHelper

  private

  def unnecessary_indexes
    [
        {
            :name  => t(:dragnet_helper_7_name, :default=> 'Detection of indexes not used for access or ensurance of uniqueness'),
            :desc  => t(:dragnet_helper_7_desc, :default=>"Selection of non-unique indexes without usage in SQL statements (checked by execution plans in SGA and AWR history).
Necessity of  existence of indexes may be put into question if these indexes are not used for uniqueness or access optimization.
However the index may be useful for coverage of foreign key constraints, even if there had been no usage of index in considered time period.
Ultimate knowledge about usage of index may be gained by tagging index with 'ALTER INDEX ... MONITORING USAGE' and monitoring usage via V$OBJECT_USAGE.
Additional info about usage of index can be gained by querying DBA_Hist_Seg_Stat or DBA_Hist_Active_Sess_History."),
            :sql=> "\
WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Index_Type, Table_Owner, Table_Name, Tablespace_Name,
                        Num_Rows, Distinct_Keys, Uniqueness
                 FROM DBA_Indexes
                 WHERE Owner NOT IN (#{system_schema_subselect}) AND UNiqueness != 'UNIQUE'
                ),
     Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Column_Name, Column_Position FROM DBA_Ind_Columns WHERE Index_Owner NOT IN (#{system_schema_subselect})),
     Ind_Columns_Group AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name,
                                   LISTAGG(Column_name, ', ') WITHIN GROUP (ORDER BY Column_Position) Columns
                            FROM   Ind_Columns
                            WHERE  Index_Owner NOT IN (#{system_schema_subselect})
                            GROUP BY Index_Owner, Index_Name
                           ),
     Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, R_Owner, R_Constraint_Name, Constraint_Type FROM DBA_Constraints WHERE Owner NOT IN (#{system_schema_subselect})),
     Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Column_Name, Position FROM DBA_Cons_Columns WHERE Owner NOT IN (#{system_schema_subselect}))
SELECT /* DB-Tools Ramm nicht genutzte Indizes */ * FROM (
        SELECT i.Owner Index_Owner, i.Index_Name, i.Index_Type, i.Table_Owner, i.Table_Name, sz.MBytes,
               i.Num_Rows, i.Tablespace_Name, i.UniqueNess, i.Distinct_Keys,
               icg.Columns Index_Columns, rc.Ref_Constraint
        FROM   (SELECT /*+ NO_MERGE USE_HASH(i p hp) */ i.*
                FROM   Indexes i
                LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT p.Object_Owner, p.Object_Name
                                 FROM   gV$SQL_Plan p
                                 JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID
                                         FROM   gv$SQLArea
                                         WHERE  SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                        ) t ON t.Inst_ID=p.Inst_ID AND t.SQL_ID=p.SQL_ID
                                 WHERE p.Object_Owner NOT IN (#{system_schema_subselect})
                                ) p ON p.Object_Owner=i.Owner AND p.Object_Name=i.Index_Name
                LEFT OUTER JOIN (SELECT /*+ NO_MERGE USE_HASH(p s t) */ DISTINCT p.Object_Owner, p.Object_Name
                                 FROM   DBA_Hist_SQL_Plan p
                                 JOIN   (SELECT /*+ NO_MERGE */ DISTINCT s.DBID, s.SQL_ID, s.Plan_Hash_Value
                                         FROM   DBA_Hist_SQLStat s
                                         JOIN   DBA_Hist_SnapShot ss ON ss.DBID = s.DBID AND ss.Snap_ID = s.Snap_ID AND ss.Instance_Number = s.Instance_Number
                                         WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                                        ) s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                                 JOIN   (SELECT /*+ NO_MERGE */ t.DBID, t.SQL_ID
                                         FROM   DBA_Hist_SQLText t
                                         WHERE  t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                        ) t ON  t.DBID = p.DBID AND t.SQL_ID = p.SQL_ID
                                ) hp ON hp.Object_Owner=i.Owner AND hp.Object_Name=i.Index_Name
                WHERE   p.OBJECT_OWNER IS NULL AND p.Object_Name IS NULL  -- keine Treffer im Outer Join
                AND     hp.OBJECT_OWNER IS NULL AND hp.Object_Name IS NULL  -- keine Treffer im Outer Join
               ) i
         LEFT OUTER JOIN Ind_Columns_Group icg ON icg.Index_Owner = i.Owner AND icg.Index_Name = i.Index_Name
         LEFT OUTER JOIN (SELECT /*+ NO_MERGE ORDERED */ f.Owner, f.Table_Name, ic.Index_Owner, ic.Index_Name, MIN(f.Constraint_Name||' Table='||rf.Table_Name) Ref_Constraint
                          FROM   Constraints f
                          JOIN   Cons_Columns fc ON fc.Owner = f.Owner AND fc.Constraint_Name = f.Constraint_Name AND fc.Position=1
                          JOIN   Ind_Columns ic ON ic.Column_Name=fc.Column_Name AND ic.Column_Position=1
                          JOIN   Constraints rf ON rf.Owner=f.r_Owner AND rf.Constraint_Name=f.r_Constraint_Name
                          WHERE  f.Constraint_Type = 'R'
                          GROUP BY f.Owner, f.Table_Name, ic.Index_Owner, ic.Index_Name
                         ) rc ON rc.Owner = i.Table_Owner AND rc.Table_Name = i.Table_Name AND rc.Index_owner = i.Owner AND rc.Index_Name = i.Index_name
         JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(bytes)/(1024*1024) MBytes
               FROM   DBA_SEGMENTS s
               GROUP BY Owner, Segment_Name
              ) sz ON sz.SEGMENT_NAME = i.Index_Name AND sz.Owner = i.Owner
        ) ORDER BY MBytes DESC NULLS LAST, Num_Rows
            ",
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
                            s.MBytes,
                            (SELECT CASE WHEN SUM(DECODE(Nullable, 'N', 1, 0)) = COUNT(*) THEN 'NOT NULL' ELSE 'NULLABLE' END
                             FROM DBA_Ind_Columns ic
                             JOIN DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                             WHERE  ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                            ) Nullable
                     FROM   DBA_Indexes i
                     JOIN   DBA_Tables t ON t.Owner=i.Table_Owner AND t.Table_Name=i.Table_Name
                     LEFT OUTER JOIN (SELECT  /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                      FROM   DBA_SEGMENTS s
                                      GROUP BY Owner, Segment_Name
                                     ) s ON s.SEGMENT_NAME = i.Index_Name AND s.Owner = i.Owner
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
            :desc  => t(:dragnet_helper_8_desc, :default=> 'This selection looks for indexes where one index indexes a subset of the columns of the other index, both starting with the same columns.
The purpose of the index with the smaller column set can regularly be covered by the second index with the larger column set (including protection of foreign key constraints).
So the first index often can be dropped without loss of function.
The effect of less indexes to maintain and less objects in database cache with better cache hit rate for the remaining objects in cache is mostly higher rated than the possible overhead of using range scan on index with larger column set.

If the index with the smaller column set ensures uniqueness, than an unique constraint with this column set based on the second index with the larger column set can also cover this task.
'),
            :sql=> "
WITH Ind_Cols AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Listagg(Column_Name, ',') WITHIN GROUP (ORDER BY Column_Position) Columns
                  FROM   DBA_Ind_Columns
                  WHERE  Index_Owner NOT IN (#{system_schema_subselect})
                  GROUP BY Index_Owner, Index_Name
                 ),
     Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Num_Rows, Uniqueness
                 FROM   DBA_Indexes
                 WHERE  OWNER NOT IN (#{system_schema_subselect})
                ),
     IndexFull AS (SELECT /*+ NO_MERGE MATERIALIZE */ i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Num_Rows, i.Uniqueness, ic.Columns
                   FROM   Indexes i
                   JOIN   Ind_Cols ic  ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                  ),
     Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes
                  FROM   DBA_Segments
                  WHERE  Owner NOT IN (#{system_schema_subselect})
                  GROUP BY Owner, Segment_Name
                 ),
     Constraints AS (SELECT  /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Index_Name, Constraint_Name FROM DBA_Constraints WHERE Index_Name IS NOT NULL AND Owner NOT IN (#{system_schema_subselect}))
SELECT x.*, ROUND(s.MBytes, 2) Size_MB_Index1, c.Constraint_Name \"Constr. Enforcement by idx1\"
FROM   (
        SELECT i1.owner, i1.Table_Owner, i1.Table_Name,
               i1.Index_Name Index_1, i1.Columns Columns_1, i1.Num_Rows Num_Rows_1, i1.Uniqueness Uniqueness_1,
               i2.Index_Name Index_2, i2.Columns Columns_2, i2.Num_Rows Num_Rows_2, i2.Uniqueness Uniqueness_2
        FROM   IndexFull i1
        JOIN   IndexFull i2 ON i2.Table_Owner = i1.Table_Owner AND i2.Table_Name = i1.Table_Name
        WHERE  i1.Index_Name != i2.Index_Name
        AND    i2.Columns LIKE i1.Columns || ',%' /* Columns of i1 are already indexed by i2 */
        AND    i1.Num_Rows > ?
       ) x
LEFT OUTER JOIN Constraints c ON c.Owner = x.Table_Owner AND c.Table_Name = x.Table_Name AND c.Index_Name = x.Index_1
LEFT OUTER JOIN segments s    ON s.Owner = x.Owner AND s.Segment_Name = x.Index_1
ORDER BY s.MBytes DESC NULLS LAST
            ",
            :parameter=>[{:name=> t(:dragnet_helper_8_param_1_name, :default=>'Minmum number of rows for index'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_8_param_1_hint, :default=>'Minimum number of rows of index for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_9_name, :default=> 'Detection of unused indexes by MONITORING USAGE'),
            :desc  => t(:dragnet_helper_9_desc, :default=>"\
The selection shows indexes monitored by MONITORING USAGE that have not been used by SQLs for x days.
A recursive index lookup during a foreign key check does not count as usage with regard to MONITORING USAGE.
Therefore, the list also contains indexes that are used exclusively to protect foreign key constraints.

The query allows the evaluation of the four reasons for the existence of an index:
1. use by SQL statements: then the index is not included in the list.
2. use for securing uniqueness by Unique Index, Unique or Primary Key Constraints ( column \"uniqueness\" ).
3. use for protection of a foreign key constraint (prevent lock propagation and full scan on detail table at delete on master table).
The additional information in the list allows you to evaluate the need for an index to protect a foreign key constraint:
Any existing foreign key constraints as well as the number of rows and DML operations since the last analysis of the referenced table.
4. Identical index structures of the tables involved in Partition Exchange (column \"Partition exchange possible\").
Shows the existence of further structure-identical tables with which partition exchange could theoretically take place.

If none of the four reasons really requires the existence, the index can be removed without risk.
"),
            :sql=> "
                    WITH Constraints AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Constraint_Type, Table_Name, R_Owner, R_Constraint_Name FROM DBA_Constraints WHERE Owner NOT IN (#{system_schema_subselect})),
                         Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Num_Rows, Last_Analyzed, Uniqueness, Index_Type, Tablespace_Name, Prefix_Length, Compression, Distinct_Keys, Partitioned
                                     FROM   DBA_Indexes
                                     WHERE  Owner NOT IN (#{system_schema_subselect})
                                    ),
                         Ind_Columns AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_name, Column_Position, Column_Length
                                                FROM DBA_Ind_Columns
                                                WHERE  Index_Owner NOT IN (#{system_schema_subselect})
                                               ),
                         Ind_Columns_Group AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name,
                                                       LISTAGG(Column_name, ', ') WITHIN GROUP (ORDER BY Column_Position) Columns
                                                FROM   Ind_Columns
                                                GROUP BY Index_Owner, Index_Name),
                         Cons_Columns AS       (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_name, Position, Constraint_Name, COUNT(*) OVER (PARTITION BY Owner, Table_Name, Constraint_Name) Column_Count
                                                FROM DBA_Cons_Columns
                                                WHERE  Owner NOT IN (#{system_schema_subselect})
                                               ),
                         Tables AS             (SELECT /*+ NO_MERGE MATERIALIZE */  Owner, Table_Name, Num_Rows, Last_analyzed, IOT_Type, Partitioned
                                                FROM DBA_Tables
                                                WHERE  Owner NOT IN (#{system_schema_subselect})
                                               ),
                         Tab_Modifications AS  (SELECT /*+ NO_MERGE MATERIALIZE */  Table_Owner, Table_Name, Inserts, Updates, Deletes
                                                FROM DBA_Tab_Modifications
                                                WHERE Partition_Name IS NULL /* Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen */
                                                AND   Table_Owner NOT IN (#{system_schema_subselect})
                                               ),
                         PE_Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ tc.Owner, tc.Table_Name, COUNT(*) Columns,
                                              SUM(ORA_HASH(tc.Data_Type) * tc.Column_ID * tc.Data_Length *
                                              NVL(tc.Data_Precision,1) * NVL(DECODE(tc.Data_Scale, 0, -1, tc.Data_Scale),1)) Structure_Hash
                                       FROM   DBA_Tab_Columns tc
                                       JOIN   Tables t ON t.Owner = tc.Owner AND t.Table_Name = tc.Table_Name /* exclude views */
                                       WHERE  tc.Owner NOT IN (#{system_schema_subselect})
                                       GROUP BY tc.Owner, tc.Table_Name
                                      ),
                         PE_Part_Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name, t.Partitioned
                                            FROM   Tables t
                                            WHERE  t.Partitioned = 'YES'
                                            AND NOT EXISTS (SELECT 1 FROM Indexes i WHERE i.Table_Owner = t.Owner AND i.Table_Name = t.Table_Name AND i.Partitioned = 'NO')
                                           ),
                         PE_Indexes as (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, COUNT(DISTINCT Index_Name) Indexes, COUNT(*) Ind_Columns,
                                               SUM(Column_Position * Column_Length ) Structure_Hash
                                        FROM   Ind_Columns ic
                                        WHERE  Table_Owner NOT IN (#{system_schema_subselect})
                                        GROUP BY Table_Owner, Table_Name
                                       ),
                         PE_Result_Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name,
                                                     t.Structure_Hash Table_Structure_Hash,
                                                     i.Structure_Hash Index_Structure_Hash,
                                                     t.Columns, i.Indexes, i.Ind_Columns,
                                                     dt.Partitioned
                                              FROM PE_Tables t
                                              LEFT OUTER JOIN PE_Part_Tables dt ON dt.Owner = t.Owner AND dt.Table_Name = t.Table_Name
                                              LEFT OUTER JOIN PE_Indexes i ON i.Table_Owner = t.Owner AND i.Table_Name = t.Table_Name
                                             ),
                         PE_Candidates AS (
                                            SELECT /*+ ORDERED NO_MERGE MATERIALIZE */ t.Owner, t.Table_Name
                                            FROM   (
                                                    SELECT Table_Structure_Hash, Index_Structure_Hash, Columns, Indexes, Ind_Columns
                                                    FROM   PE_Result_Tables
                                                    GROUP BY Table_Structure_Hash, Index_Structure_Hash, Columns, Indexes, Ind_Columns
                                                    HAVING COUNT(Partitioned) > 0               /* at least one of the matching tables is partitioned */
                                                    AND    COUNT(Partitioned) < COUNT(*)        /* not all tables are partitioned */
                                                   ) p
                                            JOIN   PE_Result_Tables t ON t.Table_Structure_Hash  = p.Table_Structure_Hash
                                                                     AND t.Index_Structure_Hash  = p.Index_Structure_Hash
                                                                     AND t.Columns               = p.Columns
                                                                     AND t.Indexes               = p.Indexes
                                                                     AND t.Ind_Columns           = p.Ind_Columns
                                           ),
                         I_Object_Usage AS (
#{
              if get_db_version >= '12.1'
                "
                            SELECT /*+ NO_MERGE MATERIALIZE */ ou.Owner, ou.Index_Name, ou.Table_Name, ou.Monitoring, ou.Used,
                                   TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') \"Start monitoring\",
                                   TO_DATE(ou.End_Monitoring, 'MM/DD/YYYY HH24:MI:SS')   \"End monitoring\"
                            FROM   DBA_Object_Usage ou
                            CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                            WHERE  TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-?
                            AND    (schema.name IS NULL OR schema.Name = ou.Owner)
                            AND    ou.Used='NO' AND ou.Monitoring='YES'
    "
              else
                "
                            SELECT /*+ NO_MERGE MATERIALIZE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
                                   decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
                                   decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                                   TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') \"Start monitoring\",
                                   TO_DATE(ou.End_Monitoring, 'MM/DD/YYYY HH24:MI:SS')   \"End monitoring\"
                            FROM   sys.object_usage ou
                            JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                            JOIN   sys.obj$ io ON io.obj# = ou.obj#
                            JOIN   sys.obj$ t  ON t.obj# = i.bo#
                            JOIN   DBA_Users u ON u.User_ID = io.owner#  --
                            CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                            WHERE  TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-?
                            AND    (schema.name IS NULL OR schema.Name = u.UserName)
                            AND    decode(bitand(ou.flags, 1), 0, 'NO', 'YES') = 'NO'
                            AND    decode(bitand(i.flags, 65536), 0, 'NO', 'YES') = 'YES'
    "
              end
}                           )
                    SELECT /*+ NOPARALLEL USE_HASH(u i t ic icg cc uc c seg pec) OPT_PARAM('_bloom_filter_enabled' 'false') */ u.Owner, u.Table_Name, u.Index_Name,
                           icg.Columns                                                                \"Index Columns\",
                           u.\"Start monitoring\",
                           ROUND(NVL(u.\"End monitoring\", SYSDATE)-u.\"Start monitoring\", 1) \"Days without usage\",
                           i.Num_Rows \"Num. rows\", i.Distinct_Keys \"Distinct keys\",
                           CASE WHEN i.Distinct_Keys IS NULL OR  i.Distinct_Keys = 0 THEN NULL ELSE ROUND(i.Num_Rows/i.Distinct_Keys) END \"Avg. rows per key\",
                           i.Compression||CASE WHEN i.Compression = 'ENABLED' THEN ' ('||i.Prefix_Length||')' END Compression,
                           seg.MBytes,
                           i.Uniqueness||CASE WHEN i.Uniqueness != 'UNIQUE' AND uc.Constraint_Name IS NOT NULL THEN ' enforcing '||uc.Constraint_Name END Uniqueness,
                           cc.Constraint_Name                                                         \"Foreign key protection\",
                           CASE WHEN cc.r_Table_Name IS NOT NULL THEN LOWER(cc.r_Owner)||'. '||cc.r_Table_Name END  \"Referenced table\",
                           cc.r_Num_Rows                                                              \"Num rows of referenced table\",
                           cc.r_Last_analyzed                                                         \"Last analyze referenced table\",
                           cc.Inserts                                                                 \"Inserts on ref. since anal.\",
                           cc.Updates                                                                 \"Updates on ref. since anal.\",
                           cc.Deletes                                                                 \"Deletes on ref. since anal.\",
                           CASE WHEN pec.Table_Name IS NOT NULL THEN 'Y' END                          \"Partition exchange possible\",
                           seg.Tablespace_Name                                                        \"Tablespace\",
                           u.\"End monitoring\",
                           i.Index_Type,
                           t.IOT_Type                                                                 \"IOT Type\"
                    FROM   I_Object_Usage u
                    JOIN Indexes i                        ON i.Owner = u.Owner AND i.Index_Name = u.Index_Name AND i.Table_Name=u.Table_Name
                    JOIN Tables t                         ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                    LEFT OUTER JOIN Ind_Columns ic        ON ic.Index_Owner = u.Owner AND ic.Index_Name = u.Index_Name AND ic.Column_Position = 1
                    LEFT OUTER JOIN Ind_Columns_Group icg ON icg.Index_Owner = u.Owner AND icg.Index_Name = u.Index_Name
                    /* Indexes used for protection of FOREIGN KEY constraints */
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE ORDERED USE_HASH(cc c rc rt m) */ cc.Owner, cc.Table_Name, cc.Column_name, c.Constraint_Name, rc.Owner r_Owner, rt.Table_Name r_Table_Name, rt.Num_rows r_Num_rows, rt.Last_Analyzed r_Last_analyzed, m.Inserts, m.Updates, m.Deletes
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c     ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
                                     JOIN   Constraints rc    ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
                                     JOIN   Tables rt     ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
                                     LEFT OUTER JOIN Tab_Modifications m ON m.Table_Owner = rc.Owner AND m.Table_Name = rc.Table_Name
                                     WHERE  cc.Position = 1
                                    ) cc ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name
                    /* Indexes used for enforcement of UNIQUE or PRIMARY KEY constraints */
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE USE_HASH(cc c ic) */ ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c   ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type IN ('U', 'P')
                                     JOIN Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name  AND ic.Column_Name = cc.Column_Name /* Position of column in index does not matter for constraint */
                                     GROUP BY ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     HAVING COUNT(DISTINCT ic.Column_Name) = MAX(cc.Column_Count) /* All constraint columns are covered by index columns, index may have additional columns */
                                     AND    MAX(ic.Column_Position) = MAX(cc.Column_Count)               /* All additional columns of index are right from contraint columns */
                                    ) uc ON uc.Index_Owner = u.Owner AND uc.Index_Name = u.Index_Name
                    JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes,
                                 CASE WHEN COUNT(DISTINCT TableSpace_Name) > 1 THEN '< '||COUNT(DISTINCT TableSpace_Name)||' different >' ELSE MIN(TableSpace_Name) END TableSpace_Name
                          FROM   DBA_Segments
                          GROUP BY Owner, Segment_Name
                          HAVING SUM(bytes)/(1024*1024) > ?
                         ) seg ON seg.Owner = u.Owner AND seg.Segment_Name = u.Index_Name
                    LEFT OUTER JOIN PE_Candidates pec ON pec.Owner = i.Table_Owner AND pec.Table_Name = i.Table_Name
                    CROSS JOIN (SELECT ? value FROM DUAL) Max_DML
                    WHERE (cc.r_Num_Rows IS NULL OR cc.r_Num_Rows < ?)
                    AND   (? = 'YES' OR i.Uniqueness != 'UNIQUE')
                    AND   (Max_DML.Value IS NULL OR NVL(cc.Inserts + cc.Updates + cc.Deletes, 0) < Max_DML.Value)
                    ORDER BY seg.MBytes DESC NULLS LAST
                   ",
          :parameter=>[{:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_9_param_3_hint, :default=>'List only indexes for this schema (optional)')},
                       {:name=>t(:dragnet_helper_9_param_1_name, :default=>'Number of days backwards without usage'),    :size=>8, :default=>7,   :title=>t(:dragnet_helper_9_param_1_hint, :default=>'Minumin age in days of Start-Monitoring timestamp of unused index')},
                       {:name=>t(:dragnet_helper_139_param_1_name, :default=>'Minimum size of index in MB'),    :size=>8, :default=>1,   :title=>t(:dragnet_helper_139_param_1_hint, :default=>'Minumin size of index in MB to be considered in selection')},
                       {:name=>t(:dragnet_helper_9_param_4_name, :default=>'Maximum DML-operations on referenced table'), :size=>8, :default=>100,   :title=>t(:dragnet_helper_9_param_4_hint, :default=>'Maximum number of DML-operations (Inserts + Updates + Deletes) on referenced table since last analyze (optional, may be empty)')},
                       {:name=>t(:dragnet_helper_9_param_5_name, :default=>'Maximum number of rows in referenced table'), :size=>8, :default=>10000,   :title=>t(:dragnet_helper_9_param_5_hint, :default=>"Maximum number rows in referenced table for consideration in selection.\n(to prevent from long running deletes if housekeeping of referenced table occurs)")},
                       {:name=>t(:dragnet_helper_9_param_2_name, :default=>'Show unique indexes also (YES/NO)'), :size=>4, :default=>'NO',   :title=>t(:dragnet_helper_9_param_2_hint, :default=>'Unique indexes are needed for uniqueness even if they are not used')},
            ]
        },
        {
            :name  => t(:dragnet_helper_139_name, :default=> 'Detection of indexes without MONITORING USAGE'),
            :desc  => t(:dragnet_helper_139_desc, :default=>"It is recommended to let the DB track usage of indexes by ALTER INDEX ... MONITORING USAGE
so you may identify indexes that are never used for direct index access from SQL.
This usage info should be refreshed from time to time to recognize also indexes that aren't used anymore.
How to and scripts for activating MONITORING USAGE may be found here:

  %{url}

Index usage can be evaluated than via v$Object_Usage or with previous selection.
", url: "https://rammpeter.blogspot.com/2017/10/oracle-db-identify-unused-indexes.html"),
            :sql=> "
                    SELECT i.Owner, i.Table_Name, i.Index_Name, i.Index_Type, i.Num_Rows, i.Distinct_Keys, seg.MBytes, o.Created, o.Last_DDL_Time
                    FROM   DBA_Indexes i
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                                    ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                    LEFT OUTER JOIN (
#{
              if get_db_version >= '12.1'
                "
                                      SELECT Owner, Index_Name
                                      FROM   DBA_Object_Usage ou
    "
              else
"
                                      SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name
                                      FROM   sys.object_usage ou
                                      JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                                      JOIN   sys.obj$ io ON io.obj# = ou.obj#
                                      JOIN   DBA_Users u ON u.User_ID = io.owner#
"
              end
            }                                    ) u ON u.Owner = i.Owner AND u.Index_Name = i.Index_Name
                    LEFT OUTER JOIN DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.Object_Type = 'INDEX'
                    CROSS JOIN (SELECT ? Schema FROM DUAL) s
                    WHERE u.Owner IS NULL AND u.Index_Name IS NULL
                    AND   i.Owner NOT IN (#{system_schema_subselect})
                    AND   i.Index_Type != 'IOT - TOP'
                    AND   seg.MBytes > ?
                    AND   (s.Schema IS NULL OR i.Owner = UPPER(s.Schema))
                    ORDER BY seg.MBytes DESC NULLS LAST
            ",
            :parameter=>[{:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_139_param_2_hint, :default=>'List only indexes for this schema (optional)')},
                         {:name=>t(:dragnet_helper_139_param_1_name, :default=>'Minimum size of index in MB'),    :size=>8, :default=>1,   :title=>t(:dragnet_helper_139_param_1_hint, :default=>'Minumin size of index in MB to be considered in selection')},
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
            :sql=> "WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name , Constraint_Name, Constraint_Type, R_Owner, R_Constraint_Name, Index_Name
                     FROM   DBA_Constraints
                     WHERE  Constraint_Type IN ('R', 'P', 'U')
                     AND    Owner NOT IN (#{system_schema_subselect})
                    )
                    SELECT /* DB-Tools Ramm Unnecessary index on Ref-Constraint*/
                           ri.Owner, ri.Table_Name, ri.Index_Name, ri.Rows_Origin \"No. of rows origin\", s.Size_MB \"Size of Index in MB\", p.Constraint_Name, ri.Column_Name,
                           ri.Position, pi.Table_Name Target_Table, pi.Index_Name Target_Index, pi.Num_Rows \"No. of rows target\", ri.No_of_Referencing_FK \"No. of referencing fk\"
                    FROM   (SELECT /*+ NO_MERGE */
                                   r.Owner, r.Table_Name, r.Constraint_Name, rc.Column_Name, rc.Position, ric.Index_Name,
                                   r.R_Owner, r.R_Constraint_Name, ri.Num_Rows Rows_Origin
                            FROM   Constraints r
                            JOIN   DBA_Cons_Columns rc  ON rc.Owner            = r.Owner            /* Columns of foreign key */
                                                       AND rc.Constraint_Name  = r.Constraint_Name
                            JOIN   DBA_Ind_Columns ric  ON ric.Table_Owner     = r.Owner            /* matching columns of an index */
                                                       AND ric.Table_Name      = r.Table_Name
                                                       AND ric.Column_Name     = rc.Column_Name
                                                       AND ric.Column_Position = rc.Position
                            JOIN   DBA_Indexes ri       ON ri.Owner            = ric.Index_Owner
                                                       AND ri.Index_Name       = ric.Index_Name
                            WHERE  r.Constraint_Type  = 'R'
                           ) ri                      -- Indizierte Foreign Key-Constraints
                    JOIN   Constraints p   ON p.Owner            = ri.R_Owner                   /* referenced PKey-Constraint */
                                          AND p.Constraint_Name  = ri.R_Constraint_Name
                    JOIN   DBA_Indexes     pi  ON pi.Owner           = p.Owner
                                              AND pi.Index_Name      = p.Index_Name
                    JOIN   (SELECT /*+ NO_MERGE */ r_Owner, r_Constraint_Name, COUNT(*) No_of_Referencing_FK /* Limit fk-target to max. x referencing tables */
                            FROM   Constraints
                            WHERE  Constraint_Type = 'R'
                            GROUP BY r_Owner, r_Constraint_Name
                           ) ri ON ri.r_owner = p.Owner AND ri.R_Constraint_Name=p.Constraint_Name
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(Bytes)/(1024*1024)) Size_MB
                                     FROM   DBA_Segments
                                     WHERE  Segment_Type LIKE 'INDEX%'
                                     GROUP BY Owner, Segment_Name
                                    ) s ON s.Owner = ri.Owner AND s.Segment_Name = ri.Index_Name
                    WHERE  pi.Num_Rows < ?                                                          /* Limit to small referenced tables */
                    AND    ri.Rows_Origin > ?                                                       /* Limit to huge referencing tables */
                    ORDER BY Rows_Origin DESC NULLS LAST",
            :parameter=>[
                         {:name=> t(:dragnet_helper_6_param_1_name, :default=>'Max. number of rows in referenced table'), :size=>8, :default=>100, :title=> t(:dragnet_helper_6_param_1_hint, :default=>'Max. number of rows in referenced table')},
                         {:name=> t(:dragnet_helper_6_param_2_name, :default=>'Min. number of rows in referencing table'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_6_param_2_hint, :default=>'Minimun number of rows in referencing table')},
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
                            WHERE  i.Owner NOT IN (#{system_schema_subselect})
                            AND    i.Uniqueness != 'UNIQUE'
                            GROUP BY i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Uniqueness, i.Partitioned,  i.Num_Rows, i.Distinct_Keys
                           ) x
                    WHERE Partition_Columns      = Matching_Index_Columns
                    AND   Matching_Index_Columns = Total_Index_Columns      -- keine weiteren Spalten des Index
                    ORDER BY x.Distinct_Keys / DECODE(Table_Partitions, 0, 1, Table_Partitions), x.Num_Rows DESC
                    ",
        },
        {
            :name  => t(:dragnet_helper_143_name, :default=> 'Removable indexes if column order of another multi-column index can be changed'),
            :desc  => t(:dragnet_helper_143_desc, :default=>"This selection looks for multi-column indexes with first column with weak selectivity and second column with strong selectivity and another single-column index existing with the same column like the second column of the multi-column index.
If column order of the multi-column index can be changed than the additional single-column index may become obsolete."),
            :sql=> "WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Owner, Index_Name, Uniqueness, Num_Rows
                                     FROM   DBA_Indexes
                                    ),
                         Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ ic.Index_Owner, ic.Index_Name, ic.Table_Owner, ic.Table_Name, ic.Column_Name, ic.Column_Position, tc.Num_Distinct, tc.Avg_Col_Len
                                         FROM   DBA_Ind_Columns ic
                                         JOIN   DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                                         WHERE  tc.Num_Distinct IS NOT NULL /* Check only analyzed tables/indexes*/
                                         AND    tc.Num_Distinct > 0         /* Suppress division by zero */
                                        )
                    SELECT /*+ ORDERED */ i.Table_Owner, i.Table_Name, i.Index_Name Index_To_Change, i.Uniqueness, i.Num_Rows,
                           ic1.Column_Name Column_1, ic1.Num_Distinct Num_Dictinct_Col_1, ROUND(i.num_rows/ic1.Num_Distinct, 1) Rows_per_Key_Col_1,
                           ic2.Column_Name Column_2, ic2.Num_Distinct Num_Dictinct_Col_2, ROUND(i.num_rows/ic2.Num_Distinct, 1) Rows_per_Key_Col_2,
                           ica.Index_Name Index_To_Remove
                    FROM   Indexes i
                    JOIN   Ind_Columns ic1 ON ic1.Index_Owner = i.Owner AND ic1.Index_Name = i.Index_Name AND ic1.Column_Position = 1   /* First column of multi-column-index */
                    JOIN   Ind_Columns ic2 ON ic2.Index_Owner = i.Owner AND ic2.Index_Name = i.Index_Name AND ic2.Column_Position = 2   /* Second column of multi-column-index */
                    JOIN   Ind_Columns ica ON ica.Table_Owner = i.Table_Owner AND ica.Table_Name = i.Table_Name AND ica.Column_Name = ic2.Column_Name AND ica.Column_Position = 1 /* single-column index with same column as second column of multi-column index*/
                    WHERE  i.num_rows/ic1.Num_Distinct > ?
                    AND    i.num_rows/ic2.Num_Distinct < ?
                    ORDER BY i.Num_Rows * ica.Avg_Col_Len DESC  /* Order by saving after removal of ica-index */
            ",
            :parameter=>[
                {:name=> t(:dragnet_helper_143_param_1_name, :default=>'Min. rows per key for first column of index'), :size=>10, :default=>100000, :title=> t(:dragnet_helper_143_param_1_hint, :default=>'Minimun number of rows per key for first column of multi-column index')},
                {:name=> t(:dragnet_helper_143_param_2_name, :default=>'Max. rows per key for second column of index'), :size=>10, :default=>1000,  :title=> t(:dragnet_helper_143_param_2_hint, :default=>'Maximun number of rows per key for second column of multi-column index')},
            ]
        },
        {
            :name  => t(:dragnet_helper_146_name, :default=> 'Tables with single-column primary key constraint which is not referenced by any foreign key constraint'),
            :desc  => t(:dragnet_helper_146_desc, :default=>"An ID-column with primary key constraint and related index may by unnecessary if primary key constraint is not referenced by any foreign key constraint.
Often this is the case if:
- there are multi-column unique constraints or unique indexes for transaction data, which may be used as alternative unique access criteria
- or there is no need for accessing single records
- the used frameworks don't require the existence of technical ID
"),
            :sql=> "\
WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Constraint_Type, Table_Name, r_Owner, r_Constraint_Name, Index_Owner, Index_Name
                     FROM   DBA_Constraints
                     WHERE  Constraint_Type IN ('P', 'R', 'U')
                    ),
     Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Owner, Table_Name, Index_Name, Uniqueness, Index_Type
                 FROM   DBA_Indexes
                ),
     Tab_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_Name, Avg_Col_Len
                     FROM   DBA_Tab_Columns
                    ),
     Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) Size_MB
                  FROM   DBA_Segments
                  GROUP BY Owner, Segment_Name
                 )
SELECT c.Owner, c.Table_Name, cc.Column_Name PKey_Column, c.Constraint_Name, t.Num_Rows,
       si.Size_MB Size_MB_PK_Index, (t.Num_Rows * tc.Avg_Col_Len)/(1024*1024) Size_MB_PK_Column,
       uc.Constraint_Name Alternative_Unique_Constraint, ui.Index_Name Alternative_Unique_Index
FROM   (
        SELECT /*+ NO_MERGE */ Owner, Constraint_Name, Table_Name, MIN(Column_Name) Column_Name
        FROM   DBA_Cons_Columns
        GROUP BY Owner, Constraint_Name, Table_Name
        HAVING COUNT(*) = 1  /* exactly one column in PK-Constraint */
       ) cc
JOIN   Constraints c  ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Table_Name = cc.Table_Name AND c.Constraint_Type = 'P'
JOIN   DBA_Tables t   ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
JOIN   Indexes pi     ON pi.Owner = c.Index_Owner AND pi.Index_Name = c.Index_Name
JOIN   Tab_Columns tc ON tc.Owner = c.Owner AND tc.Table_Name = c.Table_Name AND tc.Column_Name = cc.Column_Name
LEFT OUTER JOIN Segments si    ON si.Owner = pi.Owner AND si.Segment_Name = pi.Index_Name
LEFT OUTER JOIN Constraints uc ON uc.Owner = c.Owner AND uc.Table_Name = c.Table_Name AND c.Constraint_Type = 'U'
LEFT OUTER JOIN Indexes ui     ON ui.Table_Owner = c.Owner AND ui.Table_Name = c.Table_Name AND ui.Uniqueness = 'UNIQUE' AND ui.Index_Type NOT IN ('LOB') AND ui.Index_Name != pi.Index_Name
AND    (c.Owner, c.Constraint_Name) NOT IN (SELECT r_Owner, r_Constraint_Name FROM Constraints WHERE Constraint_Type = 'R')
ORDER BY t.Num_Rows DESC NULLS LAST
",
        },
        {
            :name  => t(:dragnet_helper_147_name, :default=> 'Detection of unused indexes by DBA_INDEX_USAGE (starting with Release 12.2)'),
            :desc  => t(:dragnet_helper_147_desc, :default=>"Starting with Release 12.2 information about index usage is gathered in DBA_Index_Usage.
This selection shows indexes without usage resp. with last usage time older than x days based on DBA_Index_Usage.

Caution:
- Per default this selection is based on cyclic sampling. That means, without 100% guarantee for recording each index usage (can be changed by \"_iut_stat_collection_type\"=ALL instead of SAMPLED).
- Recursive index-lookup by foreign key validation does not count as usage in DBA_Index_Usage.
- So please be careful if index is only needed for foreign key protection (to prevent lock propagation and full scans on detail-table at deletes on master-table).
"),
            :sql=> "
                    WITH Constraints AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Constraint_Type, Table_Name, R_Owner, R_Constraint_Name FROM DBA_Constraints),
                         Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Num_Rows, Last_Analyzed, Uniqueness, Index_Type, Tablespace_Name, Prefix_Length, Compression, Distinct_Keys
                                     FROM   DBA_Indexes
                                    ),
                         Ind_Columns AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_name, Column_Position FROM DBA_Ind_Columns),
                         Cons_Columns AS       (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_name, Position, Constraint_Name FROM DBA_Cons_Columns),
                         Tables AS             (SELECT /*+ NO_MERGE MATERIALIZE */  Owner, Table_Name, Num_Rows, Last_analyzed FROM DBA_Tables),
                         Tab_Modifications AS  (SELECT /*+ NO_MERGE MATERIALIZE */  Table_Owner, Table_Name, Inserts, Updates, Deletes FROM DBA_Tab_Modifications WHERE Partition_Name IS NULL /* Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen */)
                    SELECT /*+ USE_HASH(i ic cc c rc rt) */ i.Owner, i.Table_Name, i.Index_Name,
                           ic.Column_Name                                                             \"First Column name\",
                           ROUND(SYSDATE - NVL(iu.Last_Used, o.Created), 1)                           \"Days without usage\",
                           iu.Last_Used,
                           i.Num_Rows \"Num. rows\", i.Distinct_Keys \"Distinct keys\",
                           CASE WHEN i.Distinct_Keys IS NULL OR  i.Distinct_Keys = 0 THEN NULL ELSE ROUND(i.Num_Rows/i.Distinct_Keys) END \"Avg. rows per key\",
                           i.Compression||CASE WHEN i.Compression = 'ENABLED' THEN ' ('||i.Prefix_Length||')' END Compression,
                           seg.MBytes,
                           i.Uniqueness||CASE WHEN i.Uniqueness != 'UNIQUE' AND uc.Constraint_Name IS NOT NULL THEN ' enforcing '||uc.Constraint_Name END Uniqueness,
                           cc.Constraint_Name                                                         \"Foreign key protection\",
                           CASE WHEN cc.r_Table_Name IS NOT NULL THEN LOWER(cc.r_Owner)||'. '||cc.r_Table_Name END  \"Referenced table\",
                           cc.r_Num_Rows                                                              \"Num rows of referenced table\",
                           cc.r_Last_analyzed                                                         \"Last analyze referenced table\",
                           cc.Inserts                                                                 \"Inserts on ref. since anal.\",
                           cc.Updates                                                                 \"Updates on ref. since anal.\",
                           cc.Deletes                                                                 \"Deletes on ref. since anal.\",
                           i.Tablespace_Name                                                          \"Tablespace\",
                           i.Index_Type,
                           (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name) \"IOT Type\"
                    FROM   Indexes i
                    JOIN   All_Users u ON u.UserName = i.Owner AND u.Oracle_Maintained = 'N'
                    JOIN   DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.SubObject_Name IS NULL
                    LEFT OUTER JOIN   DBA_Index_Usage iu ON iu.Owner = i.Owner AND iu.Name = i.Index_Name AND iu.Last_Used > SYSDATE - ?
                    LEFT OUTER JOIN Ind_Columns ic        ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name AND ic.Column_Position = 1
                    /* Indexes used for protection of FOREIGN KEY constraints */
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE ORDERED USE_HASH(cc c rc rt m) */ cc.Owner, cc.Table_Name, cc.Column_name, c.Constraint_Name, rc.Owner r_Owner, rt.Table_Name r_Table_Name, rt.Num_rows r_Num_rows, rt.Last_Analyzed r_Last_analyzed, m.Inserts, m.Updates, m.Deletes
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c     ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
                                     JOIN   Constraints rc    ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
                                     JOIN   Tables rt     ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
                                     LEFT OUTER JOIN Tab_Modifications m ON m.Table_Owner = rc.Owner AND m.Table_Name = rc.Table_Name
                                     WHERE  cc.Position = 1
                                    ) cc ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name
                    /* Indexes used for enforcement of UNIQUE or PRIMARY KEY constraints */
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c   ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type IN ('U', 'P')
                                     LEFT OUTER JOIN Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name  AND ic.Column_Name = cc.Column_Name AND ic.Column_Position = cc.Position
                                     GROUP BY ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     HAVING COUNT(DISTINCT cc.Column_Name) = COUNT(DISTINCT ic.Column_Name)
                                    ) uc ON uc.Index_Owner = i.Owner AND uc.Index_Name = i.Index_Name
                    JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                          FROM   DBA_Segments
                          GROUP BY Owner, Segment_Name
                          HAVING SUM(bytes)/(1024*1024) > ?
                         ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                    CROSS JOIN (SELECT ? value FROM DUAL) Max_DML
                    WHERE (? = 'YES' OR i.Uniqueness != 'UNIQUE')
                    AND   (Max_DML.Value IS NULL OR NVL(cc.Inserts + cc.Updates + cc.Deletes, 0) < Max_DML.Value)
                    ORDER BY seg.MBytes DESC NULLS LAST
                   ",
            :parameter=>[{:name=>t(:dragnet_helper_9_param_1_name, :default=>'Number of days backwards without usage'),    :size=>8, :default=>7,   :title=>t(:dragnet_helper_9_param_1_hint, :default=>'Minumin age in days of Start-Monitoring timestamp of unused index')},
                         {:name=>t(:dragnet_helper_139_param_1_name, :default=>'Minimum size of index in MB'),    :size=>8, :default=>1,   :title=>t(:dragnet_helper_139_param_1_hint, :default=>'Minumin size of index in MB to be considered in selection')},
                         {:name=>t(:dragnet_helper_9_param_4_name, :default=>'Maximum DML-operations on referenced table'), :size=>8, :default=>'',   :title=>t(:dragnet_helper_9_param_4_hint, :default=>'Maximum number of DML-operations (Inserts + Updates + Deletes) on referenced table since last analyze (optional)')},
                         {:name=>t(:dragnet_helper_9_param_2_name, :default=>'Show unique indexes also (YES/NO)'), :size=>4, :default=>'NO',   :title=>t(:dragnet_helper_9_param_2_hint, :default=>'Unique indexes are needed for uniqueness even if they are not used')},
            ],
            min_db_version: '12.2'
        },

    ]
  end # unnecessary_indexes


end