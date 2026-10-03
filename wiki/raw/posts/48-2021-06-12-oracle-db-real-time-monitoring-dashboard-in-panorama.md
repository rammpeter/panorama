# Oracle-DB: Real-time monitoring dashboard in Panorama

Datum: 2021-06-12
URL: https://rammpeter.blogspot.com/2021/06/oracle-db-real-time-monitoring.html
Labels: Analyze performance issue, Panorama How-To

---

In addition to various functions, the free performance analysis tool Panorama now also offers a browser dashboard for real-time monitoring of Oracle database performance.
This shows key indicators for active sessions by wait class as well as top sessions and top SQLs in considered time period.
Several values within this dashboard are presented as links which allow to dig in deeper using Panorama's  standard analysis workflows.
 Choose menu entry "DBA general"/"Dashboard", the time to cover until now and a refresh rate:

As long as gv$Active_Session_History has retrospective data it is shown in the graph for the chosen time period grouped by wait class.
At next refresh time only the delta since last refresh is transferred from gv$Active_Session_History to your browser instance.
Investigate a particular time period within the presented data
The top sessions and SQLs are related to the current time frame you can select within the chart.

If you select a particular time frame in the chart or drill down by the available links then the automatic refresh of the chart is suspended until you activate refreshing again.

There are several hyperlinks for further drill down into session and SQL details:

Clicking a wait class in the legend leads to detailed ASH analysis, at first grouped by wait events:

Clicking a session ID in the top session list leads to session details:

Clicking the SQL-ID in the top SQLs list leads to current SQL details in SGA:

What about using the dashboard with Standard Edition or without Diagnostics Pack?
This dashboard is based on AWR and ASH data which requires licensing of Diagnostics Pack in Enterprise Edition.

But you can use this dashboard also for Standard Edition or without Diagnostics Pack if alternative ASH/AWR gathering by Panorama-Sampler is activated in Panorama for this database instance.
