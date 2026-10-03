# Oracle-DB: Retrieving extended statistics in execution plan for a specific SQL only

Datum: 2026-06-29
URL: https://rammpeter.blogspot.com/2026/06/oracle-db-retrieving-extended.html
Labels: Oracle Database, Performance tuning

---

For performance analysis of problematic SQL statements it is crucial to have the extended statistics of the execution plan available.

These extended statistics per plan line include as total and last gathered values:

 - The number of starts of execution of this plan line

 - The number of rows gotten by execution of this plan line

 - The number of DB buffers scanned in consistent or current mode

 - The number of disk reads and writes

 - The elapsed time during execution of this plan line

There are several ways to force the DB to record these extended statistics:

 - Set the global initialization variable 'STATISTICS_LEVEL to 'ALL' to enable them for the whole DB

 - 'ALTER SESSION SET STATISTICS_LEVEL=ALL;' to enable them for the current session

 - The optimizer hint /*+ GATHER_PLAN_STATISTICS */ in the SQL to enable the extented only for this SQL statement

Unfortunately, to activate the extended statistics for a specific SQL by adding the optimizer hint,
you need to change the SQL syntax in the application.

This may not always be possible, and even if it is, it will require the app to be redeployed, which will cause additional effort and delay.

An appropriate way to force a specific SQL statement to immediately produce extented statistics at the next execution is:

Create a SQL patch which injects the hint GATHER_PLAN_STATISTICS into the SQL without changing it.

Simply execute such PL/SQL snippet to create a SQL patch for a given SQL ID: 

DECLARE
 patch_name VARCHAR2(32767);
BEGIN
 patch_name := sys.DBMS_SQLDiag.create_SQL_patch(
 sql_id => '2rf0uw3hgtwc1',
 hint_text => 'GATHER_PLAN_STATISTICS',
 name => 'GATHER_PLAN_STATISTICS for 2rf0uw3hgtwc1',
 description => 'Show detailed plan statistics'
 );
END;
/

After next execution of the SQL the columns in V$SQL_Plan_Statistics are collected and can be shown e.g. by DBMS_XPLAN.DISPLAY.

Using the analysis tool Panorama, the values from V$SQL_Plan_Statistics are shown as additional columns in the execution plan,
calculated per SQL execution and per single start of the plan column. 

After investigation of the execution plan you can drop the SQL patch by using the name of the patch:

EXEC DBMS_SQLDiag.Drop_SQL_Patch('GATHER_PLAN_STATISTICS for 2rf0uw3hgtwc1');

The SQL statement remains in its previous state, without the additional overhead associated with collecting extended statistics.

Creating SQL patches is part of the Standard or Enterprise Edition. You don't need an additional option pack license.

To create SQL patches you need the ADMINISTER SQL MANAGEMENT OBJECT or similar grant.
