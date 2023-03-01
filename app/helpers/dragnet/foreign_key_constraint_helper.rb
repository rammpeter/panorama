# encoding: utf-8
module Dragnet::ForeignKeyConstraintHelper

  private

  def dragnet_foreign_key_constraint
    [
        {
            :name  => t(:dragnet_helper_5_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially missing indexes)'),
            :desc  => t(:dragnet_helper_5_desc, :default=> 'Protection of colums with foreign key references by index can be necessary for:
- Ensure delete performance of referenced table (suppress FullTable-Scan)
- Supress lock propagation (shared lock on index instead of table)'),
            :sql=> "WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_name, Constraint_Type, r_Owner, r_Constraint_Name
                                         FROM   DBA_Constraints
                                         WHERE  Owner NOT IN (#{system_schema_subselect})
                                        ),
                         Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_name, Column_Name, Position
                                         FROM   DBA_Cons_Columns
                                         WHERE  Owner NOT IN (#{system_schema_subselect})
                                        ),
                         Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Index_Owner, Index_Name, Column_Name
                                         FROM   DBA_Ind_Columns
                                         WHERE  Index_Owner NOT IN (#{system_schema_subselect})
                                        ),
                         Protected_Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name
                                                   FROM   (
                                                           SELECT Owner, Constraint_Name, Index_Owner, Index_Name
                                                           FROM   (SELECT cc.Owner, cc.Table_Name, cc.Constraint_Name, ic.Index_Owner, ic.Index_Name, ic.Column_Name Index_Column_Name,
                                                                          COUNT(DISTINCT cc.Column_Name) OVER (PARTITION BY cc.Owner, cc.Table_Name, cc.Constraint_Name) Cons_Column_Count
                                                                   FROM   Cons_Columns cc
                                                                   LEFT OUTER JOIN Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name AND ic.Column_name = cc.Column_Name
                                                                   )
                                                           GROUP BY Owner, Constraint_Name, Index_Owner, Index_Name
                                                           HAVING MIN(Cons_Column_Count) = COUNT(DISTINCT Index_Column_Name) /* All FK columns must exist in protecting index, no matter in which order */
                                                          )
                                                   GROUP BY Owner, Constraint_Name
                                                  )
                    SELECT /* DB-Tools Ramm  Index fehlt fuer Foreign Key*/
                           LOWER(Ref.Owner)||'.'||Ref.Table_Name Table_name,
                           reft.Num_Rows,
                           ref.Constraint_Name,
                           #{get_db_version >= "11.2" ?
                                      "(SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM Cons_Columns cc WHERE cc.Owner = ref.Owner AND cc.Constraint_Name = ref.Constraint_Name) Columns,
                                      " :
                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM Cons_Columns ORDER BY Position) cc WHERE cc.Owner = ref.Owner AND cc.Constraint_Name = ref.Constraint_Name) Columns,
                                      "
                           }
                           lower(Ref.R_Owner)||'.'||target.Table_Name Target_Table,
                           targett.Num_rows \"Target Num Rows\",
                           Ref.R_Constraint_Name \"Target Constraint Name\",
                           targett.Last_Analyzed Last_Analyzed_Target,
                           target_mod.Deletes \"Target Deletes since analyze\"
                    FROM   Constraints Ref
                    JOIN   Constraints target       ON target.Owner = ref.R_Owner AND target.Constraint_Name = ref.R_Constraint_Name
                    JOIN   DBA_Tables reft          ON reft.Owner = ref.Owner AND reft.Table_Name = ref.Table_Name
                    JOIN   DBA_Tables targett       ON targett.Owner = target.Owner AND targett.Table_Name = target.Table_Name
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, SUM(Deletes) Deletes
                                     FROM   DBA_Tab_Modifications
                                     GROUP BY Table_Owner, Table_Name
                                    ) target_mod ON target_mod.Table_Owner = target.Owner AND target_mod.Table_Name = target.Table_Name
                    WHERE  Ref.Constraint_Type='R'
                    AND targett.Num_rows > ?
                    AND (ref.Owner, ref.Constraint_Name) NOT IN (SELECT Owner, Constraint_Name FROM Protected_Constraints)
                    ORDER BY targett.Num_rows DESC NULLS LAST, ref.Table_Name",
            :parameter=>[{:name=>t(:dragnet_helper_5_param_1_name, :default=> 'Min. no. of rows of referenced table'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_5_param_1_hint, :default=> 'Minimum number of rows of referenced table') },]
        },
        {
            :name  => t(:dragnet_helper_155_name, :default=> 'Non validated foreign key constraints'),
            :desc  => t(:dragnet_helper_155_desc, :default=> 'Non validated foreign key constraints prevent the usage of some optimizer features like JOIN ELIMINATION.
For full availability of all optimizer features foreign key constraints should be regularly validated.

Missing validation can be effectively made up by temporary setting parallel degree for table:
ALTER TABLE <tab> PARALLEL x;
ALTER TABLE <tab> MODIFY CONSTRAINT <constraint> VALIDATE;
ALTER TABLE <tab> NOPARALLEL;
  '),
            :sql=> "\
WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, Constraint_Type, r_Owner, r_Constraint_Name, Validated, Last_Change FROM DBA_Constraints),
     Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Num_Rows FROM DBA_Tables)
SELECT c.Owner, c.Table_Name, t.Num_Rows, c.Constraint_Name, c.r_Owner, rt.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows, c.r_Constraint_Name, c.Last_Change
FROM   Constraints c
JOIN   Tables t       ON  t.Owner = c.Owner   AND t.Table_Name = c.Table_Name
JOIN   Constraints rc ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
JOIN   Tables rt      ON rt.Owner = rc.Owner  AND rt.Table_Name = rc.Table_Name
WHERE  c.Constraint_Type = 'R'
AND    c.Validated != 'VALIDATED'
AND    c.Owner NOT IN ('SYSTEM')
ORDER BY t.Num_Rows DESC",
        },
        {
          :name  => t(:dragnet_helper_162_name, :default=> 'Unnecessary primary keys without referencing foreign keys'),
          :desc  => t(:dragnet_helper_162_desc, :default=> 'Primary key constraint including PK-index and PK-column may be obsolete and can be dropped if:
- Purpose of this primary key is only technical nature (not ensuring business-driven uniqueness)
- No foreign keys are referencing this primary key
- No access occurs by using the primary key index

Precondition for this selection is that index usage is monitored by ALTER INDEX ... MONITORING USAGE.'),
          :sql=> "\
WITH Cons AS (SELECT /*+ NO_MERGE MATERIALIZE */ cc.Owner, cc.Constraint_Name, cc.Table_Name, MIN(cc.Column_Name) Column_Name,
                     MIN(Index_Owner) Index_Owner, MIN(Index_Name) Index_Name
              FROM   DBA_Cons_Columns cc
              JOIN   DBA_Constraints c ON c.Owner = cc.Owner AND c.Table_Name = cc.Table_Name AND c.Constraint_Name = cc.Constraint_Name
              WHERE  c.Constraint_Type = 'P'
              GROUP BY cc.Owner, cc.Constraint_Name, cc.Table_Name
              HAVING COUNT(*) = 1
             ),
     RefCons AS (SELECT /*+ NO_MERGE  MATERIALIZE */ r_Owner, r_Constraint_Name FROM DBA_Constraints WHERE Constraint_Type = 'R'),
     Usage AS (
#{
   if get_db_version >= '12.1'
     "
                SELECT Owner, Index_Name, Table_Name, Monitoring, Used, Start_Monitoring, End_Monitoring
                FROM   DBA_Object_Usage
     "
   else
     "
                SELECT /*+ NO_MERGE  MATERIALIZE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
                       decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
                       decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                       ou.start_monitoring, ou.end_monitoring
                FROM   sys.object_usage ou
                JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                JOIN   sys.obj$ io ON io.obj# = ou.obj#
                JOIN   sys.obj$ t  ON t.obj# = i.bo#
                JOIN   DBA_Users u ON u.User_ID = io.owner#
     "
   end
}              )
SELECT c.Owner, c.Table_Name, c.Constraint_Name, c.Column_Name, c.Index_Name, i.Index_Type, i.Num_Rows, u.Start_Monitoring
FROM   Cons c
JOIN   DBA_Indexes i ON i.Owner = c.Index_Owner AND i.Index_Name = c.Index_name
JOIN   Usage u ON u.Owner = c.Index_Owner AND u.Index_Name = c.Index_Name
WHERE  TO_DATE(u.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE - ?
AND    u.Used='NO' AND u.Monitoring='YES'
AND    (c.Owner, c.Constraint_Name) NOT IN (SELECT r_Owner, r_Constraint_Name FROM RefCons)
ORDER BY i.Num_Rows DESC NULLS LAST",
          parameter: [{:name=>t(:dragnet_helper_9_param_1_name, :default=>'Number of days backwards without usage'),    :size=>8, :default=>7,   :title=>t(:dragnet_helper_9_param_1_hint, :default=>'Minumin age in days of Start-Monitoring timestamp of unused index')}]
        },
    ]
  end

end