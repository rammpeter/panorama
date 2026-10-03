# Oracle-DB: Cleanup Unified Audit Trail with dynamic number of rows and oldest timestamp, but limited storage size

Datum: 2025-01-28
URL: https://rammpeter.blogspot.com/2025/01/oracle-db-cleanup-unified-audit-trail.html
Labels: Oracle Database

---

For housekeeping of Unified Audit Trail in a recent project there were some objectives:

 - A hard rule that audit records must be kept in all cases for at least x days

 - A hard rule that the stored audit records should not exceed a limited storage size, except the the above age limit requires this

 - A soft objective thet audit records should be stored as long as possible if the storage size limit is not reached

The package DBMS_AUDIT_MGMT only provides the method CLEAN_AUDIT_TRAIL with the ability to cut the records to purge at a timestamp limit.

This would require to estimate a maximum age of held audit records that ensures also in worst cases that the storage size limit will not be exceeded.
In result, outside the worst case of audit volume you will purge the audit records far too early.

You could have stored them much longer because there's enough space below the storage limit.

The following SQL script accepts all named objectives by ensuring:

 - Audit records younger than x will never be purged

 - Old audit records are purged if necessary to reach the defined size limit if they do not violate the minimum age limit

 - Audit records are stored as long as the storage size limit is not exceeded

-- purge the unified audit trail with follwing rules:
-- Audit records are purged if size/amount of stored audit data exceeds a threshold
-- Audit records younger than minimum age are never purged

-- 2025-01-27, Peter Ramm, OSP Dresden

/*
If the period to purge is larger than the interval of one partition in audsys.AUD$Unified,
then DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL will use DROP PARTITION instead of DELETE if all records of a partition should be purged.
For efficient purge it is suggested to set the partioning interval smaller than the call cycle of this script.
Use DBMS_AUDIT_MGMT.ALTER_PARTITION_INTERVAL to define the used interval.
Oracle's default of 1 month would be too coarse in most cases.
*/

SET SERVEROUTPUT ON LINESIZE 300;

DECLARE
 MIN_DAYS_KEEP CONSTANT NUMBER := 14; -- Minimum age of audit records before considered for purge, adjust to your needs
 MAX_DATA_SIZE_MB CONSTANT NUMBER := 500; -- Net size limit of stored audit records, adjust to your needs 

 v_Avg_Row_Len NUMBER;
 v_Min_Timestamp TIMESTAMP; -- timestamp of oldest record
 v_Max_Timestamp TIMESTAMP;
 v_Max_Rows_to_Keep NUMBER;
 v_Current_Rows_Count NUMBER;
 v_Rows_to_purge NUMBER;

 PROCEDURE Log(p_Msg IN VARCHAR2) IS
 BEGIN
 DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')||' '||p_Msg);
 END Log;
BEGIN
 Log('===== Start purge Unified Audit Trail =====');

 -- Use audsys.AUD$Unified to calculate the avg. net size of an audit entry
 SELECT Avg_Row_Len INTO v_Avg_Row_Len FROM DBA_Tables WHERE Owner = 'AUDSYS' AND Table_Name = 'AUD$UNIFIED';
 IF v_Avg_Row_Len IS NULL THEN
 RAISE_APPLICATION_ERROR(-20999, 'audsys.AUD$Unified must be analyzed to know the avg. row len');
 END IF;

 v_Max_Rows_to_Keep := ROUND(MAX_DATA_SIZE_MB * 1024*1024 / v_Avg_Row_Len);
 Log('Minimum days to keep : '||MIN_DAYS_KEEP);
 Log('Maximum remaining data size after purge : '||MAX_DATA_SIZE_MB||' MB');
 Log('Maximum number of rows accepted : '||v_Max_Rows_to_Keep);

 -- Use view Unified_Audit_Trai to count all audit entries
 -- table rows from audsys.AUD$Unified as well as files in filesystem for r/o instances (GV$Unified_Audit_Trail)
 SELECT /*+ PARALLEL(2) */ COUNT(*), MIN(Event_Timestamp) INTO v_Current_Rows_Count, v_Min_Timestamp FROM Unified_Audit_Trail;
 Log('Current number of rows in Unified_Audit_Trail : '||v_Current_Rows_Count);
 Log('Current oldest stored record is from : '||TO_CHAR(v_Min_Timestamp, 'YYYY-MM-DD HH24:MI_SS'));

 if v_Current_Rows_Count < v_Max_Rows_to_Keep THEN
 Log('Nothing to purge because size limit is not reached');
 Log('Calculated net data size is : '||ROUND(v_Current_Rows_Count * v_Avg_Row_Len / (1024*1024), 2)||' MB');
 ELSE
 IF v_Min_Timestamp > SYSDATE - MIN_DAYS_KEEP THEN
 Log('Size limit is exceeded, but all audit records are younger than age threshold. Nothing to purge.');
 Log('Calculated net data size is : '||ROUND(v_Current_Rows_Count * v_Avg_Row_Len / (1024*1024), 2)||' MB');
 ELSE
 Log('Calculated net data size is : '||ROUND(v_Current_Rows_Count * v_Avg_Row_Len / (1024*1024), 2)||' MB');

 -- Use view Unified_Audit_Trai to count all audit entries incl. file system
 SELECT /*+ PARALLEL(2) */ MAX(Event_Timestamp), COUNT(*) INTO v_Max_Timestamp, v_Rows_To_Purge
 FROM (SELECT RowNum Row_Num, Event_Timestamp
 FROM (SELECT Event_Timestamp
 FROM Unified_Audit_Trail
 WHERE Event_Timestamp < SYSDATE - MIN_DAYS_KEEP
 ORDER BY Event_Timestamp DESC
 )
 )
 WHERE Row_num > v_Max_Rows_to_Keep
 ;
 Log('Approximate number of rows to purge : '||v_Rows_To_Purge);
 Log('Purge audit records older than : '||TO_CHAR(v_Max_Timestamp, 'YYYY-MM-DD HH24:MI_SS'));

 DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
 last_archive_time => v_Max_Timestamp
 );
 DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
 use_last_arch_timestamp => TRUE
 );

 SELECT /*+ PARALLEL(2) */ COUNT(*), MIN(Event_Timestamp) INTO v_Current_Rows_Count, v_Min_Timestamp FROM Unified_Audit_Trail;
 Log('No. of rows after purge in Unified_Audit_Trail: '||v_Current_Rows_Count);
 Log('Oldest stored record after purge is from : '||TO_CHAR(v_Min_Timestamp, 'YYYY-MM-DD HH24:MI_SS'));
 END IF;
 END IF;
 Log('===== Finished purge Unified Audit Trail =====');
END;
/

Please keep in mind that the storage size limit is treated as net data size (avg. row length * number of rows).

The really allocated storage will be higher, e.g. due to PctFree, LOB indexes and the possibly nearly empty oldest partition.
