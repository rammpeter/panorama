# Oracle-DB: Does Active Session History always allows you to reconstruct your active sessions behaviour?

Datum: 2017-04-14
URL: https://rammpeter.blogspot.com/2017/04/oracle-db-does-active-session-history.html
Labels: Analyze performance issue

---

As the name implies one would expect that Active Session History records all information to reconstruct the main activities of sessions that are active for a longer period.

Is it really true?

I thought so before, but it isn't.

Consider the ASH-chart of this session running for approx. one hour as one unique PL/SQL package-method call.

What you would expect is that over this time the session is always active doing PL/SQL- or SQL-execution work.

That means this session is permanently active and wait states should be recorded in ASH.

But ASH-report says that this session is mostly inactive consuming time but doing nothing on database.

The reason for this confusion is: Active Session History does not record wait states for wait class "idle".

In this special case the idle waits are caused by one frequently executed SQL-statement accidentially forced to run in parallel query mode by a PARALLEL-hint, but each SQL-execution took only some milliseconds.

If you look into v$Session_Wait you will find:

The query coordinator session spent most time in wait event 

"PX Deq Credit: send bled"

that is considered as wait class "idle".

The parallel query slaves are most time in wait event 

"PX Deq: Execution Msg"

that is also considered as idle.

Surprisingly the metric v$SQL.Elapsed_Time also did not count this idle waits, so looking for SQLs with excessive runtime also did not lead to the reason.

Conclusion:

For some cases it is indispensable to have a look on the process at runtime, because idle-waits are not recorded in ASH and v$SQL.

Under some circumstances these idle waits are essential to explain the process runtime.

My free performance analysis app 
Panorama offers a selection in menu "Spec. additions" / "Dragnet investigation" to scan your database  for extremely short running SQLs in parallel query mode.
