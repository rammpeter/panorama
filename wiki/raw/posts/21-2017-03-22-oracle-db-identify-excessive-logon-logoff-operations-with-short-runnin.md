# Oracle-DB: Identify excessive logon/logoff operations with short-running sessions

Datum: 2017-03-22
URL: https://rammpeter.blogspot.com/2017/03/how-to-identify-excessive-logonlogoff.html
Labels: Analyze performance issue, Panorama How-To

---

Creating and destroying database sessions in loop may lead to significant database load.This blog post contains more about quantifying this load.

Applications should use connection pooling at client or database side to prevent excessive session creation.

But how can I identify the client processes causing this sessions?

Scan DBA_Audit_Trail to identify context info

If auditing logon/logoff-operations is activated for your database, scan DBA_Audit_Trail.

You can do this by 2 was:

Alternative 1: Use my tool "Panorama" to evaluate audit trail

Panorama is available here.

Go to menu "DBA general" / "Audit Trail":

- Select start and end time for selection

- Filter column "Action" for "LOGON"

- Set "Grouping" to "Minute"

- Execute selection via button "Show audit trail"

- Add columns of your choice to diagram by context menu (right mouse button)

This way you can identify the machine, DB-user and OS-user that executes 106 logons every minute.

Alternative 2: Select direct from DBA_Audit_Trail

SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ *
FROM (SELECT TRUNC(Timestamp, 'MI') Begin_Timestamp,
 MAX(Timestamp)+1/1440 Max_Timestamp, -- rounded to next minute
 UserHost, OS_UserName, UserName, Action_Name,
 COUNT(*) Audits
 FROM DBA_Audit_Trail
 WHERE Timestamp >= TO_DATE(:A1, 'YYYY-MM-DD HH24:MI')
 AND Timestamp < TO_DATE(:A2, 'YYYY-MM-DD HH24:MI')
 AND UPPER(Action_Name) LIKE '%LOGON%'
 GROUP BY TRUNC(Timestamp, 'MI'), UserHost, OS_UserName, UserName, Action_Name
 )
ORDER BY Begin_Timestamp, Audits
;

Identifiy short running DB-sessions just now

List currently connected sessions with logon-time less than a few seconds.
Repeat this selection in very small cycles for some seconds or minutes.

Column "Process" shows the client process id (except JBDC-Sessions, which always have process-ID=1234).

SET SERVEROUTPUT ON LINESIZE 2000;

DECLARE
 SCAN_TIME_SECS CONSTANT NUMBER := 4;
 MAX_SESSION_AGE_SECS CONSTANT NUMBER := 1;
 START_TIME CONSTANT DATE := SYSDATE;
BEGIN
 WHILE START_TIME + SCAN_TIME_SECS/86400 >= SYSDATE LOOP
 FOR Rec IN (
 SELECT TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SSxFF') TS, s.Inst_ID, s.SID, s.Serial#, s.Status, s.AudSID, s.UserName, s.OSUser, s.Process,
 s.Machine, s.Port, s.Program, s.SQL_ID, s.Prev_SQL_ID, s.SQL_Exec_Start, s.Module,
 s.Action, s.Client_Info, s.Logon_Time, s.Service_Name
 FROM gv$Session s
 WHERE s.Type = 'USER'
 AND Program NOT LIKE '%(P%)' /* Exclude own PQ processes that don't appear in gv$PX_Session while selecting from multiple RAC instances */
 AND Logon_Time > SYSDATE-1/(86400/MAX_SESSION_AGE_SECS) /* Session not older than x seconds */
 AND s.AudSID != 0 /* show only if connect is completed */
 ) LOOP
 
 DBMS_OUTPUT.PUT_LINE(Rec.TS||' Inst='||Rec.Inst_ID||' SID/SN='''||RPAD(Rec.SID||','||Rec.Serial#||'''', 12)||' Status='||RPAD(Rec.Status, 9)||
 ' AudSID='||Rec.AudSID||' User='||Rec.UserName||' OS-User='||Rec.OSUser||
 ' Process='||Rec.Process||' Machine='||Rec.Machine||' Port='||Rec.Port||' Program='''||Rec.Program||''''||
 ' SQL_ID='''||Rec.SQL_ID||''' Prev_SQL_ID='''||Rec.Prev_SQL_ID||''''||
 ' Module='''||Rec.Module||''' Action='''||Rec.Action||''' Client_Info='''||Rec.Client_Info||''' Service='||Rec.Service_Name
 ); 
 END LOOP;
 
 DBMS_LOCK.SLEEP(1/100); /* Use DBMS_SESSION.SLEEP also for Rel. >= 18.x */ 
 END LOOP;
END;
/

Identify short running DB-sessions by Active Session History

List sessions within considered period with only one sample record in Active Session History.

This may help to find short running sessions with only one occurrence in ASH.
But for this purpose a sample cycle of one second is much too large in most cases.

SELECT x.*, 
 (Select UserName FROM All_Users u WHERE u.User_ID = x.user_ID),
 s.*
FROM 
(
SELECT Inst_ID, Session_ID, Session_Serial#, 
 MIN(Sample_Time) Min_Sample_Time, 
 MAX(Sample_Time) Max_Sample_Time, 
 COUNT(*) Sample_Count, 
 MIN(SQL_ID) SQL_ID, 
 MIN(Session_Type) SessionType,
 MIN(Module) Module,
 MIN(User_ID) User_ID
FROM gv$Active_Session_History 
WHERE Sample_Time > SYSDATE-1
AND Session_Type = 'FOREGROUND'
GROUP BY Inst_ID, Session_ID, Session_Serial#
ORDER BY Max(Sample_Time) - MIN(Sample_Time)
) x
JOIN gv$Session s ON s.Inst_ID = x.Inst_ID AND s.SID=x.Session_ID AND s.Serial#=x.Session_Serial#
WHERE x.Sample_Count < 2
;

Identify client processes running Oracle-connections

Especially for JDBC-connections with faked process ID "1234" you can identify the exact client process only at client OS.

If there are multiple JDBC-processes on your client machine you can use the following approach to identify the process with multiple short running connections.

Identify linux process with short running connections on Linux systems

Assume your database hostname is "dm0401" you can list the process-IDs and the number of connections  for processes with open Oracle-connections with this command

lsof -i | grep dm0401 | awk '{print $2}' | sort | uniq -c

Than you can scan your client OS for a limited duration for connections (and their process-IDs) that occur only for a small time

# Duration in seconds to scan the client OS 
export DURATION=10
(
 typeset -i i=0
 while [ $i -lt $DURATION ] 
 do
 lsof -i | grep dm0401 | awk '{print $2 $9}' 
 sleep 1
 i=i+1
 done
) | sort | uniq -c | sort -n -r

The last records in the sort order of this output are connections that occur only for a small time.

Maybe a cycle of one second is to large to detect the short running connections.

Than you should sleep only for a fraction of a second (e.g. "sleep 0.1").
Use a dedicated monitoring package to identify short-running sessions

With this package "Detect_Short_Running_Sessions" you can get get maximum information about extremely short running sessions via gv$Session.
It creates a table DSRS_RESULT in the local schema which contains a gv$Session shadow for temporary sessions that disappear in less than x seconds.

You start investigation for temporary sessions by executing:

BEGIN
 EXEC Detect_Short_Running_Sessions.Run_Detection(
 Runtime_Seconds IN NUMBER := 10, -- How long do you want to observer your system
 MilliSeconds_Between_Snaps IN NUMBER := 100, -- Delay between lookups at gv$Session
 Max_Session_Age_Seconds IN NUMBER := 1, -- max. age of disappeared session to be logged
 Grouping_Seconds IN NUMBER := 1 -- Cycle in seconds where logged sessions are persisted and committed in DSRS_RESULT
 );
END;
/

Evaluation of results from table DSRS_RESULT can be done e.g. this way:

SELECT COUNT(*) Sessions, Inst_ID, UserName, OSUser, Machine, Program, Module, Action, Client_Info, Service_Name,
 MAX(Inst_ID||':'||SID||','||Serial#) Sample_Session, MAX(AudSID) Sample_AudSID,
 MAX(SQL_ID) Sample_SQL_ID,
 MAX(Process) Sample_Process,
 MIN(Time_Group) Min_Time,
 MAX(Time_Group) Max_Time
FROM DSRS_RESULT r
GROUP BY Inst_ID, UserName, OSUser, Machine, Program, Module, Action, Client_Info, Service_Name 
ORDER BY Sessions DESC
;

PL/SQL package:
CREATE OR REPLACE PACKAGE Detect_Short_Running_Sessions AUTHID CURRENT_USER IS

 TYPE Sample_Type IS RECORD(
 Inst_ID gv$Session.Inst_ID%TYPE, 
 SID gv$Session.SID%TYPE, 
 Serial# gv$Session.Serial#%TYPE, 
 AudSID gv$Session.AudSID%TYPE, 
 UserName gv$Session.UserName%TYPE, 
 OSUser gv$Session.OSUser%TYPE, 
 Process gv$Session.Process%TYPE, 
 Machine gv$Session.Machine%TYPE, 
 Port gv$Session.Port%TYPE, 
 Program gv$Session.Program%TYPE, 
 SQL_ID gv$Session.SQL_ID%TYPE, 
 SQL_Exec_Start gv$Session.SQL_Exec_Start%TYPE, 
 Module gv$Session.Module%TYPE, 
 Action gv$Session.Action%TYPE, 
 Client_Info gv$Session.Client_Info%TYPE, 
 Logon_Time gv$Session.Logon_Time%TYPE, 
 Service_Name gv$Session.Service_Name%TYPE 
 );

 TYPE Sample_Table_Type IS TABLE OF Sample_Type;
 
 PROCEDURE Run_Detection(Runtime_Seconds IN NUMBER := 10, MilliSeconds_Between_Snaps IN NUMBER := 100, Max_Session_Age_Seconds IN NUMBER := 1, Grouping_Seconds IN NUMBER := 1);
 
END Detect_Short_Running_Sessions;
/

CREATE OR REPLACE PACKAGE BODY Detect_Short_Running_Sessions IS
 Current_Snap Sample_Table_Type := Sample_Table_Type();
 Prev_Snap Sample_Table_Type := Sample_Table_Type();
 Temp_Snap_Diffs Sample_Table_Type := Sample_Table_Type(); 
 Snap_Diffs Sample_Table_Type := Sample_Table_Type(); 

 PROCEDURE Snapshot(Max_Session_Age_Seconds IN NUMBER) IS 
 BEGIN
 Current_Snap.Delete;
 SELECT s.Inst_ID, s.SID, s.Serial#, s.AudSID, s.UserName, s.OSUser, s.Process, 
 s.Machine, s.Port, s.Program, s.SQL_ID, s.SQL_Exec_Start, s.Module, 
 s.Action, s.Client_Info, s.Logon_Time, s.Service_Name
 BULK COLLECT INTO Current_Snap
 FROM gv$Session s
 LEFT OUTER JOIN gv$PX_Session pxs ON pxs.Inst_ID = s.Inst_ID AND pxs.SID = s.SID AND pxs.Serial#=s.Serial#
 WHERE s.Type = 'USER'
 AND pxs.SID IS NULL
 AND Program NOT LIKE 'oracle%(P%)' /* Exclude own PQ processes that don't appear gv$PX_Session in while selecting from multiple RAC instances */
 AND Logon_Time > SYSDATE-Max_Session_Age_Seconds/86400.0 /* Session not older than x seconds */
 ;
 --DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE, 'HH24:MI:SS')||' : '||Current_Snap.COUNT||' records inserted in Current_Snap');
 END Snapshot;

 PROCEDURE Compare_Snapshots(Max_Session_Age_Seconds IN NUMBER) IS
 i NUMBER;
 BEGIN
 Snapshot(Max_Session_Age_Seconds);
 IF Prev_Snap.COUNT > 0 THEN
 SELECT p.*
 BULK COLLECT INTO Temp_Snap_Diffs
 FROM TABLE(Prev_Snap) p
 WHERE (Inst_ID, SID, Serial#) NOT IN (SELECT Inst_ID, SID, Serial# FROM TABLE(Current_Snap))
 ;
 IF Temp_Snap_Diffs.COUNT > 0 THEN
 FOR i IN Temp_Snap_Diffs.FIRST..Temp_Snap_Diffs.LAST LOOP
 Snap_Diffs.EXTEND;
 Snap_Diffs(Snap_Diffs.COUNT) := Temp_Snap_Diffs(i);
 END LOOP;
 END IF; 
 --DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE, 'HH24:MI:SS')||' : '||Snap_Diffs.COUNT||' records in Snap_Diffs');
 END IF;
 Prev_Snap := current_Snap;
 
 END Compare_Snapshots;
 
 PROCEDURE Persist_Diff IS
 Dummy NUMBER;
 BEGIN
 FOR Rec IN (SELECT * FROM TABLE(Snap_Diffs)) LOOP
 EXECUTE IMMEDIATE 'INSERT INTO DSRS_RESULT (Time_Group, Inst_ID, SID, Serial#, AudSID, UserName, OSUser, Process, 
 Machine, Port, Program, SQL_ID, SQL_Exec_Start, Module, 
 Action, Client_Info, Logon_Time, Service_Name
 ) VALUES (SYSDATE, :inst_ID, :SID, :Serial#, :AudSID, :UserName, :OSUser, :Process, 
 :Machine, :Port, :Program, :SQL_ID, :SQL_Exec_Start, :Module, 
 :Action, :Client_Info, :Logon_Time, :Service_Name
 )' USING Rec.Inst_ID, Rec.SID, Rec.Serial#, Rec.AudSID, Rec.UserName, Rec.OSUser, Rec.Process, 
 Rec.Machine, Rec.Port, Rec.Program, Rec.SQL_ID, Rec.SQL_Exec_Start, Rec.Module, 
 Rec.Action, Rec.Client_Info, Rec.Logon_Time, Rec.Service_Name
 ; 
 END LOOP;
 COMMIT;
 Snap_Diffs.DELETE;
 END Persist_Diff;

 PROCEDURE Run_Detection(Runtime_Seconds IN NUMBER, MilliSeconds_Between_Snaps IN NUMBER, Max_Session_Age_Seconds IN NUMBER, Grouping_Seconds IN NUMBER) IS
 Dummy NUMBER;
 Start_time DATE := SYSDATE;
 End_Time DATE := SYSDATE + Runtime_Seconds/86400.0;
 Next_Persist_Time DATE := SYSDATE + Grouping_Seconds/86400.0;
 BEGIN
 SELECT COUNT(*) INTO Dummy FROM User_Tables WHERE Table_Name = 'DSRS_RESULT';
 IF Dummy = 0 THEN
 EXECUTE IMMEDIATE 'CREATE TABLE DSRS_RESULT AS
 SELECT SYSDATE Time_Group, Inst_ID, SID, Serial#, AudSID, UserName, OSUser, Process, 
 Machine, Port, Program, SQL_ID, SQL_Exec_Start, Module, 
 Action, Client_Info, Logon_Time, Service_Name
 FROM gv$Session 
 WHERE 1=2';
 END IF;
 
 WHILE SYSDATE < End_Time LOOP
 Compare_Snapshots(Max_Session_Age_Seconds); 
 IF SYSDATE > Next_Persist_Time THEN
 Persist_Diff;
 Next_Persist_Time := SYSDATE + Grouping_Seconds/86400.0;
 END IF;
 -- ### Use DBMS_SESSION.SLEEP starting with 18c
 DBMS_LOCK.SLEEP(MilliSeconds_Between_Snaps/1000.0);
 END LOOP;
 Persist_Diff;
 END Run_Detection;

END Detect_Short_Running_Sessions;
/
