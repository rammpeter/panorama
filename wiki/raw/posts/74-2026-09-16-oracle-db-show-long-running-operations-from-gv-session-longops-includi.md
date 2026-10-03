# Oracle DB: Show long running operations from GV$Session_LongOps including the name of the accessed partitions

Datum: 2026-09-16
URL: https://rammpeter.blogspot.com/2026/09/oracle-db-show-long-running-operations.html
Labels: Oracle Database, Partition, v$Session_LongOps

---

Sometimes it is interesting to know which partitions are currently accessed by long running scans.

One possible way to get this info is to use the GV$Session.Row_Wait_Obj#
 to determine the object that is currently accessed by the DB session.

This SQL will select the currently active long ops along with the partition info of the accessed object.

The column Object_Belongs_To_Target_Table
 checks if the partition info gotten by GV$Session.Row_Wait_Obj#
 is really valid.

SELECT l.*, l.Serial# Serial_No,
 o.Object_Type, o.Owner, o.Object_Name, o.SubObject_Name,
 CASE WHEN o.Owner = l.Target_Owner AND o.Object_Name = l.Target_Table_Name THEN 'YES' /* Table is accessed */
 ELSE CASE WHEN (o.Owner, o.Object_Name) IN (SELECT i.Owner, i.Index_Name
 FROM DBA_Indexes i
 WHERE i.Table_Owner = l.Target_Owner AND i.Table_Name = l.Target_Table_Name
 ) THEN 'YES' /* Index of table is accessed */
 ELSE 'NO' END /* Object determined by Row_Wait_Obj# is not valid / does not belong to target table */
 END Object_Belongs_To_Target_Table
FROM (SELECT l.*,
 CASE WHEN l.OpName = 'Sort Output' THEN NULL
 ELSE l.Last_Update_Time + l.Time_Remaining / 86400 END End_Time,
 CASE WHEN INSTR(l.Target, '.') > 0 THEN SUBSTR(l.Target, 1, INSTR(l.Target, '.')-1) END Target_Owner,
 CASE WHEN INSTR(l.Target, '.') > 0 THEN SUBSTR(l.Target, INSTR(l.Target, '.')+1) END Target_Table_Name
 FROM gv$Session_Longops l
 ) l
LEFT OUTER JOIN gv$Session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID AND s.Serial# = l.Serial# AND s.SQL_ID = l.SQL_ID AND s.SQL_Exec_ID = l.SQL_Exec_ID
 AND s.Row_Wait_Obj# IS NOT NULL AND s.Row_Wait_Obj# != -1 AND l.Time_Remaining > 0
LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = s.Row_Wait_Obj#
WHERE l.Time_Remaining > 0
ORDER BY l.Start_Time DESC
;

The same logic is also used in Panorama to view long ops with different filters.

There are two views:

The long ops in total (Menu "SGA/PGA-details / SQL-Area / Long operations")

and per considered session

Thanks to Matthias Rogel for the inspiration to add that logic to Panorama.
