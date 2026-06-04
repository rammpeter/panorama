-- Create AWR-Snapshots in instance for tests
prompt Creating AWR snapshots. May last at least 5 minutes!

SET SERVEROUTPUT ON;

DECLARE
  Dummy              NUMBER;
  PDB_Name           VARCHAR2(30);
  Is_PDB             NUMBER;
  Current_Container  VARCHAR2(30);
  Original_Container VARCHAR2(30);

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

  PROCEDURE Switch_Container(target_name IN VARCHAR2) IS
  BEGIN
    IF target_name <> Current_Container THEN
      EXECUTE IMMEDIATE 'ALTER SESSION SET container = '||target_name;
      Current_Container := target_name;
    END IF;
  END Switch_Container;

  PROCEDURE Create_AWR_Snapshots_Safe(target_name IN VARCHAR2) IS
  BEGIN
    Switch_Container(target_name);
    Create_AWR_Snapshots(target_name);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Skipping AWR snapshots for container='||target_name||' because of '||SQLERRM);
  END Create_AWR_Snapshots_Safe;

BEGIN
  Current_Container  := SYS_CONTEXT('USERENV', 'CON_NAME');
  Original_Container := Current_Container;
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
    Create_AWR_Snapshots(Original_Container);
  ELSE
    -- Assuming there is only one user container
    SELECT Name INTO PDB_Name FROM v$Containers WHERE Name NOT IN ('CDB$ROOT', 'PDB$SEED');

    Create_AWR_Snapshots_Safe(Original_Container);
    IF Original_Container <> 'CDB$ROOT' THEN
      Create_AWR_Snapshots_Safe('CDB$ROOT');
    END IF;
    IF PDB_Name <> Original_Container THEN
      Create_AWR_Snapshots_Safe(PDB_Name);
    END IF;
    Switch_Container(Original_Container);                                       -- restore original container
  END IF;
END;
/