# encoding: utf-8
module Dragnet::PartitioningHelper

  private

  def partitioning
    [
        {
            :name  => t(:dragnet_helper_11_name, :default=> 'Local-partitioning for NonUnique-indexes'),
            :desc  => t(:dragnet_helper_11_desc, :default=> 'Indexes of partitioned tables may be equal partitioned (LOCAL), especially if partitioning physically isolates different data content of table.
Partitioning of indexes may also reduce BLevel of index.
For unique indexes this is only true if partition key is equal with first column(s) of index.
Negative aspect is multiple access on every partition of index if partition key is not the same like indexed column(s) and partition key is not part of WHERE-filter.'),
            :sql=> "SELECT /* DB-Tools Local-Partitionierung*/
                             i.Owner, i.Table_Name, i.Index_Name,
                             i.Num_Rows , i.Distinct_Keys, seg.MBytes,
                             p.Partitions Partitions_Table,
                             sp.SubPartitions SubPartitions_Table,
                             ic.Column_Name First_Index_Column,
                             tc.Column_Name First_Partition_Key,
                             DECODE(ic.Column_Name, tc.Column_Name, 'YES') \"Partit. Key = Index Column\"
                      FROM   DBA_Indexes i
                      JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                      JOIN   (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, COUNT(*) Partitions
                              FROM   DBA_Tab_Partitions
                              GROUP BY Table_Owner, Table_Name
                             ) p ON p.Table_Owner = t.Owner AND p.Table_Name = t.Table_Name
                      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, COUNT(*) SubPartitions
                              FROM   DBA_Tab_SubPartitions
                              GROUP BY Table_Owner, Table_Name
                             ) sp ON sp.Table_Owner = t.Owner AND sp.Table_Name = t.Table_Name
                      JOIN   DBA_Part_Key_Columns tc
                             ON (    tc.Owner           = t.Owner
                                 AND tc.Name            = t.Table_Name
                                 AND tc.Object_Type     = 'TABLE'
                                 AND tc.Column_Position = 1
                                 /* Nur erste Spalte prüfen, danach manuell */
                                )
                      JOIN  DBA_Ind_Columns ic
                             ON (    ic.Index_Owner     = i.Owner
                                 AND ic.Index_Name      = i.Index_Name
                                 AND ic.Column_Position = 1
                                )
                      JOIN   (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                             ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                      WHERE  i.Partitioned = 'NO'
                      AND    t.Partitioned = 'YES'
                      AND    i.UniqueNess  = 'NONUNIQUE'
                      AND NOT EXISTS (
                             SELECT '!' FROM DBA_Constraints r
                             WHERE  r.Owner       = t.Owner
                             AND    r.Table_Name  = t.Table_Name
                             AND    r.Constraint_Type = 'U'
                             AND    r.Index_Name  = i.Index_Name
                             )
                      ORDER BY DECODE(ic.Column_Name, tc.Column_Name, 'YES') NULLS LAST, i.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_12_name, :default=> 'Local-partitioning of unique indexes with partition-key = index-column'),
            :desc  => t(:dragnet_helper_12_desc, :default=>"Also unique indexes may be local partitioned if partition key is in identical order leading part of index.
This way partition pruning may be used for access on unique indexes plus possible decrease of index' BLevel."),
            :sql=> "SELECT /* DB-Tools Ramm Partitionierung Unique Indizes */
                              t.Owner, t.Table_Name, i.Uniqueness, tc.Column_Name Partition_Key1, i.Index_Name, t.Num_Rows, seg.MBytes
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
                             JOIN (SELECT Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                                  ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                      WHERE t.Partitioned = 'YES'
                      AND   i.Partitioned = 'NO'
                      ORDER BY t.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_13_name, :default=> 'Local-partitioning of indexes with overhead in access'),
            :desc  => t(:dragnet_helper_13_desc, :default=> 'Local partitioning by not indexed columns leads to iterative access on all partitions of index during range scan or unique scan.
For frequently used indexes with high partition count this may result in unnecessary high access on database buffers.
Solution for such situations is global (not) partitioning of index.'),
            :sql=> "WITH  Days_Back AS (SELECT SYSDATE-? Limit FROM DUAL),
                          ASH_Time AS (SELECT /*+ NO_MERGE MATERIALIZE */ i.Inst_ID, NVL(Min_Sample_Time, SYSTIMESTAMP) Min_Sample_Time
                                       FROM   gv$Instance i
                                       LEFT OUTER JOIN (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time
                                                        FROM gv$Active_Session_History
                                                        GROUP BY Inst_ID
                                                       ) ash ON ash.Inst_ID = i.Inst_ID
                                      ),
                    Min_Snap AS (SELECT /*+ NO_MERGE MATERIALIZE */ MIN(Snap_ID) Min_Snap_ID FROM DBA_Hist_Snapshot WHERE Begin_Interval_Time > (SELECT Limit FROM Days_Back)),
                    Ash AS (SELECT /*+ NO_MERGE MATERIALIZE */ SUM(Sample_Cycle) Elapsed_Secs, Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_plan_Line_ID
                            FROM   (
                                     SELECT /*+ NO_MERGE */
                                           10 Sample_Cycle, s.Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                    FROM   DBA_Hist_Active_Sess_History s
                                    WHERE  s.Sample_Time < (SELECT Min_Sample_Time FROM Ash_Time a WHERE a.Inst_ID = s.Instance_Number)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
                                    AND    s.Sample_Time > (SELECT Limit FROM Days_Back)
                                    AND    s.Snap_ID > (SELECT Min_Snap_ID FROM Min_Snap)
                                    AND    s.DBID = (SELECT DBID FROM v$Database)
                                    UNION ALL
                                    SELECT 1 Sample_Cycle, Inst_ID Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                    FROM   gv$Active_Session_History
                                   )
                            GROUP BY Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_plan_Line_ID
                           ),
                   Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, Object_Owner, Object_Name,
                                    SUM(ash.Elapsed_Secs) Elapsed_Secs, SUM(p.Executions) Executions,
                                    MAX(p.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY ash.Elapsed_Secs NULLS FIRST) Heaviest_SQL_ID,
                                    MAX(ash.Elapsed_Secs) KEEP (DENSE_RANK LAST ORDER BY ash.Elapsed_Secs NULLS FIRST) Heaviest_SQL_Elapsed_Secs
                             FROM   (
                                     SELECT Inst_ID, Object_Owner, Object_Name, SQL_ID, Plan_Line_ID, Plan_Hash_Value, SUM(Executions) Executions,
                                            LISTAGG(Partition_Start, ',') WITHIN GROUP (ORDER BY Partition_Start) Partition_Start_Values,
                                            LISTAGG(Partition_Stop,  ',') WITHIN GROUP (ORDER BY Partition_Stop)  Partition_Stop_Values
                                     FROM   (
                                             SELECT /*+ NO_MERGE MATERIALIZE */ p.Inst_ID, p.Object_Owner, p.Object_Name, p.SQL_ID, p.Partition_Start, p.Partition_Stop, p.Object_Type, p.Options, p.ID Plan_Line_ID, p.Plan_Hash_Value,
                                                    s.Executions
                                             FROM   gv$SQL_Plan p
                                             JOIN   gv$SQL s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number
                                             UNION ALL
                                             SELECT /*+ NO_MERGE MATERIALIZE */ s.Instance_Number, p.Object_Owner, p.Object_Name, p.SQL_ID, p.Partition_Start, p.Partition_Stop, p.Object_Type, p.Options, p.ID Plan_Line_ID, p.Plan_Hash_Value,
                                                    s.Executions_Delta
                                             FROM   DBA_Hist_SQL_Plan p
                                             JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
                                             JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                                             CROSS JOIN Days_Back
                                             WHERE  ss.Begin_Interval_Time > Days_Back.Limit
                                            )
                                     WHERE  Partition_Start IS NOT NULL
                                     AND    Object_Name IS NOT NULL
                                     AND    Object_Type LIKE 'INDEX%'
                                     AND    Options IN ('UNIQUE SCAN', 'RANGE SCAN', 'RANGE SCAN (MIN/MAX)')
                                     GROUP BY Inst_ID, Object_Owner, Object_Name, SQL_ID, Plan_Hash_Value, Plan_Line_ID
                                    ) p
                             LEFT OUTER JOIN Ash ON ash.Instance_Number = p.Inst_ID AND ash.SQL_ID = p.SQL_ID AND ash.SQL_Plan_Hash_Value = p.Plan_Hash_Value AND ash.SQL_Plan_Line_ID = p.Plan_Line_ID
                             GROUP BY Inst_ID, Object_Owner, Object_Name
                            )
              SELECT /* DB-Tools Ramm: mehrfach frequentierte Hash-Partitions */ i.Owner, i.Index_Name, i.Index_Type,
                                           i.Table_Name, pl.Executions, pl.Elapsed_Secs Elapsed_Secs_All_SQLs, i.Num_Rows, pl.Heaviest_SQL_ID, Heaviest_SQL_Elapsed_Secs,
                                           p.Partitioning_Type, c.Column_Position, c.Column_Name Part_Col, ic.Column_Name Ind_Col,
                                           i.UniqueNess, i.Compression, i.BLevel, i.Distinct_Keys, i.Avg_Leaf_Blocks_per_Key,
                                           i.Avg_Data_blocks_Per_Key, i.Clustering_factor, p.Partition_Count, isp.SubPartition_Count, p.Locality
                                    FROM   DBA_Indexes i
                                    JOIN   DBA_Part_Indexes p     ON p.Owner=i.Owner AND p.Index_Name=i.Index_Name
                                    JOIN   DBA_Part_Key_Columns c ON c.Owner=i.Owner AND c.Name=i.Index_Name AND c.Object_Type='INDEX'
                                    JOIN   DBA_Ind_columns ic     ON ic.Index_Owner=i.Owner AND ic.Index_Name=i.Index_Name AND ic.Column_Position = c.Column_Position
                                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Index_Owner, Index_Name, COUNT(*) SubPartition_Count
                                                     FROM   DBA_Ind_SubPartitions
                                                     GROUP BY Index_Owner, Index_Name
                                                    ) isp ON isp.Index_Owner = i.Owner AND isp.Index_Name = i.Index_Name
                                    LEFT OUTER JOIN Plans pl ON pl.Object_Owner = i.Owner AND pl.Object_Name = i.Index_Name
                                    WHERE  c.Column_Name != ic.Column_Name
                                    ORDER BY pl.Elapsed_Secs DESC NULLS LAST, pl.Executions DESC NULLS LAST, i.Num_Rows DESC NULLS LAST

            ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, title: t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            ]
        },
        {
          :name  => t(:dragnet_helper_158_name, :default=> 'Partitioning for expensive full table scans with filters'),
          :desc  => t(:dragnet_helper_158_desc, :default=> "If expensive full table scan is done with filter conditions than range or list partitioning by one or more of this filter conditions may significantly reduce runtime.
Especially with release 12.2 and above automatic list partitioning lets you easy handle the creation of needed partitions without operation effort.
Conditions for useful partitioning by these filters are:
- The potential partition key should significantly reduce the result (e.g. to less than 3/4 if used as filter condition)
- The resulting number of partitions should by manageable (Oracle's absolute maximum for partitions of a table is 1048575, but the optimal number is much smaller)
- The number of records in a partition should be high enough (e.g. more than 10000 .. 100000), otherwhise it could be more sufficient to use an index
- The filter condition should by deterministic (able to be used as partition criteria)
"),
          :sql=> "\
SELECT h.SQL_ID, h.SQL_Plan_Line_ID \"SQL plan line id\", h.SQL_Plan_Hash_Value, h.Wait_Time_Sec \"Wait Time (Sec) for plan line\",
       LOWER(o.Owner)||'.'||o.Object_Name \"Object according to ASH\",
       LOWER(p.Object_Owner)||'.'||p.Object_Name \"Object according to SQL plan\",
       NVL(p.Filter_Predicates, '[Not known because SQL plan is not in SGA]') Filter_Predicates
FROM   (
        SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, Current_Obj#, SUM(Wait_Time_Sec) Wait_Time_Sec
        FROM   (
                 WITH ASH_Time AS (SELECT /*+ NO_MERGE MATERIALIZE */ i.Inst_ID, NVL(Min_Sample_Time, SYSTIMESTAMP) Min_Sample_Time
                                   FROM   gv$Instance i
                                   LEFT OUTER JOIN (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time
                                                    FROM gv$Active_Session_History
                                                    GROUP BY Inst_ID
                                                   ) ash ON ash.Inst_ID = i.Inst_ID
                                  )
                SELECT /*+ NO_MERGE ORDERED */
                       10 Wait_Time_Sec, Sample_Time, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, SQL_Child_Number, SQL_Plan_Operation, SQL_Plan_Options, User_ID, Current_Obj#
                FROM   DBA_Hist_Active_Sess_History s
                WHERE  s.Sample_Time < (SELECT Min_Sample_Time FROM Ash_Time a WHERE a.Inst_ID = s.Instance_Number)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
                AND    DBID = (SELECT DBID FROM v$Database) /* Suppress multiple occurrence of records in PDB environment */
                UNION ALL
                SELECT 1 Wait_Time_Sec,  Sample_Time, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, SQL_Child_Number, SQL_Plan_Operation, SQL_Plan_Options, User_ID, Current_Obj#
                FROM gv$Active_Session_History
               )
        WHERE  Sample_Time > SYSDATE-?
        AND    SQL_Plan_Operation = 'TABLE ACCESS'
        AND    SQL_Plan_Options LIKE '%FULL'  /* also include Exadata variants */
        AND    User_ID NOT IN (#{system_userid_subselect})
        AND    Current_Obj# != -1
        GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, SQL_Child_Number, Current_Obj#
        HAVING SUM(Wait_Time_Sec) > ?
       ) h
LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = h.Current_Obj#
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ SQL_ID, Plan_Hash_Value, ID, Filter_Predicates, Object_Owner, Object_Name  /* Compress over child numbers */
                 FROM   gv$SQL_Plan
                 WHERE  Operation = 'TABLE ACCESS'
                 AND    Options LIKE '%FULL'  /* also include Exadata variants */
                 GROUP BY SQL_ID, Plan_Hash_Value, ID, Filter_Predicates, Object_Owner, Object_Name
                ) p
                ON p.SQL_ID = h.SQL_ID AND p.Plan_Hash_Value = h.SQL_Plan_Hash_Value AND p.ID = h.SQL_Plan_Line_ID
WHERE (p.SQL_ID IS NULL OR p.Filter_Predicates IS NOT NULL)
ORDER BY Wait_Time_Sec DESC
          ",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, title: t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            {:name=>t(:dragnet_helper_158_param_1_name, :default=>'Minimum wait time for full table scan'), :size=>8, :default=>100, title: t(:dragnet_helper_158_param_1_hint, :default=>'Minimum wait time in seconds for full table scan on the object to be considered in this selection') },
          ]
        },
        {
          :name  => t(:dragnet_helper_158_name, :default=> 'Partitioning for expensive access filtered by columns with low number of distinct values'),
          :desc  => t(:dragnet_helper_158_desc, :default=> "If expensive full table access is done with filter conditions than range or list partitioning by one or more of this filter conditions may significantly reduce runtime.
Especially with release 12.2 and above automatic list partitioning lets you easy handle the creation of needed partitions without operation effort.
Conditions for useful partitioning by these filters are:
- The potential partition key should significantly reduce the result (e.g. to less than 3/4 if used as filter condition)
- The resulting number of partitions should by manageable (Oracle's absolute maximum for partitions of a table is 1048575, but the optimal number is much smaller)
- The number of records in a partition should be high enough (e.g. more than 10000 .. 100000), otherwhise it could be more sufficient to use an index
- The filter condition should by deterministic (able to be used as partition criteria)

Unfortunately, only execution plans in SGA are considered because Oracle does not store access and filter predicates in AWR speichert (fixed with rel. 21.3).

"),
          :sql=> "\
SELECT x.*, tc.Column_Name, tc.Num_Distinct
FROM   (
        SELECT /*+ NO_MERGE */ h.SQL_ID, p.Plan_Hash_Value,
               LISTAGG(h.SQL_Plan_Line_ID, ',') WITHIN GROUP (ORDER BY h.SQL_Plan_Line_ID) Plan_Line_IDs,
               SUM(h.Waiting_Secs)   Waiting_Secs,
               LISTAGG(p.Operation||' '||p.Options, ',') WITHIN GROUP (ORDER BY h.SQL_Plan_Line_ID) Operations,
               NVL(i.Table_Owner, p.Object_Owner)  Owner,
               NVL(i.Table_Name,  p.Object_Name)   Table_Name,
               LISTAGG(UPPER(p.Access_Predicates||' '||p.Filter_Predicates), ',' #{"ON OVERFLOW TRUNCATE" if get_db_version >= '12.2'}) WITHIN GROUP (ORDER BY h.SQL_Plan_Line_ID) Predicates
        FROM   (SELECT /*+ NO_MERGE */ SQL_ID, Plan_Hash_Value, ID,
                       CASE WHEN MIN(Object_Type) LIKE 'INDEX%' THEN 1 END IsIndex,
                       MIN(Operation)       Operation,
                       MIN(Options)         Options,
                       MIN(Object_Owner)    Object_Owner,
                       MIN(Object_Name)     Object_Name,
                       MIN(Filter_Predicates) Filter_Predicates,
                       MIN(Access_Predicates) Access_Predicates
                FROM   gv$SQL_Plan
                WHERE  (Object_Type LIKE 'TABLE%' OR Object_Type LIKE 'INDEX%')
                AND    Partition_Start IS NULL
                GROUP BY SQL_ID, Plan_Hash_Value, ID
               ) p
        JOIN   (SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*)*10 Waiting_Secs
                FROM   DBA_Hist_Active_Sess_History
                WHERE  Sample_Time > SYSDATE - ?
                AND    SQL_Plan_Line_ID IS NOT NULL
                GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                HAVING COUNT(*) * 10 > ?  /* * 10 seconds */
               ) h ON h.SQL_ID = p.SQL_ID AND h.SQL_Plan_Hash_Value = p.Plan_Hash_Value AND h.SQL_Plan_Line_ID = p.ID
        LEFT OUTER JOIN DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name AND p.IsIndex = 1
        GROUP BY h.SQL_ID, p.Plan_Hash_Value, NVL(i.Table_Owner, p.Object_Owner), NVL(i.Table_Name,  p.Object_Name)
       ) x
JOIN   DBA_Tab_Columns tc ON tc.Owner = x.Owner AND tc.Table_Name = x.Table_Name
WHERE  x.Predicates LIKE '%'||tc.Column_Name||'%'
AND    tc.Num_Distinct < ?
ORDER BY x.Waiting_Secs DESC
          ",
          :parameter=>[
            {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, title: t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
            {:name=>t(:dragnet_helper_164_param_1_name, :default=>'Minimum wait time for index and table access'), :size=>8, :default=>500, title: t(:dragnet_helper_164_param_1_hint, :default=>'Minimum wait time in seconds for index and table access on the object to be considered in this selection') },
            {:name=>t(:dragnet_helper_164_param_2_name, :default=>'Maximum number of dictinct values for column'), :size=>8, :default=>4000, title: t(:dragnet_helper_164_param_2_hint, :default=>'Maximum number of distinct values for column to be considered as possible partition key') },
          ]
        },
        {
          :name  => t(:dragnet_helper_165_name, :default=> 'Recommendations for automatic LIST partitioning'),
          :desc  => t(:dragnet_helper_165_desc, :default=> "\
Automatic list partitiong (available from Rel. 12.2) is an easy way to reduce the data amount for full table scans with low effort and tiny impact.
This selection shows table or index access by SQL with filtering by columns with strong selectivity ordered by the runtime of the operation.
You may choose auto list partitioning for this tables if the low and stable number of distinct values for this filter columns allows to have the same number of partitions.
Multiple columns can be combined as partition keys, so often there is no need for subpartitioning in this case.
Auto list partitioning helps to:
- reduce the amount of processed DB blocks at full table scan
- remove indexes on potential partition key columns
- reduce index columns by potential partition key columns as leading columns (combined with LOCAL partitioning of this indexes)
"),
          :sql=> "\
WITH Indexes AS     (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name
                     FROM   DBA_Indexes
                     WHERE  Owner NOT IN (#{system_schema_subselect})
                    ),
     Tables  AS     (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Num_Rows
                     FROM   DBA_Tables
                     WHERE  Owner NOT IN (#{system_schema_subselect})
                    ),
     Ind_and_Tab AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner Object_Owner, Table_Name Object_Name, Owner Table_Owner, Table_Name, Num_Rows
                     FROM   Tables
                     UNION ALL
                     SELECT i.Owner Object_Owner, i.Index_Name Object_Name, i.Table_Owner, i.Table_Name, t.Num_Rows
                     FROM  Indexes i
                     JOIN  Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
                    ),
     Plans   AS     (SELECT /*+ NO_MERGE MATERIALIZE */ DISTINCT SQL_ID, Plan_Hash_Value, ID, Operation, Options, Object_Owner, Object_Name, Access_Predicates, Filter_Predicates,
                            SUBSTR(UPPER(Access_Predicates), 1, 1500)||' '||SUBSTR(UPPER(Filter_Predicates), 1, 1500) Upper_Predicates
                     FROM   gv$SQL_PLan p
                     WHERE  Access_Predicates IS NOT NULL OR Filter_Predicates IS NOT NULL
                    ),
     Tab_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ tc.Owner, tc.Table_Name, tc.Column_Name, tc.Data_Type, tc.Num_Distinct, tc.Num_Nulls
                     FROM   DBA_Tab_Columns tc
                     LEFT OUTER JOIN DBA_Part_Key_Columns pc ON pc.Owner = tc.Owner AND pc.Name = tc.Table_Name AND pc.Column_Name = tc.Column_Name
                     WHERE  tc.Owner NOT IN (#{system_schema_subselect})
                     AND    pc.Column_Name IS NULL /* Don't show colums that are already used as partition key */
                     AND    tc.Num_Distinct + tc.Num_Nulls > 1 /* There should be more than 1 partition in result */
                     AND    tc.Num_Distinct < ?
                    ),
     Load AS        (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Wait_Seconds
                     FROM   gv$Active_Session_History
                     GROUP BY SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                     HAVING COUNT(*) > ?
                    ),
     Part_Keys AS   (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Name Table_Name, LISTAGG(Column_Name, ',') WITHIN GROUP (ORDER BY Column_Position) Partition_Keys
                     FROM   DBA_Part_Key_Columns
                     WHERE  Owner NOT IN (#{system_schema_subselect})
                     GROUP BY Owner, Name
                    )
SELECT /*+ LEADING(p l t tc pc) USE_HASH(p l t tc pc) OPT_PARAM('_bloom_filter_enabled' 'false')*/
       p.SQL_ID, p.Plan_Hash_Value \"Plan Hash Value\", p.ID \"Plan Line ID\", t.Table_Owner, t.Table_Name, t.Num_Rows,
       pc.Partition_Keys \"Already Used Partition Keys\", tc.Column_Name \"Filter Column from SQL\",
       tc.Num_Distinct \"Distinct values of column\", tc.Num_Nulls \"Nulls\",
       l.Wait_Seconds \"Waited seconds\",
       p.Operation||' '||p.Options Operation, p.Access_Predicates, p.Filter_Predicates
FROM   Plans p
JOIN   Load l                 ON l.SQL_ID = p.SQL_ID AND l.SQL_Plan_Hash_Value = p.Plan_Hash_Value AND l.SQL_Plan_Line_ID = p.ID
JOIN   Ind_and_Tab t          ON t.Object_Owner = p.Object_Owner AND t.Object_Name = p.Object_Name
JOIN   Tab_Columns tc         ON tc.Owner = t.Table_Owner AND tc.Table_Name = t.Table_Name
LEFT OUTER JOIN Part_Keys pc  ON pc.Owner = t.Table_Owner AND pc.Table_Name = t.Table_Name
WHERE  Regexp_LIKE(p.Upper_Predicates, '(^|=|\\+|-| |\")'||tc.Column_Name||'($|=|\\+|-| |\")')
ORDER BY l.Wait_Seconds DESC
          ",
          :parameter=>[
            {:name=>t(:dragnet_helper_165_param_1_name, :default=>'Max. accepted number of partitions per table '), :size=>8, :default=>10000, title: t(:dragnet_helper_165_param_1_hint, :default=>'Maximum number of partitions per table accepted for this system. Only columns with less distinct values are considered') },
            {:name=>t(:dragnet_helper_165_param_2_name, :default=>'Minimum wait time for operation (seconds)'), :size=>8, :default=>60, title: t(:dragnet_helper_165_param_2_hint, :default=>'Minimum wait time for operation in seconds to be considered in selection. Calculated from ASH for particular execution plan line.') },
          ]
        },
    ]
  end # partitioning


end

