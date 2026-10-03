# Panorama: How to identify root cause after “ORA-1652: unable to extend temp segment”

Datum: 2016-03-23
URL: https://rammpeter.blogspot.com/2016/03/panorama-how-to-identify-root-cause.html
Labels: Analyze performance issue, Panorama How-To

---

If you find this message “ORA-1652: unable to extend temp segment” in alert.log there are two alternatives for reason:

- The session causing the ORA-1652 has allocated large memory in temporary tablespace itself and got ORA-1652 at the end of available space 

- Other sessions did successfully allocate large amount of memory in temp tablespace but this session with only small demand got ORA-1652 

But how to identify the session that really claimed large amounts in temporary tablespace and therefore is responsible for the ORA-1652?

With Panorama you can clarify this as follows:

Go to menu “Schema / Storage” / “Temp usage” / “Historic”.

- Choose the concerning period and appropriate time unit. 

- Sort table by column “Max. TEMP allocated” 

- Show column “Max. TEMP allocated” in diagram via context menu click in column and select “Show column in diagram” 

Now let’s check the temp usage peak at 00:10.

One of several ways to identify the sessions causing the peak is: 

- Click the value in column “Total time waited” for the first row (at 00:10:00).

- This opens the evaluation of active session history grouped by RAC-instance for the minute from 00:10:00 until 00:11.00. 

- Click the value in column “Session / Sn.” for the instance with highest value in column “Max. temp” 

- You get a table with onle row per “Session / Sn.” now 

- Remove the filter on instance at next page if multiple instances claimed significant temp space. 

- Sort the table descending by “Max. temp” 

- Finished: Now you see the sessions claiming temp space at this time 

- Within this table you can view further details for that sessions like execution context, SQL statements they executed, wait events, affected DB-objects and much more. 

- If you use parallel query, click in column “Parallel query” to see temp usage of parallel query slaves also for this coordinator, because “Max. temp” only shows the maximum temp usage over coordinator and his slaves
