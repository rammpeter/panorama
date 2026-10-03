# Oracle-DB: Find problematic iteration at skipped columns for INDEX RANGE SCAN with multi-column indexes

Datum: 2026-06-03
URL: https://rammpeter.blogspot.com/2026/06/oracle-find-problematic-iteration-at-skipped-index-columns.html
Labels: Active Session History, Oracle Database, Panorama

---

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

After that, for each iteration on the skipped column values, an additional B-tree access with the next used index column follows.

These columns skipped in between can dramatically increase the runtime and the number of buffer gets for a single index access, although the operation is an unsuspicious INDEX RANGE SCAN and the returned number of rows is quite low. 

Indicators for such skipped columns are:

- The filter condition with the column name is part of the v$SQL_Plan.ACCESS_PREDICATES and also the number of matched predicates (v$SQL_Plan.SEARCH_COLUMNS) includes this column, but it is repeated in v$SQL_Plan.FILTER_PREDICATES.

- Also by checking the index columns for not used columns before the last used column in v$SQL_Plan.ACCESS_PREDICATES also gives a clue.

The following SQLs select all occurrences of this pattern sorted by the time that is spent in index access with skipped columns.

You'll need EE and the Diagnostics Pack to do this investigation.

Check the current SGA:

SELECT h.Elapsed_Secs Elapsed_Secs_In_Index_Access ,ic.Column_Name Skipped_Ind_Column_in_Access, tc.Num_Distinct Num_Distinct_of_Skipped_Column,
 p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Options, p.Object_Owner Owner, p.Object_Name Index_Name, p.ID Plan_Line_ID, 
 p.Search_Columns, p.Access_Predicates, p.Filter_Predicates
FROM gv$SQL_Plan p
JOIN (
 SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Elapsed_Secs
 FROM gv$Active_Session_History
 WHERE SQL_Plan_Operation = 'INDEX'
 AND (SQL_Plan_Options LIKE 'RANGE SCAN%' OR SQL_Plan_Options LIKE 'SKIP SCAN%')
 GROUP BY Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
 ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Child_Number=p.Child_Number AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
JOIN DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name 
JOIN DBA_Ind_Columns ic ON ic.Index_Owner = p.Object_Owner AND ic.Index_Name = p.Object_Name 
 AND ic.Column_Position <= p.Search_Columns /* Consider only columns of an indx before the last used column */ 
JOIN DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
WHERE p.Access_Predicates IS NOT NULL
AND p.Filter_predicates IS NOT NULL /* Filter is set if not all access criteria are scanned by B-tree access */
AND p.Operation = 'INDEX'
AND UPPER(p.Access_Predicates) NOT LIKE '%'||ic.Column_Name||'%' /* get the index column in the middle of the index that is not part of the access criteria */
AND h.Elapsed_Secs > :Min_Elapsed_Time_Sec_per_Index
AND tc.Num_Distinct > :Min_Distinct_Values_per_Skipped_Column
ORDER BY h.Elapsed_Secs DESC
;

Check the AWR history:

SELECT h.Elapsed_Secs Elapsed_Secs_In_Index_Access ,ic.Column_Name Skipped_Ind_Column_in_Access, tc.Num_Distinct Num_Distinct_of_Skipped_Column,
 h.DBID, p.SQL_ID, p.Plan_Hash_Value, p.Options, p.Object_Owner Owner, p.Object_Name Index_Name, p.ID Plan_Line_ID, 
 p.Search_Columns, p.Access_Predicates, p.Filter_Predicates
FROM DBA_Hist_SQL_Plan p
JOIN (
 SELECT /*+ NO_MERGE */ DBID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) * 10 Elapsed_Secs
 FROM DBA_Hist_Active_Sess_History
 WHERE SQL_Plan_Operation = 'INDEX'
 AND (SQL_Plan_Options LIKE 'RANGE SCAN%' OR SQL_Plan_Options LIKE 'SKIP SCAN%')
 AND Sample_Time > SYSDATE - :Considered_Days_Backward
 GROUP BY DBID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
 ) h ON h.DBID = p.DBID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
JOIN DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name 
JOIN DBA_Ind_Columns ic ON ic.Index_Owner = p.Object_Owner AND ic.Index_Name = p.Object_Name 
 AND ic.Column_Position <= p.Search_Columns /* Consider only columns of an indx before the last used column */ 
JOIN DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
WHERE p.Access_Predicates IS NOT NULL
AND p.Filter_predicates IS NOT NULL /* Filter is set if not all access criteria are scanned by B-tree access */
AND p.Operation = 'INDEX'
AND UPPER(p.Access_Predicates) NOT LIKE '%'||ic.Column_Name||'%' /* get the index column in the middle of the index that is not part of the access criteria */
AND h.Elapsed_Secs > :Min_Elapsed_Time_Sec_per_Index
AND tc.Num_Distinct > :Min_Distinct_Values_per_Skipped_Column
ORDER BY h.Elapsed_Secs DESC
;

You can also use Panorama to do such investigations

The free analysis tool Panorama also contains these SQLs as part of the "Dragnet investigation for performance bottlenecks".

From the result you may drill down immediately into SQL plans, index structures etc. .
