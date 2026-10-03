# Panorama: Handle SQL patches for Oracle-DB

Datum: 2018-01-14
URL: https://rammpeter.blogspot.com/2018/01/panorama-handle-sql-patches-for-oracle.html
Labels: Analyze performance issue, Panorama How-To

---

Long time ago Oracle introduced SQL patches as a way to influence execution plan of SQL with optimizer hints without changing the original SQL statement.

This allows fixing execution plan issues without any change at the application executing this SQL.

SQL patches don't require additional license in contrast to SQL plan baselines and SQL profiles and can also be used with Standard Edition.

SQL patches are normally used in workflow of SQL Repair Advisor but can also be created manually.

There are two variants to create a SQL patch for a SQL: By SQL-ID and by SQL text.

(See also this posts: 1 2 )

I personally prefer SQL patch creation using SQL text because SQL-ID requires existence of SQL-Statement in SGA at SQL patch creation time.

For Oracle 11.1 .. 12.1 create with package-method sys.DBMS_SQLDiag_Internal.i_create_patch

BEGIN
 sys.DBMS_SQLDiag_Internal.i_create_patch(
 sql_text => 'SELECT SYSDATE FROM DUAL',
 hint_text => 'PARALLEL(8)',
 name => 'SQL patch example',
 description => 'Example for applying optimizer-hint to unchanged SQL'
 );
END;
/

From Oracle 12.2 create with package-function sys.DBMS_SQLDiag.create_SQL_patch

DECLARE
 patch_name VARCHAR2(32767);
BEGIN
 patch_name := sys.DBMS_SQLDiag.create_SQL_patch(
 sql_text => 'SELECT SYSDATE FROM DUAL',
 hint_text => 'PARALLEL(8)',
 name => 'SQL patch example',
 description => 'Example for applying optimizer-hint to unchanged SQL'
 );
END;
/

Dictionary objects containing info about SQL patches

- View DBA_SQL_Patches list existing SQL patches

- Table sys.SQLObj$ contains match between SQL patch name and signature, category, object_type and plan_id

- Table sys.SQLObj$Data contains optimizer hint in XML outline structure

Thanks to Jonathan Lewis for his post.

Support for SQL patches with analysis tool 'Panorama'

Panorama can generate SQL patches for every SQL-statement that is in SGA or AWR-history.

Each SQL detail page has as button "SQL patch" that generates a PL/SQL-snippet for SQL patch creation.

You only have to replace your optimizer hint in this snippet and execute it as SYSDBA to create a SQL patch.

This SQL patch generation uses the more expensive alternative with SQL text instead of SQL-ID.

This ensures that SQL patch can be created even some time after the last execution of SQL regardless of wether SQL is still present in SGA.

Existing SQL patches for a SQL-statement are shown in any detail view of that SQL to explicitly prevent misinterpretation of execution plan.

All existing SQL-patches are listed in Panorama via menu 'SGA/PGA-details' / 'SQL plan management' / 'SQL patches':

You may find more about Panorama at http://rammpeter.github.io/panorama.html

See also this post: Panorama: Fix changed execution plan with SQL plan baseline
