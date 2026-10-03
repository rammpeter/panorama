# Common Oracle DB pitfall: too few redo log groups

Datum: 2017-02-25
URL: https://rammpeter.blogspot.com/2017/02/common-oracle-db-pitfall-too-less-redo.html
Labels: Analyze performance issue, Panorama How-To

---

Running an Oracle database with only 3 redo log groups often leads to suddenly frozen database, there all commit operations are suspended for some seconds or even some minutes.

This freeze behavior may cause several errors in production environments:

Services are not available, timeout exceptions are raised, process throughput decreases considerably etc. .

Unfortunately only 3 redo log groups is the default for a database created by DBCA and therefore you may find many DB instances in production with only 3 redo log groups.

But why should it be a problem to have too less redo log groups?

For example we have a database with 3 redo log groups and as advisable for production databases, archiver mode is activated.

Consider the redo logs as ring buffer where a fix number of redo log file groups is reused by the log writer process after the current log is completely written and a log switch is raised.

The precondition for successful log switch is that the next log file group to switch to is:

- completely processed by the db-writer process, signaled by “status” = “INACTIVE” 

- completely processed by the archiver process, signaled by “archived” = “YES” 

If the redo log group to be used next by the logwriter is already in status “ACTIVE” or is not yet archived, than the log switch waits until the preconditions are fulfilled and all write operations on redo log (commits) for this database are also waiting.

Reasons for this situation may be: 

- Your db-writer may not be able to process the 2 log groups until the next log switch occurs depending on the speed of your I/O-system and the amount auf redo per time unit. 

- Your archiver process is not able to copy the redo log files fast enough, especially if you active data guard / standby database (as shown in chart above).

How to avoid this problem / rules of thumb: 

- Size your redo log files so that the interval between log switches is always greater than one minute

- Set the number of redo log file groups large enough, so that under all conditions you always have at least one or two redo log groups that are ready for log switch (Status=INACTIVE and Archived=YES)

Your setting should result than in such a scenario:

This way your database becomes able to buffer short overload scenarios without loss of service where your processes produce more DML-load than your db-writer / archiver may process simultaneously.

In addition you should also consider:

- does this behavior match with your possibly requirement for max. recovery times (init-Parameter FAST_START_MTTR_TARGET)

- it may be useful to increase throughput of db-writer/archiver by tuning them (e.g. increase the number of processes)

But how can I reproduce, if delayed log switches have occurred on my database?

- You can scan your alert.log for “cannot allocate new log” and “Checkpoint not complete”.

- You can reproduce the status and archived-flag of your log groups at the timestamps of AWR-snapshots from table DBA_HIST_LOG and consider the number of active redo groups and the number of not archived redo groups.

- You can scan the active session history for wait event “log file switch (checkpoint incomplete)”. This event indicates sessions waiting for successful log switch.

You can do this analysis convenient per Web-GUI using Panorama( http://rammpeter.github.io/panorama.html ):

Evaluate DBA_Hist_Log, Menu: DBA general / Redo logs / Historic

Next show values in diagram by context menu on table

Now you can see that: 

- the archiver is fast enough to have one log group ARCHIVED and regarding archiver ready for log switch 

- the db-writer is not fast enough. Many times over some hours two redo log groups are marked ACTIVE and one is CURRENT. This is the situation where a log switch cannot succeed. 

Showing “Avg. log switch interval” in diagram in the same way allows you to scan for times where log switch interval is less than 60 seconds.

 Show “log file switch (checkpoint incomplete)” in active session history

Menu: “Analyses / statistics” / “Session waits” / “Historic”

This way you can see that up to 10 sessions are simultaneous waiting on “log file switch (checkpoint incomplete)”

Without Panorama you can use this SQL for manual evaluation of DBA_HIST_LOG

SELECT /* Panorama-Tool Ramm */ x.*,
 x.LogSwitches * x.Members * x.Avg_Size_MB LogWrites_MB,
 CASE WHEN x.Snapshot_Secs > 0 AND x.LogSwitches IS NOT NULL 
 AND x.LogSwitches > 0 
 THEN x.Snapshot_Secs / x.LogSwitches 
 END Avg_Secs_Between_LogSwitches
FROM (SELECT ss.Begin_Interval_Time, ss.End_Interval_Time, l.*,
 (CAST(ss.End_Interval_Time AS DATE)-
 CAST(ss.Begin_interval_Time AS DATE))*86400 
 Snapshot_Secs,
 l.MaxSequenceNo - LAG(l.MaxSequenceNo, 1, l.MaxSequenceNo) 
 OVER (PARTITION BY l.Instance_Number 
 ORDER BY ss.Begin_Interval_Time) LogSwitches
 FROM (
 SELECT DBID, Snap_ID, Instance_Number, 
 COUNT(*) Log_Number,
 SUM(CASE WHEN Archived='NO' THEN 1 ELSE 0 END
 ) Not_Archived,
 SUM(CASE WHEN Status='CURRENT' THEN 1 ELSE 0 END
 ) Current_No,
 SUM(CASE WHEN Status='ACTIVE' THEN 1 ELSE 0 END
 ) Active_no,
 Avg(Members) Members,
 AVG(Bytes)/ (1024*1024) Avg_Size_MB,
 MAX(Sequence#) MaxSequenceNo
 FROM DBA_Hist_Log
 WHERE Instance_Number = Thread# 
 GROUP BY DBID, Snap_ID, Instance_Number
 ) l
 JOIN DBA_Hist_Snapshot ss ON ss.DBID=l.DBID 
 AND ss.Snap_ID=l.Snap_ID AND ss.Instance_Number=l.Instance_Number
 ) x
ORDER BY x.Begin_Interval_Time, x.Instance_Number
