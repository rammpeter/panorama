# Oracle-DB: Monitor gradual password rollover usage

Datum: 2024-03-25
URL: https://rammpeter.blogspot.com/2024/03/oracle-db-monitor-gradual-password.html
Labels: Gradual password rollover, Oracle Database

---

As of Oracle DB release 19.12 it is possible to use the new and the previous password for user logon simultaneously for a limited period.

For details see New features guide.

This is a great and long-awaited feature that lowers the barriers to changing passwords with less operational risk.

But there's an obstacle for practical use:

You must be able to monitor the users who are within this rollover period and are still using the old password.

The only way of monitoring the use of old passwords known to me so far is to:

 - Use Unified Auditing

 - Create a policy for the LOGON action

 - Check for the keyword "VERIFIER=12C-OLD" in the column AUTHENTICATION_TYPE of the logon records in unified audit trail.

The following SQL provides an overview over all the users who are currently within a password rollover period, combined with info about old password usage:
SELECT u.Account_Status, u.Password_Change_Date, u.Profile, u.UserName, u.Last_Login,
 a.DBUserName, a.Logon_Count, a.Min_TS, a.Max_TS, a.OS_UserName_Cnt, a.Min_OS_UserName,
 a.UserHost_Cnt, a.Min_UserHost, a.Terminal_Cnt, a.Min_Terminal,
 a.Instance_ID_Cnt, a.Min_Instance_ID, a.External_UserID_Cnt, a.Min_External_UserID,
 a.Global_UserID_Cnt, a.Min_Global_UserID, a.Client_Program_Name_Cnt, a.Min_Client_Program_Name,
 a.DBLink_Info_Cnt, a.Min_DBLink_Info,
 u.Password_Change_Date + NUMTODSINTERVAL(pr.Limit, 'DAY') Rollover_Expiration_Date,
 u.Password_Change_Date + NUMTODSINTERVAL(pr.Limit, 'DAY')-SYSDATE Remaining_Days_for_Rollover
FROM DBA_Users u
LEFT OUTER JOIN (SELECT Profile,
 /* support both seconds and days representation, see Doc ID 2815172.1 */
 CASE WHEN REGEXP_LIKE(Limit, '^[0-9]+$') AND TO_NUMBER(Limit) > 60 THEN
 TO_CHAR(TO_NUMBER(Limit)/86400)
 ELSE Limit END AS Limit
 FROM DBA_Profiles
 WHERE Resource_Name = 'PASSWORD_ROLLOVER_TIME'
 ) pr ON pr.Profile = u.Profile
LEFT OUTER JOIN (
 SELECT NVL(DBProxy_Username, DBUserName) UserName, DBUserName, COUNT(*) Logon_Count,
 MIN(Event_Timestamp) Min_TS, MAX(Event_Timestamp) Max_TS,
 COUNT(DISTINCT OS_UserName ) OS_UserName_Cnt, MIN(OS_UserName ) Min_OS_UserName,
 COUNT(DISTINCT UserHost ) UserHost_Cnt, MIN(UserHost ) Min_UserHost,
 COUNT(DISTINCT Terminal ) Terminal_Cnt, MIN(Terminal ) Min_Terminal,
 COUNT(DISTINCT Instance_ID ) Instance_ID_Cnt, MIN(Instance_ID ) Min_Instance_ID,
 COUNT(DISTINCT External_UserID ) External_UserID_Cnt, MIN(External_UserID ) Min_External_UserID,
 COUNT(DISTINCT Global_UserID ) Global_UserID_Cnt, MIN(Global_UserID ) Min_Global_UserID,
 COUNT(DISTINCT Client_Program_Name ) Client_Program_Name_Cnt, MIN(Client_Program_Name ) Min_Client_Program_Name,
 COUNT(DISTINCT DBLink_Info ) DBLink_Info_Cnt, MIN(DBLink_Info ) Min_DBLink_Info
 FROM Unified_Audit_Trail
 WHERE Action_Name = 'LOGON'
 AND Authentication_Type LIKE '%VERIFIER=12C-OLD%'
 GROUP BY DBUserName, DBProxy_Username
 ) a ON a.UserName = u.UserName
WHERE u.Account_Status LIKE '%ROLLOVER%'
;

A bit more convenient you may get this info using the analysis tool Panorama.

Click at the number in column "Logons with old password" gives the ability to quickly evaluate the individual unified audit trail records for logons with old password for that user.
