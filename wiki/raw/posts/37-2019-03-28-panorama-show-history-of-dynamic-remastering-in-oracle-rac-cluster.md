# Panorama: Show history of Dynamic Remastering in Oracle RAC-cluster

Datum: 2019-03-28
URL: https://rammpeter.blogspot.com/2019/03/panorama-show-history-of-dynamic.html
Labels: 

---

Unfortunately, dynamic remastering in RAC clusters has very little official documentation.

Some useful information about this topic you may get here:

- http://oracleinaction.com/dynamic-remastering/

- https://www.hhutzler.de/blog/a-closer-look-into-drm-dynamic-resource-management/

- https://orainternals.wordpress.com/2010/03/25/rac-object-remastering-dynamic-remastering/

As part of the performance analysis app Panorama you can view the instance-affinity of tables, indexes and their partitions as well as the history of DRM events per object or globally.

The history info is gotten from view gv$Policy_History.

The current affinity comes from view V$GCSPFMaster_Info.

The object detail view shows you the master instance of each object like here for a table:

Click on instance number list the complete history of DRM events for this object:

In addition you can also get an overview over all DRM actions of your database.

Starting with menu "Analyses/Statistics" / "RAC-related analysis" / "Dynamic remastering events historic" you can view:

1. The distribution of events over time and per RAC-instance as table as well as chart down to single event records.

2. The affected objects in considered period down to their single event records
