# encoding: utf-8
module KeyExplanationHelper
  @@switchover_status = nil
  def explain_switchover_status(value)
    unless @@switchover_status
      @@switchover_status = {
          'NOT ALLOWED'           => "On a primary database, this status indicates that there are no valid and enabled standby databases. On a standby database, this status indicates that a switchover request has not been received from the primary database.",
          'SESSIONS ACTIVE'       => "The database has active sessions. On a physical standby database, the WITH SESSION SHUTDOWN SQL clause must be specified to perform a role transition while in this state. On a logical standby database, a role transition can be performed while in this state, but the role transition will not complete until all current transactions have committed.",
          'SWITCHOVER PENDING'    => "On a physical standby database, this status indicates that a switchover request has been received from the primary database and is being processed. A physical standby database cannot switch to the primary role while in this transient state.",
          'SWITCHOVER LATENT'     => "On a physical standby database, this status indicates that a switchover request was pending, but the original primary database has been switched back to the primary role.",
          'TO PRIMARY'            => "The database is ready to switch to the primary role.",
          'TO STANDBY'            => "The database is ready to switch to either the physical or logical standby role.",
          'TO LOGICAL STANDBY'    => "The database has received a data dictionary from a logical standby database and is ready to switch to the logical standby role.",
          'RECOVERY NEEDED'       => "On a physical standby database, this status indicates that additional redo must be applied before the database can switch to the primary role.",
          'PREPARING SWITCHOVER'  => "On a primary database, this status indicates that a data dictionary is being received from a logical standby database in preparation for switching to the logical standby role. On a logical standby database, this status indicates that the data dictionary has been sent to the primary database and other standby databases.",
          'PREPARING DICTIONARY'  => "On a logical standby database, this status indicates that the data dictionary is being sent to the primary database and other standby databases in preparation for switching to the primary role.",
          'FAILED DESTINATION'    => "On a primary database, this status indicates that one or more standby destinations are in an error state.",
          'RESOLVABLE GAP'        => "On a primary database, this status indicates that one or more standby databases have a redo gap that can be automatically resolved by fetching the missing redo from the primary database or from another standby database.",
          'UNRESOLVABLE GAP'      => "On a primary database, this status indicates that one or more standby databases have a redo gap that cannot be automatically resolved by fetching the missing redo from the primary database or from another standby database.",
          'LOG SWITCH GAP'        => "On a primary database, this status indicates that one or more standby databases are missing redo due to a recent log switch.",
      }
    end
    result = @@switchover_status[value]
    if result.nil?
      "... no explanation available yet for switchover-status #{value}"
    else
      result
    end
  end

  @@data_access = nil # Cache
  def explain_data_access(operation_options)
    unless @@data_access
      @@data_access = {
        'EXTENDED DATA LINK FULL'             => "Execution through data link on another container of this instance with it's own container-specific process",
        'HASH JOIN BUFFERED'                  => "A hash join where a hash table is built on the first row souece and the second row source must be completely read and buffered in memory rsp. temporary tablespace, before the hash join will be processed.\n\nSometimes it will process much better with the HASH JOIN SHARED (not yet producton ready up to 21.c).\nUsing HASH JOIN SHARED can be forced by either:\n- \"SET _px_shared_hash_join=TRUE\" at system or session level\n- the hint /*+ OPT_PARAM('_px_shared_hash_join' 'true') */ for th entire statement\n- the hint /*+ PQ_DISTRIBUTE(t2 SHARED NONE) */ for a particular join where t2 is the second row source of the hash join.",
        'JOIN FILTER CREATE'                  => "Create bloom filter based on data from previous operation.\nBloom filter allows to exactly state that a value does not exist in an result.\nThis created filter is used at an operation JOIN FILTER USE with same object name to filter out (not all) rows that will not match the join condition.\n\nUsage of bloom filters in SQL can be controlled by optimizer hint \"NO_PX_JOIN_FILTER\" or \"OPT_PARAM('_bloom_filter_enabled' 'false')\"",
        'JOIN FILTER USE'                     => "Usage of bloom filter to filter out (not all) rows that will not match the join condition. Used bloom filter data was created by operation JOIN FILTER CREATE with same object name.\nBloom filter allows to exactly state that a value does not exist in an result.\n\nUsage of bloom filters in SQL can be controlled by optimizer hint \"NO_PX_JOIN_FILTER\" or \"OPT_PARAM('_bloom_filter_enabled' 'false')\"",
        'LOAD AS SELECT (HYBRID TSM/HWMB)'    => "This is a hybrid solution that combines the beneficial characteristics of temp segment merge and high water mark brokering.",
        'OPTIMIZER STATISTICS GATHERING'      => "Automatic gathering of statistics for tables and indexes.\nMay double run time of load processes (e.g. CREATE TABLE AS SELECT) in worst case!\nTo disable automatic gathering:\n- Use optimizer hint like CREATE TABLE AS SELECT /*+ NO_GATHER_OPTIMIZER_STATISTICS */ ... or\n- ALTER SESSION SET \"_optimizer_gather_stats_on_load\"=FALSE;",
        'PX SEND QC (RANDOM)'                 => "Takes the result of the following line and sends it to the Query Coordinator.\nWhen they send their results to the Query Coordinator,\nthe order they send the result is not important.\nHence, it is random.",
        'REMOTE'                              => "Access remote database per DB-link.\nExecute Sub-select shown in column 'OTHER' on remote database.",
        'STATISTICS COLLECTOR'                => 'Collecting statistics for adaptive plan feature',
        'TABLE ACCESS STORAGE FULL'           =>  "Table full scan on EXADATA storage cell.\nAccess predicates contains conditions that are filtered at Exadata storage cell server before transferring result to database server.\nFilter predicates contains conditions that are filtered at database server after consuming result from cell servers.",
      }
    end
    result = @@data_access[operation_options.strip]
    if result.nil?
      "... no explanation available yet for #{operation_options}"
    else
      result
    end
  end

  def lock_modes(search_mode)
    search_mode = search_mode.to_s
    lockmodes =
    {
     '0' => 'none',
     '1' => 'null',
     '2' => 'row-S (RS), lock table row in share mode',
     '3' => 'row-X (RX), lock table row in exclusive mode',
     '4' => "share (S), Waits for TX in mode 4 can occur:\n- waiting for potential duplicates in a UNIQUE index\n- Index block split by another transaction\n- ITL overflow.\n- DML on referenced table blocked by exclusive locks on referencing table (missing index on foreign key column)",
     '5' => 'Share row-X (SRX), share row exclusive',
     '6' => 'exclusive(X), Waits for TX in mode 6 occurs when a session is waiting for a row level lock that is already held by another session.'
    }
    if lockmodes[search_mode]
      lockmodes[search_mode]
    else
      "Unknown lockmode #{search_mode}"
    end
  end

  @@locktypes = nil # Cache

  def lock_types(search_lock_type)
    unless @@locktypes
      @@locktypes = {
       'AB' => 'A general class of locks used by auto BMR for various purposes',
       'AD' => 'ASM Disk AU Lock',
       'AE' => 'Application Edition Enqueue',
       'AF' => 'Advisor Framework',
       'AG' => 'Analytic Workspace Generation',
       'AK' => 'GES Deadlock Test',
       'AO' => 'MultiWriter Object Access',
       'AR' => 'ASM Relocation Lock',
       'AS' => 'Service Operations',
       'AU' => 'Lock held to synchronize access XML to audit index file',
       'AT' => 'Lock held for the ALTER TABLE statement',
       'AV' => 'AVD DG Number Lock',
       'AW' => 'Analytic Workspace',
       'AY' => 'KSXA Test Affinity Dictionary',
       'BB' => 'Global Transaction Branch',
       'BF' => 'Synchronize access to a bloom filter in a parallel statement',
       'BL' => 'Buffer hash table instance',
       'BR' => 'Backup/Restore',
       'CA' => 'Calibration',
       'CF' => 'Control file schema global enqueue',
       'CI' => 'cross instance function invocation instance',
       'CL' => 'Label Security cache',
       'CM' => 'ASM Instance Enqueue',
       'CO' => 'KTUCLO Master Slave enqueue',
       'CQ' => 'Cleanup querycache registrations',
       'CT' => 'Block Change Tracking',
       'CU' => 'cursor bind',
       'DF' => 'datafile instance',
       'DL' => 'direct loader parallel index create',
       'DM' => 'mount/startup db primary/secondary instance',
       'DO' => 'ASM Disk Online Lock',
       'DR' => 'distributed recovery process',
       'DW' => 'In memory Dispenser',
       'DX' => 'distributed transaction entry',
       'FA' => 'ASM File Access Lock',
       'FE' => 'KTFA Recovery',
       'FS' => 'file set',
       'FX' => 'ACD Extent Info CIC',
       'FZ' => 'ASM Freezing Cache Lock',
       'HW' => 'space management operation on a specific segment',
       'IN' => 'instance number',
       'IR' => 'instance recovery serialization global enqueue',
       'IS' => 'instance state',
       'IV' => 'library cache invalidation instance',
       'JQ' => 'job queue',
       'KE' => 'ASM Cached Attributes',
       'KL' => 'LOB KSI Lock',
       'KK' => 'thread kick',
       'KQ' => 'ASM Attributes Enqueue',
       'MM' => 'mount defintion global enqueue',
       'MO' => 'MMON restricted session',
       'MR' => 'media recovery',
       'MX' => 'ksz synch',
       'OD' => 'Online DDLs',
       'PF' => 'Password File',
       'PI' => 'Parallel Query Server',
       'PR' => 'Process startup',
       'PS' => 'Parallel Query Server',
       'RC' => 'Result Cache: Enqueue',
       'RE' => 'Block Repair/Resilvering',
       'RR' => 'Workload Capture and Replay',
       'RT' => 'Redo thread global enqueue',
       'RX' => 'ASM Extent Relocation Lock',
       'SC' => 'System change number instance',
       'SJ' => 'KTSJ Slave Task Cancel',
       'SL' => 'Serialize Lock request',
       'SM' => 'SMON',
       'SN' => 'Sequence number instance',
       'SO' => 'Shared Object',
       'SQ' => 'Sequence number enqueue',
       'SS' => 'Sort segment',
       'ST' => 'Space transaction enqueue',
       'SV' => 'Sequence number value',
       'TA' => 'Generic enqueue',
       'TH' => 'Threshold Chain',
       'TK' => 'Auto Task Serialization',
       'TM' => 'DML Enqueue, prevents other sessions from DML (exclusive mode 3). Possibly indicates that there are unindexed foreign key constraints and DML on both tables.',
       'TO' => 'Temp Object',
       'TS' => 'Temporary segment enqueue (ID2=0) / New block allocation enqueue (ID2=1)',
       'TT' => 'Temporary table enqueue',
       'TX' => 'Transaction enqueue, TX enqueues are acquired exclusive when a transaction initiates its first change and held until the transaction COMMITs or ROLLBACK.',
       'UL' => 'User supplied',
       'UN' => 'User name',
       'US' => 'Undo segment DDL',
       'WL' => 'Being-written redo log instance',
       'WG' => 'Write gather local enqueue',
       'WM' => 'WLM Plan Operations',
       'WP' => 'This enqueue handles concurrency between purging and baselines',
       'WR' => 'Coordinates access to logs by Async LNS and ARCH/FG',
       'WS' => 'LogWriter Standby',
       'XB' => 'ASM Group Block Lock',
       'XC' => 'Synchronization access to XDB configuration',
       'XH' => 'AQ Notification No-Proxy',
       'XL' => 'ASM Extent Fault Lock',
       'XQ' => 'ASM extent relocation',
       'XR' => 'Quiesce / Force Logging',
       'XY' => 'Lock used for internal testing',
       'Y'  => 'Synchronizes accesses to the contents of library cache objects',
       'ZA' => 'Lock held for adding partition to Aud table',
       'ZF' => 'Lock held for adding partition to Fga table',
       'ZG' => 'Coordinates file group operations',
       'ZZ' => 'Lock held for updating Global context hash tables'
      }
      ('A'..'P').each{|x| @@locktypes["L#{x}"] = 'library cache lock instance (namespace=second character)'
      }
      ('A'..'Z').each{|x| @@locktypes["N#{x}"] = 'Library cache pin instance (A..Z = namespace)'
      }
      ('A'..'Z').each{|x| @@locktypes["Q#{x}"] = 'Row cache instance (A..Z = cache)'
      }

      if PanoramaConnection.db_version >= '11.1'
        sql_select_all("SELECT DISTINCT Type, Name, Description FROM v$Lock_Type").each do |lt|
          if @@locktypes[lt.type]
            @@locktypes[lt.type] = "#{lt.name}\n#{lt.description}\n(#{@@locktypes[lt.type]})"
          else
            @@locktypes[lt.type] = "#{lt.name}\n#{lt.description}"
          end
        end
      end
    end

    if @@locktypes[search_lock_type]
      @@locktypes[search_lock_type]
    else
      "unknown locktype '#{search_lock_type}'"
    end
  end

  @@wait_events = nil # Cache

  def explain_wait_event(event)
    unless @@wait_events
      @@wait_events = {
          'acknowledge over PGA limit'                          => "Check MOS note 2138882.1.\nThe \"acknowlege over PGA limit\" is a new wait event that was introduced with PGA_AGGREGATE_LIMIT in 12.1, and it will force a process that wants more PGA to wait a bit if the  instance is getting close to hitting the limit.\nThe hope is some other process will release memory and avoid the ORA-4036 error.\nPGA_AGGREGATE_LIMIT specifies a limit on the aggregate PGA memory consumed by the instance. By default, PGA_AGGREGATE_LIMIT is set to the greater of 2 GB, 200% of PGA_AGGREGATE_TARGET, and 3 MB times the PROCESSES parameter. It will be set below 200% of PGA_AGGREGATE_TARGET if it is larger than 90% of the physical memory size minus the total SGA size, but not below 100% of PGA_AGGREGATE_TARGET.\n\nEach of the following will independently increase the default PGA_AGGREGATE_LIMIT value:\n\n(1) Increasing PGA_AGGREGATE_TARGET.\n(2) Increasing PROCESSES parameter.\n(3) Setting underscore parameter \"_pga_limit_target_perc\" to a value greater than the default value.",
          'asynch descriptor resize'                            => "Wait event 'asynch descriptor resize' is set when the number of asynchronous descriptors reserved inside the OS kernel has to be readjusted.\nIt is signaled when the number of asynchronous I/O's submitted by a process has to be increased.\nMany Unix Kernels (for example: Linux kernel) do not allow the limit to be increased when there are outstanding I/O's; all outstanding I/O's must be resolved before the limit is increased.\nThis event is shown when the kernel wants to increase the limit and is waiting for all the outstanding I/O's to be resolved so that the increase can be implemented.\nIf you see this wait event often, it might be a good idea to install the fix for Bug: 9829397 ASYNC DESCRIPTOR RESIZE.",
          'buffer busy waits'                                   => "Buffer busy waits occur when an Oracle session needs to access a block in the buffer cache, but cannot because the buffer copy of the data block is locked.\nThis buffer busy wait condition can happen for either of the following reasons:\n1. The block is being read into the buffer by another session, so the waiting session must wait for the block read to complete.\n2. Another session has the buffer block locked in a mode that is incompatible with the waiting sessions request.",
          'cell interconnect retransmit during physical read'   => "This wait event appears during retransmission for an I/O of a single-block or multiblock read.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view is the same cell identified for cell single block physical read and cell multiblock physical read.\nThe P2 column contains the subnet number to the cell, and the P3 column contains the number of bytes processed during the I/O read operation.",
          'cell list of blocks physical read'                   => "This wait event is equivalent to database file parallel read for a cell.\nThe P1, P2, and P3 columns in V$SESSION_WAIT view for this event identify the cell hash number,\ndisk hash number, and the number of blocks processed during the I/O read operation.",
          'cell multiblock physical read'                       => "This wait event is equivalent to db file scattered read for a cell.\nThe P1, P2, and P3 columns in the V$SESSION_WAIT view for this event identify the cell hash number,\ndisk hash number, and the total number of bytes processed during the I/O read operation.",
          'cell single block physical read'                     => "This wait event is equivalent to db file sequential read for a cell.\nThe P1, P2, and P3 columns in the V$SESSION_WAIT view for this event identify the cell hash number,\ndisk hash number, and the number of bytes processed during the I/O read operation.",
          'cell smart file creation'                            => "This wait event appears when the database is waiting for the completion of a file creation on a cell.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view for this event should help identify a slow cell compared to the rest of the cells.",
          'cell smart incremental backup'                       => "This wait event appears when the database is waiting for the completion of an incremental backup on a cell.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view for this event should help identify a slow cell when compared to the rest of the cells.",
          'cell smart index scan'                               => "This wait event appears when the database is waiting for index or index-organized table (IOT) fast full scans.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view for this event should help identify a slow cell when compared to the rest of the cells.",
          'cell smart restore from backup'                      => "This wait event appears when the database is waiting for the completion of a file initialization for restore from backup on a cell.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view for this event should help identify a slow cell when compared to the rest of the cells.",
          'cell smart table scan'                               => "Full table scan offloaded to Exadata storage cell server.\nThis wait event appears when the database is waiting for table scans to complete on a cell.\nThe cell hash number in the P1 column in the V$SESSION_WAIT view for this event should help identify a slow cell when compared to the rest of the cells.",
          'cell sparse block physical read'                     => "This wait event appears when an I/O did not return any data.",
          'cell statistics gather'                              => "This wait event appears when a select is done on the V$CELL_STATE, V$CELL_THREAD_HISTORY, or V$CELL_REQUEST_TOTALS tables.\nDuring the select, data from the cells and any wait events are shown in this wait event.",
          'control file sequential read'                        => 'Reading from the control file.',
          'cursor: mutex S'                                     => 'A session waits on this event when it is requesting a mutex in shared mode, when another session is currently holding a this mutex in exclusive mode on the same cursor object.',
          'cursor: mutex X'                                     => 'The session requests the mutex for a cursor object in exclusive mode, and it must wait because the resource is busy. The mutex is busy because either the mutex is being held in exclusive mode by another session or the mutex is being held shared by one or more sessions. The existing mutex holder(s) must release the mutex before the mutex can be granted exclusively. Possible reasons: build new child cursor, capture SQL bind data, modify cursor related statistics',
          'cursor: pin S'                                       => 'A session waits on this event when it wants to update a shared mutex pin and another session is currently in the process of updating a shared mutex pin for the same cursor object.  This wait event should rarely be seen because a shared mutex pin update is very fast. Possible reason: Massive parse while executing the cursor. Solution: Diversify frequent used SQL-ID (e.g. by machine name in comment) ',
          'cursor: pin S wait on X'                             => 'A session waits for this event when it is requesting a shared mutex pin and another session is holding an exclusive mutex pin on the same cursor object.',
          'cursor: pin X'                                       => 'Wants exlusively pin a cursor in cache. Possible reasons: create the cursor, alter the cursor',
          'db file parallel read'                               => "This happens during recovery.\nIt can also happen during buffer prefetching, as an optimization (rather than performing multiple single-block reads).\nDatabase blocks that must be changed as part of recovery are read in parallel from the database.",
          'db file sequential read'                             => 'A single-block read (i.e., index fetch by ROWID)',
          'db file scattered read'                              => 'A multiblock read (a full-table scan, OPQ, sorting)',
          'DFS lock handle'                                     => "The session waits for the lock handle of a global lock request.\nThe lock handle identifies a global lock.\nWith this lock handle, other operations can be performed on this global lock (to identify the global lock in future operations such as conversions or release).\nThe global lock is maintained by the DLM.",
          'direct path read'                                    => "The session is waiting for a direct read to complete.\nA direct read is a physical I/O from a data file that bypasses the buffer cache and reads the data block directly into process-private memory.",
          'enq: AD - allocate AU'                               => 'Synchronizes accesses to a specific OSM disk AU',
          'enq: AD - deallocate AU'                             => 'Synchronizes accesses to a specific OSM disk AU',
          'enq: AF - task serialization'                        => 'This enqueue is used to serialize access to an advisor task',
          'enq: AG - contention'                                => 'Synchronizes generation use of a particular workspace',
          'enq: AO - contention'                                => 'Synchronizes access to objects and scalar variables',
          'enq: AS - contention'                                => 'Synchronizes new service activation',
          'enq: AT - contention'                                => "Serializes 'alter tablespace' operations",
          'enq: AW - AW$ table lock'                            => 'Global access synchronization to the AW$ table',
          'enq: AW - AW generation lock'                        => 'In-use generation state for a particular workspace',
          'enq: AW - user access for AW'                        => 'Synchronizes user accesses to a particular workspace',
          'enq: AW - AW state lock'                             => 'Row lock synchronization for the AW$ table',
          'enq: BR - file shrink'                               => 'Lock held to prevent file from decreasing in physical size during RMAN backup',
          'enq: BR - proxy-copy'                                => 'Lock held to allow cleanup from backup mode during an RMAN proxy-copy backup',
          'enq: CF - contention'                                => 'Synchronizes accesses to the controlfile',
          'enq: CI - contention'                                => 'Coordinates cross-instance function invocations',
          'enq: CL - drop label'                                => 'Synchronizes accesses to label cache when dropping a label',
          'enq: CL - compare labels' => 'Synchronizes accesses to label cache for label comparison',
          'enq: CM - gate' => 'Serialize access to instance enqueue',
          'enq: CM - instance' => 'Indicate OSM disk group is mounted',
          'enq: CT - global space management' => 'Lock held during change tracking space management operations that affect the entire change tracking file',
          'enq: CT - state' => 'Lock held while enabling or disabling change tracking, to ensure that it is only enabled or disabled by one user at a time',
          'enq: CT - state change gate 2' => 'Lock held while enabling or disabling change tracking in RAC',
          'enq: CT - reading' => 'Lock held to ensure that change tracking data remains in existence until a reader is done with it',
          'enq: CT - CTWR process start/stop' => 'Lock held to ensure that only one CTWR process is started in a single instance',
          'enq: CT - state change gate 1' => 'Lock held while enabling or disabling change tracking in RAC',
          'enq: CT - change stream ownership' => 'Lock held by one instance while change tracking is enabled, to guarantee access to thread-specific resources',
          'enq: CT - local space management' => 'Lock held during change tracking space management operations that affect just the data for one thread',
          'enq: CU - contention' => 'Recovers cursors in case of death while compiling',
          'enq: DB - contention' => 'Synchronizes modification of database wide supplemental logging attributes',
          'enq: DD - contention' => 'Synchronizes local accesses to ASM disk groups',
          'enq: DF - contention' => 'Enqueue held by foreground or DBWR when a datafile is brought online in RAC',
          'enq: DG - contention' => 'Synchronizes accesses to ASM disk groups',
          'enq: DL - contention' => 'Lock to prevent index DDL during direct load',
          'enq: DM - contention' => 'Enqueue held by foreground or DBWR to synchronize database mount/open with other operations',
          'enq: DN - contention' => 'Serializes group number generations',
          'enq: DP - contention' => 'Synchronizes access to LDAP parameters',
          'enq: DR - contention' => 'Serializes the active distributed recovery operation',
          'enq: DS - contention' => 'Prevents a database suspend during LMON reconfiguration',
          'enq: DT - contention' => 'Serializes changing the default temporary table space and user creation',
          'enq: DV - contention' => 'Synchronizes access to lower-version Diana (PL/SQL intermediate representation)',
          'enq: DX - contention' => 'Serializes tightly coupled distributed transaction branches',
          'enq: FA - access file' => 'Synchronizes accesses to open ASM files',
          'enq: FB - contention' => 'Ensures that only one process can format data blocks in auto segment space managed tablespaces',
          'enq: FC - open an ACD thread' => 'LGWR opens an ACD thread',
          'enq: FC - recover an ACD thread' => 'SMON recovers an ACD thread',
          'enq: FD - Marker generation' => 'Synchronization',
          'enq: FD - Flashback coordinator' => 'Synchronization',
          'enq: FD - Tablespace flashback on/off' => 'Synchronization',
          'enq: FD - Flashback on/off' => 'Synchronization',
          'enq: FG - serialize ACD relocate' => 'Only 1 process in the cluster may do ACD relocation in a disk group',
          'enq: FG - LGWR redo generation enq race' => 'Resolve race condition to acquire Disk Group Redo Generation Enqueue',
          'enq: FG - FG redo generation enq race' => 'Resolve race condition to acquire Disk Group Redo Generation Enqueue',
          'enq: FL - Flashback database log' => 'Synchronization',
          'enq: FL - Flashback db command' => 'Enqueue used to synchronize Flashback Database and deletion of flashback logs.',
          'enq: FM - contention' => 'Synchronizes access to global file mapping state',
          'enq: FR - contention' => 'Begin recovery of disk group',
          'enq: FS - contention' => 'Enqueue used to synchronize recovery and file operations or synchronize dictionary check',
          'enq: FT - allow LGWR writes' => 'Allow LGWR to generate redo in this thread',
          'enq: FT - disable LGWR writes' => 'Prevent LGWR from generating redo in this thread',
          'enq: FU - contention' => 'This enqueue is used to serialize the capture of the DB Feature, Usage and High Water Mark Statistics',
          'enq: HD - contention' => 'Serializes accesses to ASM SGA data structures',
          'enq: HP - contention' => 'Synchronizes accesses to queue pages',
          'enq: HQ - contention' => 'Synchronizes the creation of new queue IDs',
          'enq: HV - contention' => 'Lock used to broker the high water mark during parallel inserts',
          'enq: HW - contention' => 'Lock used to broker the high water mark during parallel inserts',
          'enq: ID - contention' => 'Lock held to prevent other processes from performing controlfile transaction while NID is running',
          'enq: IL - contention' => 'Synchronizes accesses to internal label data structures',
          'enq: IM - contention for blr' => 'Serializes block recovery for IMU txn',
          'enq: IR - contention' => 'Synchronizes parallel instance recovery and shutdown immediate',
          'enq: IS - contention' => 'Enqueue used to synchronize instance state changes',
          'enq: IT - contention' => "Synchronizes accesses to a temp object's metadata",
          'enq: JD - contention' => 'Synchronizes dates between job queue coordinator and slave processes',
          'enq: JI - contention'              => 'Lock held during materialized view operations (like refresh, alter) to prevent concurrent operations on the same materialized view',
          'enq: JQ - contention'              => 'Lock to prevent multiple instances from running a single job',
          'enq: JS - contention'              => 'Synchronizes accesses to the job cache',
          'enq: JS - coord post lock'         => 'Lock for coordinator posting',
          'enq: JS - global wdw lock'         => 'Lock acquired when doing wdw ddl',
          'enq: JS - job chain evaluate lock' => 'Lock when job chain evaluated for steps to create',
          'enq: JS - q mem clnup lck'         => 'Lock obtained when cleaning up q memory',
          'enq: JS - slave enq get lock2'     => 'Get run info locks before slv objget',
          'enq: JS - slave enq get lock1'     => 'Slave locks exec pre to sess strt',
          'enq: JS - running job cnt lock3'   => 'Lock to set running job count epost',
          'enq: JS - running job cnt lock2'   => 'Lock to set running job count epre',
          'enq: JS - running job cnt lock'    => 'Lock to get running job count',
          'enq: JS - coord rcv lock'          => 'Lock when coord receives msg',
          'enq: JS - queue lock'              => 'Lock on internal scheduler queue',
          'enq: JS - job run lock - synchronize' => 'Lock to prevent job from running elsewhere',
          'enq: JS - job recov lock'          => 'Lock to recover jobs running on crashed RAC inst',
          'enq: KK - context'                 => 'Lock held by open redo thread, used by other instances to force a log switch',
          'enq: KM - contention'              => 'Synchronizes various Resource Manager operations',
          'enq: KO - fast object checkpoint'  => "Object level checkpoint happened before running direct path reads on a table.\nDirty blocks must be written by DBWR to disk before consistent direct path read becomes possible.",
          'enq: KP - contention' => 'Synchronizes kupp process startup',
          'enq: KT - contention' => 'Synchronizes accesses to the current Resource Manager plan',
          'enq: MD - contention' => 'Lock held during materialized view log DDL statements',
          'enq: MH - contention' => 'Lock used for recovery when setting Mail Host for AQ e-mail notifications',
          'enq: ML - contention' => 'Lock used for recovery when setting Mail Port for AQ e-mail notifications',
          'enq: MN - contention' => 'Synchronizes updates to the LogMiner dictionary and prevents multiple instances from preparing the same LogMiner session',
          'enq: MR - contention' => 'Lock used to coordinate media recovery with other uses of datafiles',
          'enq: MS - contention' => 'Lock held during materialized view refresh to setup MV log',
          'enq: MW - contention' => 'This enqueue is used to serialize the calibration of the manageability schedules with the Maintenance Window',
          'enq: OC - contention' => 'Synchronizes write accesses to the outline cache',
          'enq: OL - contention' => 'Synchronizes accesses to a particular outline name',
          'enq: OQ - xsoqhiAlloc' => 'Synchronizes access to olapi history allocation',
          'enq: OQ - xsoqhiClose' => 'Synchronizes access to olapi history closing',
          'enq: OQ - xsoqhistrecb' => 'Synchronizes access to olapi history globals',
          'enq: OQ - xsoqhiFlush' => 'Synchronizes access to olapi history flushing',
          'enq: OQ - xsoq*histrecb'           => 'Synchronizes access to olapi history parameter CB',
          'enq: PD - contention'              => 'Prevents others from updating the same property',
          'enq: PE - contention'              => 'Synchronizes system parameter updates',
          'enq: PF - contention'              => 'Synchronizes accesses to the password file',
          'enq: PG - contention'              => 'Synchronizes global system parameter updates',
          'enq: PH - contention'              => 'Lock used for recovery when setting Proxy for AQ HTTP notifications',
          'enq: PI - contention'              => 'Communicates remote Parallel Execution Server Process creation status',
          'enq: PL - contention'              => 'Coordinates plug-in operation of transportable tablespaces',
          'enq: PR - contention'              => 'Synchronizes process startup',
          'enq: PS - contention'              => 'Parallel Execution Server Process reservation and synchronization',
          'enq: PT - contention'              => 'Synchronizes access to ASM PST metadata',
          'enq: PV - syncstart'               => 'Synchronizes slave start shutdown',
          'enq: PV - syncshut'                => 'Synchronizes instance shutdown_slvstart',
          'enq: PW - perwarm status in dbw0'  => 'DBWR 0 holds enqueue indicating prewarmed buffers present in cache',
          'enq: PW - flush prewarm buffers'   => 'Direct Load needs to flush pre-warmed buffers if DBWR 0 holds enqueue',
          'enq: RB - contention'              => 'Serializes OSM rollback recovery operations',
          'enq: RF - synch: per-SGA Broker metadata' => 'Ensures r/w atomicity of DG configuration metadata per unique SGA',
          'enq: RF - synchronization: critical ai' => 'Synchronizes critical apply instance among primary instances',
          'enq: RF - new AI'                  => 'Synchronizes selection of the new apply instance',
          'enq: RF - synchronization: chief'  => "Anoints 1 instance's DMON as chief to other instances' DMONs",
          'enq: RF - synchronization: HC master' => "Anoints 1 instance's DMON as health check master",
          'enq: RF - synchronization: aifo master' => 'Synchronizes apply instance failure detection and fail over operation',
          'enq: RF - atomicity'               => 'Ensures atomicity of log transport setup',
          'enq: RN - contention'              => 'Coordinates nab computations of online logs during recovery',
          'enq: RO - contention'              => 'Coordinates flushing of multiple objects',
          'enq: RO - fast object reuse'       => 'Coordinates fast object reuse',
          'enq: RP - contention'              => 'Enqueue held when resilvering is needed or when data block is repaired from mirror',
          'enq: RS - file delete'             => 'Lock held to prevent file from accessing during space reclamation',
          'enq: RS - persist alert level'     => 'Lock held to make alert level persistent',
          'enq: RS - write alert level'       => 'Lock held to write alert level',
          'enq: RS - read alert level'        => 'Lock held to read alert level',
          'enq: RS - prevent aging list update' => 'Lock held to prevent aging list update',
          'enq: RS - record reuse'            => 'Lock held to prevent file from accessing while reusing circular record',
          'enq: RS - prevent file delete'     => 'Lock held to prevent deleting file to reclaim space',
          'enq: RT - contention'              => 'Thread locks held by LGWR, DBW0, and RVWR to indicate mounted or open status',
          'enq: SB - contention'              => 'Synchronizes Logical Standby metadata operations',
          'enq: SF - contention'              => 'Lock used for recovery when setting Sender for AQ e-mail notifications',
          'enq: SH - contention'              => 'Should seldom see this contention as this Enqueue is always acquired in no-wait mode',
          'enq: SI - contention'              => 'Prevents multiple streams table instantiations',
          'enq: SK - contention'              => 'Serialize shrink of a segment',
          'enq: SQ - contention'              => 'Lock to ensure that only one process can replenish the sequence cache',
          'enq: SR - contention'              => 'Coordinates replication / streams operations',
          'enq: SS - contention'              => "Ensures that sort segments created during parallel DML operations aren't prematurely cleaned up",
          'enq: ST - contention'              => 'Synchronizes space management activities in dictionary-managed tablespaces',
          'enq: SU - contention'              => 'Serializes access to SaveUndo Segment',
          'enq: SW - contention'              => "Coordinates the 'alter system suspend' operation",
          'enq: TA - contention'              => 'Serializes operations on undo segments and undo tablespaces',
          'enq: TB - SQL Tuning Base Cache Update' => 'Synchronizes writes to the SQL Tuning Base Existence Cache',
          'enq: TB - SQL Tuning Base Cache Load' => 'Synchronizes writes to the SQL Tuning Base Existence Cache',
          'enq: TC - contention'              => 'Lock held to guarantee uniqueness of a tablespace checkpoint',
          'enq: TC - contention2'             => 'Lock of setup of a unique tablespace checkpoint in null mode',
          'enq: TD - KTF dump entries'        => 'KTF dumping time/scn mappings in SMON_SCN_TIME table',
          'enq: TE - KTF broadcast'           => 'KTF broadcasting',
          'enq: TF - contention'              => 'Serializes dropping of a temporary file',
          'enq: TL - contention'              => 'Serializes threshold log table read and update',
          'enq: TM - contention'              => "Synchronizes accesses to an object.\nMay be caused by missing index on foreign key column.",
          'enq: TO - contention'              => 'Synchronizes DDL and DML operations on a temp object',
          'enq: TQ - TM contention'           => 'TM access to the queue table',
          'enq: TQ - DDL contention'          => 'TM access to the queue table',
          'enq: TQ - INI contention'          => 'TM access to the queue table',
          'enq: TS - contention'              => 'Serializes accesses to temp segments',
          'enq: TT - contention'              => 'Serializes DDL operations on tablespaces',
          'enq: TW - contention'              => 'Lock held by one instance to wait for transactions on all instances to finish',
          'enq: TX - contention'              => 'Lock held by a transaction to allow other transactions to wait for it',
          'enq: TX - row lock contention'     => 'Lock held on a particular row by a transaction to prevent other transactions from modifying it',
          'enq: TX - allocate ITL entry'      => 'Allocating an ITL entry in order to begin a transaction',
          'enq: TX - index contention'        => 'Lock held on an index during a split to prevent other operations on it',
          'enq: UL - contention'              => 'Lock used by user applications',
          'enq: US - contention'              => 'Lock held to perform DDL on the undo segment',
          'enq: WA - contention'              => 'Lock used for recovery when setting Watermark for memory usage in AQ notifications',
          'enq: WF - contention'              => "it's basically the MMON processes periodically flushing ASH data into AWR tables. The WF enqueue is used to serialize the flushing of snapshot.",
          'enq: WL - contention'              => 'Coordinates access to redo log files and archive logs',
          'enq: WP - contention'              => 'This enqueue handles concurrency between purging and baselines',
          'enq: XH - contention'              => 'Lock used for recovery when setting No Proxy Domains for AQ HTTP notifications',
          'enq: XR - quiesce database'        => 'Lock held during database quiesce',
          'enq: XR - database force logging'  => 'Lock held during database force logging mode',
          'enq: ZZ - update hash tables'      => 'Frequent change of global context content in RAC environment',
          'Failed Logon Delay'                => 'Delay after unsuccessful logon try with SYS account. Delay duration is defined by _sys_logon_delay',
          'enq: XY - contention'              => 'Lock used for internal testing',
          'gc buffer busy'                    => 'a session is trying to access a buffer,but there is an open request (gc current request) for Global cache lock for that block already from same instance, and so, the session must wait for the GC lock request to complete before proceeding.',
          'gc buffer busy acquire'            => 'If existing GC open request (gc current request) originated from the local instance, then current session will wait for ‘gc buffer busy acquire’. Essentially, current process is waiting for another process in the local instance to acquire GC lock, on behalf of the local instance. Once GC lock is acquired, current process can access that buffer without additional GC processing (if the lock is acquired in a compatible mode).',
          'gc buffer busy release'            => 'If existing GC open request (gc current request) originated from a remote instance, then current session will wait for ‘gc buffer busy release’ event. In this case session is waiting for another remote session (hence another instance) to release the GC lock, so that local instance can acquire buffer.',
          'gc cr block 3-way'                 => 'More than 2 RAC-Instances: 1. message to master of block. 2. message from master to holder of block. 3. transfer block from holder to requester',
          'gc cr block busy'                  => 'The gc current block busy and gc cr block busy wait events indicate that the local instance that is making the request did not immediately receive a current or consistent read block. The term "busy" in these events indicates that the sending of the block was delayed on a remote instance. For example, a block cannot be shipped immediately if Oracle Database has not yet written the redo for the blocks changes to a log file.',
          'gc cr block congested'             => 'If LMS process did not process a request within 1ms than LMS marks the response to that block with the congestion wait event. Root cause: LMS is suffering CPU scheduling, LMS is suffering resources like memory ( paging ). As LMS processes are RT processes OS scheduling delays should be minimal',
          'gc cr failure'                     => ' This wait event is triggered when a CR ( Consistent Read) block is requested from the holder of the block and a failure status message is received.',
          'gc cr grant 2-way'                 => 'Indicates that no current block was received because it was not cached in any instance. Instead a global grant was given, enabling the requesting instance to read the block from disk or modify it.',
          'gc cr grant congested'             => 'Whenever any instance request for any data block in any mode, this request will be served by MASTER NODE of that data block.Meanwhile requesting instance is waiting for approval from master instance to perform physical IO to read data block from DISK.',
          'gc cr multi block request'         => "This event is a multi-block read, also known as 'db file scattered read',\na full scan read that is usually a full-table scan or a fast-full index scan.\nIn RAC, this event can indicate an overloaded network connection between the RAC nodes,\nand general network issues because of the work processing the large-table full-table scan.",
          'gc cr request'                     => 'These are placeholder requests which should which should be mapped to one of the detailed events once the LMS responds',
          'gc current block 2-way'            => 'an instance requests authorization for a block to be accessed in current mode to modify a block, the instance mastering the resource receives the request. The master has the current version of the block and sends the current copy of the block to the requestor via Cache Fusion and keeps a Past Image (.PI)',
          'gc current block 3-way'            => 'More than 2 RAC-Instances: 1. message to master of block. 2. message from master to holder of block. 3. transfer block from holder to requester',
          'gc current block congested'        => 'If LMS process did not process a request within 1ms than LMS marks the response to that block with the congestion wait event. Root cause: LMS is suffering CPU scheduling, LMS is suffering resources like memory ( paging ). As LMS processes are RT processes OS scheduling delays should be minimal',
          'gc current grant 2-way'            => 'Indicates that no current block was received because it was not cached in any instance. Instead a global grant was given, enabling the requesting instance to read the block from disk or modify it.',
          'gc current grant congested'        => 'Whenever any instance request for any data block in any mode, this request will be served by MASTER NODE of that data block.Meanwhile requesting instance is waiting for approval from master instance to perform physical IO to read data block from DISK.',
          'gc current block busy'             => 'The gc current block busy and gc cr block busy wait events indicate that the local instance that is making the request did not immediately receive a current or consistent read block. The term "busy" in these events indicates that the sending of the block was delayed on a remote instance. For example, a block cannot be shipped immediately if Oracle Database has not yet written the redo for the blocks changes to a log file.',
          'gc current request'                => 'These are placeholder requests which should which should be mapped to one of the detailed events once the LMS responds',
          'gc current retry'                  =>  "Instance asks for a current block, but requested block was not received either because the block was corrupted or the block was lost during transmission over the interconnect.",
          'gc domain validation'              =>  'GC domain validation is a third (or fourth) step during instance recovery. In instance recovery gc domain validation comes after second pass recovery and during gc domain validation SMON issues a recovery lock claim to the IDLM (now GRD) and recovery process proceeds further.',
          'gcs drm freeze in enter server mode' => 'Burst in remastering by Dynamic Resource Mastering (DRM)',
          'latch free'                        => "Occurs when a session needs a latch, tries to get the latch, but fails because someone else has it.\nSo, it sleeps with a wait on latch free, wakes up and tries again.\nThe time it was asleep is the wait time for “latch free.”\nThere is no ordered queue for the waiters on a latch so the first to grab the latch gets it.",
          'latch: ges resource hash list'     => 'GES resources (GES = Global Enqueue Service) are accessed via a hash array where each resource is protected by a ges resource hash list child latch.',
          'latch: row cache objects'          => 'A latch wait on a row cache object often means that there is a point of contention within the data dictionary. The row cache object latch can also indicate SQL with excessive hard parsing or excessive reliance on data dictionary information such as views row-level security, synonyms, etc. The general solution for row cache latch waits is to increase shared_pool_size.',
          'latch: shared pool'                => "This latch protects the allocation of memory from the shared pool.\nIf there is contention on this latch, it is often an indication that the shared pool is fragmented.",
          'library cache: mutex X'            => "This wait event is present whenever a library cache mutex is held in exclusive mode by a session and other sessions need to wait for it to be released.  There are many different operations in the library cache that will require a mutex, so its important to recognize which 'location' (in Oracle's code) is involved in the wait.  'Location' is useful to Oracle Support engineers for diagnosing the cause for this wait event.",
          'library cache lock'                => "This event controls the concurrency between clients of the library cache.\nIt acquires a lock on the object handle so that either:\n- One client can prevent other clients from accessing the same object.\n- The client can maintain a dependency for a long time (for example, so that no other client can change the object).\nThis lock is also obtained to locate an object in the library cache.\nLibrary cache lock will be obtained on database objects referenced during parsing or compiling of SQL or PL/SQL statements (table, view, procedure, function, package, package body, trigger, index, cluster, synonym). The lock will be released at the end of the parse or compilation.",
          'library cache pin'                 => "Library cache pins are used to manage library cache concurrency.\nPinning an object causes the heaps to be loaded into memory (if not already loaded).\nPINS can be acquired in NULL, SHARE or EXCLUSIVE modes and can be considered like a special form of lock.\nA wait for a 'library cache pin' implies some other session holds that PIN in an incompatible mode.",
          'LNS wait on SENDREQ'               => "Active data guard:\nThis wait event monitors the amount of time spent by all network servers to write the received redo to disk as well as open and close the remote archived redo logs.",
          'log file sequential read'          => 'Indicates that the process is waiting for blocks to be read from the online redo log into memory. This primarily occurs at instance startup and when the ARCH process archives filled online redo logs.',
          'log file sync'                     => 'Event is triggered when a user session issues a commit (or a rollback). The user session will signal or post the LGWR to write the log buffer to the redo log file. When the LGWR has finished writing, it will post the user session. The wait is entirely dependent on LGWR to write out the necessary redo blocks and send confirmation of its completion back to the user session. The wait time includes the writing of the log buffer and the post, and is sometimes called “commit latency". Parameter P1: All changes up to this buffer number (in the log buffer) must be flushed to disk.',
          'name-service call wait'            => 'RAC-event seen if PQ is used for short running SQLs with high execution count',
          'ON CPU'                            => "Pseudo wait event, working in database server's CPU",
          'os thread startup'                 => "A SQL statement is waiting for parallel query slave process to be allocated.\nConsider higher value for init-parameter 'parallel_min_servers' if this is a problem.",
          'PL/SQL lock timer'                 => "Session is sleeping during execution of DBMS_LOCK.SLEEP rsp. DBMS_SESSION.SLEEP",
          'PX Deq Credit: send blkd'          => 'PQ process with result (producer) waiting for credit to send next message to consumer (e.g. query coordinator)',
          'PX Deq: Parse Reply'               => 'Query Coordinator waiting for the slaves to parse their SQL statements. Examine trace files of PQ-slaves for reason.',
          'PX Deq: Table Q Normal'            => 'Consumer slave set ist waiting for data-rows from producer slave set',
          'PX qref latch'                     => 'The PX qref latch event can often mean that the Producers are producing data quicker than the Consumers can consume it. Make sure that PARALLEL_EXECUTION_MESSAGE_SIZE is set to 16384 in order to avoid many small communications and reduce this kind of contention.',
          'read by other session'             => 'Wait for another session to read the data from disk into the Oracle buffer cache.',
          'reliable message'                  =>  "Waiting for a response from the other instances in a RAC cluster.\nP1 can be evaluated from x$ksrcdes, x$ksrcctx, GV$CHANNEL_WAITS\n\nOften caused by inefficient usage of result cache",
          'SGA: allocation forcing component growth' => "Process waiting on an immediate mode memory transfer with auto-tune SGA after a 4031 for MMAN to get the memory and post it.",
          'SQL*Net break/reset to client'     => "The server is sending a break or reset message to the client. The session running on the server is waiting for a reply from the client.\nThese waits are caused by an application attempting to:\nSelect from a closed cursor\nSelect on a cursor after the last row has already been fetched and no data has been returned\nSelect on a non-existent table\nInsert a duplicate row into a uniquely indexed table\nIssuing a query with invalid syntax\nIf the value, v$session_wait.p2, for this parameter equals 0, it means a reset was sent to the client. A non-zero value means that the break was sent to the client.",
          'SQL*Net message from client'       => 'Server (shadow process) waiting for client action (idle wait)',
          'SQL*Net message from dblink'       => 'Waiting for data transfer or remote execution across DB-link',
          'SQL*Net message to client'         => 'Transfer query result to client during fetch operation',
          'transaction'                       => 'Wait for a blocking transaction to be rolled back. Continue waiting until the transaction has been rolled back.',
       }

      sql_select_all("SELECT e.Name Event, t.Name, t.Description
                      FROM   v$Event_Name e
                      JOIN   v$Lock_Type t ON t.Type = SUBSTR(e.Name, 6, 2)
                      WHERE  e.Name like 'enq:%-%contention'
                      ").each do |ev|
        if @@wait_events[ev.event]
          @@wait_events[ev.event] = "#{ev.name}\n#{ev.description}\n(#{@@wait_events[ev.event]})"
        else
          @@wait_events[ev.event] = "#{ev.name}\n#{ev.description}"
        end
      end
    end

    if @@wait_events[event]
      @@wait_events[event].freeze                                               # Prevent content from being changed
    else
      "no explanation available for wait event '#{event}'"
    end
  end

  def explain_wait_state(state)
    case state
      when 'WAITING'             then 'really waiting on given event'
      when 'WAITED KNOWN TIME'   then 'ON CPU. Event is last event process was waiting for. Wait_Time is length of last wait.'
      when 'WAITED UNKNOWN TIME' then 'ON CPU. Event is last event process was waiting for. Last wait time was less than 1 centiscond.'
      when 'WAITED SHORT TIME'   then 'ON CPU. Event is last event process was waiting for. Last wait time was less than 1 centiscond.'
      else "Unknown wait state #{state}. Waiting on CPU. Event is last event process was waiting for."
    end
  end

  def statistic_classes
    [
        {:bit => 128, :name =>  'Debug'},
        {:bit => 64,  :name =>  'SQL'},
        {:bit => 32,  :name =>  'RAC'},
        {:bit => 16,  :name =>  'OS'},
        {:bit => 8,   :name =>  'Cache'},
        {:bit => 4,   :name =>  'Enqueue'},
        {:bit => 2,   :name =>  'Redo'},
        {:bit => 1,   :name =>  'User'},
    ]
  end

    # Statistik-Klassen aus v$stat_name etc.
  def statistic_class(class_id)
    return nil if class_id.nil?
    @class_number = class_id
    @result = ''

    def check_for_class(value, name)
      if @class_number >= value
        @result << "#{name} "
        @class_number -= value
      end
    end

    statistic_classes.each do |stat_class|      # Alle Klassen auf Treffer prüfen
      check_for_class(stat_class[:bit], stat_class[:name])
    end
    @result
  end


  @@sga_names = nil # Cache

  def sga_name_explanation(search_sga_name)
    unless @@sga_names
      @@sga_names = {
          'buffer cache'          => 'Cached database blocks',
          'free memory'           => 'Available free memory in pool for usage',
          'gcs res hash bucket'   => 'Status info of cached data blocks for Global Cache Service (GCS)',
          'gcs resources'         => 'Status info of cached data blocks for Global Cache Service (GCS)',
          'gcs shadows'           => 'Status info of cached data blocks for Global Cache Service (GCS)',
          'KGLH0'                 => 'Kernel generic library heap 0: session specific environment informations for child cursors',
          'shared_io_pool'        => 'Used for handling of LOB secure files',
          'SQLA'                  => 'SQL area (parsed SQL statements)',
      }
    end

    if @@sga_names[search_sga_name]
      @@sga_names[search_sga_name]
    else
      "unknown SGA name '#{search_sga_name}'"
    end
  end

  # detect management pack from feature
  # Details from MOS-Note 1317265.1, Script options_packs_usage_statistics.sql
  def pack_from_feature(feature) 
    retval = {
        'Active Data Guard - Real-Time Query on Physical Standby'           => 'Active Data Guard',
        'ADDM'                                                              => 'Diagnostics Pack',
        'ADVANCED Index Compression'                                        => 'Advanced Compression',
        'Advanced Index Compression'                                        => 'Advanced Compression',
        'Application Express'                                               => :Default,
        'Automatic Maintenance - SQL Tuning Advisor'                        => 'Tuning Pack',
        'Automatic SQL Tuning Advisor'                                      => 'Tuning Pack',
        'Automatic SGA Tuning'                                              => :Default,
        'Automatic Storage Management'                                      => :Default,
        'Automatic Undo Management'                                         => :Default,
        'Automatic Workload Repository'                                     => 'Diagnostics Pack',
        'AWR Baseline'                                                      => 'Diagnostics Pack',
        'AWR Baseline Template'                                             => 'Diagnostics Pack',
        'AWR Report'                                                        => 'Diagnostics Pack',
        'Backup Encryption'                                                 => 'Advanced Security',
        'Backup HIGH Compression'                                           => 'Advanced Compression',
        'Backup LOW Compression'                                            => 'Advanced Compression',
        'Backup MEDIUM Compression'                                         => 'Advanced Compression',
        'Backup ZLIB Compression'                                           => 'Advanced Compression',
        'Baseline Adaptive Thresholds'                                      => 'Diagnostics Pack',
        'Baseline Static Computations'                                      => 'Diagnostics Pack',
        'Change Management Pack'                                            => 'Change Management Pack',
        'Database Replay: Workload Capture'                                 => 'Real Application Testing',
        'Database Replay: Workload Replay'                                  => 'Real Application Testing',
        'Data Guard'                                                        => 'Advanced Compression',
        'Data Masking Pack'                                                 => 'Data Masking Pack',
        'Data Mining'                                                       => 'Advanced Analytics',
        'Data Redaction'                                                    => 'Advanced Security',
        'Diagnostic Pack'                                                   => 'Diagnostics Pack',
        'EM AS Provisioning and Patch Automation Pack'                      => '.WebLogic Server Management Pack Enterprise Edition',
        'EM Config Management Pack'                                         => 'Configuration Management Pack for Oracle Database',
        'EM Database Provisioning and Patch Automation Pack'                => 'Provisioning and Patch Automation Pack for Database',
        'EM Performance Page'                                               => 'Diagnostics Pack',
        'EM Standalone Provisioning and Patch Automation Pack'              => '.Provisioning and Patch Automation Pack',
        'Encrypted Tablespaces'                                             => 'Advanced Security',
        'Exadata'                                                           => '.Exadata',
        'Flashback Data Archive'                                            => 'Advanced Compression',
        'Gateways'                                                          => '.Database Gateway',
        'Global Data Services'                                              => 'Active Data Guard',
        'GoldenGate'                                                        => '.GoldenGate',
        'HeapCompression'                                                   => 'Advanced Compression',
        'Heat Map'                                                          => 'Advanced Compression',
        'Hybrid Columnar Compression Row Level Locking'                     => 'Advanced Compression',
        'Hybrid Columnar Compression'                                       => '.HW',
        'Information Lifecycle Management'                                  => 'Advanced Compression',
        'In-Memory Aggregation'                                             => 'Database In-Memory',
        'In-Memory Column Store'                                            => 'Database In-Memory',
        'Label Security'                                                    => 'Label Security',
        'LOB'                                                               => :Default,
        'Locally Managed Tablespaces (system)'                              => :Default,
        'Materialized Views (User)'                                         => :Default,
        'Object'                                                            => :Default,
        'Oracle Advanced Network Compression Service'                       => 'Advanced Compression',
        'Oracle Database Vault'                                             => 'Database Vault',
        'Oracle Multitenant'                                                => 'Multitenant',
        'Oracle Pluggable Databases'                                        => 'Multitenant',
        'Oracle Secure Backup'                                              => '.Secure Backup',
        'Oracle Utility Datapump (Export)'                                  => 'Advanced Compression',
        'Oracle Utility Datapump (Import)'                                  => 'Advanced Compression',
        'Oracle Utility External Table'                                     => :Default,
        'Oracle Utility SQL Loader (Direct Path Load)'                      => :Default,
        'OLAP - Analytic Workspaces'                                        => 'OLAP',
        'OLAP - Cubes'                                                      => 'OLAP',
        'Partitioning (user)'                                               => 'Partitioning',
        'Partitioning (system)'                                             => :Default,
        'Pillar Storage'                                                    => '.Pillar Storage',
        'Pillar Storage with EHCC'                                          => '.Pillar Storage',
        'Privilege Capture'                                                 => 'Database Vault',
        'Quality of Service Management'                                     => 'RAC or RAC One Node',
        'Real Application Clusters (RAC)'                                   => 'Real Application Clusters',
        'Real Application Cluster One Node'                                 => 'Real Application Clusters One Node',
        'Real-Time SQL Monitoring'                                          => 'Tuning Pack',
        'Result Cache'                                                      => :Default,
        'Spatial'                                                           => 'Spatial and Graph',
        'SecureFile Compression (user)'                                     => 'Advanced Compression',
        'SecureFile Deduplication (user)'                                   => 'Advanced Compression',
        'SecureFile Encryption (user)'                                      => 'Advanced Security',
        'SQL Access Advisor'                                                => 'Tuning Pack',
        'SQL Monitoring and Tuning pages'                                   => 'Tuning Pack',
        'SQL Performance Analyzer'                                          => 'Real Application Testing',
        'SQL Plan Management'                                               => :Default,
        'SQL Profile'                                                       => 'Tuning Pack',
        'SQL Tuning Advisor'                                                => 'Tuning Pack',
        'SQL Tuning Set (user)'                                             => 'Tuning Pack',
        'Sun ZFS with EHCC'                                                 => '.HW',
        'Transparent Data Encryption'                                       => 'Advanced Security',
        'Transparent Gateway'                                               => '.Database Gateway',
        'Tuning Pack'                                                       => 'Tuning Pack',
        'ZFS Storage'                                                       => '.HW',
        'Zone maps'                                                         => 'Partitioning',
    }[feature]
    retval = '### Unknown pack for feature ###' if retval.nil?
    retval
  end

  def policy_event_explanation(search_name)
    policy_events = {
      'initiate_affinity'     => 'Change or fix master role of object to RAC instance',
    }

    if policy_events[search_name]
      policy_events[search_name]
    else
      "unknown policy event '#{search_name}'"
    end
  end



end