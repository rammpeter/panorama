# Oracle-DB: Link between audit trail and active session history

Datum: 2021-01-05
URL: https://rammpeter.blogspot.com/2021/01/oracle-db-link-between-audit-trail-and.html
Labels: Analyze performance issue, Code templates

---

Unfortunately the audit trail of the Oracle-DB uses a different session identifier (AudSid) than the Active Session History (SID + Serial#).
Both identifiers are available in v$Session (AudSid, SID, Serial#). So during lifetime of a session it is possible to link between the session info from v$Session an audit trail.
But neither the AudSID is stored in ASH (v$Active_Session_History) nor the SID + Serial# is stored in audit trail. 
This prevents from combining session info of both sources after the session is closed.

There is a possible way to link audit trail with ASH by establishing a logon trigger for that. 
The LOGOFF records in audit trail (if AUDIT SESSION is active) record also the Client_Identifier from v$Session. 
So supplying v$Session.Client_Identifier with the needed info allows to retrieve it from DBA_Audit_Trail.Client_ID. 

This logon trigger does it:

CREATE OR REPLACE TRIGGER Client_ID AFTER LOGON ON DATABASE
-- Put unique session identifier into client-id to have it also in DBA_AUDIT_TRAIL.Client_ID for LOGOFF-records
-- works than as missing link between Active Session History and Audit Trail
-- Peter Ramm, OSP Dresden, 2021-01-05
BEGIN
 -- Use alternative public package instead of SYS_CONTEXT to get the serial#
 sys.DBMS_SESSION.Set_Identifier('SID = '||DBMS_DEBUG_JDWP.CURRENT_SESSION_ID||', Serial# = '||DBMS_DEBUG_JDWP.CURRENT_SESSION_SERIAL);
END;
/

Update 2025-02

If using unified audit trail there's a solution by adding custom attributes to the the audit trail.

Execute AUDIT CONTEXT NAMESPACE USERENV ATTRIBUTES SID;
 to add the SID from V$Session to the unified audit trail.

You'll find the result in the column 'Application_Contexts' of Unifed_Audit_Trail like "(USERENV,SID=55);".
