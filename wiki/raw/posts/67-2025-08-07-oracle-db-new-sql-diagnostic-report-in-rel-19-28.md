# Oracle-DB: New SQL Diagnostic Report in rel. 19.28

Datum: 2025-08-07
URL: https://rammpeter.blogspot.com/2025/08/oracle-db-new-sql-diagnostics-report-in.html
Labels: Oracle Database, Panorama How-To

---

One of the new features backported from 23ai into release 19.28 is the SQL Diagnostic Report.

This shows a comprehensive summary of diagnostic information for a certain SQL statement.
Included are execution plan info, optimizer statistics, object info, ASH info, SQL Monitor reports and lots more.

The documentation for 19c already includes the new method DBMS_SQLDIAG.Report_SQL.

Which edition or option pack license is needed

Including ASH, SQL Monitor etc. raises the question: What about licensing limitations for use of this function.

As of current documentation there is no Enterprise Addition or additional management pack license needed for execution of DBMS_SQLDIAG.Report_SQL.

The package DBMS_SQLDIAG and it's subroutines are often named as "SQL Repair Advisor".

Looking at Features and Licensing there is no limitation for usage of SQL Repair Advisor and there's also a section for SQL Diagnostic Report confirming no limitation:

The note "How To Use DBMS_SQLDIAG To Diagnose Various Query Issues" (Doc ID 1509192.1) tells "DBMS_SQLDIAG is shipped with the standard Oracle Database Software and usage requires no additional license.", but last update of this note was in 2022.

As a last test I used a fresh 23.9 DB to check if something is recorded in DBA_Feature_Usage_Statistics after use of DBMS_SQLDIAG.Report_SQL.

exec dbms_feature_usage_internal.exec_db_usage_sampling(SYSDATE, test_name => 'hugo');
CREATE TABLE before_diag AS SELECT * FROM DBA_Feature_Usage_Statistics where detected_usages != 0;
-- call DBMS_SQLDIAG.Report_SQL
exec dbms_feature_usage_internal.exec_db_usage_sampling(SYSDATE, test_name => 'hugo');
CREATE TABLE after_diag AS SELECT * FROM DBA_Feature_Usage_Statistics where detected_usages != 0;

The only difference in DBA_Feature_Usage_Statistics is a use of "Oracle Utility Metadata API" that is expected for this function.

Not any other additional feature was marked as used.

Using SQL Diagnostic Report

Executing 
DBMS_SQLDIAG.Report_SQL(SQL_ID => 'my SQL-ID', Level => 'ALL')

 returns a CLOB with the generated HTML content.

Using the free analysis tool Panorama for 19.28 or newer there is also a button "Diag. report" now at the page for SQL details which generates this SQL Diagnostic Report for the choosen SQL in a new browser window.

An example for the resulting report you'll find here.

Thanks to Claudia Hüffer for the support in investigation of licensing issues
