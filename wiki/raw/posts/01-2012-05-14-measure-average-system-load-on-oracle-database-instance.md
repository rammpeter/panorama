# Measure average system load on oracle database instance

Datum: 2012-05-14
URL: https://rammpeter.blogspot.com/2017/03/measure-average-system-load-on-oracle.html
Labels: Benchmark system load

---

Short overview over utilization of DB system.

Lists average and peak values for every instance (in case of RAC) for given time range:

– Total number of active DB sessions

– Number of active DB sessions on CPU (no other wait event)

Value and timestamp are shown for:

– maximum peak load

– average load over total time range

– maximum average load over one minute

– maximum average load over one hour

SELECT /* DB-Tools Ramm average system load */
 Instance_Number, MIN(Sample_Time) Start_Range, MAX(Sample_Time) End_Range,
 MAX(Active) Max_Active,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY Active) Max_Active_Sample_Time, 
 MAX(CPU) Max_CPU,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY CPU) Max_CPU_Sample_Time, 
 ROUND(AVG(Active),1) Avg_Active_Total,
 ROUND(AVG(CPU),1) Avg_CPU_Total,
 ROUND(MAX(Avg_Active_Minute),1) Max_Avg_Active_Minute,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY Avg_Active_Minute) Max_Avg_Active_Minute_End, 
 ROUND(MAX(Avg_CPU_Minute),1) Max_Avg_CPU_Minute,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY Avg_CPU_Minute) Max_Avg_CPU_Minute_End, 
 ROUND(MAX(Avg_Active_Hour),1) Max_Avg_Active_Hour,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY Avg_Active_Hour) Max_Avg_Active_Hour_End, 
 ROUND(MAX(Avg_CPU_Hour),1) Max_Avg_CPU_Hour,
 MAX(Sample_Time) KEEP (DENSE_RANK LAST ORDER BY Avg_CPU_Hour) Max_Avg_CPU_Hour_End 
FROM ( 
 SELECT h.*,
 AVG(Active) OVER (PARTITION BY Instance_Number, TRUNC(Sample_Time, 'MI')) Avg_Active_Minute, 
 AVG(Active) OVER (PARTITION BY Instance_Number, TRUNC(Sample_Time, 'HH24')) Avg_Active_Hour, 
 AVG(CPU) OVER (PARTITION BY Instance_Number, TRUNC(Sample_Time, 'MI')) Avg_CPU_Minute, 
 AVG(CPU) OVER (PARTITION BY Instance_Number, TRUNC(Sample_Time, 'HH24')) Avg_CPU_Hour 
 FROM (
 SELECT /*+ NO_MERGE LEADING(h.ash) PARALLEL(h,4) */ 
 Instance_Number, Sample_Time, 
 COUNT(*) Active,
 SUM(CASE WHEN Session_State = 'ON CPU' THEN 1 ELSE 0 END) CPU 
 FROM DBA_Hist_Active_Sess_History h
 WHERE Sample_Time > SYSTIMESTAMP - 4
 AND NVL(Event, Session_State) NOT IN ('PX Deq Credit: send blkd') -- Idle-Events nicht zaehlen
 GROUP BY Instance_Number, Sample_Time
 ) h
 )
GROUP BY Instance_Number 
;
