# encoding: utf-8
module Dragnet::SuboptimalIndexUsageHelper

  private

  def suboptimal_index_usage
    [
        {
            :name  => t(:dragnet_helper_106_name, :default => 'Sub-optimal index access with only partial usage of index'),
            :desc  => t(:dragnet_helper_106_desc, :default => 'Occurrence of index attributes as filter instead of access criteria with significant load by index access targets to possible problems with index usage.
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
            :desc  => t(:dragnet_helper_115_desc, :default => 'INDEX RANGE|SKIP SCAN with high number of rows returned and restrictive filter after TABLE ACCESS BY ROWID leads to unnecessary effort for table access before rejecting table records from result.
You should consider to expand index by filter criteria of table access to reduce number of TABLE ACCESS BY ROWID.
This selection evaluates the current content of SGA.
Result is sorted by time effort for operation TABLE ACCESS BY ROWID.
'),
            :sql=>  " SELECT /* Panorama: cardinality_ratio index/table, thanks to Leonid Nossov */
                             ta.Inst_ID, ta.SQL_ID, ta.Plan_Hash_Value, ta.ID SQL_Plan_Line_ID, ir.Object_Owner||'.'||ir.Object_Name Index_Name,  ta.Object_Owner||'.'||ta.Object_Name Table_Name, ir.Cardinality Cardinality_Index, ta.Cardinality Cardinality_Table,
                             ir.Access_Predicates Access_Index, ir.Filter_Predicates Filter_Index, ta.Access_Predicates Access_Table, ta.Filter_Predicates Filter_Table, ROUND(ir.Cardinality/ta.Cardinality) Cardinality_Ratio, ash.Seconds Elapsed_Seconds,
                             ash.Min_Sample_Time, ash.Max_Sample_Time
                      FROM   (SELECT /*+ MO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Address, Access_Predicates, Filter_Predicates, ID, Cardinality, Object_Owner, Object_Name
                              FROM   gv$SQL_Plan
                              WHERE  Operation = 'TABLE ACCESS' AND Options LIKE 'BY%INDEX ROWID%'           /* should also catch BY LOCAL INDEX ROWID and INDEX ROWID BATCHED */
                             ) ta
                      JOIN   (SELECT /*+ MO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Address, Access_Predicates, Filter_Predicates, Parent_ID, Cardinality, Object_Owner, Object_Name
                              FROM   gv$SQL_Plan
                              WHERE  Operation = 'INDEX' AND Options IN ('RANGE SCAN', 'SKIP SCAN')
                             ) ir ON ir.Inst_ID=ta.Inst_ID AND ir.SQL_ID=ta.SQL_ID AND ir.Plan_Hash_Value=ta.Plan_Hash_Value AND ir.Child_Number=ta.Child_Number AND ir.Address=ta.Address AND ir.Parent_ID=ta.ID
                      JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Seconds, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time
                              FROM   gv$Active_Session_History
                              WHERE  SQL_Plan_Operation = 'TABLE ACCESS' AND SQL_Plan_Options LIKE 'BY%INDEX ROWID%'        /* only for this operation */
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
            :desc  => t(:dragnet_helper_116_desc, :default => 'INDEX RANGE|SKIP SCAN with high number of rows returned and restrictive filter after TABLE ACCESS BY ROWID leads to unnecessary effort for table access before rejecting table records from result.
You should consider to expand index by filter criteria of table access to reduce number of TABLE ACCESS BY ROWID.
This selection evaluates the AWR history.
Result is sorted by time effort for operation TABLE ACCESS BY ROWID.
'),
            :sql=>  " SELECT ta.DBID, ash.Instance_Number, ta.SQL_ID, ta.ID SQL_Plan_Line_ID,ir.Object_Owner||'.'||ir.Object_Name Index_Name,  ta.Object_Owner||'.'||ta.Object_Name Table_Name, ir.Cardinality Cardinality_Index, ta.Cardinality Cardinality_Table,
                             ir.Access_Predicates Access_Index, ir.Filter_Predicates Filter_Index, ta.Access_Predicates Access_Index, ta.Filter_Predicates Filter_Index, ROUND(ir.Cardinality/ta.Cardinality) Cardinality_Ratio, ash.Seconds Elapsed_Seconds
                      FROM   (SELECT /*+ MO_MERGE */ DBID, SQL_ID, Plan_Hash_Value, Access_Predicates, Filter_Predicates, ID, Cardinality, Object_Owner, Object_Name
                              FROM   DBA_Hist_SQL_Plan
                              WHERE  Operation = 'TABLE ACCESS' AND Options LIKE 'BY%INDEX ROWID%'  /* should also catch BY LOCAL INDEX ROWID and INDEX ROWID BATCHED */
                             ) ta
                      JOIN   (SELECT /*+ MO_MERGE */ DBID, SQL_ID, Plan_Hash_Value, Access_Predicates, Filter_Predicates, Parent_ID, Cardinality, Object_Owner, Object_Name
                              FROM   DBA_Hist_SQL_Plan
                              WHERE  Operation = 'INDEX' AND Options IN ('RANGE SCAN', 'SKIP SCAN')
                             ) ir ON ir.DBID=ta.DBID AND ir.SQL_ID=ta.SQL_ID AND ir.Plan_Hash_Value=ta.Plan_Hash_Value AND ir.Parent_ID=ta.ID
                      JOIN   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Seconds
                              FROM   DBA_Hist_Active_Sess_History
                              WHERE  Sample_Time > SYSDATE - ?
                              AND    SQL_Plan_Operation = 'TABLE ACCESS' AND SQL_Plan_Options LIKE 'BY%INDEX ROWID%'
                              AND    DBID = #{get_dbid}  /* do not count multiple times for multiple different DBIDs/ConIDs */
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
        {
          :name  => 'Find problematic iteration at skipped columns for INDEX RANGE SCAN with multi-column indexes (SGA)',
          :desc  => "\
If only following columns of an index are used as filter conditions and the first columns of the index are missing in the filter, Oracle's optimizer may use the INDEX SKIP SCAN operation.
At SQL execution the DB will iterate in that case over all distinct values of the skipped column and proceed with B-tree access for the columns used as access criteria.
The efficiency of a SKIP SCAN therefore depends on the number of distinct values for the skipped column(s).
If the skipped column has only one distinct value, then the SKIP SCAN operation will succeed with 3-5 buffer gets similar to a regular RANGE SCAN.
If the skipped column has lots of distinct values, then the B-tree access with the filter criteria will be executed as many times as the number of distinct values,
resulting in thousands or millions of buffer gets for a single index access instead of 3-5.

So far, this is mostly known for SKIP SCAN.
But also if the SQL plan states an INDEX RANGE SCAN, this possibly problematic iteration may happen.
Consider the following example:
There are columns of an index that are not used as access criteria, but subsequent columns of the index are part of the access criteria.
In that case the B-tree access is used for the first used columns of the index.
Then, the execution is iterating over all values of the skipped column for the previous criteria, in worst case as many iterations as distinct values exist for that column.
Then, for each iteration on the skipped column values, an additional B-tree access with the next used index column follows.

These columns skipped in between can dramatically increase the runtime and the number of buffer gets for a single index access, although the operation is an unsuspicious INDEX RANGE SCAN and the returned number of rows is quite low.

Indicators for such skipped columns are:
- The filter condition with the column name is part of the v$SQL_Plan.ACCESS_PREDICATES and also the number of matched predicates (v$SQL_Plan.SEARCH_COLUMNS) includes this column, but it is repeated in v$SQL_Plan.FILTER_PREDICATES.
- Also by checking the index columns for not used columns before the last used column in v$SQL_Plan.ACCESS_PREDICATES also gives a clue.

This SQL selects all occurrences of this pattern from SGA sorted by the time that is spent in index access with skipped columns.
You'll need EE and the Diagnostics Pack to do this investigation.
",
          :sql=>  "\
SELECT h.Elapsed_Secs Elapsed_Secs_In_Index_Access ,ic.Column_Name Skipped_Ind_Column_in_Access, tc.Num_Distinct Num_Distinct_of_Skipped_Column,
       p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Options, p.Object_Owner Owner, p.Object_Name Index_Name, p.ID Plan_Line_ID,
       p.Search_Columns, p.Access_Predicates, p.Filter_Predicates
FROM   gv$SQL_Plan p
JOIN   (
        SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Elapsed_Secs
        FROM   gv$Active_Session_History
        WHERE  SQL_Plan_Operation = 'INDEX'
        AND    (SQL_Plan_Options LIKE 'RANGE SCAN%' OR SQL_Plan_Options LIKE 'SKIP SCAN%')
        GROUP BY Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
       ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Child_Number=p.Child_Number AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
JOIN   DBA_Indexes i      ON  i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name
JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = p.Object_Owner AND ic.Index_Name = p.Object_Name
                          AND ic.Column_Position <= p.Search_Columns  /* Consider only columns of an indx before the last used column */
JOIN   DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
WHERE  p.Access_Predicates IS NOT NULL
AND    p.Filter_predicates IS NOT NULL    /* Filter is set if not all access criteria are scanned by B-tree access */
AND    p.Operation = 'INDEX'
AND    UPPER(p.Access_Predicates) NOT LIKE '%'||ic.Column_Name||'%' /* get the index column in the middle of the index that is not part of the access criteria */
AND    h.Elapsed_Secs > ?
AND    tc.Num_Distinct > ?
ORDER BY h.Elapsed_Secs DESC                      ",
          :parameter=>[
            {:name=>'Minimum elapsed time for the plan line of the index access (seconds)', :size=>8, :default=>100, :title=>'Minimum elapsed time in seconds for the particular plan line of the index access (seconds from ASH)' },
            {:name=>'Minimum distinct values of the skipped column', :size=>8, :default=>5, :title=>'Minimum number of distinct values of the skipped column to be considered in select' },
          ]
        },
        {
          :name  => 'Find problematic iteration at skipped columns for INDEX RANGE SCAN with multi-column indexes (AWR history)',
          :desc  => "\
If only following columns of an index are used as filter conditions and the first columns of the index are missing in the filter, Oracle's optimizer may use the INDEX SKIP SCAN operation.
At SQL execution the DB will iterate in that case over all distinct values of the skipped column and proceed with B-tree access for the columns used as access criteria.
The efficiency of a SKIP SCAN therefore depends on the number of distinct values for the skipped column(s).
If the skipped column has only one distinct value, then the SKIP SCAN operation will succeed with 3-5 buffer gets similar to a regular RANGE SCAN.
If the skipped column has lots of distinct values, then the B-tree access with the filter criteria will be executed as many times as the number of distinct values,
resulting in thousands or millions of buffer gets for a single index access instead of 3-5.

So far, this is mostly known for SKIP SCAN.
But also if the SQL plan states an INDEX RANGE SCAN, this possibly problematic iteration may happen.
Consider the following example:
There are columns of an index that are not used as access criteria, but subsequent columns of the index are part of the access criteria.
In that case the B-tree access is used for the first used columns of the index.
Then, the execution is iterating over all values of the skipped column for the previous criteria, in worst case as many iterations as distinct values exist for that column.
Then, for each iteration on the skipped column values, an additional B-tree access with the next used index column follows.

These columns skipped in between can dramatically increase the runtime and the number of buffer gets for a single index access, although the operation is an unsuspicious INDEX RANGE SCAN and the returned number of rows is quite low.

Indicators for such skipped columns are:
- The filter condition with the column name is part of the v$SQL_Plan.ACCESS_PREDICATES and also the number of matched predicates (v$SQL_Plan.SEARCH_COLUMNS) includes this column, but it is repeated in v$SQL_Plan.FILTER_PREDICATES.
- Also by checking the index columns for not used columns before the last used column in v$SQL_Plan.ACCESS_PREDICATES also gives a clue.

This SQL selects all occurrences of this pattern from AWR history sorted by the time that is spent in index access with skipped columns.
You'll need EE and the Diagnostics Pack to do this investigation.
",
          :sql=>  "\
SELECT h.Elapsed_Secs Elapsed_Secs_In_Index_Access ,ic.Column_Name Skipped_Ind_Column_in_Access, tc.Num_Distinct Num_Distinct_of_Skipped_Column,
       h.DBID, p.SQL_ID, p.Plan_Hash_Value, p.Options, p.Object_Owner Owner, p.Object_Name Index_Name, p.ID Plan_Line_ID,
       p.Search_Columns, p.Access_Predicates, p.Filter_Predicates
FROM   DBA_Hist_SQL_Plan p
JOIN   (
        SELECT /*+ NO_MERGE */ DBID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) * 10 Elapsed_Secs
        FROM   DBA_Hist_Active_Sess_History
        WHERE  SQL_Plan_Operation = 'INDEX'
        AND    (SQL_Plan_Options LIKE 'RANGE SCAN%' OR SQL_Plan_Options LIKE 'SKIP SCAN%')
        AND    Sample_Time > SYSDATE - ?
        GROUP BY DBID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
       ) h ON h.DBID = p.DBID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
JOIN   DBA_Indexes i      ON  i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name
JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = p.Object_Owner AND ic.Index_Name = p.Object_Name
                          AND ic.Column_Position <= p.Search_Columns   /* Consider only columns of an indx before the last used column */
JOIN   DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
WHERE  p.Access_Predicates IS NOT NULL
AND    p.Filter_predicates IS NOT NULL    /* Filter is set if not all access criteria are scanned by B-tree access */
AND    p.Operation = 'INDEX'
AND    UPPER(p.Access_Predicates) NOT LIKE '%'||ic.Column_Name||'%' /* get the index column in the middle of the index that is not part of the access criteria */
AND    h.Elapsed_Secs > ?
AND    tc.Num_Distinct > ?
ORDER BY h.Elapsed_Secs DESC                      ",
          :parameter=>[
            {:name=>'Consideration of history backward in days', :size=>8, :default=>8, :title=>'Number of days in history backward from now for consideration' },
            {:name=>'Minimum elapsed time for the plan line of the index access (seconds)', :size=>8, :default=>100, :title=>'Minimum elapsed time in seconds for the particular plan line of the index access (seconds from ASH)' },
            {:name=>'Minimum distinct values of the skipped column', :size=>8, :default=>5, :title=>'Minimum number of distinct values of the skipped column to be considered in select' },
          ]
        },
    ]

  end # suboptimal_index_usage


end