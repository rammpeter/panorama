# Oracle-DB: Create trace file for optimizer parse (event 10053)

Datum: 2026-03-31
URL: https://rammpeter.blogspot.com/2026/03/oracle-db-create-trace-file-for.html
Labels: Optimizer, Oracle Database, Panorama

---

To view how the Oracle optimizer comes to his decision, there are several ways to create a trace file like

 - ALTER SESSION SET EVENTS '10053 TRACE NAME CONTEXT FOREVER, LEVEL 1'; 

 - ALTER SESSION SET EVENTS 'TRACE[rdbms.SQL_Optimizer.*][sql:6jksrnjx4zvuk]';

 - EXEC DBMS_SQLDIAG.DUMP_TRACE(p_sql_id, p_child_number, p_component, p_file_id); 

Especially the DBMS_SQLDIAG.DUMP_TRACE helps to quickly review the parse steps of a SQL that already has a valid plan in the SGA.

Using the parameter p_component=>'Compiler' parses the SQL again even if it only needs a soft parse.

Use this steps to view the optimizer trace also without filesystem access on DB server

-- grab the SQL and reparse it with trace 
EXEC DBMS_SQLDIAG.DUMP_TRACE(p_sql_id=>'6jksrnjx4zvuk', p_child_number=>0, p_component=>'Compiler', p_file_id=>'mine');

-- find the created trace file by the used p_file_id
SELECT Inst_ID, ADR_Home, Trace_Filename,
 MIN(TIMESTAMP) Min_Timestamp, MAX(TIMESTAMP) Max_Timestamp,
 Con_ID, COUNT(*) Num_Rows_In_Period
FROM GV$Diag_Trace_File_Contents
WHERE Timestamp >= SYSDATE -1
AND Trace_Filename LIKE '%mine%'
GROUP BY Inst_ID, ADR_Home, Trace_Filename, CON_ID
ORDER BY Max(Timestamp)
;

-- List the content of the trace file
SELECT *
FROM gv$Diag_Trace_File_Contents 
WHERE Trace_FileName = 'FREE_ora_155_mine.trc'
/* Do not ORDER BY Line_Number because the original order within on line_number should be retained */
;

You can also use Panorama now to get the optimzer trace of a SQL statement

The free analysis tool Panorama also contains the above steps to quickly show the optimizer trace.

In SQL detail view there's an entry "Create optimizer parsing trace" in the Hamburger menu:

This will call DBMS_SQLDIAG.DUMP_TRACE with p_component=>'Compiler' and show the resulting trace file:

A click at the trace file name shows the content of the trace file with the parsing steps of the optimizer:
