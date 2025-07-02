-- Create AWR-Snapshots in instance for tests
prompt Creating AWR snapshots. May last at least 5 minutes!

SET SERVEROUTPUT ON;

DECLARE
  Dummy     NUMBER;
  PDB_Name  VARCHAR2(30);
  Is_PDB    NUMBER;

  PROCEDURE Create_AWR_Snapshots(pdb_name IN VARCHAR2) IS
  BEGIN
    -- Ensure that snapshots are recorded only once a day and are not deleted in the next 10 years
    dbms_workload_repository.modify_snapshot_settings (interval => 1440, retention => 1440*365*10);

    -- Ensure that first snapshot ends more than 60 seconds after begin
    FOR i IN 1..5 LOOP
      DBMS_LOCK.SLEEP(121);  -- Ensure next snapshot is in another minute
      dbms_workload_repository.create_snapshot;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('DBA_Hist_Snapshot-Content for PDB='||pdb_name);
    FOR REC IN (SELECT DBID, Snap_ID, Instance_Number, TO_CHAR(Begin_Interval_Time, 'DD.MM.YYYY HH24:MI:SS') Begin_Interval_Time, Con_ID
                FROM DBA_Hist_Snapshot
                ORDER BY Snap_ID DESC
               ) LOOP
      DBMS_OUTPUT.PUT_LINE('DBID='||REC.DBID||', Snap_ID='||REC.Snap_ID||', Instance_Number='||REC.Instance_Number||
                           ', Begin_Interval_Time='||REC.Begin_Interval_Time||', Con_ID='||REC.Con_ID);
    END LOOP;
  END Create_AWR_Snapshots;

BEGIN
  Is_PDB := 0;                                                                  -- is not a PDB
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) from v$pdbs' INTO Dummy;
    IF Dummy > 0 THEN
      Is_PDB := 1;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  IF Is_PDB =0 THEN
    Create_AWR_Snapshots('Non-PDB');
  ELSE
    -- Assuming there is only one user container
    SELECT Name INTO PDB_Name FROM v$Containers WHERE Name NOT IN ('CDB$ROOT', 'PDB$SEED');

    EXECUTE IMMEDIATE 'ALTER SESSION SET container = CDB$ROOT';  -- we are just in this container after sqlplus / as sysdba
    Create_AWR_Snapshots('CDB$ROOT');
    EXECUTE IMMEDIATE 'ALTER SESSION SET container = '||PDB_Name;
    Create_AWR_Snapshots(PDB_Name);
    EXECUTE IMMEDIATE 'ALTER SESSION SET container = CDB$ROOT';  -- restore to CDB$ROOT
  END IF;
END;
/