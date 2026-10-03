# Create SQL trace for unique application by DBMS_MONITOR

Datum: 2014-04-28
URL: https://rammpeter.blogspot.com/2017/03/create-sql-trace-for-unique-application.html
Labels: Code templates

---

Create SQL trace file for systems with connection pool

If using connection pools the default SQL_TRACE=TRUE does not help because the DB-connection should only be traced if used for a special considered application.

For identification of application you can use the context info set by DBMS_Application_Info.Set_Module.

Trace the run of an single application

For a special module info you can specify creation of trace file already before execution of this application.

Setting trace config has to be done as SYSDBA.

In addition you can set parameters for "waits" and "binds", default is FALSE.

Examples

Activate trace for application by module with recording of bind variables

exec DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE(service_name => 'SYS$USERS', 
 module_name => 'ID_Application = 56', binds => TRUE);

Deactivate trace for module

exec DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE(service_name => 'SYS$USERS', 
 module_name => 'ID_Application = 56');

Activate trace for running session

exec DBMS_MONITOR.SESSION_TRACE_ENABLE(session_id => 2910, serial_num => 3015);

Deactivate trace for running session

exec DBMS_MONITOR.SESSION_TRACE_DISABLE(session_id => 2910, serial_num => 3015);

Get Info about active trace configuration

SELECT * from DBA_Enabled_Traces;

Export trace output to one result file

Tracing by module leads to multiple trace files, each one for every affected DB-session.

The utility trcsess allows extracting relevant trace output into one file, e.g. for considered module:

trcsess output=osp.trc module='AmosOrder::Gui::Dialogs::OrderEntryDialog'
