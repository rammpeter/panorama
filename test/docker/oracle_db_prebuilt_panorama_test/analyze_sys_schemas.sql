-- Analyze sys schemas
-- Peter Ramm, OSP Dresden 30.04.2019

DECLARE
  Dummy     NUMBER;
  v_UserName  VARCHAR2(30);
  PDB_Name  VARCHAR2(30);
  Is_PDB    NUMBER;

BEGIN
  Is_PDB := 0;                                                                  -- is not a PDB
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) from v$pdbs' INTO Dummy;
    IF Dummy > 0 THEN
      Is_PDB := 1;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;                                                      -- catch error for rel < 12.1
  END;

  IF Is_PDB =0 THEN
    DBMS_STATS.Gather_Schema_Stats('SYS');
  ELSE
    -- Assuming there is only one user container
    SELECT Name INTO PDB_Name FROM v$Containers WHERE Name NOT IN ('CDB$ROOT', 'PDB$SEED');

    EXECUTE IMMEDIATE 'ALTER SESSION SET container = CDB$ROOT';  -- we are just in this container after sqlplus / as sysdba
    DBMS_STATS.Gather_Schema_Stats('SYS');
    EXECUTE IMMEDIATE 'ALTER SESSION SET container = '||PDB_Name;
    DBMS_STATS.Gather_Schema_Stats('SYS');
  END IF;

END;
/