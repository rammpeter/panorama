# Oracle-DB: Valid and enabled LOGON trigger does not fire at Exadata Cloud Service

Datum: 2025-04-01
URL: https://rammpeter.blogspot.com/2025/04/oracle-db-valid-and-enabled-logon.html
Labels: 

---

Question:

A simple LOGON trigger that works on several DBs does not work as expected in one environment.

The trigger code is:

CREATE OR REPLACE TRIGGER Test_Logon AFTER LOGON ON DATABASE
DECLARE
 Dummy NUMBER;
BEGIN
 SELECT COUNT(*) INTO DUmmy FROM User_Tables WHERE Table_Name = 'DB_TRIGGER_TEST';
 IF Dummy = 0 THEN
 -- Table created for owner of DB trigger
 EXECUTE IMMEDIATE 'CREATE TABLE DB_TRIGGER_TEST (TS DATE, Text VARCHAR2(1000))';
 END IF;
END;
/

The creation command succeeded without errors and the trigger exists and is enabled.

At next user logon the expectation is that either an exception occurs or the table DB_TRIGGER_TEST is created in the schema of the trigger owner.

But nothing happened at user logon, logon succeeds with no exception and no table DB_TRIGGER_TEST exists within the PDB.

Missing execution of trigger is independent from trigger creator. Tested with SYS and a privileged user.

Trigger creation was also tried with the DB-Vault owner, but this user was not allowed to create the trigger (ORA-01031: insufficient privileges).

The used environment is:

 - Oracle Exadata Database Service on Dedicated Infrastructure in OCI cloud

 - Database version 19.25

 - Database vault activated

Resolution of the case

The underscore parameter "_system_trig_enabled" controls if existing logon triggers will fire at logon or not.

This parameter was set to FALSE in the considered DB.

Many thanks to Sean Scott for the helpful advice.
