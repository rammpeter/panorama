# encoding: utf-8
module Dragnet::InstanceSetupTuning

  private

  def instance_setup_tuning
    [
      {
        :name     => t(:dragnet_helper_group_parallel_query_usage, default: 'Parallel query usage'),
        :entries  => parallel_query_usage
      },
      {
            name:   'Inconsistent dependency timestamps between dependency and parent object',
            desc:   'Timestamp of last specification change of a parent object (DBA_Objects.Timestamp) and timestamp of stored dependency should be identical.
If they differ this may be a reason for ORA-4068, ORA-4065, ORA-06508.
Solution: recompile affected dependent objects
',
            sql:     "SELECT dep.p_Obj# Parent_Obj#, LOWER(po.Owner)||'.'||po.Object_Name Parent_Object, po.Object_Type Parent_Type, po.Status Parent_Status, po.Created Parent_Created, po.Last_DDL_Time Parent_Last_DDL,
                             TO_DATE(po.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Parent_Spec_TS, dep.p_Timestamp Dependency_Parent_TS,
                             dep.d_Obj# Dependent_Obj#, LOWER(d.Owner)||'.'||d.Object_Name Dependent_Object, d.Object_Type Dependent_Type, d.Status Dependent_Status
                      FROM   sys.dependency$ dep
                      LEFT OUTER JOIN sys.Obj$ o ON o.Obj# = dep.p_Obj#
                      LEFT OUTER JOIN DBA_Objects po ON po.Object_ID = dep.p_Obj#
                      LEFT OUTER JOIN DBA_Objects d ON d.Object_ID = dep.d_Obj#
                      WHERE TO_DATE(po.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') != dep.p_Timestamp
                     ",
            not_for_autonomous: true
        },
        {
          :name  => t(:dragnet_helper_103_name, :default=>'System-statistics: Check for up-to-date system analyze info'),
          :desc  => t(:dragnet_helper_103_desc, :default=>'For cost-based optimizer system statistics should be enough up-to-date and describe reality'),
          :sql=> 'SELECT * FROM sys.Aux_Stats$',
          not_for_autonomous: true
        },
        {
          :name  => t(:dragnet_helper_104_name, :default=>'Objekt statistics: Check on up-to-date analyze info (Tables)'),
          :desc  => t(:dragnet_helper_104_desc, :default=>'Sufficient up-to-date object statistics should exist for cost-based optimizers'),
          :sql=> "\
WITH Segments AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, Partition_Name, ROUND(SUM(Bytes/(1024*1024)),2) Size_MB
                  FROM   DBA_Segments
                  WHERE  Owner NOT IN (#{system_schema_subselect})
                  GROUP BY Owner, Segment_Name, Partition_Name
                 ),
     Tab_Modifications AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, SubPartition_Name,
                                  SUM(Inserts) Inserts, SUM(Updates) Updates, SUM(Deletes) Deletes
                           FROM   DBA_Tab_Modifications
                           GROUP BY Table_Owner, Table_Name, Partition_Name, SubPartition_Name
                          )
SELECT CASE
         WHEN Last_Analyzed IS NULL                       THEN 'Object never analyzed'
         WHEN Last_Analyzed < SYSDATE-d.Min_Age           THEN 'Last analyzed too old'
         WHEN x.Num_Rows = 0 AND x.MBytes > d.Min_MBytes  THEN 'Size does not match with rows=0'
       END Possible_Problem,
       x.*
FROM   (SELECT t.Owner, t.Table_Name, NULL Partition_Name, NULL SubPartition_Name, t.Num_Rows, t.Last_Analyzed,
               s.MBytes, m.Inserts \"Inserts since last analyze\", m.Updates \"Updates since last analyze\", m.Deletes \"Deletes since last analyze\"
        FROM   DBA_Tables t
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Size_MB) MBytes
                         FROM   Segments
                         GROUP BY Owner, Segment_Name
                        ) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, SUM(Inserts) Inserts, SUM(Updates) Updates, SUM(Deletes) Deletes
                         FROM Tab_Modifications
                         GROUP BY Table_Owner, Table_Name
                        ) m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name
        WHERE  t.Temporary = 'N'
        UNION ALL
        SELECT t.Table_Owner Owner, t.Table_Name, t.Partition_Name, NULL SubPartition_Name, t.Num_Rows, t.Last_Analyzed,
               s.Size_MB, m.Inserts, m.Updates, m.Deletes
        FROM   DBA_Tab_Partitions t
        LEFT OUTER JOIN Segments s ON s.Owner = t.Table_Owner AND s.Segment_Name = t.Table_Name AND s.Partition_Name = t.Partition_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, Partition_Name, SUM(Inserts) Inserts, SUM(Updates) Updates, SUM(Deletes) Deletes
                         FROM DBA_Tab_Modifications
                         GROUP BY Table_Owner, Table_Name, Partition_Name
                        ) m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name
        UNION ALL
        SELECT t.Table_Owner Owner, t.Table_Name, t.Partition_Name, t.SubPartition_Name, t.Num_Rows, t.Last_Analyzed,
               s.Size_MB, m.Inserts, m.Updates, m.Deletes
        FROM   DBA_Tab_SubPartitions t
        LEFT OUTER JOIN Segments s ON s.Owner = t.Table_Owner AND s.Segment_Name = t.Table_Name AND s.Partition_Name = t.SubPartition_Name
        LEFT OUTER JOIN Tab_Modifications m ON m.Table_Owner = t.Table_Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name = t.Partition_Name AND m.SubPartition_Name = t.SubPartition_Name
       ) x
CROSS JOIN (SELECT ? Min_Age, ? Min_Mbytes FROM DUAL) d
WHERE  x.Owner NOT IN (#{system_schema_subselect})
AND   (   Last_Analyzed IS NULL
       OR Last_Analyzed < SYSDATE-d.Min_Age
       OR (x.Num_Rows = 0 AND x.MBytes > d.Min_MBytes)
      )
ORDER BY x.MBytes DESC NULLS LAST
                    ",
          :parameter=>[
            {:name=>t(:dragnet_helper_104_param_1_name, :default=>'Minimum age of existing analyze info in days'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_104_param_1_hint, :default=>'If analyze info exists: minimun age for consideration in selection')},
            {:name=>t(:dragnet_helper_104_param_2_name, :default=>'Minimum size (MB) if Num_Rows = 0'), :size=>8, :default=>100, :title=>t(:dragnet_helper_104_param_2_hint, :default=>'Minimum size of object in MB for check if num_rows=0 matches with size of object')}
          ]
        },
        {
          :name  => t(:dragnet_helper_108_name, :default=>'Objekt statistics: Check on up-to-date analyze info (Indexes)'),
          :desc  => t(:dragnet_helper_108_desc, :default=>'Sufficient up-to-date object statistics should exist for cost-based optimizers'),
          :sql=> "\
SELECT CASE
         WHEN Last_Analyzed IS NULL                       THEN 'Object never analyzed'
         WHEN Last_Analyzed < SYSDATE-d.Min_Age           THEN 'Last analyzed too old'
         WHEN x.Num_Rows = 0 AND x.MBytes > d.Min_MBytes  THEN 'Size does not match with rows=0'
       END Possible_Problem,
       x.*
FROM   (
        SELECT i.Owner, i.Table_Name, i.Index_Name, NULL Partition_Name, NULL SubPartition_Name, i.Num_Rows, i.Last_Analyzed,
               ROUND(s.MBytes,2) MBytes
        FROM   DBA_Indexes i
        JOIN   DBA_Tables t ON t.Owner = i.Table_Owner AND t.Table_Name = i.Table_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes
                         FROM   DBA_Segments
                         GROUP BY Owner, Segment_Name
                        ) s ON s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
        WHERE  t.Temporary = 'N'
        UNION ALL
        SELECT ip.Index_Owner Owner, i.Table_Name, ip.Index_Name, ip.Partition_Name, NULL SubPartition_Name, ip.Num_Rows, ip.Last_Analyzed,
               ROUND(s.MBytes,2) MBytes
        FROM   DBA_Ind_Partitions ip
        JOIN   DBA_Indexes i ON i.Owner = ip.Index_Owner AND i.Index_Name = ip.Index_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, Partition_Name, SUM(Bytes)/(1024*1024) MBytes
                         FROM   DBA_Segments
                         GROUP BY Owner, Segment_Name, Partition_Name
                        ) s ON s.Owner = ip.Index_Owner AND s.Segment_Name = ip.Index_Name AND s.Partition_Name = ip.Partition_Name
        UNION ALL
        SELECT ip.Index_Owner Owner, i.Table_Name, ip.Index_Name, ip.Partition_Name, ip.SubPartition_Name, ip.Num_Rows, ip.Last_Analyzed,
               ROUND(s.MBytes,2) MBytes
        FROM   DBA_Ind_SubPartitions ip
        JOIN   DBA_Indexes i ON i.Owner = ip.Index_Owner AND i.Index_Name = ip.Index_Name
        LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, Partition_Name, SUM(Bytes)/(1024*1024) MBytes
                         FROM   DBA_Segments
                         GROUP BY Owner, Segment_Name, Partition_Name
                        ) s ON s.Owner = ip.Index_Owner AND s.Segment_Name = ip.Index_Name AND s.Partition_Name = ip.SubPartition_Name
       ) x
CROSS JOIN (SELECT ? Min_Age, ? Min_Mbytes FROM DUAL) d
WHERE  x.Owner NOT IN (#{system_schema_subselect})
AND   (   Last_Analyzed IS NULL
       OR Last_Analyzed < SYSDATE-d.Min_Age
       OR (x.Num_Rows = 0 AND x.MBytes > d.Min_MBytes)
      )
ORDER BY x.MBytes DESC NULLS LAST
                    ",
          :parameter=>[
            {:name=>t(:dragnet_helper_108_param_1_name, :default=>'Minimum age of existing analyze info in days'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_108_param_1_hint, :default=>'If analyze info exists: minimun age for consideration in selection')},
            {:name=>t(:dragnet_helper_104_param_2_name, :default=>'Minimum size (MB) if Num_Rows = 0'), :size=>8, :default=>100, :title=>t(:dragnet_helper_104_param_2_hint, :default=>'Minimum size of object in MB for check if num_rows=0 matches with size of object')}
          ]
        },

    ]
  end # instance_setup_tuning


end


