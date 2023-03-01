module PanoramaSampler::PackagePanoramaSamplerSnapshot
  # PL/SQL-Package for snapshot creation
  # panorama_owner is replaced by real schema owner
  def panorama_sampler_snapshot_spec
    "
CREATE OR REPLACE PACKAGE panorama_owner.Panorama_Sampler_Snapshot IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Do_Snapshot(p_Snap_ID                     IN NUMBER,
                        p_Instance                    IN NUMBER,
                        p_DBID                        IN NUMBER,
                        p_Con_ID                      IN NUMBER,
                        p_Begin_Interval_Time         IN DATE,
                        p_Snapshot_Cycle              IN NUMBER,
                        p_Snapshot_Retention          IN NUMBER,
                        p_SQL_Min_No_of_Execs         IN NUMBER,
                        p_SQL_Min_Runtime_MilliSecs   IN NUMBER,
                        p_ash_1sec_sample_keep_hours  IN NUMBER
                      );
-- TODO: Remove
END Panorama_Sampler_Snapshot;
    "


  end

  def panorama_sampler_snapshot_code
    "
  PROCEDURE Move_ASH_To_Snapshot_Table(p_Snap_ID                      IN NUMBER,
                                       p_DBID                         IN NUMBER,
                                       p_Instance                     IN NUMBER,
                                       p_ash_1sec_sample_keep_hours   IN NUMBER
                                      ) IS
    v_current_max_ash_sample_id   NUMBER;
    v_last_snap_max_ash_sample_id NUMBER;
  BEGIN
    -- Get the maximum Sample_ID to move and remember this value for the next snapshot
    SELECT NVL(MAX(Sample_ID), 0) INTO v_current_max_ash_sample_id FROM panorama_owner.Internal_V$Active_Sess_History WHERE Instance_Number = p_Instance;

    -- There is only one or no record in result of this SQL, MAX(... catches no_record_found
    SELECT MAX(last_snap_max_ash_sample_id) INTO v_last_snap_max_ash_sample_id FROM panorama_owner.Panorama_ASH_Counter WHERE Instance_Number = p_Instance;
    IF v_last_snap_max_ash_sample_id IS NULL THEN /* Backward compatibility */
      SELECT NVL(MAX(Sample_ID), 0) INTO v_last_snap_max_ash_sample_id FROM panorama_owner.Internal_Active_Sess_History WHERE Instance_Number = p_Instance;
    END IF;

    -- Rember the current value for next snapshot
    UPDATE panorama_owner.Panorama_ASH_Counter SET last_snap_max_ash_sample_id = v_current_max_ash_sample_id WHERE Instance_Number = p_Instance;

    INSERT INTO panorama_owner.Internal_Active_Sess_History (
      Snap_ID, DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Serial#, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
      SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
      SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
      QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID, SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
      Session_State, Time_Waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
      Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
      IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
      IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
      IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
      IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
      REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program, Module, Action, Client_ID, Machine, Port, ECID, DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER,
      TM_Delta_Time, TM_DELTA_CPU_TIME, TM_DELTA_DB_TIME, Delta_Time, DELTA_READ_IO_REQUESTS, DELTA_WRITE_IO_REQUESTS, DELTA_READ_IO_BYTES,
      DELTA_WRITE_IO_BYTES, DELTA_INTERCONNECT_IO_BYTES, PGA_Allocated, Temp_Space_Allocated,
      Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Serial#, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
             SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
             SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
             QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID, SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
             Session_State, Time_waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
             Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
             IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
             IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
             IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
             IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
             REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program, Module, Action, Client_ID, Machine, Port, ECID, DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER,
             TM_Delta_Time, TM_DELTA_CPU_TIME, TM_DELTA_DB_TIME, Delta_Time, DELTA_READ_IO_REQUESTS, DELTA_WRITE_IO_REQUESTS, DELTA_READ_IO_BYTES,
             DELTA_WRITE_IO_BYTES, DELTA_INTERCONNECT_IO_BYTES, PGA_Allocated, Temp_Space_Allocated,
             panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID
      FROM   panorama_owner.Internal_V$Active_Sess_History
      WHERE  Sample_ID       > v_last_snap_max_ash_sample_id
      AND    Sample_ID       <= v_current_max_ash_sample_id
      AND    Instance_Number = p_Instance
      AND    Preserve_10Secs = 'Y'
    ;

    DELETE FROM panorama_owner.Internal_V$Active_Sess_History
    WHERE Sample_ID <= v_current_max_ash_sample_id /* don't delete newer samples just created */
    AND   Sample_Time < SYSDATE-p_ash_1sec_sample_keep_hours/24 /* Consider the minimum keep time */
    AND   Instance_Number = p_Instance
    ;
    COMMIT;
  END Move_ASH_To_Snapshot_Table;

  PROCEDURE Snap_Datafile(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Datafile (DBID, FILE#, CREATION_CHANGE#, FILENAME, TS#, TSNAME, BLOCK_SIZE, CON_DBID, CON_ID
    ) SELECT p_DBID, d.File#, d.Creation_Change#, d.Name, d.ts#, ts.Name, d.Block_Size, d.Con_DBID, d.Con_ID
      FROM   (SELECT File#, Creation_Change#, Name, ts#, Block_Size,
                     #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
              FROM   v$Datafile
             ) d
      JOIN   v$Tablespace ts ON ts.ts# = d.ts# #{" AND ts.Con_ID = d.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      AND    NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_Datafile di WHERE di.DBID = p_DBID AND di.FILE# = d.FILE# AND di.CREATION_CHANGE# = d.CREATION_CHANGE# AND di.Con_DBID = d.Con_DBID)
    ;
    COMMIT;
  END Snap_Datafile;

  PROCEDURE Snap_DB_Cache_Advice(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_DB_Cache_Advice (SNAP_ID, DBID, INSTANCE_NUMBER, BPID, BUFFERS_FOR_ESTIMATE, NAME, BLOCK_SIZE, ADVICE_STATUS, SIZE_FOR_ESTIMATE,
    SIZE_FACTOR, PHYSICAL_READS, BASE_PHYSICAL_READS, ACTUAL_PHYSICAL_READS, ESTD_PHYSICAL_READ_TIME, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance,
             ID, BUFFERS_FOR_ESTIMATE, Name, Block_Size, Advice_Status, SIZE_FOR_ESTIMATE, SIZE_FACTOR, ESTD_PHYSICAL_READS,
             NULL, /* BASE_PHYSICAL_READS origin not yet known */
             NULL, /* ACTUAL_PHYSICAL_READS origin not yet known */
             #{PanoramaConnection.db_version >= '11.2' ? "ESTD_PHYSICAL_READ_TIME, " : "NULL, "}
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$DB_Cache_Advice
    ;
    COMMIT;
  END Snap_DB_cache_Advice;

  PROCEDURE Snap_Enqueue_Stat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Enqueue_Stat (SNAP_ID, DBID, INSTANCE_NUMBER, EQ_TYPE, REQ_REASON, TOTAL_REQ#, TOTAL_WAIT#, SUCC_REQ#, FAILED_REQ#,
                                       CUM_WAIT_TIME, EVENT#, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance,
             EQ_TYPE, REQ_REASON, TOTAL_REQ#, TOTAL_WAIT#, SUCC_REQ#, FAILED_REQ#, CUM_WAIT_TIME, EVENT#,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$Enqueue_Statistics
    ;
    COMMIT;
  END Snap_Enqueue_Stat;

  PROCEDURE Snap_FileStatXS(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Internal_FileStatXS (SNAP_ID, DBID, INSTANCE_NUMBER, FILE#, Creation_Change#,
                                     PHYRDS, PHYWRTS, SINGLEBLKRDS, READTIM, WRITETIM, SINGLEBLKRDTIM, PHYBLKRD, PHYBLKWRT, WAIT_COUNT, TIME,
                                     OPTIMIZED_PHYBLKRD, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, f.File#, d.Creation_Change#, f.PHYRDS, f.PHYWRTS, f.SINGLEBLKRDS, f.READTIM, f.WRITETIM, f.SINGLEBLKRDTIM, f.PHYBLKRD, f.PHYBLKWRT, NULL /* WAIT_COUNT */, NULL /* TIME */,
             f.OPTIMIZED_PHYBLKRD,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(f.Con_ID), f.Con_ID" : "p_DBID, 0"}
      FROM   v$FileStat f
      JOIN   v$Datafile d ON d.File# = f.File# #{ " AND d.Con_ID = f.Con_ID" if PanoramaConnection.db_version >= '12.1'}
    ;
    COMMIT;
  END Snap_FileStatXS;

  PROCEDURE Snap_IOStat_Detail(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_IOStat_Detail (SNAP_ID, DBID, INSTANCE_NUMBER, FUNCTION_ID, FUNCTION_NAME, FILETYPE_ID, FILETYPE_NAME, SMALL_READ_MEGABYTES, SMALL_WRITE_MEGABYTES, LARGE_READ_MEGABYTES, LARGE_WRITE_MEGABYTES,
                                   SMALL_READ_REQS, SMALL_WRITE_REQS, LARGE_READ_REQS, LARGE_WRITE_REQS, NUMBER_OF_WAITS, WAIT_TIME, CON_DBID, CON_ID
    ) SELECT p_SNAP_ID, p_DBID, p_INSTANCE, FUNCTION_ID, FUNCTION_NAME, FILETYPE_ID, FILETYPE_NAME, SMALL_READ_MEGABYTES, SMALL_WRITE_MEGABYTES, LARGE_READ_MEGABYTES, LARGE_WRITE_MEGABYTES,
             SMALL_READ_REQS, SMALL_WRITE_REQS, LARGE_READ_REQS, LARGE_WRITE_REQS, NUMBER_OF_WAITS, WAIT_TIME,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$IOStat_Function_Detail
    ;
    COMMIT;
  END Snap_IOStat_Detail;

  PROCEDURE Snap_IOStat_Filetype(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_IOStat_Filetype (SNAP_ID, DBID, INSTANCE_NUMBER, FILETYPE_ID, FILETYPE_NAME,
                                          SMALL_READ_MEGABYTES, SMALL_WRITE_MEGABYTES, LARGE_READ_MEGABYTES, LARGE_WRITE_MEGABYTES,
                                          SMALL_READ_REQS, SMALL_WRITE_REQS, SMALL_SYNC_READ_REQS, LARGE_READ_REQS, LARGE_WRITE_REQS,
                                          SMALL_READ_SERVICETIME, SMALL_WRITE_SERVICETIME, SMALL_SYNC_READ_LATENCY, LARGE_READ_SERVICETIME, LARGE_WRITE_SERVICETIME,
                                          RETRIES_ON_ERROR, CON_DBID, CON_ID
    ) SELECT p_SNAP_ID, p_DBID, p_INSTANCE, FILETYPE_ID, MIN(FILETYPE_NAME),
             SUM(SMALL_READ_MEGABYTES), SUM(SMALL_WRITE_MEGABYTES), SUM(LARGE_READ_MEGABYTES), SUM(LARGE_WRITE_MEGABYTES),
             SUM(SMALL_READ_REQS), SUM(SMALL_WRITE_REQS), SUM(SMALL_SYNC_READ_REQS), SUM(LARGE_READ_REQS), SUM(LARGE_WRITE_REQS),
             SUM(SMALL_READ_SERVICETIME), SUM(SMALL_WRITE_SERVICETIME), SUM(SMALL_SYNC_READ_LATENCY), SUM(LARGE_READ_SERVICETIME), SUM(LARGE_WRITE_SERVICETIME),
             SUM(RETRIES_ON_ERROR),
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0 Con_ID"}
      FROM   V$IOSTAT_FILE
      GROUP BY FILETYPE_ID#{", Con_ID" if PanoramaConnection.db_version >= '12.1'}
    ;
    COMMIT;
  END Snap_IOStat_Filetype;

  PROCEDURE Snap_Latch(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Latch (SNAP_ID, DBID, INSTANCE_NUMBER, LATCH_HASH, LATCH_NAME, LEVEL#, GETS, MISSES, SLEEPS, IMMEDIATE_GETS, IMMEDIATE_MISSES,
                                SPIN_GETS, SLEEP1, SLEEP2, SLEEP3, SLEEP4, WAIT_TIME, CON_DBID, CON_ID
    )
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, HASH, NAME, LEVEL#, GETS, MISSES, SLEEPS, IMMEDIATE_GETS, IMMEDIATE_MISSES,
           SPIN_GETS, SLEEP1, SLEEP2, SLEEP3, SLEEP4, WAIT_TIME,
           #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
    FROM   v$Latch l
    ;
    COMMIT;
  END Snap_Latch;

  PROCEDURE Snap_Log(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Log (Snap_ID, DBID, Instance_Number, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time,
    Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$Log
    ;
    COMMIT;
  END Snap_Log;

  PROCEDURE Snap_Memory_Resize_Ops(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Begin_Interval_Time IN DATE) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Memory_Resize_Ops (SNAP_ID, DBID, INSTANCE_NUMBER, COMPONENT, OPER_TYPE, START_TIME, END_TIME, TARGET_SIZE,
                                            OPER_MODE, PARAMETER, INITIAL_SIZE, FINAL_SIZE, STATUS, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, COMPONENT, OPER_TYPE, START_TIME, MIN(END_TIME), TARGET_SIZE,
             MIN(OPER_MODE), MIN(PARAMETER), MIN(INITIAL_SIZE), MIN(FINAL_SIZE), MIN(STATUS),
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$Memory_Resize_Ops
      WHERE  End_Time >= p_Begin_Interval_Time  /* Resize ended in considered snapshot period */
      GROUP BY COMPONENT, OPER_TYPE, START_TIME, TARGET_SIZE#{", Con_ID" if PanoramaConnection.db_version >= '12.1'} /* eliminate possible duplicates */
    ;
    COMMIT;
  END Snap_Memory_Resize_Ops;

  PROCEDURE Snap_Metric_Name(p_DBID IN NUMBER) IS
  BEGIN
    /* Check for new group_names in AWR by select distinct group_id, group_name from AWR-pendant of Panorama_METRIC_NAME order by Group_ID; */
    INSERT INTO panorama_owner.Panorama_Metric_Name (DBID, GROUP_ID, GROUP_NAME, METRIC_ID, METRIC_NAME, METRIC_UNIT, CON_DBID, CON_ID
    ) SELECT p_DBID, Group_ID,
             CASE
              WHEN Group_ID = 0	THEN 'Event Metrics'
              WHEN Group_ID = 1	THEN 'Event Class Metrics'
              WHEN Group_ID = 2	THEN 'System Metrics Long Duration'
              WHEN Group_ID = 3	THEN 'System Metrics Short Duration'
              WHEN Group_ID = 4	THEN 'Session Metrics Long Duration'
              WHEN Group_ID = 5	THEN 'Session Metrics Short Duration'
              WHEN Group_ID = 6	THEN 'Service Metrics'
              WHEN Group_ID = 7	THEN 'File Metrics Long Duration'
              WHEN Group_ID = 9	THEN 'Tablespace Metrics Long Duration'
              WHEN Group_ID = 10	THEN 'Service Metrics (Short)'
              WHEN Group_ID = 11	THEN 'I/O Stats by Function Metrics'
              WHEN Group_ID = 12	THEN 'Resource Manager Stats'
              WHEN Group_ID = 13	THEN 'WCR metrics'
              WHEN Group_ID = 14	THEN 'WLM PC Metrics'
             ELSE '[Unknown group_id]' END,
             METRIC_ID, METRIC_NAME, METRIC_UNIT, Con_DBID, Con_ID
      FROM   (SELECT DISTINCT Group_ID, Metric_ID, Metric_Name, Metric_Unit, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
              FROM   v$SysMetric_History
             )
      WHERE  (p_DBID, Group_ID, Metric_ID, Con_DBID) NOT IN (SELECT DBID, Group_ID, Metric_ID, Con_DBID FROM panorama_owner.Panorama_Metric_Name)
    ;
    COMMIT;
  END Snap_Metric_Name;

  PROCEDURE Snap_OSStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_OSStat_Name (DBID, Stat_ID, Stat_Name, CON_DBID
    ) SELECT p_DBID, OSStat_ID, Stat_Name, p_DBID
      FROM   v$OSStat
      WHERE (p_DBID, OSStat_ID) NOT IN (SELECT DBID, Stat_ID FROM panorama_owner.Panorama_OSStat_Name)
    ;

    INSERT INTO panorama_owner.Internal_OSStat (Snap_ID, DBID, Instance_Number, Stat_ID, Value, CON_DBID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, OSStat_ID, Value, p_DBID
      FROM   v$OSStat
    ;

    COMMIT;
  END Snap_OSStat;

  PROCEDURE Snap_Parameter(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Parameter (SNAP_ID, DBID, INSTANCE_NUMBER, PARAMETER_HASH, PARAMETER_NAME, VALUE, ISDEFAULT, ISMODIFIED, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, Hash, Name, Value, ISDEFAULT, ISMODIFIED,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$Parameter
    ;
    COMMIT;
  END Snap_Parameter;

  PROCEDURE Snap_PGAStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_PGAStat (SNAP_ID, DBID, INSTANCE_NUMBER, NAME, VALUE, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, Name, Value,
             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
      FROM   v$PGAStat
    ;
    COMMIT;
  END Snap_PGAStat;

  PROCEDURE Snap_Process_Mem_Summary(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Process_Mem_Summary (SNAP_ID, DBID, INSTANCE_NUMBER, CATEGORY, IS_INSTANCE_WIDE,
                                              NUM_PROCESSES, NON_ZERO_ALLOCS, USED_TOTAL, ALLOCATED_TOTAL, ALLOCATED_AVG,
                                              ALLOCATED_STDDEV, ALLOCATED_MAX, MAX_ALLOCATED_MAX, CON_ID, CON_DBID
    ) SELECT p.*, panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID)
      FROM   (SELECT p_Snap_ID, p_DBID, p_Instance, Category, DECODE(#{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}, 0, 1, 0),
                     COUNT(*), SUM(DECODE(Allocated, 0, 0, 1)), SUM(Used), SUM(Allocated), AVG(Allocated),
                     STDDEV(Allocated), MAX(Max_Allocated), SUM(Max_Allocated),
                     #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"} Con_ID
              FROM   v$Process_Memory
              GROUP BY Category, DECODE(#{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}, 0, 1, 0), #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
             ) p
    ;
    COMMIT;
  END Snap_Process_Mem_Summary;

  PROCEDURE Snap_Resource_Limit(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Resource_Limit (Snap_ID, DBID, Instance_Number, Resource_Name, Current_Utilization, Max_Utilization, Initial_Allocation, Limit_Value, Con_DBID, Con_ID)
    SELECT p_Snap_ID, p_DBID, p_Instance, Resource_Name, Current_Utilization, Max_Utilization, Initial_Allocation, Limit_Value,
           #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
    FROM   v$Resource_Limit
    ;
    COMMIT;
  END Snap_Resource_Limit;

  PROCEDURE Snap_Seg_Stat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_ID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Seg_Stat (SNAP_ID, DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#,
                                   LOGICAL_READS_TOTAL, LOGICAL_READS_DELTA,
                                   BUFFER_BUSY_WAITS_TOTAL, BUFFER_BUSY_WAITS_DELTA,
                                   DB_BLOCK_CHANGES_TOTAL, DB_BLOCK_CHANGES_DELTA,
                                   PHYSICAL_READS_TOTAL, PHYSICAL_READS_DELTA,
                                   PHYSICAL_WRITES_TOTAL, PHYSICAL_WRITES_DELTA,
                                   PHYSICAL_READS_DIRECT_TOTAL, PHYSICAL_READS_DIRECT_DELTA,
                                   PHYSICAL_WRITES_DIRECT_TOTAL, PHYSICAL_WRITES_DIRECT_DELTA,
                                   ITL_WAITS_TOTAL, ITL_WAITS_DELTA,
                                   ROW_LOCK_WAITS_TOTAL, ROW_LOCK_WAITS_DELTA,
                                   GC_CR_BLOCKS_SERVED_TOTAL, GC_CR_BLOCKS_SERVED_DELTA,
                                   GC_CU_BLOCKS_SERVED_TOTAL, GC_CU_BLOCKS_SERVED_DELTA,
                                   GC_BUFFER_BUSY_TOTAL, GC_BUFFER_BUSY_DELTA,
                                   GC_CR_BLOCKS_RECEIVED_TOTAL, GC_CR_BLOCKS_RECEIVED_DELTA,
                                   GC_CU_BLOCKS_RECEIVED_TOTAL, GC_CU_BLOCKS_RECEIVED_DELTA,
                                   SPACE_USED_TOTAL, SPACE_USED_DELTA,
                                   SPACE_ALLOCATED_TOTAL, SPACE_ALLOCATED_DELTA,
                                   TABLE_SCANS_TOTAL, TABLE_SCANS_DELTA,
                                   CHAIN_ROW_EXCESS_TOTAL, CHAIN_ROW_EXCESS_DELTA,
                                   PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA,
                                   PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA,
                                   OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA,
                                   CON_DBID, CON_ID
    )
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, TS#, OBJ#, DATAOBJ#, LOGICAL_READS_TOTAL, LOGICAL_READS_DELTA, BUFFER_BUSY_WAITS_TOTAL, BUFFER_BUSY_WAITS_DELTA,
           DB_BLOCK_CHANGES_TOTAL, DB_BLOCK_CHANGES_DELTA, PHYSICAL_READS_TOTAL, PHYSICAL_READS_DELTA, PHYSICAL_WRITES_TOTAL, PHYSICAL_WRITES_DELTA,
           PHYSICAL_READS_DIRECT_TOTAL, PHYSICAL_READS_DIRECT_DELTA, PHYSICAL_WRITES_DIRECT_TOTAL, PHYSICAL_WRITES_DIRECT_DELTA, ITL_WAITS_TOTAL, ITL_WAITS_DELTA,
           ROW_LOCK_WAITS_TOTAL, ROW_LOCK_WAITS_DELTA, GC_CR_BLOCKS_SERVED_TOTAL, GC_CR_BLOCKS_SERVED_DELTA, GC_CU_BLOCKS_SERVED_TOTAL, GC_CU_BLOCKS_SERVED_DELTA,
           GC_BUFFER_BUSY_TOTAL, GC_BUFFER_BUSY_DELTA, GC_CR_BLOCKS_RECEIVED_TOTAL, GC_CR_BLOCKS_RECEIVED_DELTA, GC_CU_BLOCKS_RECEIVED_TOTAL, GC_CU_BLOCKS_RECEIVED_DELTA,
           SPACE_USED_TOTAL, SPACE_USED_DELTA, SPACE_ALLOCATED_TOTAL, SPACE_ALLOCATED_DELTA, TABLE_SCANS_TOTAL, TABLE_SCANS_DELTA, CHAIN_ROW_EXCESS_TOTAL, CHAIN_ROW_EXCESS_DELTA,
           PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA, PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA,
           OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA, panorama_owner.Con_DBID_From_Con_ID.Get(p_Con_ID), p_Con_ID
    FROM   (
            SELECT vs.TS#, vs.OBJ#, vs.DATAOBJ#, s.DBID Prev_DBID,
                   vs.LOGICAL_READS_TOTAL,            vs.LOGICAL_READS_TOTAL            - NVL(s.LOGICAL_READS_TOTAL,            vs.LOGICAL_READS_TOTAL)             LOGICAL_READS_DELTA,
                   vs.BUFFER_BUSY_WAITS_TOTAL,        vs.BUFFER_BUSY_WAITS_TOTAL        - NVL(s.BUFFER_BUSY_WAITS_TOTAL,        vs.BUFFER_BUSY_WAITS_TOTAL)         BUFFER_BUSY_WAITS_DELTA,
                   vs.DB_BLOCK_CHANGES_TOTAL,         vs.DB_BLOCK_CHANGES_TOTAL         - NVL(s.DB_BLOCK_CHANGES_TOTAL,         vs.DB_BLOCK_CHANGES_TOTAL)          DB_BLOCK_CHANGES_DELTA,
                   vs.PHYSICAL_READS_TOTAL,           vs.PHYSICAL_READS_TOTAL           - NVL(s.PHYSICAL_READS_TOTAL,           vs.PHYSICAL_READS_TOTAL)            PHYSICAL_READS_DELTA,
                   vs.PHYSICAL_WRITES_TOTAL,          vs.PHYSICAL_WRITES_TOTAL          - NVL(s.PHYSICAL_WRITES_TOTAL,          vs.PHYSICAL_WRITES_TOTAL)           PHYSICAL_WRITES_DELTA,
                   vs.PHYSICAL_READS_DIRECT_TOTAL,    vs.PHYSICAL_READS_DIRECT_TOTAL    - NVL(s.PHYSICAL_READS_DIRECT_TOTAL,    vs.PHYSICAL_READS_DIRECT_TOTAL)     PHYSICAL_READS_DIRECT_DELTA,
                   vs.PHYSICAL_WRITES_DIRECT_TOTAL,   vs.PHYSICAL_WRITES_DIRECT_TOTAL   - NVL(s.PHYSICAL_WRITES_DIRECT_TOTAL,   vs.PHYSICAL_WRITES_DIRECT_TOTAL)    PHYSICAL_WRITES_DIRECT_DELTA,
                   vs.ITL_WAITS_TOTAL,                vs.ITL_WAITS_TOTAL                - NVL(s.ITL_WAITS_TOTAL,                vs.ITL_WAITS_TOTAL)                 ITL_WAITS_DELTA,
                   vs.ROW_LOCK_WAITS_TOTAL,           vs.ROW_LOCK_WAITS_TOTAL           - NVL(s.ROW_LOCK_WAITS_TOTAL,           vs.ROW_LOCK_WAITS_TOTAL)            ROW_LOCK_WAITS_DELTA,
                   vs.GC_CR_BLOCKS_SERVED_TOTAL,      vs.GC_CR_BLOCKS_SERVED_TOTAL      - NVL(s.GC_CR_BLOCKS_SERVED_TOTAL,      vs.GC_CR_BLOCKS_SERVED_TOTAL)       GC_CR_BLOCKS_SERVED_DELTA,
                   vs.GC_CU_BLOCKS_SERVED_TOTAL,      vs.GC_CU_BLOCKS_SERVED_TOTAL      - NVL(s.GC_CU_BLOCKS_SERVED_TOTAL,      vs.GC_CU_BLOCKS_SERVED_TOTAL)       GC_CU_BLOCKS_SERVED_DELTA,
                   vs.GC_BUFFER_BUSY_TOTAL,           vs.GC_BUFFER_BUSY_TOTAL           - NVL(s.GC_BUFFER_BUSY_TOTAL,           vs.GC_BUFFER_BUSY_TOTAL)            GC_BUFFER_BUSY_DELTA,
                   vs.GC_CR_BLOCKS_RECEIVED_TOTAL,    vs.GC_CR_BLOCKS_RECEIVED_TOTAL    - NVL(s.GC_CR_BLOCKS_RECEIVED_TOTAL,    vs.GC_CR_BLOCKS_RECEIVED_TOTAL)     GC_CR_BLOCKS_RECEIVED_DELTA,
                   vs.GC_CU_BLOCKS_RECEIVED_TOTAL,    vs.GC_CU_BLOCKS_RECEIVED_TOTAL    - NVL(s.GC_CU_BLOCKS_RECEIVED_TOTAL,    vs.GC_CU_BLOCKS_RECEIVED_TOTAL)     GC_CU_BLOCKS_RECEIVED_DELTA,
                   vs.SPACE_USED_TOTAL,               vs.SPACE_USED_TOTAL               - NVL(s.SPACE_USED_TOTAL,               vs.SPACE_USED_TOTAL)                SPACE_USED_DELTA,
                   vs.SPACE_ALLOCATED_TOTAL,          vs.SPACE_ALLOCATED_TOTAL          - NVL(s.SPACE_ALLOCATED_TOTAL,          vs.SPACE_ALLOCATED_TOTAL)           SPACE_ALLOCATED_DELTA,
                   vs.TABLE_SCANS_TOTAL,              vs.TABLE_SCANS_TOTAL              - NVL(s.TABLE_SCANS_TOTAL,              vs.TABLE_SCANS_TOTAL)               TABLE_SCANS_DELTA,
                   vs.CHAIN_ROW_EXCESS_TOTAL,         vs.CHAIN_ROW_EXCESS_TOTAL         - NVL(s.CHAIN_ROW_EXCESS_TOTAL,         vs.CHAIN_ROW_EXCESS_TOTAL)          CHAIN_ROW_EXCESS_DELTA,
                   vs.PHYSICAL_READ_REQUESTS_TOTAL,   vs.PHYSICAL_READ_REQUESTS_TOTAL   - NVL(s.PHYSICAL_READ_REQUESTS_TOTAL,   vs.PHYSICAL_READ_REQUESTS_TOTAL)    PHYSICAL_READ_REQUESTS_DELTA,
                   vs.PHYSICAL_WRITE_REQUESTS_TOTAL,  vs.PHYSICAL_WRITE_REQUESTS_TOTAL  - NVL(s.PHYSICAL_WRITE_REQUESTS_TOTAL,  vs.PHYSICAL_WRITE_REQUESTS_TOTAL)   PHYSICAL_WRITE_REQUESTS_DELTA,
                   vs.OPTIMIZED_PHYSICAL_READS_TOTAL, vs.OPTIMIZED_PHYSICAL_READS_TOTAL - NVL(s.OPTIMIZED_PHYSICAL_READS_TOTAL, vs.OPTIMIZED_PHYSICAL_READS_TOTAL)  OPTIMIZED_PHYSICAL_READS_DELTA
            FROM   (SELECT /*+ NO_MERGE */ TS#, Obj#, DataObj#,
                           SUM(CASE WHEN Statistic_Name = 'logical reads'               THEN Value END) LOGICAL_READS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'buffer busy waits'           THEN Value END) BUFFER_BUSY_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'db block changes'            THEN Value END) DB_BLOCK_CHANGES_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical reads'              THEN Value END) PHYSICAL_READS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical writes'             THEN Value END) PHYSICAL_WRITES_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical reads direct'       THEN Value END) PHYSICAL_READS_DIRECT_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical writes direct'      THEN Value END) PHYSICAL_WRITES_DIRECT_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'ITL waits'                   THEN Value END) ITL_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'row lock waits'              THEN Value END) ROW_LOCK_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc cr blocks served'         THEN Value END) GC_CR_BLOCKS_SERVED_TOTAL,    -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'gc current blocks served'    THEN Value END) GC_CU_BLOCKS_SERVED_TOTAL,    -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'gc buffer busy'              THEN Value END) GC_BUFFER_BUSY_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc cr blocks received'       THEN Value END) GC_CR_BLOCKS_RECEIVED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc current blocks received'  THEN Value END) GC_CU_BLOCKS_RECEIVED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'space used'                  THEN Value END) SPACE_USED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'space allocated'             THEN Value END) SPACE_ALLOCATED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'segment scans'               THEN Value END) TABLE_SCANS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'chain row excess'            THEN Value END) CHAIN_ROW_EXCESS_TOTAL,       -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'physical read requests'      THEN Value END) PHYSICAL_READ_REQUESTS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical write requests'     THEN Value END) PHYSICAL_WRITE_REQUESTS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'optimized physical reads'    THEN Value END) OPTIMIZED_PHYSICAL_READS_TOTAL
                    FROM   v$SegStat
                    GROUP BY TS#, Obj#, DataObj#
                   ) vs
            -- Last Snapshot for each object
            LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#, CON_DBID
                              FROM   panorama_owner.Panorama_Seg_Stat
                              GROUP BY DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#, CON_DBID
                             ) ms ON ms.DBID=p_DBID AND ms.Instance_Number=p_Instance AND ms.TS#=vs.TS# AND ms.Obj#=vs.Obj# AND ms.DataObj#=vs.DataObj# AND ms.Con_DBID=panorama_owner.Con_DBID_From_Con_ID.Get(p_Con_ID)
            -- Complete record of last snapshot for each object
            LEFT OUTER JOIN panorama_owner.Panorama_Seg_Stat s ON  s.DBID=p_DBID AND s.Snap_ID=ms.Max_Snap_ID AND s.Instance_Number=p_Instance AND s.TS#=vs.TS# AND s.DataObj#=vs.DataObj# AND s.Obj#=vs.Obj# AND s.Con_DBID=panorama_owner.Con_DBID_From_Con_ID.Get(p_Con_ID)
           )
    WHERE      Prev_DBID IS NULL /* No previous record exists */
            OR LOGICAL_READS_DELTA            > 0
            OR BUFFER_BUSY_WAITS_DELTA        > 0
            OR DB_BLOCK_CHANGES_DELTA         > 0
            OR PHYSICAL_READS_DELTA           > 0
            OR PHYSICAL_WRITES_DELTA          > 0
            OR PHYSICAL_READS_DIRECT_DELTA    > 0
            OR PHYSICAL_WRITES_DIRECT_DELTA   > 0
            OR ITL_WAITS_DELTA                > 0
            OR ROW_LOCK_WAITS_DELTA           > 0
            OR GC_CR_BLOCKS_SERVED_DELTA      > 0
            OR GC_CU_BLOCKS_SERVED_DELTA      > 0
            OR GC_BUFFER_BUSY_DELTA           > 0
            OR GC_CR_BLOCKS_RECEIVED_DELTA    > 0
            OR GC_CU_BLOCKS_RECEIVED_DELTA    > 0
            OR SPACE_USED_DELTA               > 0
            OR SPACE_ALLOCATED_DELTA          > 0
            OR TABLE_SCANS_DELTA              > 0
            OR CHAIN_ROW_EXCESS_DELTA         > 0
            OR PHYSICAL_READ_REQUESTS_DELTA   > 0
            OR PHYSICAL_WRITE_REQUESTS_DELTA  > 0
            OR OPTIMIZED_PHYSICAL_READS_DELTA > 0
    ;
    COMMIT;
  END Snap_Seg_Stat;


  PROCEDURE Snap_Service_Name(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Service_Name (DBID, Service_Name_Hash, Service_Name, Con_DBID, Con_ID)
    SELECT s.*
    FROM   (SELECT p_DBID, Name_Hash, Name, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0"}
            FROM   v$Services
           ) s
    WHERE  NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_Service_Name ps WHERE ps.DBID = p_DBID AND ps.Service_Name = s.Name AND ps.Con_DBID = s.Con_DBID)
    ;
    COMMIT;
  END Snap_Service_Name;

  PROCEDURE Snap_SGAStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    -- Grouped to ensure PK uniqueness because for CDB there are often duplicates for name='KKKI consumer', pool='shared pool' in Con_ID 0 and 1 with same Con_DBID
    INSERT INTO panorama_owner.Panorama_SGAStat (SNAP_ID, DBID, INSTANCE_NUMBER, NAME, Pool, Bytes, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, Name, Pool, SUM(Bytes), #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(MAX(Con_ID)), MAX(Con_ID)" : "p_DBID, 0"}
      FROM   v$SGAStat
      GROUP BY Name, Pool
    ;
    COMMIT;
  END Snap_SGAStat;

  PROCEDURE Snap_SQLBind(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_SQLBind(
      SNAP_ID, DBID, INSTANCE_NUMBER, SQL_ID, NAME, POSITION, DUP_POSITION, DATATYPE, DATATYPE_STRING, CHARACTER_SID,
      PRECISION, SCALE, MAX_LENGTH, WAS_CAPTURED, LAST_CAPTURED, VALUE_STRING, VALUE_ANYDATA,
      CON_DBID, CON_ID
    )
    SELECT p_Snap_ID, p_DBID, p_Instance, b.SQL_ID, b.Name, b.Position, b.Dup_Position, b.DATATYPE, b.DATATYPE_STRING, b.CHARACTER_SID,
                   b.PRECISION, b.SCALE, b.MAX_LENGTH, b.WAS_CAPTURED, b.LAST_CAPTURED, b.VALUE_STRING, b.VALUE_ANYDATA,
                   b.Con_DBID, b.Con_ID
    FROM   (SELECT SQL_ID, Name, Position, Dup_Position, DATATYPE, DATATYPE_STRING, CHARACTER_SID,
                   PRECISION, SCALE, MAX_LENGTH, WAS_CAPTURED, LAST_CAPTURED, VALUE_STRING, VALUE_ANYDATA, Child_Number,
                   #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
            FROM   v$SQL_Bind_Capture b
           ) b
    -- Select only the plan of last captured child with that SQL_ID
    JOIN   (SELECT /*+ NO_MERGE */ SQL_ID, MAX(Child_Number) KEEP (DENSE_RANK LAST ORDER BY Last_Captured) Max_Child_Number
            FROM   v$SQL_Bind_Capture
            GROUP BY SQL_ID
           ) bm ON bm.SQL_ID = b.SQL_ID AND bm.Max_Child_Number = b.Child_Number
    WHERE  EXISTS (SELECT 1 FROM panorama_owner.Panorama_SQLStat ss WHERE ss.DBID = p_DBID AND ss.Snap_ID = p_Snap_ID AND ss.SQL_ID = b.SQL_ID AND ss.Con_DBID = b.Con_DBID) -- Only for SQLs recorded in Panorama_SQLStat in same snapshot
    ;
    COMMIT;
  END Snap_SQLBind;

  -- call before dependent statistics like text, binds etc.
  PROCEDURE Snap_SQLStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Begin_Interval_Time IN DATE, p_SQL_Min_No_of_Execs IN NUMBER, p_SQL_Min_Runtime_MilliSecs IN NUMBER) IS
  BEGIN
    -- Child cursors created in this snapshot period should count full in delta because they are not counted in previous snapshot's total values
    -- Child cursors created in former snapshots shoud only count with the difference new total - old total, but not smaller than 0
    INSERT INTO panorama_owner.Panorama_SQLStat (Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, OPTIMIZER_COST, OPTIMIZER_MODE, OPTIMIZER_ENV_HASH_VALUE, SHARABLE_MEM,
        LOADED_VERSIONS, VERSION_COUNT, MODULE, ACTION, SQL_PROFILE, FORCE_MATCHING_SIGNATURE, PARSING_SCHEMA_ID, PARSING_SCHEMA_NAME, PARSING_USER_ID,
        FETCHES_TOTAL, FETCHES_DELTA, END_OF_FETCH_COUNT_TOTAL, END_OF_FETCH_COUNT_DELTA, SORTS_TOTAL, SORTS_DELTA, EXECUTIONS_TOTAL, EXECUTIONS_DELTA,
        PX_SERVERS_EXECS_TOTAL, PX_SERVERS_EXECS_DELTA, LOADS_TOTAL, LOADS_DELTA, INVALIDATIONS_TOTAL, INVALIDATIONS_DELTA, PARSE_CALLS_TOTAL, PARSE_CALLS_DELTA,
        DISK_READS_TOTAL, DISK_READS_DELTA, BUFFER_GETS_TOTAL, BUFFER_GETS_DELTA, ROWS_PROCESSED_TOTAL, ROWS_PROCESSED_DELTA, CPU_TIME_TOTAL, CPU_TIME_DELTA,
        ELAPSED_TIME_TOTAL, ELAPSED_TIME_DELTA, IOWAIT_TOTAL, IOWAIT_DELTA, CLWAIT_TOTAL, CLWAIT_DELTA, APWAIT_TOTAL, APWAIT_DELTA, CCWAIT_TOTAL, CCWAIT_DELTA,
        DIRECT_WRITES_TOTAL, DIRECT_WRITES_DELTA, PLSEXEC_TIME_TOTAL, PLSEXEC_TIME_DELTA, JAVEXEC_TIME_TOTAL, JAVEXEC_TIME_DELTA,
        #{"IO_OFFLOAD_ELIG_BYTES_TOTAL, IO_OFFLOAD_ELIG_BYTES_DELTA," if PanoramaConnection.db_version >= '12.1'}
        #{"IO_INTERCONNECT_BYTES_TOTAL, IO_INTERCONNECT_BYTES_DELTA," if PanoramaConnection.db_version >= '12.1'}
        PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA, PHYSICAL_READ_BYTES_TOTAL, PHYSICAL_READ_BYTES_DELTA,
        PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA, PHYSICAL_WRITE_BYTES_TOTAL, PHYSICAL_WRITE_BYTES_DELTA,
        #{"OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA, "  if PanoramaConnection.db_version >= '12.1'}
        #{"CELL_UNCOMPRESSED_BYTES_TOTAL, CELL_UNCOMPRESSED_BYTES_DELTA, "    if PanoramaConnection.db_version >= '12.1'}
        #{"IO_OFFLOAD_RETURN_BYTES_TOTAL, IO_OFFLOAD_RETURN_BYTES_DELTA, "    if PanoramaConnection.db_version >= '12.2'}
        BIND_DATA,
        Con_DBID, Con_ID
    ) SELECT  /*+ INDEX(p, PANORAMA_SQLSTAT_PK) PUSH_PRED(ms) OPT_PARAM('_push_join_predicate' 'TRUE')  */
              p_Snap_ID, p_DBID, p_Instance, s.SQL_ID, s.Plan_Hash_Value, s.OPTIMIZER_COST, s.OPTIMIZER_MODE, s.OPTIMIZER_ENV_HASH_VALUE, s.SHARABLE_MEM,
              s.LOADED_VERSIONS, s.VERSION_COUNT, s.MODULE, s.ACTION, s.SQL_PROFILE, s.FORCE_MATCHING_SIGNATURE, s.PARSING_SCHEMA_ID, s.PARSING_SCHEMA_NAME, s.PARSING_USER_ID,
              s.Fetches,                            GREATEST(NVL(s.Fetches_O                   , 0) - NVL(p.Fetches_Total,                  0), 0) + NVL(s.Fetches_N,                     0),
              s.End_Of_Fetch_Count,                 GREATEST(NVL(s.End_Of_Fetch_Count_O        , 0) - NVL(p.End_Of_Fetch_Count_Total,       0), 0) + NVL(s.End_Of_Fetch_Count_N,          0),
              s.Sorts,                              GREATEST(NVL(s.Sorts_O                     , 0) - NVL(p.Sorts_Total,                    0), 0) + NVL(s.Sorts_N,                       0),
              s.Executions,                         GREATEST(NVL(s.Executions_O                , 0) - NVL(p.Executions_Total,               0), 0) + NVL(s.Executions_N,                  0),
              s.PX_Servers_Execs,                   GREATEST(NVL(s.PX_Servers_Execs_O          , 0) - NVL(p.PX_Servers_Execs_Total,         0), 0) + NVL(s.PX_Servers_Execs_N,            0),
              s.Loads,                              GREATEST(NVL(s.Loads_O                     , 0) - NVL(p.Loads_Total,                    0), 0) + NVL(s.Loads_N,                       0),
              s.Invalidations,                      GREATEST(NVL(s.Invalidations_O             , 0) - NVL(p.Invalidations_Total,            0), 0) + NVL(s.Invalidations_N,               0),
              s.Parse_Calls,                        GREATEST(NVL(s.Parse_Calls_O               , 0) - NVL(p.Parse_Calls_Total,              0), 0) + NVL(s.Parse_Calls_N,                 0),
              s.Disk_Reads,                         GREATEST(NVL(s.Disk_Reads_O                , 0) - NVL(p.Disk_Reads_Total,               0), 0) + NVL(s.Disk_Reads_N,                  0),
              s.Buffer_Gets,                        GREATEST(NVL(s.Buffer_Gets_O               , 0) - NVL(p.Buffer_Gets_Total,              0), 0) + NVL(s.Buffer_Gets_N,                 0),
              s.Rows_Processed,                     GREATEST(NVL(s.Rows_Processed_O            , 0) - NVL(p.Rows_Processed_Total,           0), 0) + NVL(s.Rows_Processed_N,              0),
              s.CPU_Time,                           GREATEST(NVL(s.CPU_Time_O                  , 0) - NVL(p.CPU_Time_Total,                 0), 0) + NVL(s.CPU_Time_N,                    0),
              s.Elapsed_Time,                       GREATEST(NVL(s.Elapsed_Time_O              , 0) - NVL(p.Elapsed_Time_Total,             0), 0) + NVL(s.Elapsed_Time_N,                0),
              s.User_IO_Wait_Time,                  GREATEST(NVL(s.User_IO_Wait_Time_O         , 0) - NVL(p.IOWait_Total,                   0), 0) + NVL(s.User_IO_Wait_Time_N,           0),
              s.Cluster_Wait_Time,                  GREATEST(NVL(s.Cluster_Wait_Time_O         , 0) - NVL(p.CLWait_Total,                   0), 0) + NVL(s.Cluster_Wait_Time_N,           0),
              s.Application_Wait_Time,              GREATEST(NVL(s.Application_Wait_Time_O     , 0) - NVL(p.ApWait_Total,                   0), 0) + NVL(s.Application_Wait_Time_N,       0),
              s.Concurrency_Wait_Time,              GREATEST(NVL(s.Concurrency_Wait_Time_O     , 0) - NVL(p.CCWait_Total,                   0), 0) + NVL(s.Concurrency_Wait_Time_N,       0),
              s.Direct_Writes,                      GREATEST(NVL(s.Direct_Writes_O             , 0) - NVL(p.Direct_Writes_Total,            0), 0) + NVL(s.Direct_Writes_N,               0),
              s.PLSQL_Exec_Time,                    GREATEST(NVL(s.PLSQL_Exec_Time_O           , 0) - NVL(p.PLSExec_Time_Total,             0), 0) + NVL(s.PLSQL_Exec_Time_N,             0),
              s.Java_Exec_Time,                     GREATEST(NVL(s.Java_Exec_Time_O            , 0) - NVL(p.JavExec_Time_Total,             0), 0) + NVL(s.Java_Exec_Time_N,              0),
              #{"s.IO_OFFLOAD_ELIG_BYTES,           GREATEST(NVL(s.IO_OFFLOAD_ELIG_BYTES_O     , 0) - NVL(p.IO_OFFLOAD_ELIG_BYTES_Total,    0), 0) + NVL(s.IO_OFFLOAD_ELIG_BYTES_N,       0), " if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Interconnect_Bytes,           GREATEST(NVL(s.IO_Interconnect_Bytes_O     , 0) - NVL(p.IO_Interconnect_Bytes_Total,    0), 0) + NVL(s.IO_Interconnect_Bytes_N,       0), " if PanoramaConnection.db_version >= '12.1'}
              s.Physical_Read_Requests,             GREATEST(NVL(s.Physical_Read_Requests_O    , 0) - NVL(p.Physical_Read_Requests_Total,   0), 0) + NVL(s.Physical_Read_Requests_N,      0),
              s.Physical_Read_Bytes,                GREATEST(NVL(s.Physical_Read_Bytes_O       , 0) - NVL(p.Physical_Read_Bytes_Total,      0), 0) + NVL(s.Physical_Read_Bytes_N,         0),
              s.Physical_Write_Requests,            GREATEST(NVL(s.Physical_Write_Requests_O   , 0) - NVL(p.Physical_Write_Requests_Total,  0), 0) + NVL(s.Physical_Write_Requests_N,     0),
              s.Physical_Write_Bytes,               GREATEST(NVL(s.Physical_Write_Bytes_O      , 0) - NVL(p.Physical_Write_Bytes_Total,     0), 0) + NVL(s.Physical_Write_Bytes_N,        0),
              #{"s.Optimized_Physical_Reads,        GREATEST(NVL(s.Optimized_Physical_Reads_O  , 0) - NVL(p.Optimized_Physical_Reads_Total, 0), 0) + NVL(s.Optimized_Physical_Reads_N,    0), "  if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Cell_Uncompressed_Bytes,      GREATEST(NVL(s.IO_Cell_Uncompressed_Bytes_O, 0) - NVL(p.Cell_Uncompressed_Bytes_Total,  0), 0) + NVL(s.IO_Cell_Uncompressed_Bytes_N,  0), "  if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Offload_Return_Bytes,         GREATEST(NVL(s.IO_Offload_Return_Bytes_O   , 0) - NVL(p.IO_Offload_Return_Bytes_Total,  0), 0) + NVL(s.IO_Offload_Return_Bytes_N,     0), "  if PanoramaConnection.db_version >= '12.2'}
              s.Bind_Data,
              s.Con_DBID, s.Con_ID
      FROM   --v$SQLArea s
             (SELECT SQL_ID, Plan_Hash_Value, Con_DBID, Con_ID,  MAX(Optimizer_Cost) Optimizer_Cost, MAX(Optimizer_Mode) Optimizer_Mode, MAX(Optimizer_Env_Hash_Value) Optimizer_Env_Hash_Value,
                     SUM(SHARABLE_MEM) SHARABLE_MEM, SUM(LOADED_VERSIONS) LOADED_VERSIONS, COUNT(*) VERSION_COUNT, MAX(Module) Module, MAX(Action) Action, MAX(SQL_PROFILE) SQL_PROFILE, MAX(FORCE_MATCHING_SIGNATURE) FORCE_MATCHING_SIGNATURE,
                     MAX(PARSING_SCHEMA_ID) PARSING_SCHEMA_ID, MAX(PARSING_SCHEMA_NAME) PARSING_SCHEMA_NAME, MAX(PARSING_USER_ID) PARSING_USER_ID,
                     SUM(Fetches) Fetches,                                            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Fetches END) Fetches_N,                                        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Fetches END) Fetches_O,
                     SUM(End_Of_Fetch_Count) End_Of_Fetch_Count,                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN End_Of_Fetch_Count END) End_Of_Fetch_Count_N,                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN End_Of_Fetch_Count END) End_Of_Fetch_Count_O,
                     SUM(Sorts) Sorts,                                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Sorts END) Sorts_N,                                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Sorts END) Sorts_O,
                     SUM(Executions) Executions,                                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Executions END) Executions_N,                                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Executions END) Executions_O,
                     SUM(PX_Servers_Executions) PX_Servers_Execs,                     SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN PX_Servers_Executions END) PX_Servers_Execs_N,                 SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN PX_Servers_Executions END) PX_Servers_Execs_O,
                     SUM(Loads) Loads,                                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Loads END) Loads_N,                                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Loads END) Loads_O,
                     SUM(Invalidations) Invalidations,                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Invalidations END) Invalidations_N,                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Executions END) Invalidations_O,
                     SUM(Parse_Calls) Parse_Calls,                                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Parse_Calls END) Parse_Calls_N,                                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Parse_Calls END) Parse_Calls_O,
                     SUM(Disk_Reads) Disk_Reads,                                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Disk_Reads END) Disk_Reads_N,                                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Disk_Reads END) Disk_Reads_O,
                     SUM(Buffer_Gets) Buffer_Gets,                                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Buffer_Gets END) Buffer_Gets_N,                                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Buffer_Gets END) Buffer_Gets_O,
                     SUM(Rows_Processed) Rows_Processed,                              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Rows_Processed END) Rows_Processed_N,                          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Rows_Processed END) Rows_Processed_O,
                     SUM(CPU_Time) CPU_Time,                                          SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN CPU_Time END) CPU_Time_N,                                      SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN CPU_Time END) CPU_Time_O,
                     SUM(Elapsed_Time) Elapsed_Time,                                  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Elapsed_Time END) Elapsed_Time_N,                              SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Elapsed_Time END) Elapsed_Time_O,
                     SUM(User_IO_Wait_Time) User_IO_Wait_Time,                        SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN User_IO_Wait_Time END) User_IO_Wait_Time_N,                    SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN User_IO_Wait_Time END) User_IO_Wait_Time_O,
                     SUM(Cluster_Wait_Time) Cluster_Wait_Time,                        SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Cluster_Wait_Time END) Cluster_Wait_Time_N,                    SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Cluster_Wait_Time END) Cluster_Wait_Time_O,
                     SUM(Application_Wait_Time) Application_Wait_Time,                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Application_Wait_Time END) Application_Wait_Time_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Application_Wait_Time END) Application_Wait_Time_O,
                     SUM(Concurrency_Wait_Time) Concurrency_Wait_Time,                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Concurrency_Wait_Time END) Concurrency_Wait_Time_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Concurrency_Wait_Time END) Concurrency_Wait_Time_O,
                     SUM(Direct_Writes) Direct_Writes,                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Direct_Writes END) Direct_Writes_N,                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Direct_Writes END) Direct_Writes_O,
                     SUM(PLSQL_Exec_Time) PLSQL_Exec_Time,                            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN PLSQL_Exec_Time END) PLSQL_Exec_Time_N,                        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN PLSQL_Exec_Time END) PLSQL_Exec_Time_O,
                     SUM(Java_Exec_Time) Java_Exec_Time,                              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Java_Exec_Time END) Java_Exec_Time_N,                          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Java_Exec_Time END) Java_Exec_Time_O,
                     #{"SUM(IO_CELL_OFFLOAD_ELIGIBLE_BYTES) IO_OFFLOAD_ELIG_BYTES,    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_CELL_OFFLOAD_ELIGIBLE_BYTES END) IO_OFFLOAD_ELIG_BYTES_N,   SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_CELL_OFFLOAD_ELIGIBLE_BYTES END) IO_OFFLOAD_ELIG_BYTES_O,
                        SUM(IO_Interconnect_Bytes) IO_Interconnect_Bytes,             SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Interconnect_Bytes END) IO_Interconnect_Bytes_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Interconnect_Bytes END) IO_Interconnect_Bytes_O," if PanoramaConnection.db_version >= '12.1'}
                     SUM(Physical_Read_Requests) Physical_Read_Requests,              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Read_Requests END) Physical_Read_Requests_N,          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Read_Requests END) Physical_Read_Requests_O,
                     SUM(Physical_Read_Bytes) Physical_Read_Bytes,                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Read_Bytes END) Physical_Read_Bytes_N,                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Read_Bytes END) Physical_Read_Bytes_O,
                     SUM(Physical_Write_Requests) Physical_Write_Requests,            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Write_Requests END) Physical_Write_Requests_N,        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Write_Requests END) Physical_Write_Requests_O,
                     SUM(Physical_Write_Bytes) Physical_Write_Bytes,                  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Write_Bytes END) Physical_Write_Bytes_N,              SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Write_Bytes END) Physical_Write_Bytes_O,
                     #{"SUM(Optimized_Phy_Read_Requests) Optimized_Physical_Reads,    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Optimized_Phy_Read_Requests END) Optimized_Physical_Reads_N,   SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Optimized_Phy_Read_Requests END) Optimized_Physical_Reads_O,
                        SUM(IO_Cell_Uncompressed_Bytes) IO_Cell_Uncompressed_Bytes,   SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Cell_Uncompressed_Bytes END) IO_Cell_Uncompressed_Bytes_N,  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Cell_Uncompressed_Bytes END) IO_Cell_Uncompressed_Bytes_O,"  if PanoramaConnection.db_version >= '12.1'}
                     #{"SUM(IO_Cell_Offload_Returned_Bytes) IO_Offload_Return_Bytes,  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Cell_Offload_Returned_Bytes END) IO_Offload_Return_Bytes_N, SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Cell_Offload_Returned_Bytes END) IO_Offload_Return_Bytes_O,"  if PanoramaConnection.db_version >= '12.2'}
                     MAX(Bind_Data) Bind_Data
              FROM   (SELECT v.*, TO_DATE(Last_Load_time, 'YYYY-MM-DD/HH24:MI:SS') dLast_Load_Time,
                             #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID" : "p_DBID Con_DBID, 0 Con_ID" }
                      FROM   v$SQL v
                     )
              CROSS JOIN (SELECT p_Begin_Interval_Time Begin FROM DUAL) i
              GROUP BY SQL_ID, Plan_Hash_Value, Con_DBID, Con_ID
              HAVING MAX(Last_Active_time) > MAX(i.Begin)  -- Count all childs if one child is active in period
             ) s
      LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                        FROM   panorama_owner.Panorama_SQLStat
                        GROUP BY DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                       ) ms ON ms.DBID=p_DBID AND ms.Instance_Number=p_Instance AND ms.SQL_ID=s.SQL_ID AND ms.Plan_Hash_Value=s.Plan_Hash_Value AND ms.Con_DBID=s.Con_DBID
      LEFT OUTER JOIN panorama_owner.Panorama_SQLStat p ON  p.DBID=p_DBID AND p.Snap_ID=ms.Max_Snap_ID AND p.Instance_Number=p_Instance AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value AND p.Con_DBID=s.Con_DBID
      WHERE  (GREATEST(NVL(s.Executions_O   , 0) - NVL(p.Executions_Total,   0), 0) + NVL(s.Executions_N,   0))      >= p_SQL_Min_No_of_Execs
      OR     (GREATEST(NVL(s.Elapsed_Time_O , 0) - NVL(p.Elapsed_Time_Total, 0), 0) + NVL(s.Elapsed_Time_N, 0))/1000 >= p_SQL_Min_Runtime_MilliSecs
    ;
    COMMIT;
  END Snap_SQLStat;

  PROCEDURE Snap_SQL_Plan(p_Snap_ID IN NUMBER, p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_SQL_Plan (
      DBID, SQL_ID, PLAN_HASH_VALUE, ID, OPERATION, OPTIONS, OBJECT_NODE, OBJECT#, OBJECT_OWNER, OBJECT_NAME, OBJECT_ALIAS, OBJECT_TYPE, OPTIMIZER,
      PARENT_ID, DEPTH, POSITION, SEARCH_COLUMNS, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID, OTHER,
      DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME,
      REMARKS, TIMESTAMP, OTHER_XML, CON_DBID, CON_ID
    )
    SELECT /*+ ORDERED */ p_DBID, p.SQL_ID, p.Plan_Hash_Value, p.ID, p.OPERATION, p.OPTIONS, p.OBJECT_NODE, p.OBJECT#, p.OBJECT_OWNER, p.OBJECT_NAME, p.OBJECT_ALIAS, p.OBJECT_TYPE, p.OPTIMIZER,
           p.PARENT_ID, p.DEPTH, p.POSITION, p.SEARCH_COLUMNS, p.COST, p.CARDINALITY, p.BYTES, p.OTHER_TAG, p.PARTITION_START, p.PARTITION_STOP, p.PARTITION_ID, p.OTHER,
           p.DISTRIBUTION, p.CPU_COST, p.IO_COST, p.TEMP_SPACE, p.ACCESS_PREDICATES, p.FILTER_PREDICATES, NULL /* p.PROJECTION also not sampled in AWR because of large size */, p.TIME, p.QBLOCK_NAME,
           p.REMARKS, p.TIMESTAMP, p.OTHER_XML, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(p.Con_ID) Con_DBID, p.Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
    FROM   (SELECT ip.*,
                   MAX(CHILD_NUMBER) KEEP (DENSE_RANK LAST ORDER BY TIMESTAMP) OVER (PARTITION BY SQL_ID, PLAN_HASH_VALUE) MAX_CHILD_NUMBER
            FROM   v$SQL_Plan ip
           ) p
    /* join PANORAMA_SQL_PLAN and Panorama_SQLStat with Con_ID instead of PK attribute Con_DBID to avoid multiple calculation by Con_DBID_From_Con_ID */
    LEFT OUTER JOIN panorama_owner.PANORAMA_SQL_PLAN e on e.DBID = p_DBID AND e.SQL_ID = p.SQL_ID AND e.Plan_Hash_Value = p.Plan_Hash_Value AND e.ID = p.ID AND e.Con_ID = #{PanoramaConnection.db_version >= '12.1' ? "p.Con_ID" : "0"}
    WHERE  p.Max_Child_Number = p.Child_Number /* Select only the plan of last parsed child with that plan_hash_value */
    AND    e.DBID IS NULL   -- New records does not already exist in table
    /* get plans only for SQLs recorded in Panorama_SQLStat in same snapshot */
    AND    EXISTS (SELECT 1 FROM panorama_owner.Panorama_SQLStat ss WHERE ss.DBID = p_DBID AND ss.Snap_ID = p_Snap_ID AND ss.SQL_ID = p.SQL_ID AND ss.Plan_Hash_Value = p.Plan_Hash_Value AND ss.Con_ID = #{PanoramaConnection.db_version >= '12.1' ? "p.Con_ID" : "0"})
    ;
    COMMIT;
  END Snap_SQL_Plan;

  PROCEDURE Snap_SQLText(p_Snap_ID IN NUMBER, p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_SQLText (DBID, SQL_ID, SQL_Text, Command_Type, Con_DBID, Con_ID)
    SELECT p_DBID, s.SQL_ID, s.SQL_FullText, s.Command_Type, s.Con_DBID, s.Con_ID
    FROM   (SELECT SQL_ID, SQL_FullText, Command_Type, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
            FROM   v$SQLArea
           ) s
    LEFT OUTER JOIN panorama_owner.Panorama_SQLText p ON p.DBID=p_DBID AND p.SQL_ID=s.SQL_ID AND p.Con_DBID=s.Con_DBID
    WHERE  p.SQL_ID IS NULL  -- SQLText does not already exist
    AND    EXISTS (SELECT 1 FROM panorama_owner.Panorama_SQLStat ss WHERE ss.DBID = p_DBID AND ss.Snap_ID = p_Snap_ID AND ss.SQL_ID = s.SQL_ID AND ss.Con_DBID = s.Con_DBID) -- Only for SQLs recorded in Panorama_SQLStat in same snapshot
    ;
    COMMIT;
  END Snap_SQLText;

  PROCEDURE Snap_StatName(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Internal_StatName(DBID, STAT_ID, Name, Con_DBID, Con_ID)
    SELECT p_DBID, Stat_ID, Name, p_DBID, 0 /* Con_ID is always 0 and Con_DBID = DBID */
    FROM   V$StatName n
    WHERE  n.Stat_ID NOT IN (SELECT Stat_ID FROM panorama_owner.Internal_StatName WHERE DBID = p_DBID AND Con_DBID = p_DBID)
    ;
    COMMIT;
  END Snap_StatName;

  PROCEDURE Snap_Sysmetric_History(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Internal_SysMetric_History (SNAP_ID, DBID, INSTANCE_NUMBER, BEGIN_TIME, END_TIME, INTSIZE, GROUP_ID,
                                            METRIC_ID, VALUE, CON_DBID, CON_ID)
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, BEGIN_TIME, END_TIME, INTSIZE_CSEC, GROUP_ID,
           METRIC_ID, VALUE, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(sm.Con_ID), sm.Con_ID" : "p_DBID, 0"}
      FROM   v$SysMetric_History sm
    JOIN   panorama_owner.Panorama_Snapshot ss ON ss.DBID = p_DBID AND ss.Snap_ID = p_Snap_ID AND ss.Instance_Number = p_Instance
    WHERE  sm.End_Time >= ss.Begin_Interval_Time
    AND    sm.End_Time < ss.End_Interval_Time
    ;
    COMMIT;
  END Snap_Sysmetric_History;

  PROCEDURE Snap_Sysmetric_Summary(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Internal_SysMetric_Summary (SNAP_ID, DBID, INSTANCE_NUMBER, BEGIN_TIME, END_TIME, INTSIZE, GROUP_ID,
                                            METRIC_ID, NUM_INTERVAL, MinVal, MaxVal, Average,
                                            STANDARD_DEVIATION, SUM_SQUARES,
                                            CON_DBID, CON_ID)
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, MIN(BEGIN_TIME), MAX(END_TIME), SUM(INTSIZE_CSEC), GROUP_ID,
           METRIC_ID, COUNT(*), MIN(Value), MAX(Value), AVG(Value),
           STDDEV(Value), SUM(POWER(Avg_Value-Value, 2)),
           panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID
    FROM   (SELECT sm.*, AVG(Value) OVER (PARTITION BY sm.Group_ID, sm.Metric_ID, sm.Con_ID) avg_value
            FROM   (SELECT sm.*#{PanoramaConnection.db_version < '12.1' ? ", 0 Con_ID" : ""}
                    FROM   v$SysMetric_History sm
                   ) sm
            JOIN   panorama_owner.Panorama_Snapshot ss ON ss.DBID = p_DBID AND ss.Snap_ID = p_Snap_ID AND ss.Instance_Number = p_Instance
            WHERE  sm.End_Time >= ss.Begin_Interval_Time
            AND    sm.End_Time < ss.End_Interval_Time
            AND    Group_ID = 2
           )
    GROUP BY Group_ID, Metric_ID, Con_ID
    ;
    COMMIT;
  END Snap_Sysmetric_Summary;

  PROCEDURE Snap_System_Event(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_System_Event(SNAP_ID, DBID, INSTANCE_NUMBER, EVENT_ID, EVENT_NAME, WAIT_CLASS_ID, WAIT_CLASS,
                                      TOTAL_WAITS, TOTAL_TIMEOUTS, TIME_WAITED_MICRO, TOTAL_WAITS_FG, TOTAL_TIMEOUTS_FG, TIME_WAITED_MICRO_FG,
                                      CON_DBID, CON_ID
                                     )
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, EVENT_ID, EVENT, WAIT_CLASS_ID, WAIT_CLASS,
           TOTAL_WAITS, TOTAL_TIMEOUTS, TIME_WAITED_MICRO, TOTAL_WAITS_FG, TOTAL_TIMEOUTS_FG, TIME_WAITED_MICRO_FG,
           #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
    FROM   V$System_Event
    ;
    COMMIT;
  END Snap_System_Event;

  PROCEDURE Snap_SysStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Internal_SysStat(SNAP_ID, DBID, INSTANCE_NUMBER, STAT_ID, VALUE, CON_DBID, CON_ID)
    SELECT p_Snap_ID, p_DBID, p_Instance, Stat_ID, Value, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID), Con_ID" : "p_DBID, 0"}
    FROM   V$SysStat
    ;
    COMMIT;
  END Snap_SysStat;

  PROCEDURE Snap_Tablespace(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Tablespace (DBID, TS#, TSNAME, CONTENTS, SEGMENT_SPACE_MANAGEMENT, EXTENT_MANAGEMENT, BLOCK_SIZE, CON_DBID, CON_ID
    ) SELECT p_DBID, d.TS#, d.NAME, t.CONTENTS, t.SEGMENT_SPACE_MANAGEMENT, t.EXTENT_MANAGEMENT, t.BLOCK_SIZE, d.Con_DBID, d.Con_ID
      FROM   (SELECT TS#, NAME,
                     #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
              FROM   v$Tablespace
             ) d
      JOIN   DBA_Tablespaces t ON t.Tablespace_Name = d.Name
      WHERE  NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_Tablespace di WHERE di.DBID = p_DBID AND di.TS# = d.TS# AND di.Con_DBID = d.Con_DBID)
    ;
    COMMIT;
  END Snap_Tablespace;

  PROCEDURE Snap_Tempfile(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Tempfile (DBID, FILE#, CREATION_CHANGE#, FILENAME, TS#, TSNAME, BLOCK_SIZE, CON_DBID, CON_ID
    ) SELECT p_DBID, d.File#, d.Creation_Change#, d.Name, d.TS#, ts.Name, d.Block_Size, d.Con_DBID, d.Con_ID
      FROM   (SELECT File#, Creation_Change#, Name, TS#, Block_Size,
                     #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
              FROM   v$Tempfile
             ) d
      JOIN   v$Tablespace ts ON ts.ts# = d.ts##{" AND ts.Con_ID = d.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      WHERE  NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_Tempfile di WHERE di.DBID = p_DBID AND di.FILE# = d.FILE# AND di.CREATION_CHANGE# = d.CREATION_CHANGE# AND di.Con_DBID = d.Con_DBID)
    ;
    COMMIT;
  END Snap_Tempfile;

  PROCEDURE Snap_TempStatXS(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_TempStatXS (SNAP_ID, DBID, INSTANCE_NUMBER, FILE#, Creation_Change#,
                                     PHYRDS, PHYWRTS, SINGLEBLKRDS, READTIM, WRITETIM, SINGLEBLKRDTIM, PHYBLKRD, PHYBLKWRT, WAIT_COUNT, TIME,
                                     CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, f.File#, d.Creation_Change#, f.PHYRDS, f.PHYWRTS, f.SINGLEBLKRDS, f.READTIM, f.WRITETIM, f.SINGLEBLKRDTIM, f.PHYBLKRD, f.PHYBLKWRT, NULL /* WAIT_COUNT */, NULL /* TIME */,
              #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(f.Con_ID), f.Con_ID" : "p_DBID, 0"}
      FROM   v$TempStat f
      JOIN   v$Tempfile d ON d.File# = f.File#
    ;
    COMMIT;
  END Snap_TempStatXS;

  PROCEDURE Snap_TopLevelCallName(p_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_TopLevelCall_Name (DBID, Top_Level_Call#, Top_Level_Call_Name, Con_DBID, Con_ID)
    SELECT s.*
    FROM   (SELECT p_DBID, Top_Level_Call#, Top_Level_Call_Name, #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0"}
            FROM   v$TopLevelCall
           ) s
    WHERE  NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_TopLevelCall_Name t WHERE t.DBID = p_DBID AND t.Top_Level_Call# = s.Top_Level_Call# AND t.Con_DBID = s.Con_DBID)
    ;
    COMMIT;
  END Snap_TopLevelCallName;

  PROCEDURE Snap_UndoStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_UndoStat(BEGIN_TIME, END_TIME, DBID, INSTANCE_NUMBER, SNAP_ID, UNDOTSN, UNDOBLKS, TXNCOUNT, MAXQUERYLEN, MAXQUERYSQLID, MAXCONCURRENCY, UNXPSTEALCNT,
                                  UNXPBLKRELCNT, UNXPBLKREUCNT, EXPSTEALCNT, EXPBLKRELCNT, EXPBLKREUCNT, SSOLDERRCNT, NOSPACEERRCNT, ACTIVEBLKS, UNEXPIREDBLKS, EXPIREDBLKS,
                                  TUNED_UNDORETENTION, CON_DBID, CON_ID)
    SELECT u.*
    FROM   (SELECT BEGIN_TIME, END_TIME, p_DBID, p_INSTANCE, p_SNAP_ID, UNDOTSN, UNDOBLKS, TXNCOUNT, MAXQUERYLEN, MAXQUERYID, MAXCONCURRENCY, UNXPSTEALCNT, UNXPBLKRELCNT,
                   UNXPBLKREUCNT, EXPSTEALCNT, EXPBLKRELCNT, EXPBLKREUCNT, SSOLDERRCNT, NOSPACEERRCNT, ACTIVEBLKS, UNEXPIREDBLKS, EXPIREDBLKS, TUNED_UNDORETENTION,
                   #{PanoramaConnection.db_version >= '12.1' ? "panorama_owner.Con_DBID_From_Con_ID.Get(Con_ID) Con_DBID, Con_ID" : "p_DBID Con_DBID, 0 Con_ID"}
            FROM   V$UndoStat
           ) u
    WHERE NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_UndoStat i WHERE i.BEGIN_TIME = u.Begin_Time AND i.END_TIME = u.End_time AND i.DBID = p_DBID AND i.INSTANCE_NUMBER = p_Instance AND i.CON_DBID = u.Con_DBID)
    AND   u.Begin_Time < (SELECT MAX(Begin_Time) FROM V$UndoStat) /* Newest record is dynamically cumulated until age of 10 minutes */
    ;
    COMMIT;
  END Snap_UndoStat;

  PROCEDURE Snap_WR_Control(p_DBID IN NUMBER, p_Snapshot_Cycle IN NUMBER, p_Snapshot_Retention IN NUMBER) IS
  BEGIN
    -- Create record if not exists
    INSERT INTO panorama_owner.Panorama_WR_Control (DBID, SNAP_INTERVAL, RETENTION, Con_ID)
    SELECT p_DBID, NUMTODSINTERVAL(p_Snapshot_Cycle, 'MINUTE'), NUMTODSINTERVAL(p_Snapshot_Retention, 'DAY'),
           #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
    FROM   v$Instance
    WHERE  NOT EXISTS (SELECT 1 FROM panorama_owner.Panorama_WR_Control WHERE DBID = p_DBID)
    ;

    UPDATE panorama_owner.Panorama_WR_Control SET SNAP_INTERVAL  = NUMTODSINTERVAL(p_Snapshot_Cycle,     'MINUTE'),
                                   RETENTION      = NUMTODSINTERVAL(p_Snapshot_Retention, 'DAY'),
                                   Con_ID = (SELECT  #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"} FROM   v$Instance)
    WHERE DBID = p_DBID
    ;
    COMMIT;
  END Snap_WR_Control;

  PROCEDURE Snap_Database_Instance(p_DBID IN NUMBER, p_Instance IN NUMBER) IS
  BEGIN
    INSERT INTO panorama_owner.Panorama_Database_Instance(DBID, Instance_Number, Startup_Time, Parallel, Version, DB_Name, Instance_Name,
                                                          Host_Name, Last_ASH_Sample_ID, Platform_Name, CDB, Edition, DB_Unique_Name,
                                                          Database_Role, CDB_Root_DBID, Startup_Time_TZ, CON_ID)
    SELECT p_DBID, p_Instance, i.Startup_Time, i.Parallel, i.Version, d.Name, i.Instance_Name,
           i.Host_Name, 0, d.Platform_Name,
           #{PanoramaConnection.db_version >= '12.1' ? "d.CDB" : "''"},
           #{PanoramaConnection.db_version >= '12.1' ? "i.Edition" : "''"},
           d.DB_Unique_Name,
           d.Database_Role, p_DBID, i.Startup_Time,
           #{PanoramaConnection.db_version >= '12.1' ? "i.Con_ID" : "0"}
    FROM   v$Instance i
    CROSS JOIN v$Database d
    WHERE  i.Instance_Number = p_Instance
    AND    NOT EXISTS (SELECT 1
                      FROM   panorama_owner.Panorama_Database_Instance t
                      WHERE  t.DBID = p_DBID AND t.Instance_Number = p_Instance AND t.Startup_Time = i.Startup_Time
                     )
    ;
    COMMIT;
  END Snap_Database_Instance;


  PROCEDURE Do_Snapshot(p_Snap_ID                     IN NUMBER,
                        p_Instance                    IN NUMBER,
                        p_DBID                        IN NUMBER,  /* DBID of container-DB */
                        p_Con_ID                      IN NUMBER,  /* Con-ID of calling PDB / Connection */
                        p_Begin_Interval_Time         IN DATE,
                        p_Snapshot_Cycle              IN NUMBER,
                        p_Snapshot_Retention          IN NUMBER,
                        p_SQL_Min_No_of_Execs         IN NUMBER,
                        p_SQL_Min_Runtime_MilliSecs   IN NUMBER,
                        p_ash_1sec_sample_keep_hours  IN NUMBER
                       ) IS
    ErrMsg  VARCHAR2(32000) := NULL;
  BEGIN
    CATCH_START Move_ASH_To_Snapshot_Table(p_Snap_ID,   p_DBID,     p_Instance, p_ash_1sec_sample_keep_hours); CATCH_END
    CATCH_START Snap_Datafile             (p_DBID); CATCH_END
    CATCH_START Snap_DB_cache_Advice      (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Enqueue_Stat         (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_FileStatXS           (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_IOStat_Detail        (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_IOStat_Filetype      (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Latch                (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Log                  (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Memory_Resize_Ops    (p_Snap_ID,   p_DBID,     p_Instance,   p_Begin_Interval_Time); CATCH_END
    CATCH_START Snap_Metric_Name          (p_DBID); CATCH_END
    CATCH_START Snap_Parameter            (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_OSStat               (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_PGAStat              (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Process_Mem_Summary  (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Resource_Limit       (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Seg_Stat             (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_ID); CATCH_END
    CATCH_START Snap_Service_Name         (p_DBID); CATCH_END
    CATCH_START Snap_SGAStat              (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    -- call Snap_SQLStat before any dependent statistic, because dependents record only for SQLs already in SQLStat
    CATCH_START Snap_SQLStat              (p_Snap_ID,   p_DBID,     p_Instance,   p_Begin_Interval_Time,     p_SQL_Min_No_of_Execs,      p_SQL_Min_Runtime_MilliSecs); CATCH_END
    CATCH_START Snap_SQLBind              (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_SQL_Plan             (p_Snap_ID,   p_DBID); CATCH_END
    CATCH_START Snap_SQLText              (p_Snap_ID,   p_DBID); CATCH_END
    CATCH_START Snap_StatName             (p_DBID); CATCH_END
    CATCH_START Snap_Sysmetric_History    (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Sysmetric_Summary    (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_System_Event         (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_SysStat              (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_Tablespace           (p_DBID); CATCH_END
    CATCH_START Snap_Tempfile             (p_DBID); CATCH_END
    CATCH_START Snap_TempStatXS           (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_TopLevelCallName     (p_DBID); CATCH_END
    CATCH_START Snap_UndoStat             (p_Snap_ID,   p_DBID,     p_Instance); CATCH_END
    CATCH_START Snap_WR_Control           (p_DBID,      p_Snapshot_Cycle, p_Snapshot_Retention); CATCH_END
    CATCH_START Snap_Database_Instance    (p_DBID,      p_Instance); CATCH_END

    IF ErrMsg IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20999, SUBSTR(ErrMsg, 1, 2048));
    END IF;
  END Do_Snapshot;
    "
  end

  def panorama_sampler_snapshot_body
    "
CREATE OR REPLACE PACKAGE BODY panorama_owner.Panorama_Sampler_Snapshot IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
#{panorama_sampler_snapshot_code}
END Panorama_Sampler_Snapshot;
    "
  end

end