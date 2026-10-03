# Panorama: List Oracle trace files and it's content

Datum: 2019-09-03
URL: https://rammpeter.blogspot.com/2019/09/panorama-list-oracle-trace-files-and.html
Labels: Analyze performance issue, Panorama How-To

---

Starting with Release 12.2 of Oracle database you can list and view trace files from database server file system by SQL selects.

Dynamic performance views for representation of trace files are:

- V$DIAG_TRACE_FILE: lists files from ADR (automatic diagnostic repository)

- V$DIAG_TRACE_FILE_CONTENTS: lists text content of trace files with one record per line

Panorama now supports viewing server side trace files via menu "DBA general" / "Server Files" / "Server Trace Files".

This way people without access rights on database server file systems (like software developer) are enabled to access the trace files they produce by their own.

This view shows all existing trace files for chosen period and optional including or excluding patterns for trace file name.
This works for server trace files as well as for user trace files created by:ALTER SESSION SET SQL_TRACE=TRUE;
 or ALTER SESSION SET EVENTS '10046 trace name context forever, level 4|8|12';
.

Click on trace file name shows the content of trace file with some context information and links for further investigation.

From this list you can proceed to the SQL details of the corresponding AWR period or the Active Session History of the DB-Session via link.

Also from detailed view of a particular DB session you can directly head over to the trace file content if this session is in trace mode (Button 'Show trace file' is displayed in this case).
