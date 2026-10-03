# Oracle DB: Detect missing use of prepared statements in SQLs

Datum: 2024-12-06
URL: https://rammpeter.blogspot.com/2024/12/oracle-db-detect-missing-use-of.html
Labels: 

---

A quite common and recurring problem by developers is the use of literals in SQLs instead of prepared statements with bind variables.

This problem pattern has been haunting me for years, there was a post about that in this blog also from 2017.

It is now time to sum up the ideas that have emerged in the meantime to quickly identify the most problematic occurrences on this topic.

The severity of this issue depends on the variety of the used literals. The more different literals are used in the SQL, the greater the problem becomes.

If the used value does not come from outside (SQL injection), it could be tolerable if using a limited number of values for a filter condition directly in the SQL resulting in some 10 or 100 variations of a SQL statement.

On the other hand, it could also be helpful in these cases to use the clear values in SQLs instead of a bind variables to support the optimizer in the use of histograms for different optimal execution plans.

However, if thousands or millions of different values are used, the disadvantages clearly outweigh the possible advantages.

But first question: why should it be a problem to simply include filter conditions etc. as literal part of the SQL text?

 - SQL injection: Adding abitrary content from external sources to the executed SQL code opens a common security hole

 - Execution time: Each new used value leads to a unique new SQL syntax, no exsiting SQL execution plan can be reused. Therefore SQL execution starts with a hard parse of the new SQL which often takes mch longer than the final execution of the SQL itself 

 - CPU resource usage: Hard parses may consume significant CPU at the DB machine depending on the number of upcoming new SQLs

 - Memory resource usage: The parsed SQLs are stored with their execution plans in the cursor cache for possible reuse. This will increase the cursor cache (SQL area) to a not necessary size and permanently age out other SQLs that could have been reused

 - Buffer cache efficency: If not limited by hard settings the increasing SQL area will drive the automatic SGA memory management to decrease the buffer cache, thus decreasing the buffer cache efficiency.

 - Expansion of monitoring data: A new SQL syntax for each execution of such SQLs floods not only the current SQL area. Also AWR recordings writes significant more data about the executed SQLs

 - Much more, like risk of queuing at mutexes or latches in library cache etc.

So at the end the simple recommendation for most cases is:

 Use prepared statements for value bindings instead of placing them inline in the SQL syntax.

But isn't cursor_sharing = FORCE a much simpler solution?

For existing systes there seems to be a more easy solution than changing the implementation: set "cursor_sharing = FORCE" instead of it's default EXACT.
 
But this easy solution could be a false friend. While fixing some drawbacks like hard parses there are others remaining.

Like: all the original SQLs are remaining stored for some time in SGA before the translation to system generated bind variables happens.

So the memory pressure due to the large amount of different SQLs remains at least partially also if using cursor_sharing = FORCE.

The actual question: How Do I check running system for missing use of prepared statements that are worth to fix?

There are a few approaches to scan a whole DB system for ocurrences of that problem:

 - SQLs with different SQL-ID but the same Force-Matching-Signature.
 
 Even if not using cursor_sharing = FORCE the hash value of the result of a theoretical SQL transformation to system generated bind variables gives us the opportunity to find the similarities.

 - SQL with different SQL-ID but the same execution plan
Lots of different SQL-IDs with identic execution plan are often a sign of missing use of prepared statements. There might also be false positives, but these should not have such large amounts of different SQL IDs.
This seems not so accurate as the force matching signature, but checks also SQLs with plan hash value where force matching signatur is 0 (like inserts).

 - Check SQLs for partial similarity
Check for SQLs where the first x characters are identical. Assuming that the differences due to inline filter conditions are after the WHERE clause at the end of the statement.
This stupid approach is also helpful to check for missing prepared statement use for SQLs where no force matching signature and no plan hash value exists (like PL/SQL calls).

SQLs for a quick system check can be found at https://rammpeter.github.io/oracle_performance_tuning.html.

As shown in the following picture, the selections 4.1.1 ... 4.1.5 give ordered results for the three aproaches, differentiated for querying the current SGA or the AWR history. The shown SQL ID in that case is only one example SQL for the amount of found issues.

The same predefined selections you'll also find as part of the free analysis tool "Panorama" (https://github.com/rammpeter/panorama).

Here, however, a little more comfortable with immediate links to the SQL details and other functions.

Are there other ideas how to identify and catch these issues?

Please feel free to comment.

Peter
