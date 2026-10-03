# Oracle-DB: Accessing Unified_Audit_Trail is very slow. Why?

Datum: 2025-01-17
URL: https://rammpeter.blogspot.com/2025/01/oracle-db-accessing-unifiedaudittrail.html
Labels: Oracle Database, Panorama, Unidied Audit Trail

---

After migrating DB instances to Exadata cloud service in Oracle's OCI cloud we noticed that selects from the view UNIFIED_AUDIT_TRAIL did not succeed in accepted time, even if they were quite simple.

Looking at the execution plan shows that nearly the whole excution time is spent on full table scan on table X$UNIFIED_AUDIT_TRAIL.

A click in the column "Waits" in that line shows the wait events for that execution plan line that have been recorded by ASH.

Mostly X$-tables will present an SQL interface for Oracle's internal memory structures. In this case the wait event 'Disk file operations I/O' let the X$UNIFIED_AUDIT_TRAIL table look like a wrapper for file structures on disk.

Trying to explain what happened

Some blog posts and a note in the documentation gave the needed background info.

Note:1. When the database is writeable, audit records are written to the unified audit trail. If the database is not writable (typically occurs when the database is closed or is read-only as in Oracle Data GuardADG), the Oracle Database writes audit records to external operating system spillover .BIN files in the $ORACLE_BASE/audit/$ORACLE_SID directory. The audit data present in the .BIN files is also surfaced in the UNIFIED_AUDIT_TRAIL data dictionary view.

The view UNIFIED_AUDIT_TRAIL is fed from two sources:

 - The table audsys.AUD$UNIFIED contains the audit records created when the DB is writable

 - The table sys.X$UNIFIED_AUDIT_TRAIL shows the audit records in file system created when the DB is not writable. The view GV$UNIFIED_AUDIT_TRAIL provides access on this source across RAC instances.

Our DB was cloned from a standby instance which had a lot of unified audit policy actions and had been used by lots of read/only connections.

So several millions of unified audit records have been stored in file system. This slowed down access by view UNIFIED_AUDIT_TRAIL up to unusability.

One-off solution in our case was to purge the unified audit trail by DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL.

The investigation has been done using the free analysis tool Panorama (https://github.com/rammpeter/panorama).
