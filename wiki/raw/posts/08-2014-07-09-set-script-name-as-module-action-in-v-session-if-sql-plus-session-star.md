# Set script name as module/action in V$Session if SQL*Plus-session starts

Datum: 2014-07-09
URL: https://rammpeter.blogspot.com/2014/07/set-script-name-as-moduleaction-in.html
Labels: Code templates

---

Setting module and action info via DBMS_Application_Info.Set_Module gives valuable context info in V$Session, Active Session History etc.

For jobs executing SQL via SQL*Plus mostly needed information in module/action is the name of the process executing sqlplus.To prevent jobs from directly executing DBMS_Application_Info.Set_Module and to ensure that every sqlplus-process is setting this context info,you can use the startup-script feature via login.sql.

Ensure that environment variable SQLPATH will target to the directory that contains login.sql,so all executions of sqlplus will  immediately set their context info in v$Session.

Example for login.sql:

-- Description : Default login sequence for SQL*Plus, executed at start time of every SQLPlus-process if file is in search path
-- Unix environment variable SQLPATH must contain directory of file "login.sql"

SET TERMOUT OFF;

-- Determine unique session identifier for unique tempfile name
COLUMN Session_ID_Col NEW_VALUE Session_ID
SELECT SYS_CONTEXT('USERENV','SESSIONID') AS Session_ID_Col FROM DUAL;

-- filename for generated SQL commands
DEFINE SCRIPT='/tmp/&Session_ID..sql'

-- Generate call for DBMS_Application_Info.Set_Module and output in tempfile
-- Determine name of parent prozess of SQLPLus 
HOST ps -ocommand= -p `ps -oppid= -p $PPID` | awk '{print "EXEC DBMS_Application_Info.Set_Module('\''" substr( $0, length($0) - 47, length($0) ) "'\'', '\''sqlplus started with defaults'\'');"}' >&SCRIPT

-- execute generated script
START &SCRIPT

-- remove generated script from file system
HOST rm &SCRIPT
SET TERMOUT ON;
