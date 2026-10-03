# Panorama: Fix changed execution plan with SQL plan baseline

Datum: 2016-03-20
URL: https://rammpeter.blogspot.com/2016/03/panorama-fix-changed-execution-plans.html
Labels: Panorama How-To

---

You recognize a long running query caused by poor execution plan.

You also know that until yesterday this query worked fine but now execution plan has suddenly changed due to ???.

Filipe Martins named a solution here by transferring a good execution plan from AWR history into a SQL plan baseline.

This solution is available in Panorama now.

It allows you to quickly generate a SQL snippet for creation of SQL plan baseline by simple button click.

Steps to fix this issue:

- Identify the problematic query, open SQL details page in Panorama for this statement.

- For example via menu “SGA/PGA details” / “SQL Area” / “Current”

- Hit button “Complete time line of SQL” at the bottom of the SQL details page

- Identify a day (or hour/minute) in history in the list with exactly one good execution plan.

- Column “Elapsed/Execution” may help you to rate the quality.

- Column “Plan hash value” allows you to differentiate different plans.

- Click the link in column “Start time” to open SQL detail page for this period

- Hit button “Generate SQL plan baseline” at the bottom of the SQL details page

- Execute the generated SQL snippet as appropriate user, e.g. SYS as SYSDBA

-- Build SQL plan baseline for SQL-ID = '9qfast7c8bxcy', plan hash value = 2381209795
-- Generated with Panorama at 2018-01-21 19:42:56 +0100
-- based on idea from rmoff (https://rnm1978.wordpress.com/?s=baseline)

-- to create a SQL-baseline execute this snippet as SYSDBA in SQL*Plus

-- Drop eventually existing SQL Tuning Set (STS)
BEGIN
 DBMS_SQLTUNE.DROP_SQLSET(sqlset_name => 'PANORAMA_STS');
EXCEPTION
 WHEN OTHERS THEN
 NULL;
END;
/

-- Create new SQL Tuning Set (STS)
BEGIN
 DBMS_SQLTUNE.CREATE_SQLSET(
 sqlset_name => 'PANORAMA_STS',
 description => 'Panorama: SQL Tuning Set for loading plan into SQL Plan Baseline');
END;
/

-- Populate STS from AWR, using a time duration when the desired plan was used
-- Specify the sql_id in the basic_filter (other predicates are available, see documentation)
DECLARE
 cur sys_refcursor;
BEGIN
 OPEN cur FOR
 SELECT VALUE(P)
 FROM TABLE(
 DBMS_SQLTUNE.Select_Workload_Repository(Begin_Snap=>1600, End_Snap=>1606, Basic_Filter=>'sql_id = ''9qfast7c8bxcy''',attribute_list=>'ALL')
 ) p;
 DBMS_SQLTUNE.LOAD_SQLSET( sqlset_name=> 'PANORAMA_STS', populate_cursor=>cur);
 CLOSE cur;
END;
/

-- you can check now the result in tunning set by executing
-- SELECT * FROM TABLE(DBMS_SQLTUNE.SELECT_SQLSET(sqlset_name => 'PANORAMA_STS'));

-- Load desired plan from STS as SQL Plan Baseline
-- Filter explicitly for the plan_hash_value here if you want
DECLARE
 my_plans pls_integer;
BEGIN
 my_plans := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(sqlset_name => 'PANORAMA_STS', Basic_Filter=>'plan_hash_value = ''2381209795''');
END;
/

-- Drop SQL Tuning Set (STS) which is not needed no more
BEGIN
 DBMS_SQLTUNE.DROP_SQLSET(sqlset_name => 'PANORAMA_STS');
END;
/

-- You can check the existence of the baseline now by executing:
-- SELECT * FROM dba_sql_plan_baselines;
-- or by looking at SQL details page for your SQL with Panorama

-- Next commands remove possibly existing cursors of this SQL from SGA to ensure hard parse with SQL plan baseline at next execution
-- If you are working on a RAC system you should execute this 'DBMS_SHARED_POOL.PURGE'-commands once again connected on the appropriate RAC-instance

Now next execution of this statement will use the execution plan pinned by SQL plan baseline.

SQL details page will show you now the existence and some parameters of SQL plan baseline.

Remember please, that this joyful solution may be only temporary because if you modify the SQL statement next time it will lose the link to baseline.

So a better permanent solution would be to fix the execution plan by appropriate analyze-info, using optimizer hints in SQL etc. .
