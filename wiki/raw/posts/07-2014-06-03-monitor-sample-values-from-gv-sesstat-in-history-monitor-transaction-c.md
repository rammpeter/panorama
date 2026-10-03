# Monitor/sample values from gv$SesStat in history: monitor transaction count per session in history

Datum: 2014-06-03
URL: https://rammpeter.blogspot.com/2017/03/monitorsample-values-from-gvsesstat-in.html
Labels: Analyze performance issue

---

In current version of Oracle database there’s no way to breakdown historic statistic values to sessions if session has already terminated.

Some times this information is strongly needed to identify bottlenecks.

Actual situation was:

– massive number of transactions which caused massive small write I/O reaching limits of physical disks

– to identify root cause identification fo processes/sessions was needed

– consideration can only be done in history with time gap of some hours, problematic sessions have been terminated for long time

Solution:

Create sampling process with minimal resource impact to CPU and I/O with result storage in database table.

Preparation

Create two tables, one for result storage and one for abortion of sampling process:

CREATE TABLE SessMon_Semaphore (Name VARCHAR2(30));

COMMENT ON TABLE SessMon_Semaphore IS 'Control abortion of sampling process';
COMMENT ON COLUMN SessMon_Semaphore.Name IS 'Record identifier to store record lock on it';

CREATE TABLE SessMon_Log (
 SampleTime DATE,
 StartTime DATE,
 EndTime DATE,
 Inst_ID NUMBER,
 SID NUMBER,
 Serial# NUMBER, 
 Statistic# NUMBER,
 Value NUMBER
);

COMMENT ON TABLE SessMon_Log IS 'Logging Table for session statistics';
COMMENT ON COLUMN SessMon_Log.SampleTime IS 'Timestamp of storage of sample record in table (end of sample cycle)';
COMMENT ON COLUMN SessMon_Log.StartTime IS 'First occurrence of session within sample cycle';
COMMENT ON COLUMN SessMon_Log.EndTime IS 'Last occurrence of session within sample cycle';
COMMENT ON COLUMN SessMon_Log.Inst_ID IS 'Instance number (allows link to active session history)';
COMMENT ON COLUMN SessMon_Log.SID IS 'Session identifier (allows link to active session history)';
COMMENT ON COLUMN SessMon_Log.Serial# IS 'Session serial number (allows link to active session history)';
COMMENT ON COLUMN SessMon_Log.Statistic# IS 'Statistic number from V$StatName';
COMMENT ON COLUMN SessMon_Log.Value IS 'Delta between last and current sample for value from GV$SesStat';

Sampling statistic results

Execute anonymous PL/SQL block which samples data in memory and periodically stores result in database table.

This requires execute grant on DBMS_LOCK for executor to reduce CPU consumption. 

DECLARE
 SEMAPHORE CONSTANT VARCHAR2(30) := 'Session Monitoring';
 SAMPLE_CYCLE CONSTANT NUMBER := 10; -- Seconds between sampling in memory
 SAVE_CYCLE CONSTANT NUMBER := 900; -- Seconds between save to table on disk
 STAT_NAME CONSTANT VARCHAR2(30) := 'user commits'; -- Statistic name to sample according to v$StatName
 MIN_VALUE CONSTANT NUMBER := 1000; -- Minimum value in GV$SesStat to include in sample
 
 Loops_per_SaveCycle NUMBER := SAVE_CYCLE/SAMPLE_CYCLE; 
 Loop_Count NUMBER := 0;
 StatNo_User_Commits NUMBER;
 First_Cycle BOOLEAN := true; -- First cycle should not be saved because of missing predecessor
 v_Count NUMBER;
 Begin_Memory_Cycle DATE := SYSDATE; -- Remember begin of cycle as timestamp of last snapshot
 
 TYPE Sample_Type IS RECORD (
 Inst_ID SessMon_Log.Inst_ID%TYPE,
 SID SessMon_Log.SID%TYPE,
 Serial# SessMon_Log.Serial#%TYPE,
 Statistic# SessMon_Log.Statistic#%TYPE,
 StartTime SessMon_Log.StartTime%TYPE,
 EndTime SessMon_Log.EndTime%TYPE,
 Value SessMon_Log.Value%TYPE
 ); 
 
 TYPE Sample_Table_Type IS TABLE OF Sample_Type INDEX BY VARCHAR2(30);
 Sample_Table Sample_Table_Type;
 Prev_Sample_Table Sample_Table_Type; -- Memory table with last saved values

 PROCEDURE LockSem IS
 Resource_Busy EXCEPTION;
 pragma Exception_Init(Resource_Busy, -54);
 v_Dummy SessMon_Semaphore.Name%TYPE;
 BEGIN
 BEGIN
 -- Try to aquire lock (don't wait):
 SELECT Name INTO v_Dummy FROM SessMon_Semaphore WHERE Name=SEMAPHORE FOR UPDATE NOWAIT;
 EXCEPTION
 WHEN Resource_Busy THEN -- another similar process tries to stop working
 RAISE_APPLICATION_ERROR(-20999, 'Process stopped because semaphore is locked by another process'); 
 END;
 END LockSem;
 
 PROCEDURE Sample_Records_in_Memory IS
 v_Index VARCHAR2(30);
 Sample_Rec Sample_Type;
 BEGIN
 FOR Rec IN (SELECT t.Inst_ID, t.SID, s.Serial#, t.Statistic#, t.Value 
 FROM GV$SesStat t 
 JOIN GV$Session s ON s.Inst_ID = t.Inst_ID AND S.SID = t.SID
 WHERE t.Statistic#=StatNo_User_Commits AND t.Value > MIN_VALUE
 )
 LOOP
 v_Index := Rec.Inst_ID||':'||Rec.SID||':'||Rec.Serial#||':'||Rec.Statistic#;
 IF Sample_Table.EXISTS(v_Index) THEN
 Sample_Rec := Sample_Table(v_Index); 
 ELSE
 Sample_Rec.Inst_ID := Rec.Inst_ID;
 Sample_Rec.SID := Rec.SID;
 Sample_Rec.Serial# := Rec.Serial#;
 Sample_Rec.Statistic# := Rec.Statistic#;
 Sample_Rec.StartTime := Begin_Memory_Cycle;
 END IF;
 Sample_Rec.EndTime := SYSDATE;
 Sample_Rec.Value := Rec.Value;
 
 Sample_Table(v_Index) := Sample_Rec;
 END LOOP;
 Begin_Memory_Cycle := SYSDATE; -- Begin for next cycle
 END Sample_Records_in_Memory; 
 
 PROCEDURE Save_Sample_Records IS
 v_Index VARCHAR2(30);
 Sample_Rec Sample_Type;
 BEGIN
 v_Index := Sample_Table.FIRST;
 WHILE v_Index IS NOT NULL LOOP
 Sample_Rec := Sample_Table(v_Index);
 
 IF Prev_Sample_Table.EXISTS(v_Index) THEN
 Sample_Rec.Value := Sample_Rec.Value - Prev_Sample_Table(v_Index).Value; -- Reduce value to delta between last saved cycle an now
 END IF;
 
 IF Sample_Rec.Value != 0 AND NOT First_Cycle THEN -- Suppress saving of 0-values
 INSERT INTO SessMon_Log (SampleTime, StartTime, EndTime, Inst_ID, SID, Serial#, Statistic#, Value)
 VALUES (SYSDATE, Sample_Rec.StartTime, Sample_Rec.EndTime, Sample_Rec.Inst_ID, Sample_Rec.SID, Sample_Rec.Serial#, Sample_Rec.Statistic#, Sample_Rec.Value);
 END IF;
 
 v_Index := Sample_Table.NEXT(v_Index);
 END LOOP;
 
 Prev_Sample_Table := Sample_Table;
 Sample_Table.DELETE;
 First_Cycle := false;
 END Save_Sample_Records; 

BEGIN
 SELECT COUNT(*) INTO v_Count FROM SessMon_Semaphore WHERE Name = SEMAPHORE;
 IF v_Count = 0 THEN 
 INSERT INTO SessMon_Semaphore (Name) VALUES (SEMAPHORE); -- create Semaphore-record if not exists
 END IF; 
 COMMIT;
 LockSem; 
 SELECT Statistic# INTO StatNo_User_Commits FROM v$StatName WHERE Name = STAT_NAME; -- what statistic to sample
 LOOP
 Sample_Records_in_Memory;
 
 Loop_Count := Loop_Count + 1;
 IF Loop_Count >= Loops_per_SaveCycle THEN
 Save_Sample_Records;
 COMMIT; -- Free Semaphore, make samples visible to others
 LockSem; -- Cancel processing of semaphore is locked
 Loop_Count := 0;
 END IF;
 
 DBMS_LOCK.Sleep(SAMPLE_CYCLE);
 END LOOP;
END;
/

Finish sampling, analysis of results

Stop anonymous PL/SQL sampler by locking semaphore records for SAVE_CYCLE seconds until PL/SQL-Job terminates:

select * from SessMon_Semaphore for update;

Find sessions in history with most resource consumption (user commits) enriched with context info from active session history:

SELECT l.*,
 (SELECT 'Module="'||MIN(h.Module)||'" Action="'||MIN(Action)||'" User_ID='||MIN(h.User_ID)||
 ' Program="'||MIN(h.Program)||'" Machine="'||MIN(h.Machine)||'"'
 FROM DBA_Hist_Active_Sess_History h
 WHERE h.DBID = (SELECT DBID FROM v$Database)
 AND h.Snap_ID >= (SELECT MIN(Snap_ID) FROM DBA_Hist_Snapshot ss WHERE ss.Instance_Number = l.Inst_ID AND ss.End_Interval_Time >= l.StartTime)
 AND h.Snap_ID <= (SELECT MAX(Snap_ID) FROM DBA_Hist_Snapshot ss WHERE ss.Instance_Number = l.Inst_ID AND ss.Begin_Interval_Time <= l.EndTime)
 AND h.Instance_Number = l.Inst_ID 
 AND h.Session_ID = l.SID
 AND h.Session_Serial# = l.Serial#
 ) ASH_Info
FROM (SELECT Inst_ID, SID, Serial#, MIN(StartTime) StartTime, MAX(EndTime) EndTime, SUM(Value) Value
 FROM SessMon_Log
 GROUP BY Inst_ID, SID, Serial#
 ) l
ORDER BY Value DESC
;
