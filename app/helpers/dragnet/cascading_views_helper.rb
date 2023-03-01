# encoding: utf-8
module Dragnet::CascadingViewsHelper

  private

  def cascading_views
    [
        {
            :name  => t(:dragnet_helper_97_name, :default=>'Cascading views (views with dependency from other views)'),
            :desc  => t(:dragnet_helper_97_desc, :default=>'Views with dependencies from other views (possibly with multilevel dependency hierarchy) have the risk
to select data from unnecessesary objects which are not relevant for executing SQL statement.
This way the optimizer is not able to detect irrelevant parts of view neither to remove this parts from execution plan.
Sensible architecture pattern is, to use views only in one dimension without further dependencies from other views.
'),
            :sql=>  "WITH ViewDep AS (
                                    SELECT /*+ NO_MERGE */
                                           *
                                    FROM dba_dependencies
                                    WHERE  Type='VIEW' AND Referenced_Type='VIEW'
                                    AND    Owner NOT IN (#{system_schema_subselect})
                                    AND   Owner NOT LIKE 'APEX%'
                                    )
                    SELECT level Dependency_Depth, LOWER(CONNECT_BY_ROOT Owner)||'.'||CONNECT_BY_ROOT Name Considered_View,
                            LOWER(Owner)||'.'||Name Referencing_View,
                            LOWER(Referenced_Owner)||'.'||Referenced_Name Referenced_View
                    FROM   ViewDep
                    CONNECT BY NOCYCLE PRIOR Referenced_Owner=Owner AND PRIOR Referenced_Name=Name
           "
        },
        {
            :name  => t(:dragnet_helper_98_name, :default=>'SQLs using Cascading views (views with dependency from other views), evaluation of current SGA'),
            :desc  => t(:dragnet_helper_98_desc, :default=>'Views with dependencies from other views (possibly with multilevel dependency hierarchy) have the risk
to select data from unnecessesary objects which are not relevant for executing SQL statement.
This way the optimizer is not able to detect irrelevant parts of view neither to remove this parts from execution plan.
Sensible architecture pattern is, to use views only in one dimension without further dependencies from other views.
--- Selection may take some time ---
'),
            :sql=>  "WITH ViewDep AS ( -- Alle
                                      SELECT /*+ NO_MERGE */
                                             *
                                      FROM dba_dependencies
                                      WHERE  Type='VIEW' AND Referenced_Type='VIEW'
                                      AND    Owner NOT IN (#{system_schema_subselect})
                                      AND   Owner NOT LIKE 'APEX%'
                                      ),
                           Views AS ( SELECT /*+ NO_MERGE MATERIALIZE */ level Dependency_Depth, CONNECT_BY_ROOT Owner Root_Owner, CONNECT_BY_ROOT Name Root_View_Name,
                                             LOWER(CONNECT_BY_ROOT Owner)||'.'||CONNECT_BY_ROOT Name Considered_View,
                                             LOWER(Owner)||'.'||Name Referencing_View,
                                             LOWER(Referenced_Owner)||'.'||Referenced_Name Referenced_View
                                      FROM   ViewDep
                                      CONNECT BY NOCYCLE PRIOR Referenced_Owner=Owner AND PRIOR Referenced_Name=Name
                                    )
                      SELECT /*+ NO_MERGE MATERIALIZE */ s.Inst_ID, s.SQL_ID, ROUND(s.Elapsed_Time/1000000,2) Elapsed_Time_Secs, Executions,
                             v.Dependency_Depth, v.Considered_View, v.Referencing_View, v.Referenced_View,
                             SUBSTR(s.SQL_FullText,1,1000) SQL_Text
                      FROM   gv$SQLArea s
                      CROSS JOIN Views v
                      WHERE /*+ ORDERED_PREDICATES */
                            s.Command_Type IN (2,3,6,7) -- Insert/Update/Delete/SELECT
                      AND   s.Elapsed_Time > ? * 1000000
                      AND   UPPER(s.SQL_FullText) LIKE '%'||v.Root_View_Name||'%'
                      AND   (    REGEXP_LIKE(SQL_FullText, '[ ,.]'||Root_View_Name||'[ ,.]', 'im')
                              OR REGEXP_LIKE(SQL_FullText, '[ ,.]'||Root_View_Name||'$', 'im')
                              OR REGEXP_LIKE(SQL_FullText, '^'||Root_View_Name||'[ ,.]', 'im')
                            )
                      ORDER BY s.Elapsed_Time DESC
            ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_minimal_elapsed_name, :default=>'Minimum total elapsed time (sec.)'), :size=>8, :default=>60, :title=>t(:dragnet_helper_param_minimal_elapsed_hint, :default=>'Minimum total elapsed time in seconds for consideration in selection') }]

        },
        {
            :name  => t(:dragnet_helper_99_name, :default=>'SQLs using Cascading views (views with dependency from other views), evaluation of AWH History'),
            :desc  => t(:dragnet_helper_99_desc, :default=>'Views with dependencies from other views (possibly with multilevel dependency hierarchy) have the risk
to select data from unnecessesary objects which are not relevant for executing SQL statement.
This way the optimizer is not able to detect irrelevant parts of view neither to remove this parts from execution plan.
Sensible architecture pattern is, to use views only in one dimension without further dependencies from other views.
--- Selection may take some time ---
'),
            :sql=>  " WITH ViewDep AS ( -- Alle
                                      SELECT /*+ NO_MERGE */
                                             *
                                      FROM dba_dependencies
                                      WHERE  Type='VIEW' AND Referenced_Type='VIEW'
                                      AND    Owner NOT IN (#{system_schema_subselect})
                                      AND   Owner NOT LIKE 'APEX%'
                                      ),
                           Views AS ( SELECT /*+ NO_MERGE MATERIALIZE */ level Dependency_Depth, CONNECT_BY_ROOT Owner Root_Owner, CONNECT_BY_ROOT Name Root_View_Name,
                                             LOWER(CONNECT_BY_ROOT Owner)||'.'||CONNECT_BY_ROOT Name Considered_View,
                                             LOWER(Owner)||'.'||Name Referencing_View,
                                             LOWER(Referenced_Owner)||'.'||Referenced_Name Referenced_View
                                      FROM   ViewDep
                                      CONNECT BY NOCYCLE PRIOR Referenced_Owner=Owner AND PRIOR Referenced_Name=Name
                                    ),
                          SQLs AS (SELECT /*+ NO_MERGE MATERIALIZE */ si.*, t.SQL_Text SQL_FullText
                                    FROM   (SELECT s.DBID, s.SQL_ID,
                                                   ROUND(SUM(s.Elapsed_Time_Delta)/1000000,2) Elapsed_Time_Secs,
                                                   SUM(s.Executions_Delta) Executions
                                            FROM   DBA_Hist_Snapshot ss
                                            JOIN   DBA_Hist_SqlStat s ON s.DBID = ss.DBID AND s.Snap_ID = ss.Snap_ID AND s.Instance_Number = ss.Instance_Number
                                            WHERE  ss.Begin_Interval_Time > SYSDATE - ?
                                            GROUP BY s.DBID, s.SQL_ID
                                           )si
                                    JOIN   DBA_Hist_SQLText t ON t.DBID = si.DBID AND t.SQL_ID = si.SQL_ID
                                    WHERE  t.Command_Type IN (2,3,6,7) -- Insert/Update/Delete/SELECT
                                    AND    Elapsed_Time_Secs > ?
                                  )
                      SELECT /*+ NO_MERGE MATERIALIZE */ s.SQL_ID, Elapsed_Time_Secs, Executions,
                             v.Dependency_Depth, v.Considered_View, v.Referencing_View, v.Referenced_View,
                             SUBSTR(s.SQL_FullText,1,1000) SQL_Text
                      FROM   SQLs s
                      CROSS JOIN Views v
                      WHERE /*+ ORDERED_PREDICATES */
                            UPPER(s.SQL_FullText) LIKE '%'||v.Root_View_Name||'%'
                      AND   (    REGEXP_LIKE(SQL_FullText, '[ ,.]'||Root_View_Name||'[ ,.]', 'im')
                              OR REGEXP_LIKE(SQL_FullText, '[ ,.]'||Root_View_Name||'$', 'im')
                              OR REGEXP_LIKE(SQL_FullText, '^'||Root_View_Name||'[ ,.]', 'im')
                            )
                      ORDER BY s.Elapsed_Time_Secs DESC
            ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=>t(:dragnet_helper_param_minimal_elapsed_name, :default=>'Minimum total elapsed time (sec.)'), :size=>8, :default=>60, :title=>t(:dragnet_helper_param_minimal_elapsed_hint, :default=>'Minimum total elapsed time in seconds for consideration in selection') }
            ]
        },
    ]
  end


end