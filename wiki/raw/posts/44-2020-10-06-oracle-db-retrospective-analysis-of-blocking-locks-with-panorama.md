# Oracle-DB: Retrospective analysis of blocking locks with Panorama

Datum: 2020-10-06
URL: https://rammpeter.blogspot.com/2020/10/oracle-db-retrospective-analysis-of.html
Labels: Analyze performance issue, Panorama How-To

---

The recorded session activity in Oracle databases (Active Session History / ASH) enables the retrospective analysis of locking scenarios between database sessions.

This post shows how the free performance analysis tool Panorama supports this investigation.Precondition for using ASH is the Enterprise Edition of Oracle DB and the licensing of the Diagnostics Pack.
If you don't have licensed Diagnostics Pack or you are running Standard or Express Edition, then you can use the similar function of Panorama-Sampler to record the session activity. Panorama evaluates both sources (AWR/ASH or Panorama-Sampler) transparently in the same way.
In general there are several ways in Panorama for retrospective evaluation of previous blocking lock situations:

- Top down analysis of lock dependency tree to identify a root blocking session
- Top down analysis of wait event dependencies to get an overview based on blocking and blocked events (new in Panorama)
- Bottom up analysis to find the root cause of a particular blocked session

Top down analysis of lock dependency tree to identify the root blocking session
Both root session analysis and wait event analysis are available in menu "DBA general" / "DB-Locks" / "Blocking locks historic from ASH".
Choose the time period to consider at first and hit the button "Blocking locks session dependency tree".

This gives a list of all detected root blocking sessions in time period ordered by the amount of wait time for all directly or indirectly blocked sessions.

This function for identification of root blocking sessions has already been described in detail in a previous block post.
Top down analysis of wait event dependencies to get an overview based on blocking and blocked events
This list shows blocking and blocked sessions grouped by their wait events.

This gives an overview over how sessions blocked on a particular wait event are dependent from blocking sessions which are currently in a particular wait event.
This way it allows to evaluate the reason of locking problems even if there are large amounts of database sessions included.

For RAC systems it is also possible to show the wait events per instance to identify concurrency between RAC nodes. 

Clicking one of the chart icons in the upper left corner shows a time chart with the amount of sessions that are affected by blocking/blocked combination.

For each combination of blocking/blocked wait event you can drill down into the blocking or blocked sessions as well as drill down into the fine grained ASH samples.
Blocking sessions:

Blocked/waiting sessions:

Single ASH samples the previous aggregations are based on:

Other links allows further investigation of the whole ASH history for particular sessions, SQL-IDs etc. .
Bottom up analysis to find the root cause of a particular blocked session
From each single ASH record of a blocked session you can pass through the blocking sessions dependency tree up to the root blocking session that is not blocked by any other session.
Here are single ASH records of a blocking/waiting event combination:

Hit button "Thread" in column "Block." to view the whole dependency tree up to the root blocking session:

This way you see all sessions included in the lock dependency tree and identify the session causing this locking cascade.
Some times you may also see a cross dependency that is cleared later on by the database by "deadlock detected". The last session before cycling in dependency is marked "DEADLOCK" in this case.

Please feel free to try out this functions and share a comment if you have been successful (or not).
