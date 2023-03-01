-- Create AWR-Snapshots in instance for tests
prompt Creating AWR snapshots. May last at least 5 minutes!
BEGIN
  -- Ensure that snapshots are recorded only once a day and are not deleted in the next 10 years
  dbms_workload_repository.modify_snapshot_settings (interval => 1440, retention => 1440*365*10);

  dbms_workload_repository.create_snapshot;
  FOR i IN 1..4 LOOP
    DBMS_LOCK.SLEEP(61);  -- Ensure next snapshot is in another minute
    dbms_workload_repository.create_snapshot;
  END LOOP;
END;
/

prompt DBA_Hist_Snapshot-Content

SELECT Snap_ID, Instance_Number, TO_CHAR(Begin_Interval_Time, 'DD.MM.YYYY HH24:MI:SS') Begin_Interval_Time FROM DBA_Hist_Snapshot;
