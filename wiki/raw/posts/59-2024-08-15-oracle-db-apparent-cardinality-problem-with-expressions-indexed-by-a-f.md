# Oracle-DB: Apparent cardinality problem with expressions indexed by a function based index 

Datum: 2024-08-15
URL: https://rammpeter.blogspot.com/2024/08/oracle-db-cardinality-problem-for.html
Labels: Extended statistic, Function based index, Oracle Database

---

Recently a problem occured using function based indexes:

The optimizer switched to full table scan on a table with 3.2 billion rows although the used function expression is covered by a function based index.

The expression often evaluates to NULL ond so this index has only 4.9 million rows ( < 1% of the table rows ) and a low selectivity of approx. 4 rows per key. 

Let's consider the simple case.

The table INVOICE has two interesting columns:

- CUSTOMER_ID 38 mio distinct values, not null, avg. 84 rows/key

- OPEN_AMOUNT not null, 4,8 mio. records > 0

A function based index was created to quickly identify the small portion of rows of a certain customer where the OPEN_AMOUNT is > 0 
CREATE INDEX IX_OPENAMOUNT ON INVOICE(CASE WHEN Open_Amount > 0 THEN Customer_ID END);

This SQL is used to select the rows of a certain customer where the OPEN_AMOUNT is > 0 

SELECT ID
FROM Invoice
WHERE CASE WHEN Open_Amount > 0 THEN Customer_ID END = :B1 
;

The execution plan shows a full table scan with the cardinality = number of rows / 100

The expectation for this SQL which returns only approx. 4 rows per execution would be that the optimizer chooses the function based index.

If we look at the execution plan it shows that a fixed rule for function expressions is used:

The estimated cardinality for a function expression is the number of rows divided by 100.

The unexpected fact is, that this rule "rows/100" is also used for cardinality if the function expression is covered by a function based index.

Unexpected, because the function based index provides excellent statistics about the selectivity of the function expression (number of null values, number of distinct rows etc.) which could be used by the optimizer to better estimate the cardinality.

But why didn't the optimizer use the existing index?

An answer is shown if we force the optimizer to use the index:

SELECT /*+ INDEX_RS_ASC(Invoice) */ ID
FROM Invoice
WHERE CASE WHEN Open_Amount > 0 THEN Customer_ID END = :B1 
;

Now the index is used. The SQL execution is fast as expected. The execution shows the index usage.

The cardinality for the index access is the number of rows of that index, independent from the known statistic values of that index.

The cardinality for the following table access is the number of rows for the table / 100, although there is no additional filter at the table access.

The costs of that SQL with index usage (4,539,007) is twice as high as the costs for the full scan (2,818,600). That's why the optimzer chooses the full scn over the index scan.

However, the expected values were a cardinality close to 1 for both the index access and the subsequent table access with correspondingly low costs.

I tended to treat this beaviour as a bug at this time.

Real cause for that problem

After digging a little deeper, it turned out that:

- The creation of a function based index also creates an extended statistic for the index expression

- This extended statistic (to be found in view DBA_Stat_Extensions) does not contain statistics calculations after index creation (visible by DBA_Tab_Col_Statistics, DBA_Tab_Histograms).

- This statistics calculation is done at next GATHER_TABLE_STATS.

- The missing statistics for the extended statististic are gathered even if there is nothing else done because analyze info was not stale (DBA_Tab_Modifications).

ALso the Last_Analyzed_Date does not change in that case.

- The statistic attributes known by the function based index do not count for cardinality calculation as long as no extended statistics values are available.
- Calling only DBMS_STATS.GATHER_INDEX_STATS after creation of the function based index does not solve the problem / does not create the statistics values for the extended statistic related to this index.

After execution of DBMS_STATS.GATHER_TABLE_STATS the execution plan now shows the expected very small cardinaltiy:

Conclusion

Ensure to run DBMS_STATS.GATHER_TABLE_STATS after creation of function based indexes to be sure that valid cardinality estimations are used by the optimizer.

Especially if the automatic statistics gathering in the daily maintenance window is not used this is necessary, because looking at DBA_Tab_Modifications only does not give the glue that exeution of GATHER_TABLE_STATS is needed.

If execution of DBMS_STATS.GATHER_TABLE_STATS takes too long (e.g. for a very larhe table of thousands of partitions), than the analysis con be limited to the extended statistic only by using it's name "SYS_NC00004$" in parameter "Method_Opt":

DBMS_STATS.GATHER_TABLE_STATS (TabName => 'INVOICE', 
 Estimate_Percent => 1/10000, 
 Method_Opt => 'FOR COLUMNS SYS_NC00004$ SIZE AUTO'
);

Evaluation of this case has been done with Panorama

To be notified directly, the performance analysis tool Panorama now shows the missing values for extended statistics in the table structure view as colored background of column "Last analyzed".

Clicking at the last analyzed date shows detailled statiscs infos including the extended statistics where the statistics values / histograms are missing (empty columns):
