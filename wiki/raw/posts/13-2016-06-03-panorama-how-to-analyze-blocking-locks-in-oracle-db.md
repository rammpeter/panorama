# Panorama: How to analyze blocking locks in Oracle-DB

Datum: 2016-06-03
URL: https://rammpeter.blogspot.com/2016/06/panorama-how-to-analyze-blocking-locks.html
Labels: Analyze performance issue, Panorama How-To

---

This article describes how to analyze blocking locking lock constellations just now in database and also back in history.

Especially this includes the identification of database sessions that are initially causing hierarchic blocking lock dependencies.

Analyze current blocking lock situation with Panorama

Choose menu “DBA general” / “DB locks” / “Current”:

Hit button “Blocking DML-Locks”

You see a constellation of four sessions blocking each other wile accessing table EMPLOYEE.

For each blocking lock you see the waiting session, the blocking session and also the root blocking session which causes the blocking hierarchy.

If the blocking session of the lock is also the root cause for the blocking hierarchy than this blocking session is marked orange.

That means that you have to clarify this orange sessions problem (probably by killing this session) to release the whole hierarchy of blocked sessions.

Via link you can further view detailed info about:

- blocking and waiting session

- waiting SQL

- Other sessions trying to lock the same combination of ID1/ID2

If you click the link on file, block and row# than the blocking rowid will be calculated.

If you click the appearing rowid than it shows the primary key column(s) and the primary key value of the blocking row.

Analyze blocking lock situations in history with Panorama

Based on the recorded active session history Panorama may also identify blocking lock situations back in history and also identify the root cause for a hierarchy of blocking sessions.

Choose menu “DBA general” / “DB locks” / “Blocking locks historic” and select the time period to consider.

At first you get a list of all blocking sessions that are the root cause for a blocking hierarchy ordered by cumulative wait time of all sessions blocked by this session.

There is a separate line for each session that acts as root-blocker in the considered period.

You see the number of direct blocked sessions and the total number of sessions blocked in a hierarchy as links.

You now have several ways to drill down in analysis with root blocking session:

- List detailed sample records from active session history and reconstruct the variation of blocking locks in time for that blocking session

- Show cumulated info from active session history for blocking session

- Show detailed information for currently executed SQL-statements for blocking and waiting sessions

- Describe blocking object down to rowid and primary key value (if they are unique over the period)

- Show all sessions blocked by this session and their possibly next blocked sessions (step down in blocking hierarchy)

List detailed sample records:

Hit the link in column “Samples direct” and you get a list of single ASH-records for blocking session. Might be several records for one snapshot if this session locks several sessions.

This list shows the finest view onto ASH-records as base for the historic consideration.

You can group the ASH-records by time slot and view the variation over time in diagram:

Show all sessions blocked by this session

If you hit the link at “Direct blocked” you will get a list of the sessions directly blocked by this sessions and also information about the other sessions blocked by this listed sessions.

Via link in column “Direct blocked” you can navigate through the complete locking tree.

Just like for current locks you are also able to identify the blocking record by calculating the rowid and get the primary key value of the affected record.

Analyze current blocking lock situation with Oracle's builtin tools

Persist current hanging state of database into trace file by:

sqlplus / as sysdba
> oradebug setmypid
> oradebug hanganalyze 12

This way allows you to quickly persist hanging state of database before restarting instance in emergency cases.
