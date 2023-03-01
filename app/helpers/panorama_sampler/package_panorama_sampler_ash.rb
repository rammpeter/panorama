module PanoramaSampler::PackagePanoramaSamplerAsh
  # PL/SQL-Package for snapshot creation
  # panorama_owner is replaced by real schema owner
  def panorama_sampler_ash_spec
    "
CREATE OR REPLACE Package panorama_owner.Panorama_Sampler_ASH AS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  FUNCTION Get_Stat_ID(p_Name IN VARCHAR2) RETURN NUMBER;
  PROCEDURE Run_Sampler_Daemon(p_Instance_Number IN NUMBER, p_Next_Snapshot_Start_Seconds IN NUMBER);

END Panorama_Sampler_ASH;
    "
  end

  def panorama_sampler_ash_code
    "
  TYPE AshType IS RECORD (
    Sample_ID                 NUMBER,
    Sample_Time               TIMESTAMP(3),
    Session_ID                NUMBER,
    SESSION_SERIAL#           NUMBER,
    Session_Type              VARCHAR2(10),
    Flags                     NUMBER,
    User_ID                   NUMBER,
    SQL_ID                    VARCHAR2(13),
    Is_SQLID_Current          VARCHAR2(1),
    SQL_CHILD_NUMBER          NUMBER,
    SQL_OPCODE                NUMBER,
    SQL_OpName                VARCHAR2(64),
    FORCE_MATCHING_SIGNATURE  NUMBER,
    TOP_LEVEL_SQL_ID          VARCHAR2(13),
    TOP_LEVEL_SQL_OPCODE      NUMBER,
    SQL_PLAN_HASH_VALUE       NUMBER,
    SQL_PLAN_LINE_ID          NUMBER,
    SQL_PLAN_OPERATION        VARCHAR2(64),
    SQL_PLAN_OPTIONS          VARCHAR2(64),
    SQL_EXEC_ID               NUMBER,
    SQL_EXEC_START            DATE,
    PLSQL_ENTRY_OBJECT_ID     NUMBER,
    PLSQL_ENTRY_SUBPROGRAM_ID NUMBER,
    PLSQL_OBJECT_ID           NUMBER,
    PLSQL_SUBPROGRAM_ID       NUMBER,
    QC_INSTANCE_ID            NUMBER,
    QC_SESSION_ID             NUMBER,
    QC_SESSION_SERIAL#        NUMBER,
    PX_FLAGS                  NUMBER,
    EVENT                     VARCHAR2(64),
    EVENT_ID                  NUMBER,
    SEQ#                      NUMBER,
    P1TEXT                    VARCHAR2(64),
    P1                        NUMBER,
    P2TEXT                    VARCHAR2(64),
    P2                        NUMBER,
    P3TEXT                    VARCHAR2(64),
    P3                        NUMBER,
    WAIT_CLASS                VARCHAR2(64),
    Wait_Class_ID             NUMBER,
    Wait_Time                 NUMBER,
    SESSION_STATE             VARCHAR2(7),
    TIME_WAITED               NUMBER,
    BLOCKING_SESSION_STATUS   VARCHAR2(11),
    BLOCKING_SESSION          NUMBER,
    BLOCKING_SESSION_SERIAL#  NUMBER,
    BLOCKING_INST_ID          NUMBER,
    BLOCKING_HANGCHAIN_INFO   VARCHAR2(1),
    CURRENT_OBJ#              NUMBER,
    CURRENT_FILE#             NUMBER,
    CURRENT_Block#            NUMBER,
    CURRENT_Row#              NUMBER,
    TOP_LEVEL_CALL#           NUMBER,
    CONSUMER_GROUP_ID         NUMBER,
    XID                       RAW(8),
    REMOTE_INSTANCE#          NUMBER,
    TIME_MODEL                NUMBER,
    IN_CONNECTION_MGMT        VARCHAR2(1),
    IN_PARSE                  VARCHAR2(1),
    IN_HARD_PARSE             VARCHAR2(1),
    IN_SQL_EXECUTION          VARCHAR2(1),
    IN_PLSQL_EXECUTION        VARCHAR2(1),
    IN_PLSQL_RPC              VARCHAR2(1),
    IN_PLSQL_COMPILATION      VARCHAR2(1),
    IN_JAVA_EXECUTION         VARCHAR2(1),
    IN_BIND                   VARCHAR2(1),
    IN_CURSOR_CLOSE           VARCHAR2(1),
    IN_SEQUENCE_LOAD          VARCHAR2(1),
    IN_INMEMORY_QUERY         VARCHAR2(1),
    IN_INMEMORY_POPULATE      VARCHAR2(1),
    IN_INMEMORY_PREPOPULATE   VARCHAR2(1),
    IN_INMEMORY_REPOPULATE    VARCHAR2(1),
    IN_INMEMORY_TREPOPULATE   VARCHAR2(1),
    IN_TABLESPACE_ENCRYPTION  VARCHAR2(1),
    CAPTURE_OVERHEAD          VARCHAR2(1),
    REPLAY_OVERHEAD           VARCHAR2(1),
    IS_CAPTURED               VARCHAR2(1),
    IS_REPLAYED               VARCHAR2(1),
    SERVICE_HASH              NUMBER,
    PROGRAM                   VARCHAR2(64),
    Module                    VARCHAR2(64),
    Action                    VARCHAR2(64),
    Client_ID                 VARCHAR2(64),
    Machine                   VARCHAR2(64),
    Port                      NUMBER,
    ECID                      VARCHAR2(64),
    DBREPLAY_FILE_ID          NUMBER,
    DBREPLAY_CALL_COUNTER     NUMBER,
    TM_DELTA_TIME             NUMBER,
    TM_DELTA_CPU_TIME         NUMBER,
    TM_DELTA_DB_TIME          NUMBER,
    DELTA_TIME                NUMBER,
    DELTA_READ_IO_REQUESTS    NUMBER,
    DELTA_WRITE_IO_REQUESTS   NUMBER,
    DELTA_READ_IO_BYTES       NUMBER,
    DELTA_WRITE_IO_BYTES      NUMBER,
    DELTA_INTERCONNECT_IO_BYTES NUMBER,
    PGA_ALLOCATED             NUMBER,
    TEMP_SPACE_ALLOCATED      NUMBER,
    Con_ID                    NUMBER,
    Preserve_10Secs           VARCHAR2(1)
  );
  TYPE AshTableType IS TABLE OF AshType INDEX BY BINARY_INTEGER;
  AshTable                AshTableType;
  AshTable4Select         AshTableType;

  TYPE StatNameTableType IS TABLE OF NUMBER INDEX BY VARCHAR2(64);
  StatNameTable           StatNameTableType;

  v_Ash_Run_ID            NUMBER;                                               -- ID of current ASH daemon run for the duration of AWR snapshot
  v_Dummy                 NUMBER;


  FUNCTION Get_Stat_ID(p_Name IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF NOT StatNameTable.EXISTS(p_Name) THEN
      SELECT Statistic# INTO StatNameTable(p_Name) FROM v$StatName WHERE Name = p_Name;
    END IF;
    RETURN StatNameTable(p_Name);
  END Get_Stat_ID;

  PROCEDURE CreateSample(
    p_Instance_Number IN NUMBER,
    p_Preserve_10Secs IN VARCHAR2,                                              -- Y or NULL
    p_SysTimestamp    IN TIMESTAMP,
    p_Sample_ID       IN OUT NUMBER
  ) IS
      v_DoubleCheck_SID NUMBER := -1;                                           -- suppress double records
    BEGIN
      p_Sample_ID := p_Sample_ID + 1;
      AshTable4Select.DELETE;

      SELECT p_Sample_ID,
             p_SysTimestamp,      -- Sample_Time
             s.SID,
             s.Serial#,
             s.Type,
             NULL,                -- Flags
             s.User#,
             s.SQL_ID,
             'Y',                 -- TODO: Is_SQLID_Current ermitteln
             s.SQL_Child_Number,
             s.Command,           -- SQL_OpCode
             c.Command_Name,      -- SQL_OpName
             sql.FORCE_MATCHING_SIGNATURE,
             NULL,                -- TODO: TOP_LEVEL_SQL_ID ermitteln
             NULL,                -- TODO: TOP_LEVEL_SQL_OPCODE ermitteln
             sql.PLAN_HASH_VALUE,
             0,                   -- SQL_PLAN_LINE_ID set to the first line of an SQL because there's no source in v$-Views
             NULL,                -- TODO: SQL_PLAN_OPERATION ermitteln
             NULL,                -- TODO SQL_PLAN_OPTIONS ermitteln
             s.SQL_EXEC_ID,
             s.SQL_EXEC_START,
             s.PLSQL_ENTRY_OBJECT_ID,
             s.PLSQL_ENTRY_SUBPROGRAM_ID,
             s.PLSQL_OBJECT_ID,
             s.PLSQL_SUBPROGRAM_ID,
             pxs.QCInst_ID,
             pxs.QCSID,
             pxs.QCSerial#,
             NULL,                -- TODO: PX_FLAGS ermitteln
             DECODE(s.State, 'WAITING', s.Event, NULL),     -- Event
             DECODE(s.State, 'WAITING', s.Event#, NULL),    -- Event#
             s.SEQ#,
             s.P1TEXT,
             s.P1,
             s.P2TEXT,
             s.P2,
             s.P3TEXT,
             s.P3,
             DECODE(s.State, 'WAITING', s.Wait_Class, NULL),    -- Wait_Class
             DECODE(s.State, 'WAITING', s.Wait_Class_ID, NULL), -- Wait_Class_ID
             DECODE(s.State, 'WAITING', 0, s.Wait_Time_Micro),    -- Wait_Time: Time waited on last wait event in ON CPU, 0 currently waiting
             DECODE(s.State, 'WAITING', 'WAITING', 'ON CPU'),     -- Session_State
             DECODE(s.State, 'WAITING', s.Wait_Time_Micro, 0),    -- Time_waited: Current wait time if in wait, 0 if ON CPU
             s.BLOCKING_SESSION_STATUS,
             s.BLOCKING_SESSION,
             CASE WHEN s.Blocking_Session_Status = 'VALID' THEN (SELECT Serial# FROM gv$Session bs WHERE bs.Inst_ID=s.Blocking_Instance AND bs.SID=s.Blocking_Session)
             END BLOCKING_SESSION_SERIAL#,
             s.Blocking_Instance,
             'N',                 -- BLOCKING_HANGCHAIN_INFO
             s.Row_Wait_Obj#,     -- Current_Obj#
             s.Row_Wait_File#,    -- Current_File#
             s.Row_Wait_Block#,   -- Current_Block#
             s.Row_Wait_Row#,     -- Current_Row#
             #{PanoramaConnection.db_version >= '11.2' ?  "s.TOP_LEVEL_CALL#" : "NULL"  }, -- Top_Level_Call#
             cg.ID,               -- CONSUMER_GROUP_ID
             t.XID,
             NULL,                -- TODO: REMOTE_INSTANCE# ermitteln
             NULL,                -- TODO: TIME_MODEL ermitteln
             NULL,                -- TODO: ermitteln IN_CONNECTION_MGMT
             NULL,                -- TODO: ermitteln IN_PARSE
             NULL,                -- TODO: ermitteln IN_HARD_PARSE
             NULL,                -- TODO: ermitteln IN_SQL_EXECUTION
             NULL,                -- TODO: ermitteln IN_PLSQL_EXECUTION
             NULL,                -- TODO: ermitteln IN_PLSQL_RPC
             NULL,                -- TODO: ermitteln IN_PLSQL_COMPILATION
             NULL,                -- TODO: ermitteln IN_JAVA_EXECUTION
             NULL,                -- TODO: ermitteln IN_BIND
             NULL,                -- TODO: ermitteln IN_CURSOR_CLOSE
             NULL,                -- TODO: ermitteln IN_SEQUENCE_LOAD
             NULL,                -- TODO: ermitteln IN_INMEMORY_QUERY
             NULL,                -- TODO: ermitteln IN_INMEMORY_POPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_PREPOPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_REPOPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_TREPOPULATE
             NULL,                -- TODO: ermitteln IN_TABLESPACE_ENCRYPTION
             NULL,                -- TODO: ermitteln CAPTURE_OVERHEAD
             NULL,                -- TODO: ermitteln REPLAY_OVERHEAD
             NULL,                -- TODO: ermitteln IS_CAPTURED
             NULL,                -- TODO: ermitteln IS_REPLAYED
             srv.Name_Hash,       -- Service_Hash
             s.Program,
             s.Module,
             s.Action,
             s.Client_Identifier, -- Client_ID
             s.Machine,
             #{PanoramaConnection.db_version >= '11.2' ?  "s.Port" : "NULL"  }, -- Port
             #{PanoramaConnection.db_version >= '11.2' ?  "s.ECID" : "NULL"  }, -- ECID
             NULL,                -- DBREPLAY_FILE_ID
             NULL,                -- DBREPLAY_CALL_COUNTER
             -- cast SYSTIMESTAMP to timestamp without timezone to ensure timezone setting does not influence the difference SYSTIMESTAMP-Sample_Time
             DECODE(ph.Sample_Time, NULL, NULL, (EXTRACT(DAY    FROM p_SysTimestamp-ph.Sample_Time)*86400 + EXTRACT(HOUR FROM p_SysTimestamp-ph.Sample_Time)*3600 +
                                                 EXTRACT(MINUTE FROM p_SysTimestamp-ph.Sample_Time)*60    + EXTRACT(SECOND FROM p_SysTimestamp-ph.Sample_Time))*1000000), -- TM_Delta_Time
             DECODE(ph.Sample_Time, NULL, NULL, stm_cp.Value - NVL(ph.TM_Delta_CPU_Time, 0)),     -- TM_DELTA_CPU_TIME
             DECODE(ph.Sample_Time, NULL, NULL, stm_db.Value - NVL(ph.TM_Delta_DB_Time, 0)),      -- TM_DELTA_DB_TIME
             DECODE(ph.Sample_Time, NULL, NULL, (EXTRACT(DAY    FROM p_SysTimestamp-ph.Sample_Time)*86400 + EXTRACT(HOUR FROM p_SysTimestamp-ph.Sample_Time)*3600 +
                                                 EXTRACT(MINUTE FROM p_SysTimestamp-ph.Sample_Time)*60    + EXTRACT(SECOND FROM p_SysTimestamp-ph.Sample_Time))*1000000), -- Delta_Time
             NULL, -- DECODE(ph.Sample_Time, NULL, NULL, ss_rio.Value - NVL(ph.DELTA_READ_IO_REQUESTS, 0)),  --  DELTA_READ_IO_REQUESTS
             NULL, -- DELTA_WRITE_IO_REQUESTS
             NULL, -- DELTA_READ_IO_BYTES
             NULL, -- DELTA_WRITE_IO_BYTES
             NULL, -- DELTA_INTERCONNECT_IO_BYTES
             p.PGA_Alloc_Mem,     -- PGA_ALLOCATED
             NVL(ts.blocks * #{PanoramaConnection.db_blocksize}, 0),  -- TEMP_SPACE_ALLOCATED
             #{PanoramaConnection.db_version >= '12.1' ? "s.Con_ID" : "0"}, -- Con_ID
             p_Preserve_10Secs -- Preserve_10Secs, decide MOD 10 on rounded seconds (distance between samples may be a bit smaller than 1 second)
      BULK COLLECT INTO AshTable4Select
      FROM   v$Session s
      LEFT OUTER JOIN v$Process p               ON p.Addr = s.pAddr -- dont think that join per Con_ID is necessary here
      LEFT OUTER JOIN v$SQLCommand c            ON c.Command_Type = s.Command #{"AND c.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$SQL sql                 ON sql.SQL_ID = s.SQL_ID AND sql.Child_Number = s.SQL_Child_Number #{"AND sql.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$PX_Session pxs          ON pxs.SID = s.SID AND pxs.Serial#=s.Serial#
      LEFT OUTER JOIN V$RSRC_CONSUMER_GROUP cg  ON cg.Name = s.Resource_Consumer_Group #{"AND cg.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$Transaction t           ON t.Ses_Addr = s.SAddr
      LEFT OUTER JOIN v$Services srv            ON srv.Name = s.Service_Name #{"AND srv.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$Sess_Time_Model stm_db  ON stm_db.SID = s.SID AND stm_db.Stat_Name = 'DB time'
      LEFT OUTER JOIN v$Sess_Time_Model stm_cp  ON stm_cp.SID = s.SID AND stm_cp.Stat_Name = 'DB CPU'
      LEFT OUTER JOIN (SELECT Session_ID, MAX(Sample_ID) Max_Sample_ID
                       FROM   panorama_owner.Internal_V$Active_Sess_History phm
                       WHERE  phm.Instance_Number = p_Instance_Number
                       GROUP BY Session_ID
                      ) phms ON phms.Session_ID = s.SID
      LEFT OUTER JOIN panorama_owner.Internal_V$Active_Sess_History ph ON ph.Instance_Number = p_Instance_Number AND ph.Session_ID = s.SID AND ph.Sample_ID = phms.Max_Sample_ID
      LEFT OUTER JOIN (SELECT Session_Addr, SUM(Blocks) Blocks
                       FROM   v$Tempseg_Usage
                       GROUP BY Session_Addr) ts ON ts.Session_Addr = s.SAddr
      -- Access on v$SesStat is too slow for execution per second
      --LEFT OUTER JOIN v$SesStat ss_rio          ON ss_rio.SID = s.SID AND ss_rio.Statistic#=Panorama_Sampler_ASH.Get_Stat_ID('physical read total IO requests') #{"AND ss_rio.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      WHERE  s.Status = 'ACTIVE'
      AND    s.Wait_Class != 'Idle'
      AND    s.SID        != USERENV('SID')  -- dont record the own session that assumes always active this way
      #{"AND s.Con_ID IN (SELECT /*+ NO_MERGE */ Con_ID FROM v$Containers) /* Consider sessions of Con-IDs to sample only */ " if PanoramaConnection.db_version >= '12.1'}
      ORDER BY s.SID  -- sorted order needed for suppression of doublettes in next step
      ;

      FOR Idx IN 1 .. AshTable4Select.COUNT LOOP                                -- Move selected records into memory buffer for x Seconds
        IF AshTable4Select(Idx).Session_ID < v_DoubleCheck_SID THEN
          RAISE_APPLICATION_ERROR(-20999, 'CreateSample; Wrong order after SELECT ORDER BY! Test-SID < v_DoubleCheck_SID '||AshTable4Select(Idx).Session_ID||' / '||v_DoubleCheck_SID);
        END IF;
        IF AshTable4Select(Idx).Session_ID != v_DoubleCheck_SID THEN            -- Insert each SID only one time, doublettes may be caused by v$Transaction
          AshTable(AshTable.COUNT+1) := AshTable4Select(Idx);
        END IF;
        v_DoubleCheck_SID := AshTable4Select(Idx).Session_ID;                   -- Remember the last used SID
      END LOOP;
    END CreateSample;

  PROCEDURE Persist_Samples(
    p_Instance_Number IN NUMBER
  ) IS
      Msg VARCHAR2(2000);
    BEGIN
      FORALL Idx IN 1 .. AshTable.COUNT
      INSERT INTO panorama_owner.Internal_V$Active_Sess_History (
        Instance_Number, Sample_ID, Sample_Time, Is_AWR_Sample, Session_ID, Session_Serial#,
        Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
        SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE,
        SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS,
        SQL_EXEC_ID, SQL_EXEC_START,
        PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
        QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID,
        SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
        Session_State, Time_Waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#,
        BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
        Current_Obj#, Current_File#, Current_Block#, Current_Row#,
        Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
        IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
        IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
        IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
        IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
        REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program,
        Module, Action, Client_ID, Machine, Port, ECID,
        DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER, TM_Delta_Time, TM_DELTA_CPU_TIME, TM_DELTA_DB_TIME,
        DELTA_TIME, DELTA_READ_IO_REQUESTS, DELTA_WRITE_IO_REQUESTS, DELTA_READ_IO_BYTES,
        DELTA_WRITE_IO_BYTES, DELTA_INTERCONNECT_IO_BYTES, PGA_Allocated, Temp_Space_Allocated,
        Con_ID, Preserve_10Secs
      ) VALUES (
        p_Instance_Number, AshTable(Idx).Sample_ID, AshTable(Idx).Sample_Time, 'N', AshTable(Idx).Session_ID, AshTable(Idx).Session_Serial#,
        AshTable(Idx).Session_Type, AshTable(Idx).Flags, AshTable(Idx).User_ID, AshTable(Idx).SQL_ID, AshTable(Idx).Is_SQLID_Current, AshTable(Idx).SQL_Child_Number,
        AshTable(Idx).SQL_OpCode, AshTable(Idx).SQL_OpName, AshTable(Idx).FORCE_MATCHING_SIGNATURE, AshTable(Idx).TOP_LEVEL_SQL_ID, AshTable(Idx).TOP_LEVEL_SQL_OPCODE,
        AshTable(Idx).SQL_PLAN_HASH_VALUE, AshTable(Idx).SQL_PLAN_LINE_ID, AshTable(Idx).SQL_PLAN_OPERATION, AshTable(Idx).SQL_PLAN_OPTIONS,
        AshTable(Idx).SQL_EXEC_ID, AshTable(Idx).SQL_EXEC_START,
        AshTable(Idx).PLSQL_ENTRY_OBJECT_ID, AshTable(Idx).PLSQL_ENTRY_SUBPROGRAM_ID, AshTable(Idx).PLSQL_OBJECT_ID, AshTable(Idx).PLSQL_SUBPROGRAM_ID,
        AshTable(Idx).QC_INSTANCE_ID, AshTable(Idx).QC_SESSION_ID, AshTable(Idx).QC_SESSION_SERIAL#, AshTable(Idx).PX_FLAGS, AshTable(Idx).Event, AshTable(Idx).Event_ID,
        AshTable(Idx).SEQ#, AshTable(Idx).P1TEXT, AshTable(Idx).P1, AshTable(Idx).P2TEXT, AshTable(Idx).P2, AshTable(Idx).P3TEXT, AshTable(Idx).P3, AshTable(Idx).Wait_Class, AshTable(Idx).Wait_Class_ID, AshTable(Idx).Wait_Time,
        AshTable(Idx).Session_State, AshTable(Idx).Time_Waited, AshTable(Idx).BLOCKING_SESSION_STATUS, AshTable(Idx).BLOCKING_SESSION, AshTable(Idx).BLOCKING_SESSION_SERIAL#,
        AshTable(Idx).BLOCKING_INST_ID, AshTable(Idx).BLOCKING_HANGCHAIN_INFO,
        AshTable(Idx).Current_Obj#, AshTable(Idx).Current_File#, AshTable(Idx).Current_Block#, AshTable(Idx).Current_Row#,
        AshTable(Idx).Top_Level_Call#, AshTable(Idx).CONSUMER_GROUP_ID, AshTable(Idx).XID, AshTable(Idx).REMOTE_INSTANCE#, AshTable(Idx).TIME_MODEL,
        AshTable(Idx).IN_CONNECTION_MGMT, AshTable(Idx).IN_PARSE, AshTable(Idx).IN_HARD_PARSE, AshTable(Idx).IN_SQL_EXECUTION, AshTable(Idx).IN_PLSQL_EXECUTION,
        AshTable(Idx).IN_PLSQL_RPC, AshTable(Idx).IN_PLSQL_COMPILATION, AshTable(Idx).IN_JAVA_EXECUTION, AshTable(Idx).IN_BIND, AshTable(Idx).IN_CURSOR_CLOSE,
        AshTable(Idx).IN_SEQUENCE_LOAD, AshTable(Idx).IN_INMEMORY_QUERY, AshTable(Idx).IN_INMEMORY_POPULATE, AshTable(Idx).IN_INMEMORY_PREPOPULATE,
        AshTable(Idx).IN_INMEMORY_REPOPULATE, AshTable(Idx).IN_INMEMORY_TREPOPULATE, AshTable(Idx).IN_TABLESPACE_ENCRYPTION, AshTable(Idx).CAPTURE_OVERHEAD,
        AshTable(Idx).REPLAY_OVERHEAD, AshTable(Idx).IS_CAPTURED, AshTable(Idx).IS_REPLAYED, AshTable(Idx).Service_Hash, AshTable(Idx).Program,
        AshTable(Idx).Module, AshTable(Idx).Action, AshTable(Idx).Client_ID, AshTable(Idx).Machine, AshTable(Idx).Port, AshTable(Idx).ECID,
        AshTable(Idx).DBREPLAY_FILE_ID, AshTable(Idx).DBREPLAY_CALL_COUNTER, AshTable(Idx).TM_Delta_Time, AshTable(Idx).TM_DELTA_CPU_TIME, AshTable(Idx).TM_DELTA_DB_TIME,
        AshTable(Idx).DELTA_TIME, AshTable(Idx).DELTA_READ_IO_REQUESTS, AshTable(Idx).DELTA_WRITE_IO_REQUESTS, AshTable(Idx).DELTA_READ_IO_BYTES,
        AshTable(Idx).DELTA_WRITE_IO_BYTES, AshTable(Idx).DELTA_INTERCONNECT_IO_BYTES, AshTable(Idx).PGA_Allocated, AshTable(Idx).Temp_Space_Allocated,
        AshTable(Idx).Con_ID, AshTable(Idx).Preserve_10Secs
      );
      COMMIT;
      AshTable.DELETE;
   EXCEPTION
      WHEN OTHERS THEN
        Msg := SQLERRM||':';
        SELECT MAX(Sample_ID) INTO v_Dummy FROM panorama_owner.Internal_V$Active_Sess_History; -- Compare max existing value in table
        Msg := Msg||':'||v_Dummy||':';
        FOR Idx IN 1 .. AshTable.COUNT LOOP
          IF Idx < 50 THEN                                                      -- Ensure max. VARCHAR2 size is not exceeded
            Msg := Msg||AshTable(Idx).Sample_ID||'.'||AshTable(Idx).Session_ID||'/';
          END IF;
        END LOOP;
        AshTable.DELETE;                                                        -- Delete double content in case of exception
        RAISE_APPLICATION_ERROR(-20999, Msg);
    END Persist_Samples;

  PROCEDURE Run_Sampler_Daemon(
    p_Instance_Number IN NUMBER,
    p_Next_Snapshot_Start_Seconds IN NUMBER
  ) IS
    v_Sample_ID       NUMBER;
    v_LastSampleTime  DATE;
    v_SysTimestamp    TIMESTAMP(3);
    v_Preserve_10Secs VARCHAR2(1);
    BEGIN
      -- Initiate Counter
      SELECT MAX(Ash_Run_ID) INTO v_Ash_Run_ID FROM panorama_owner.Panorama_ASH_Counter WHERE Instance_Number = p_Instance_Number;
      IF v_Ash_Run_ID IS NULL THEN
        v_Ash_Run_ID := 0;                                                      -- start value
        INSERT INTO panorama_owner.Panorama_ASH_Counter(Instance_Number, Ash_Run_ID) VALUES (p_Instance_Number, v_Ash_Run_ID);
        COMMIT;
      END IF;

      -- Ensure that local database time controls end of PL/SQL-execution (allows different time zones and some seconds delay between Panorama and DB)
      -- but assumes that PL/SQL-Job is started at the exact second
      v_LastSampleTime := SYSDATE + (p_Next_Snapshot_Start_Seconds+2)/86400;    -- Ensure that the last 10 seconds block is executed after end_snapshot

      -- The daemon starts at minute boundary, but the samples for the first 10 seconds after the snapshot time are still processed by the previously running daemon
      -- To cover some time shift between Panorama-Server and DB the daemon should start so that it will not process this first 10 seconds itself, because this may lead to PK error
      DBMS_LOCK.SLEEP(2);

      v_Ash_Run_ID := v_Ash_Run_ID + 1;
      -- Inform predecessing daemon to terminate at next 10 seconds boundary
      UPDATE panorama_owner.Panorama_ASH_Counter SET Ash_Run_ID = v_Ash_Run_ID WHERE Instance_Number = p_Instance_Number;
      COMMIT;

      DBMS_LOCK.SLEEP(10-MOD(EXTRACT(SECOND FROM SYSTIMESTAMP), 10));           -- Wait until time is at excact 10 seconds boundary
      DBMS_LOCK.SLEEP(0.1);                                                     -- Ensure next SLEEP waits until 0.1 second after 10 seconds boundary

      SELECT NVL(MAX(Sample_ID), 0) INTO v_Sample_ID FROM panorama_owner.Internal_V$Active_Sess_History WHERE Instance_Number = p_Instance_Number;
      IF v_Sample_ID = 0 THEN                                                   -- no sample found in Internal_V$Active_Sess_History
        -- use EXECUTE IMMEDIATE for accessing panorama_owner.Panorama_Active_Sess_History because this view does not exists at first run
        SELECT COUNT(*) INTO v_Dummy FROM All_Tables WHERE Owner = UPPER('panorama_owner') AND Table_Name = UPPER('Panorama_Active_Sess_History');
        IF V_Dummy > 0 THEN
          -- look for Sample_ID in permanent table
          EXECUTE IMMEDIATE 'SELECT NVL(MAX(Sample_ID), 0) FROM panorama_owner.Panorama_Active_Sess_History WHERE Instance_Number = :Instance_Number' INTO v_Sample_ID USING p_Instance_Number;
        END IF;
      END IF;
      v_Sample_ID := v_Sample_ID + 10;                                          -- Start with next bulk because predecessing daemon will write up to 10 samples before terminating

      LOOP
        -- Wait until current second ends, ensure also that first sample is at seconds bound
        -- DBMS_LOCK will be replaced with DBMS_SESSION before execution if DB version >= 18.0
        -- Add 2/100 seconds to sleep time to be sure that next timestamp is surely at the next second (possible round problem)
        DBMS_LOCK.SLEEP(1-MOD(EXTRACT(SECOND FROM SYSTIMESTAMP), 1)+0.02);

        -- cast SYSTIMESTAMP to timestamp without timezone to ensure timezone setting does not influence the difference SYSTIMESTAMP-Sample_Time
        v_SysTimestamp := CAST(SYSTIMESTAMP AS TIMESTAMP);


        if MOD(TRUNC(EXTRACT(SECOND FROM v_SysTimestamp)), 10) = 0 THEN
          v_Preserve_10Secs := 'Y';
        ELSE
          v_Preserve_10Secs := NULL;
        END IF;

        CreateSample(p_Instance_Number, v_Preserve_10Secs, v_SysTimestamp, v_Sample_ID);
        IF v_Preserve_10Secs = 'Y' THEN                                         -- Persist into DB each 10 seconds
          Persist_Samples(p_Instance_Number);                                   -- write content of AshTable into DB
          -- Check for termination
          SELECT Ash_Run_ID INTO v_Dummy FROM panorama_owner.Panorama_ASH_Counter WHERE Instance_Number = p_Instance_Number;
          EXIT WHEN v_Dummy > v_Ash_Run_ID;                                     -- a successing daemon process is active
          EXIT WHEN SYSDATE >= v_LastSampleTime;                                -- return control to Panorama server at least x seconds after end of AWR snapshot
        END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20999, 'Exception raised for Inst='||p_Instance_Number||', Next_Snapshot_Start_Seconds='||p_Next_Snapshot_Start_Seconds||', LastSampleTime='||TO_CHAR(v_LastSampleTime, 'HH24:MI:SS'), TRUE);
    END Run_Sampler_Daemon;
    "
  end

  def panorama_sampler_ash_body
    "
-- Package for use by Panorama-Sampler
CREATE OR REPLACE PACKAGE BODY panorama_owner.Panorama_Sampler_ASH AS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
#{panorama_sampler_ash_code}
END Panorama_Sampler_ASH;
"
  end


end
