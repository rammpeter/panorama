# Oracle-DB: Evaluation of recorded SQL-Monitor reports with Panorama

Datum: 2018-03-19
URL: https://rammpeter.blogspot.com/2018/03/oracle-db-evaluation-of-recorded-sql.html
Labels: Analyze performance issue, Panorama How-To

---

SQL-Monitoring records individual executions of an SQL statement in detail if they fulfill one of the following prerequisites:

- Execution with parallel query

- CPU- or I/O-activity for more than 5 seconds

- Optimizer-hint `MONITOR` in SQL statement

SQL-Monitoring reports are stored in table v$SQL_Monitor during SQL execution and for a very short period after execution.

The precondition for using the monitoring reports is licensing of the Tuning Pack for the Enterprise Edition.

Starting with Oracle 12.1, the short-living detailed monitoring reports from v$SQL_Monitor are also available for a longer time within the AWR retention period via DBA_Hist_Reports and DBA_Hist_Reports_Details.

This report can be exported as HTML-page which uses Adobe-Flash to render the Database Activity Report for this SQL execution similar to Enterprise manager.

To generate the HTML-report from v$SQL_Monitor call:

SELECT DBMS_SQLTUNE.report_sql_monitor(
 sql_id => :SQL_ID,
 Session_ID => :SID,
 Session_Serial => :SerialNo,
 SQL_Exec_ID => :SQL_Exec_ID,
 Inst_ID => :Instance,
 type => 'ACTIVE',
 report_level => 'ALL'
 )
FROM Dual;

To generate the HTML-report from DBA_Hist_Reports call:

SELECT DBMS_AUTO_REPORT.REPORT_REPOSITORY_DETAIL(RID => :Report_ID, TYPE => 'ACTIVE') FROM Dual;

The performance analysis tool Panorama lists SQL monitor reports existing for the respective object (SQL / DB session) and period via the button "SQL Monitor" from:

- SQL detail view from current SGA

- SQL detail view from historic AWR data

- current DB-session detail view

Clicking on the report ID opens the Database Activity Report for this SQL execution in a new browser tab.
If an internet connection is available for the browser, it will be displayed as an active Flash page, otherwise as a static HTML page.

p.s.:

If the DB Activity Report is not completely shown in the new browser tab, please check browser console if there are security restriction settings active.

Especially Google Chrome often does not accept Oracle's Flash source URLs.
