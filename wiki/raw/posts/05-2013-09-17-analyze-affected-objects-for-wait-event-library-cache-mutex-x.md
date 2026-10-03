# Analyze affected objects for wait event “library cache: mutex X”

Datum: 2013-09-17
URL: https://rammpeter.blogspot.com/2017/03/analyze-affected-objects-for-wait-event.html
Labels: Analyze performance issue

---

With shown SQLs you can identify objects causing “library cache: mutex X”-waits in library cache.

From oracle 11g this problem may be reduced by cloning objects in library cache via DBMS_SHARED_POOL.MARKHOT. Please keep in mind to set the exact namespace in call of DBMS_SHARED_POOL.MARKHOT, for PL/SQL packages it has to be called twice for package and body. 

View on Active Session History from current SGA:

SELECT COUNT(*) Seconds_in_Wait, obj.NameSpace, h.Inst_ID, o.Owner, o.Type, o.Name, 
 ROUND(AVG(Time_Waited)/1000,2) Avg_Time_waited_ms,
 MIN(Sample_Time) First_Sample,
 MAX(Sample_Time) Last_Sample
FROM gv$Active_Session_History h
LEFT OUTER JOIN gv$DB_Object_Cache o ON o.Hash_Value = h.P1 AND o.Inst_ID = h.Inst_ID
LEFT OUTER JOIN DBA_Objects obj ON obj.Owner = o.Owner AND obj.Object_Name = o.Name AND obj.Object_Type = o.Type 
WHERE Event = 'library cache: mutex X'
GROUP BY h.Inst_ID, o.Owner, o.Type, o.Name, obj.NameSpace
HAVING COUNT(*) > 100 
ORDER BY COUNT(*) DESC
;

View on historic Active Session History from AWR data:

SELECT COUNT(*) Seconds_in_Wait, ROUND(AVG(Time_Waited)/1000,2) Avg_Time_waited_ms, obj.NameSpace, h.Instance_Number, o.Owner, o.Type, o.Name 
FROM DBA_Hist_Active_Sess_History h
LEFT OUTER JOIN gv$DB_Object_Cache o ON o.Hash_Value = h.P1 AND o.Inst_ID = h.Instance_Number
LEFT OUTER JOIN DBA_Objects obj ON obj.Owner = o.Owner AND obj.Object_Name = o.Name AND obj.Object_Type = o.Type 
WHERE h.Event = 'library cache: mutex X'
AND h.Sample_Time > TO_TIMESTAMP('18.09.2013 10:00', 'DD.MM.YYYY HH24:MI:SS')
AND h.Sample_Time < TO_TIMESTAMP('18.09.2013 12:00', 'DD.MM.YYYY HH24:MI:SS')
GROUP BY h.Instance_Number, o.Owner, o.Type, o.Name, obj.NameSpace
HAVING COUNT(*) > 100 
ORDER BY COUNT(*) DESC
;
