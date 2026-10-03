# Oracle DB: Evaluate current segment statistics prior to next AWR snapshot

Datum: 2024-09-29
URL: https://rammpeter.blogspot.com/2024/09/oracle-db-evaluate-current-segment.html
Labels: Oracle Database, Panorama How-To, Performance tuning

---

The views gv$SegStat
 rsp. gv$Segment_Statistics
 provides several cumulative statistics per DB segment.

This information is populated at AWR snapshots, visible via DBA_Hist_Seg_Stat.

But sometimes you don't want to wait for the next AWR snapshot to get results or the resolution of the AWR snapshot period is too coarse.

In this case the values from gv$Segment_Statistics
 are quite helpful if you could get the condensed results for the last x seconds only.

Unfortunately, gv$Segment_Statistics contains only values cumulated since the last DB restart resp. since other events (possibly since the last load of blocks of a segment into the buffer cache).

The following SQL collects the statistics value changes within the last x seconds by sampling twice and providing the differences.

It shows all the segments and their statistics where values have changed in the considered period.
 
The entire function is encapsulated within a single SELECT SQL, so that nothing needs to be installed or changed at the target DB.

WITH 
 FUNCTION ConcatResult(p_SampleTime NUMBER) RETURN SYS.DBMS_DEBUG_VC2COLL IS
 mylist SYS.DBMS_DEBUG_VC2COLL := SYS.DBMS_DEBUG_VC2COLL(); 
 
 Key_Length CONSTANT NUMBER := 500;
 v_Key VARCHAR2(Key_Length);
 v_Diff NUMBER;
 v_StartTime TIMESTAMP;
 v_EndTime TIMESTAMP;
 v_TimeDiff NUMBER;
 
 TYPE Stat_Table_Type IS TABLE OF NUMBER INDEX BY VARCHAR2(Key_Length);
 Stat1 Stat_Table_Type;
 Stat2 Stat_Table_Type;
 
 FUNCTION BuildKey(p_Inst_ID GV$Segment_Statistics.Inst_ID%TYPE,
 p_Owner GV$Segment_Statistics.Owner%TYPE,
 p_Object_Name GV$Segment_Statistics.Object_Name%TYPE,
 p_SubObject_Name GV$Segment_Statistics.SubObject_Name%TYPE,
 p_Object_Type GV$Segment_Statistics.Object_Type%TYPE,
 p_Statistic_Name GV$Segment_Statistics.Statistic_Name%TYPE
 ) RETURN VARCHAR2 IS
 BEGIN
 RETURN p_Inst_ID||'^'||p_Owner||'^'||p_Object_Name||'^'||p_SubObject_Name||'^'||p_Object_Type||'^'||p_Statistic_Name;
 END BuildKey;
 
 PROCEDURE CollectStat(p_Table IN OUT Stat_Table_Type) IS
 BEGIN
 FOR Rec IN (
 SELECT Inst_ID, Owner, Object_Name, SubObject_Name, Object_Type, Statistic_Name, Value
 FROM GV$Segment_Statistics
 WHERE Value != 0
 ORDER BY Owner, Object_Name, SubObject_Name, Object_Type, Statistic_Name, Inst_ID 
 ) LOOP
 p_Table(BuildKey(Rec.Inst_ID, Rec.Owner, Rec.Object_Name, Rec.SubObject_Name, Rec.Object_Type, Rec.Statistic_Name)) := Rec.Value; 
 END LOOP; 
 END CollectStat; 
 /*
*/
 BEGIN
 v_StartTime := SYSTIMESTAMP;
 CollectStat(Stat1);
 v_EndTime := SYSTIMESTAMP;
 v_TimeDiff := EXTRACT(MINUTE FROM (v_EndTime - v_StartTime)) * 60 + EXTRACT(SECOND FROM (v_EndTime - v_StartTime));
 IF v_TimeDiff > p_SampleTime THEN
 RAISE_APPLICATION_ERROR(-20999, 'Select from GV$Segment_Statistics tooks longer ('||v_TimeDiff||' seconds) than expected delay between samples ('||p_SampleTime||' seconds)! Please choose a greater period between samples.');
 END IF;
 
 DBMS_Session.Sleep(p_SampleTime - v_TimeDiff);
 CollectStat(Stat2);
 
 v_Key := Stat2.FIRST; -- Get the first key
 WHILE v_Key IS NOT NULL LOOP
 IF Stat1.EXISTS(v_Key) THEN
 v_Diff := Stat2(v_Key) - Stat1(v_Key);
 IF v_Diff > 0 THEN
 mylist.EXTEND;
 mylist(mylist.LAST) := v_Key||'^'||v_Diff;
 END IF;
 END IF; 
 v_Key := Stat2.NEXT(v_Key); -- Get the next key
 END LOOP;
 
 RETURN mylist; 
 END;
SELECT Owner, Object_Name, SubObject_Name, Object_Type, Statistic_Name, SUM(Value) Value
FROM (SELECT SUBSTR(COLUMN_VALUE, 1, INSTR(COLUMN_VALUE, '^')-1) Inst_ID,
 SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 1)+1, INSTR(COLUMN_VALUE, '^', 1, 2)-INSTR(COLUMN_VALUE, '^', 1, 1)-1) Owner, 
 SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 2)+1, INSTR(COLUMN_VALUE, '^', 1, 3)-INSTR(COLUMN_VALUE, '^', 1, 2)-1) Object_Name, 
 SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 3)+1, INSTR(COLUMN_VALUE, '^', 1, 4)-INSTR(COLUMN_VALUE, '^', 1, 3)-1) SubObject_Name, 
 SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 4)+1, INSTR(COLUMN_VALUE, '^', 1, 5)-INSTR(COLUMN_VALUE, '^', 1, 4)-1) Object_Type, 
 SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 5)+1, INSTR(COLUMN_VALUE, '^', 1, 6)-INSTR(COLUMN_VALUE, '^', 1, 5)-1) Statistic_Name, 
 TO_NumBER(SUBSTR(Column_Value, INSTR(COLUMN_VALUE, '^', 1, 6)+1)) Value 
 FROM TABLE(ConcatResult(&seconds))
 ) 
GROUP BY Owner, Object_Name, SubObject_Name, Object_Type, Statistic_Name 
ORDER BY Owner, Object_Name, SubObject_Name, Object_Type, Statistic_Name 
;

A more convenient way to get this result would by to run this selection using the free analysis tool Panorama.
