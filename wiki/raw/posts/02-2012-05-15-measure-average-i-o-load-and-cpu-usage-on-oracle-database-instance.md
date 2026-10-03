# Measure average I/O-load and CPU-usage on Oracle database instance

Datum: 2012-05-15
URL: https://rammpeter.blogspot.com/2017/03/measure-average-io-load-and-cpu-usage.html
Labels: Benchmark system load

---

Short overview on peak I/O requests, transfer volume and CPU-usage for given time range.

Based on average values within AWR-cycle.

SELECT /* DB-Tools Ramm average system load */
 Instance_Number, MIN(Begin_Time) Start_Range, MAX(End_Time) End_Range,
 MAX(Phys_Write_Total_kB_per_Sec) Max_Phys_Writes_kB_per_Sec,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY Phys_Write_Total_kB_per_Sec) Max_Write_per_Sec_BeginTime,
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY Phys_Write_Total_kB_per_Sec) Cycle_Minutes_1, 
 MAX(Phys_Read_Total_kB_per_Sec) Max_Phys_Read_kB_per_Sec,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY Phys_Read_Total_kB_per_Sec) Max_Read_per_Sec_BeginTime, 
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY Phys_Read_Total_kB_per_Sec) Cycle_Minutes_2, 
 MAX(Phys_Write_IO_per_Sec) Max_Phys_Write_IO_per_Sec,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY Phys_Write_IO_per_Sec) Max_Write_IO_per_Sec_BeginTime,
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY Phys_Write_IO_per_Sec) Cycle_Minutes_3, 
 MAX(Phys_Read_IO_per_Sec) Max_Phys_Read_IO_per_Sec,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY Phys_Read_IO_per_Sec) Max_Read_IO_per_Sec_BeginTime, 
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY Phys_Read_IO_per_Sec) Cycle_Minutes_4, 
 MAX(Host_CPU_Utilization_Pct) Max_Host_CPU_Utilization_Pct,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY Host_CPU_Utilization_Pct) Max_Host_CPU_Pct_BeginTime, 
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY Host_CPU_Utilization_Pct) Cycle_Minutes_4, 
 MAX(DB_CPUs) Max_DB_CPUs,
 MAX(Begin_Time) KEEP (DENSE_RANK LAST ORDER BY DB_CPUs) DB_CPUs_BeginTime, 
 MAX((End_Time-Begin_Time)*1440) KEEP (DENSE_RANK LAST ORDER BY DB_CPUs) Cycle_Minutes_4 
FROM ( 
 SELECT /*+ NO_MERGE LEADING(h.ash) PARALLEL(h,4) */ 
 Instance_Number, Begin_Time, End_Time,
 ROUND(SUM(CASE WHEN Metric_Name = 'Physical Write Total Bytes Per Sec' THEN Average ELSE 0 END)/1024) Phys_Write_Total_kB_per_Sec,
 ROUND(SUM(CASE WHEN Metric_Name = 'Physical Read Total Bytes Per Sec' THEN Average ELSE 0 END)/1024) Phys_Read_Total_kB_per_Sec,
 ROUND(SUM(CASE WHEN Metric_Name = 'Physical Write IO Requests Per Sec' THEN Average ELSE 0 END)) Phys_Write_IO_per_Sec,
 ROUND(SUM(CASE WHEN Metric_Name = 'Physical Read IO Requests Per Sec' THEN Average ELSE 0 END)) Phys_Read_IO_per_Sec,
 ROUND(SUM(CASE WHEN Metric_Name = 'Host CPU Utilization (%)' THEN Average ELSE 0 END)) Host_CPU_Utilization_Pct,
 ROUND(SUM(CASE WHEN Metric_Name = 'CPU Usage Per Sec' THEN Average ELSE 0 END)/100,2) DB_CPUs
 FROM DBA_Hist_SysMetric_Summary
 WHERE Begin_Time > SYSTIMESTAMP - 7
 AND Metric_Name IN ('Physical Write Total Bytes Per Sec', 'Physical Write IO Requests Per Sec', 'Physical Read Total Bytes Per Sec', 'Physical Read IO Requests Per Sec',
 'Host CPU Utilization (%)', 'CPU Usage Per Sec' )
 GROUP BY Instance_Number, Begin_Time, End_Time
 ) h
GROUP BY Instance_Number 
;
