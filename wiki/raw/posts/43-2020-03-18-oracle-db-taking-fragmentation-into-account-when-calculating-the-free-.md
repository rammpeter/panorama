# Oracle-DB: Taking fragmentation into account when calculating the free tablespace

Datum: 2020-03-18
URL: https://rammpeter.blogspot.com/2020/03/oracle-db-taking-fragmentation-into.html
Labels: 

---

Even if you think to have enough free space in tablespace your operation may end up in:

ORA-01653 unable to extend table <xy> by <z> in tablespace <TS>

The reason for this often unexpected behavior is:

The table needs a contiguous free space in tablespace in next extent size to allocate a new extent.

If free space in total is enough available but only in smaller slices than the required size of the extent to allocate than this will happen.

Several years / Oracle versions ago fragmentation issues have been addressed by uniform extent size for tablespaces.

Today this issue ist mostly addressed by locally managed tablespaces with an automatically defined limited number of used extent sizes.

Locally managed tablespaces reduce the risk of fragmentation issues, but not completely.

So especially if less space remains available in tablespace fragmentation sometimes becomes important.

One way to check a database for the risk of running into ORA-01653 is to look for the available space in tablespace that can be allocated by the largest used extent size at this tablespace.

So instead of checking the total available space in tablespace, check for further possible allocations of the largest used extent size.

This SQL statement evaluates the remaining number of extent allocations per tablespace for the largest used extent:

WITH Tablespaces AS (
 SELECT /*+ NO_MERGE MATERIALIZE */ Tablespace_Name, 
 SUM(Bytes) Current_Size,
 SUM(CASE WHEN AutoExtensible = 'YES' THEN MaxBytes - Bytes ELSE 0 END) Extensible
 FROM DBA_Data_Files
 GROUP BY Tablespace_Name
 ),
 Extents AS (
 SELECT /*+ NO_MERGE MATERIALIZE */ Tablespace_Name, MAX(Bytes) Max_Extent_Size
 FROM DBA_Extents e
 GROUP BY e.Tablespace_Name
 ) 
SELECT x.*,
 ROUND(Free_GB_for_largest_Extents * 100 / Max_Size_GB, 2) Pct_Free_for_largest_Extents
FROM (
 SELECT t.Tablespace_Name, 
 ROUND(t.Current_Size/(1024*1024*1024)) Current_Size_GB,
 ROUND((t.Current_Size + t.Extensible)/(1024*1024*1024)) Max_Size_GB,
 ef.Max_Extent_Size/(1024*1024) Max_Extent_Size_MB,
 ROUND((ef.Free + t.Extensible)/(1024*1024*1024), 2) Total_Free_GB,
 ef.Max_Free_Extents Max_Avail_Largest_Extents,
 ROUND((ef.Max_Free_Extents * ef.Max_Extent_Size + t.Extensible)/(1024*1024*1024), 2) Free_GB_for_largest_Extents
 FROM Tablespaces t
 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ e.Tablespace_Name,
 MIN(e.Max_Extent_Size) Max_Extent_Size,
 SUM(f.Bytes) Free,
 SUM(TRUNC(f.Bytes/e.Max_Extent_Size)) Max_Free_Extents
 FROM Extents e 
 JOIN DBA_Free_Space f ON f.Tablespace_Name = e.Tablespace_Name
 GROUP BY e.Tablespace_Name
 ) ef ON ef.Tablespace_Name = t.Tablespace_Name 
 ) x
ORDER BY Free_GB_for_largest_Extents / Max_Size_GB 
;

You can also evaluate free space status with the free analysis tool Panorama in menu "Schema/Storage" / "Disk-storage summary".

Clicking in column "MB free" lists the available space and extents for several extent sizes.
