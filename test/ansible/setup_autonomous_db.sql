-- Setup Oracle allways free autonomous DB for Panorama tests
-- connect as 'admin'

purge dba_recyclebin;
alter profile DEFAULT limit password_life_time UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_VERIFY_FUNCTION NULL;

-- Disable SQL Tuning Advisor
EXEC DBMS_AUTO_TASK_ADMIN.DISABLE(client_name=>'sql tuning advisor', operation=>NULL, window_name=>NULL);

BEGIN
  DBMS_SQLTUNE.DROP_SQLSET( sqlset_name => 'SYS_AUTO_STS', sqlset_owner=>'SYS' );
END;
/

DECLARE
  PROCEDURE Create_User(P_Name VARCHAR2) IS
  BEGIN
    BEGIN
      EXECUTE IMMEDIATE 'DROP USER '||p_Name||' CASCADE';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -1918 THEN -- User does not exist
          RAISE;
      END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE User '||p_Name||' IDENTIFIED BY SimpePW9 PROFILE DEFAULT DEFAULT TABLESPACE DATA TEMPORARY TABLESPACE TEMP';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE, CREATE VIEW, SELECT ANY DICTIONARY, SELECT_CATALOG_ROLE, ANALYZE ANY, SELECT ANY TRANSACTION TO '||p_Name;
    EXECUTE IMMEDIATE 'GRANT SELECT ON V$DIAG_ALERT_EXT TO '||p_Name;
    EXECUTE IMMEDIATE 'GRANT READ ON SYS.DBMS_LOCK_ALLOCATED TO '||p_Name;
    EXECUTE IMMEDIATE 'GRANT READ ON gv$BH TO '||p_Name;
    EXECUTE IMMEDIATE 'ALTER USER '||p_Name||' QUOTA UNLIMITED ON DATA';
  END Create_User;
BEGIN
  Create_User('Panorama_Test');
  Create_User('Panorama_Test1');
  Create_User('Panorama_Test2');
  Create_User('Panorama_Test3');
  Create_User('Panorama_Test4');
END;
/