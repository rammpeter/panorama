# encoding: utf-8
module Dragnet::SuboptimalIndexUsageHelper

  private

  def suboptimal_index_usage
    [
        {
            :name  => t(:dragnet_helper_106_name, :default => 'Sub-optimal index access with only partial usage of index'),
            :desc  => t(:dragnet_helper_106_desc, :default => 'Occurrence of index attributes as filter instead of access criteria with signifcant load by index access targets to possible problems with index usage.
This may be caused by for example:
- wrong data type for bind variable
- usage of functions at the wrong side while accessing columns of index
This selection evaluates current SGA.
'),
            :sql=>  " SELECT h.Elapsed_Secs , p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.ID Plan_Line_ID, p.Access_Predicates, p.Filter_Predicates
                      FROM   gv$SQL_Plan p
                      JOIN   (
                              SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Elapsed_Secs
                              FROM   gv$Active_Session_History
                              WHERE  SQL_Plan_Operation = 'INDEX'
                              GROUP BY Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                           ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Child_Number=p.Child_Number AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                      WHERE  p.Access_Predicates IS NOT NULL
                      AND    p.Filter_predicates IS NOT NULL
                      AND    p.Operation = 'INDEX'
                      --AND    INSTR(p.access_predicates, p.filter_predicates) !=0  -- Filter vollständig in Access enthalten
                      AND h.Elapsed_Secs > ?
                      ORDER BY h.Elapsed_Secs DESC
                    ",
            :parameter=>[
                {:name=>t(:dragnet_helper_106_param_1_name, :default=>'Minimum runtime for index access in seconds'), :size=>8, :default=>100, :title=>t(:dragnet_helper_106_param_1_hint, :default=>'Minimum runtime in seconds for index access since last load of SQL in SGA') },
            ]
        },
        {
            :name  => t(:dragnet_helper_115_name, :default => 'Excessive filtering after TABLE ACCESS BY ROWID due to weak index access criteria (current SGA)'),
            :desc  => t(:dragnet_helper_115_desc, :default => 'INDEX RANGE SCAN with high number of rows returned and restrictive filter after TABLE ACCESS BY ROWID leads to unnecessary effort for table access before rejecting table records from result.
You should consider to expand index by filter criterias of table access to reduce number of TABLE ACCESS BY ROWID.
This selection evaluates the current content of SGA.
Result is sorted by time effort for operation TABLE ACCESS BY ROWID.
'),
            :sql=>  " SELECT /* Panorama: cardinality_ratio index/table, thanks to Leonid Nossov */
                             ta.Inst_ID, ta.SQL_ID, ta.Plan_Hash_Value, ta.ID SQL_Plan_Line_ID, ir.Object_Owner||'.'||ir.Object_Name Index_Name,  ta.Object_Owner||'.'||ta.Object_Name Table_Name, ir.Cardinality Cardinality_Index, ta.Cardinality Cardinality_Table,
                             ir.Access_Predicates Access_Index, ir.Filter_Predicates Filter_Index, ta.Access_Predicates Access_Table, ta.Filter_Predicates Filter_Table, ROUND(ir.Cardinality/ta.Cardinality) Cardinality_Ratio, ash.Seconds Elapsed_Seconds,
                             ash.Min_Sample_Time, ash.Max_Sample_Time
                      FROM   (SELECT /*+ MO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Address, Access_Predicates, Filter_Predicates, ID, Cardinality, Object_Owner, Object_Name
                              FROM   gv$SQL_Plan
                              WHERE  Operation = 'TABLE ACCESS' AND Options LIKE 'BY%INDEX ROWID'           /* should also catch BY LOCAL INDEX ROWID */
                             ) ta
                      JOIN   (SELECT /*+ MO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Address, Access_Predicates, Filter_Predicates, Parent_ID, Cardinality, Object_Owner, Object_Name
                              FROM   gv$SQL_Plan
                              WHERE  Operation = 'INDEX' AND Options = 'RANGE SCAN'
                             ) ir ON ir.Inst_ID=ta.Inst_ID AND ir.SQL_ID=ta.SQL_ID AND ir.Plan_Hash_Value=ta.Plan_Hash_Value AND ir.Child_Number=ta.Child_Number AND ir.Address=ta.Address AND ir.Parent_ID=ta.ID
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Seconds, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time
                              FROM   gv$Active_Session_History
                              WHERE  SQL_Plan_Operation = 'TABLE ACCESS' AND SQL_Plan_Options LIKE 'BY%INDEX ROWID'        /* only for this operation */
                              GROUP BY Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                              HAVING COUNT(*) > ?
                             ) ash ON ash.Inst_ID=ta.Inst_ID AND ash.SQL_ID=ta.SQL_ID AND ash.SQL_Child_Number=ta.Child_Number AND ash.SQL_Plan_Hash_Value=ta.Plan_Hash_Value AND ash.SQL_Plan_Line_ID=ta.ID
                      WHERE  ta.Cardinality < ir.Cardinality / ?
                      ORDER BY ash.Seconds DESC
                    ",
            :parameter=>[
                {:name=>t(:dragnet_helper_115_param_2_name, :default=>'Minimum database time in ASH for TABLE ACCESS BY ROWID (seconds)'), :size=>8, :default=>100, :title=>t(:dragnet_helper_115_param_2_hint, :default=>'Minimum elapsed time in seconds for operation TABLE ACCESS BY ROWID in Active Session History to consider SQL in result') },
                {:name=>t(:dragnet_helper_115_param_1_name, :default=>'Minimum ratio of cardinality index/table'), :size=>8, :default=>5, :title=>t(:dragnet_helper_115_param_1_hint, :default=>'Minimum value for "cardinality of index / cardinality of table"') },
            ]
        },
        {
            :name  => t(:dragnet_helper_116_name, :default => 'Excessive filtering after TABLE ACCESS BY ROWID due to weak index access criteria (AWR history)'),
            :desc  => t(:dragnet_helper_116_desc, :default => 'INDEX RANGE SCAN with high number of rows returned and restrictive filter after TABLE ACCESS BY ROWID leads to unnecessary effort for table access before rejecting table records from result.
You should consider to expand index by filter criterias of table access to reduce number of TABLE ACCESS BY ROWID.
This selection evaluates the AWR history.
Result is sorted by time effort for operation TABLE ACCESS BY ROWID.
'),
            :sql=>  " SELECT ta.DBID, ash.Instance_Number, ta.SQL_ID, ta.ID SQL_Plan_Line_ID,ir.Object_Owner||'.'||ir.Object_Name Index_Name,  ta.Object_Owner||'.'||ta.Object_Name Table_Name, ir.Cardinality Cardinality_Index, ta.Cardinality Cardinality_Table,
                             ir.Access_Predicates Access_Index, ir.Filter_Predicates Filter_Index, ta.Access_Predicates Access_Index, ta.Filter_Predicates Filter_Index, ROUND(ir.Cardinality/ta.Cardinality) Cardinality_Ratio, ash.Seconds Elapsed_Seconds
                      FROM   (SELECT /*+ MO_MERGE */ DBID, SQL_ID, Plan_Hash_Value, Access_Predicates, Filter_Predicates, ID, Cardinality, Object_Owner, Object_Name
                              FROM   DBA_Hist_SQL_Plan
                              WHERE  Operation = 'TABLE ACCESS' AND Options LIKE 'BY%INDEX ROWID'  /* should also catch BY LOCAL INDEX ROWID */
                             ) ta
                      JOIN   (SELECT /*+ MO_MERGE */ DBID, SQL_ID, Plan_Hash_Value, Access_Predicates, Filter_Predicates, Parent_ID, Cardinality, Object_Owner, Object_Name
                              FROM   DBA_Hist_SQL_Plan
                              WHERE  Operation = 'INDEX' AND Options = 'RANGE SCAN'
                             ) ir ON ir.DBID=ta.DBID AND ir.SQL_ID=ta.SQL_ID AND ir.Plan_Hash_Value=ta.Plan_Hash_Value AND ir.Parent_ID=ta.ID
                      JOIN   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Seconds
                              FROM   DBA_Hist_Active_Sess_History
                              WHERE  Sample_Time > SYSDATE - ?
                              AND    SQL_Plan_Operation = 'TABLE ACCESS' AND SQL_Plan_Options LIKE 'BY%INDEX ROWID'
                              GROUP BY DBID, Instance_Number, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                              HAVING COUNT(*) > ?
                             ) ash ON ash.DBID=ta.DBID AND ash.SQL_ID=ta.SQL_ID AND ash.SQL_Plan_Hash_Value=ta.Plan_Hash_Value AND ash.SQL_Plan_Line_ID=ta.ID
                      WHERE  ta.Cardinality < ir.Cardinality / ?
                      ORDER BY ash.Seconds DESC
                      ",
            :parameter=>[
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                {:name=>t(:dragnet_helper_116_param_2_name, :default=>'Minimum database time in ASH for TABLE ACCESS BY ROWID (seconds)'), :size=>8, :default=>100, :title=>t(:dragnet_helper_116_param_2_hint, :default=>'Minimum elapsed time in seconds for operation TABLE ACCESS BY ROWID in Active Session History to consider SQL in result') },
                {:name=>t(:dragnet_helper_116_param_1_name, :default=>'Minimum ratio of cardinality index/table'), :size=>8, :default=>5, :title=>t(:dragnet_helper_116_param_1_hint, :default=>'Minimum value for "cardinality of index / cardinality of table"') },
            ]
        },

    ]

  end # suboptimal_index_usage


end