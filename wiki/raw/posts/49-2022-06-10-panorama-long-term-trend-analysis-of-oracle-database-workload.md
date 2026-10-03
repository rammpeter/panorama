# Panorama: Long-term trend analysis of Oracle database workload

Datum: 2022-06-10
URL: https://rammpeter.blogspot.com/2019/02/panorama-long-term-trend-analysis-of.html
Labels: Active Session History, Long-term storage of ASH data, Oracle, Oracle Database, Oracle DB, System load evolution

---

Why

Oracle DB allows retrospective evaluation of workload of active sessions by Active Session History (ASH) if you have Enterprise Edition and Diagnostics Pack.

The default retention time for ASH is 7 days back from now, usual settings for production are around 30 days.

But sometimes you need to analyze the evolution of database load over longer periods like over many years (e.g. as base for hardware planning and capital budgeting).

There are less builtin alternatives yet:

- Increase the ASH retention time up to years leads to a huge amount of data, cumbersome or impossible to handle

- Using the AWR-warehouse function in an EM Cloud Control installation may fit your needs, but especially for single or less database instances this causes an inappropriate effort.

What

Panorama-Sampler allows you to extract some information from ASH and store it compressed as summary other periods between one hour and one day.

The Panorama-GUI contains table-views and diagrams for evaluation of stored workload history.

You can let Panorama-Sampler feed this long-term trend data from original ASH as well as from Panorama's own ASH-like sampling.

This way you don't really need EE and Diagnostics Pack. Sampling this long-term trend data also works for Standard Edition.

Stored data contains the summary time of all active sessions over the snapshot period, distributed by some topics. This topics are:

- Instance-Number

- Wait-Class

- Wait-Event

- User-Name

- TNS-Service-Name

- Machine

- Module

- Action

The size of the stored long-term data is much smaller than the ASH source data so it is possible to store several years of workload with acceptable storage requirements. 

For one snapshot per day storage footprint is about 1/1000 compared to ASH data. 

How

Configure sampling engine

You configure your target database like shown for Panorama-Sampler and activate long-term trend recording independently for each target database:

You may control for each topic if it records the active time/session load for each occurrence of this topic or not. This allows you to influence the amount recorded data.

A value for "Subsume limit" sets a limit for less relevant values of a topic to be subsumed under "[OTHERS]". This feature also reduces the amount of recorded data. 

Evaluate stored long-term trends with Panorama

Evaluation of long-term trend data is similar to evaluation of ASH data in Panorama.

Start with menu entry "Long-term trend":

Choose time and first grouping criteria to start digging into the recorded data:

Show evolution over time in diagrams:

Dig deeper in top-down way by clicking the number of distinct occurrences of a topic, like "User-Name":

Show evolution over time for your selection:

Conclusion
There is an easy way for long-term analysis based on Active Session History.
For the frequently used 10 TB DB system shown here as example, the stored long-term ASH for the last four years consumes about 55 MB of storage capacity with a data accuracy of one day.
