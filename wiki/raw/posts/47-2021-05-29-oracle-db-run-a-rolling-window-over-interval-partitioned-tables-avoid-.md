# Oracle-DB: Run a rolling window over interval partitioned tables / avoid ORA-14300, ORA-14758

Datum: 2021-05-29
URL: https://rammpeter.blogspot.com/2021/05/oracle-db-run-rolling-window-over.html
Labels: Code templates

---

A problem using interval partitions may be that the number of partitions may not
exceed 1.048.575 (1024*1024-1). If using interval partitions not only the
physical partitions count. Instead, the number of possible partitions between
the required first range partiton and the last interval partition counts for the
limit (in consideration of the used interval). 

If you exceed the limit,
ORA-14300 (partitioning key maps to a partition outside maximum permitted number
of partitions) is raised . 
So if you have a rolling window with interval
partitions, where new interval partitions at the upper bound are created and
older partitions are dropped if no longer needed, you may run into ORA-14300 if
your initially created range partition becomes to far away from the upper bound
of interval partitions. 

A possible solution should be to increase the high value
of the initial range partition to lower the distance to the highest interval
partition. 

But how to do that? 

The first idea is to remove the fist range partition by a simple ALTER TABLE DROP PARTITON; .
This will a raise an ORA-14758 (Last partition in the range section cannot be dropped).

At least from Oracle 19c you can online redefine
the whole partitioning rule of the table with a higher start date like e.g. for
a Date interval: 

 ALTER TABLE MyTab MODIFY PARTITION BY RANGE (Created_At) 
 INTERVAL( NUMTODSINTERVAL(1,'MINUTE')) ( PARTITION MIN VALUES
 LESS THAN (TO_DATE(' 2021-01-01 00:00:00', 'SYYYY-MM-DD HH24:MI:SS',
 'NLS_CALENDAR=GREGORIAN')) ) ONLINE;

But this causes a lot of physical data move and possible impact on the used interval partitions.In addition this approach does not work with Oracle 12 or below.

Another possible solution would be to temporary disable the interval partitioning, than drop the first partition and reenable interval partitioning. But for uninterrupted availability of interval partitioning this will not fit. 

So what else may help?

Based on the meaning of ORA-14758 it implies that if there are multiple range partitions below the interval partition than any of them except the last one can be dropped. So this way the partition with the oldest high value can be dropped and so fix the issue with ORA-14300.

Let's assume our table is created with this partition clause:

 CREATE TABLE MyTab (Created_At DATE) 
 PARTITION BY RANGE (Created_At) INTERVAL( NUMTODSINTERVAL(1,'MINUTE')) 
 ( PARTITION MIN VALUES LESS THAN 
 (TO_DATE(' 2018-01-01 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 
 'NLS_CALENDAR=GREGORIAN')) ); 

With an interval of one minute we can only cover about 1.9 years before getting ORA-14300.

A last interval partition has been created by:

INSERT INTO MyTab (Created_At) VALUES (TO_DATE('2019-12-29 12:11:53', 'YYYY-MM-DD HH24:MI:SS'));

But creating a partition at the next day will fail with ORA-14300:
INSERT INTO MyTab (Created_At) VALUES (TO_DATE('2019-12-30 12:11:53', 'YYYY-MM-DD HH24:MI:SS'));

What we can do here (also for Oracle 12.2) is:
- to trigger the creation of an empty interval partition below the lower bound of the existing interval portions
- split this partition into two partitions (this way they become pure range partitions instead of interval partition)
- drop the former only range partition with the problematic high value (now possible without ORA-14300)
- drop one of the remaining partitions after the split operation
- the other remaining partition of the spilt operation now becomes the only pure range partition with the lowest high value

This way this operation does not influence the existing interval partitions (except possible impact on global indexes in lower Oracle releases).

So let's realise this steps:

Trigger an empty partition creation below the lower bound of the existing interval partitions:

INSERT INTO MyTab (Created_At) VALUES (TO_DATE('2019-12-28 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));
ROLLBACK;

Look what happened:
SELECT Partition_name, high_value, interval FROM User_Tab_Partitions 
WHERE Table_Name = 'MYTAB' ORDER BY Partition_Position;

An empty partition SYS_P262 has been created between the initial range partition and the oldest interval partition.
PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2018-01-01 00:00:00', ... NO
SYS_P262 TO_DATE(' 2019-12-28 11:51:00', ... YES
SYS_P261 TO_DATE(' 2019-12-29 12:12:00', ... YES

At next we split this empty partition into two pure range partitions.ALTER TABLE MyTab SPLIT PARTITION SYS_P262 INTO (
PARTITION Split1 VALUES LESS THAN (TO_DATE(' 2019-12-29 12:00:00', 
 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')),
PARTITION Split2);

The high value for the split operation has to be exactly the high value of the lowest interval partition minus the interval. If we get a ORA-14080 (partition cannot be split along the specified high bound), than try with +/- one second for the high value to workaround possible rounding issues. 

PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2018-01-01 00:00:00', ... NO
SPLIT1 TO_DATE(' 2019-12-28 12:00:01', ... NO
SPLIT2 TO_DATE(' 2019-12-28 12:01:00', ... NO
SYS_P261 TO_DATE(' 2019-12-29 12:12:00', ... YES

Now the have the partition splitted into two range partitions and may drop two of the three range partitions.

ALTER TABLE MyTab DROP PARTITION MIN;
ALTER TABLE MyTab DROP PARTITION Split1;
ALTER TABLE MyTab RENAME PARTITION Split2 TO MIN;

The remaining result is what we wanted to achieve. Now it's possible to create further interval partitions.
PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2019-12-28 12:01:00', ... NO
SYS_P261 TO_DATE(' 2019-12-29 12:12:00', ... YES

This works for Oracle 19c as well as for 12.2. 
But unfortunately it does not work for Oracle 12.1 because ALTER TABLE SPLIT PARTITION for the oldest interval partition each time leads to ORA-14080 also for 12.1.0.2 with PSU April 2021.

 Another approach (also including 12.1) is:

 - to trigger the creation of two empty interval partitions below the lower bound of the existing interval portions

 - merge this partitions into one partition (this way the merged partition becomes a pure range partition instead of interval partition)

 - drop the former only range partition with the problematic high value (now possible without ORA-14300)

 - the merged partition now becomes the only pure range partition with the lowest high value

 Let's assume the same starting situation like for the previous approach.

 Trigger the creation of two adjacent empty interval partitions below the lower bound of the existing interval partitions. The time distance should be exactly the interval.

 INSERT INTO MyTab (Created_At) VALUES (TO_DATE('2019-12-28 11:45:03', 'YYYY-MM-DD HH24:MI:SS'));
INSERT INTO MyTab (Created_At) VALUES (TO_DATE('2019-12-28 11:46:03', 'YYYY-MM-DD HH24:MI:SS'));
ROLLBACK;

Look what happened:
 SELECT Partition_name, high_value, interval FROM User_Tab_Partitions 
WHERE Table_Name = 'MYTAB' ORDER BY Partition_Position;

 SYS_P258 is productive, SYS_P259 and SYS_P260 are empty partitions.

 PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2018-01-01 00:00:00', ... NO
SYS_P259 TO_DATE(' 2019-12-28 11:46:00', ... YES
SYS_P260 TO_DATE(' 2019-12-28 11:47:00', ... YES
SYS_P258 TO_DATE(' 2019-12-29 12:12:00', ... YES

 At next we merge this empty partitions into one pure range partitions.ALTER TABLE MyTab MERGE PARTITIONS SYS_P259, SYS_P260;

 An empty partition SYS_P261 has been created between the initial range partition and the oldest interval partition.
PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2018-01-01 00:00:00', ... NO
SYS_P262 TO_DATE(' 2019-12-28 11:47:00', ... NO
SYS_P258 TO_DATE(' 2019-12-29 12:12:00', ... YES

Now we may drop the oldest range partition.
 ALTER TABLE MyTab DROP PARTITION MIN;
ALTER TABLE MyTab RENAME PARTITION SYS_P261 TO MIN;

The remaining result is also what we wanted to achieve, but in contrast to the previous approach also works for 12.1.0.2.PARTITION_NAME HIGH_VALUE INTERVAL
--------------- ------------------------------------ ---
MIN TO_DATE(' 2019-12-28 11:47:00', ... NO
SYS_P258 TO_DATE(' 2019-12-29 12:12:00', ... YES
