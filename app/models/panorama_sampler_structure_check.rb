class PanoramaSamplerStructureCheck
  include ExceptionHelper
  include PanoramaSampler::PackagePanoramaSamplerAsh
  include PanoramaSampler::PackageConDbidFromConId
  include PanoramaSampler::PackagePanoramaSamplerSnapshot
  include PanoramaSampler::PackagePanoramaSamplerBlockingLocks

  def self.domains                                                              # supported domain names
    [:ASH, :AWR, :OBJECT_SIZE, :CACHE_OBJECTS, :BLOCKING_LOCKS, :LONGTERM_TREND]                 # :ASH needs to be first before :AWR
  end

  # Execute the check of schema objects structure
  # @param [PanoramaSamplerConfig] sampler_config The configuration object
  # @param [Symbol] domain The domain the check is executed for
  # @param [TrueClass,FalseClass] force_repeated_execution repeated call as reaction to error or execute on first call only?
  def self.do_check(sampler_config, domain, force_repeated_execution: false)
    raise "Unsupported domain #{domain}" if !domains.include? domain

    case sampler_config.get_structure_check(domain)
    when :running then
      err_msg = "Previous structure check for domain #{domain} not yet finshed, no structure check is done now"
      sampler_config.set_error_message(err_msg)
      msg  = "ID=#{sampler_config.get_id} (#{sampler_config.get_name}): #{err_msg}"
      Rails.logger.error('PanoramaSamplerStructureCheck.do_check') { msg }
      raise msg
    when :finished then
      if force_repeated_execution
        Rails.logger.debug('WorkerThread.do_check') { "Repeated execution for domain #{domain} forced"}
      else
        Rails.logger.debug('WorkerThread.do_check') { "Execution suppressed because initial execution for domain #{domain} already finished"}
        return                                                                    # Nothing to do because already executed for this config / domain
      end
    end

    sampler_config.set_structure_check(domain, :running)                        # Create semaphore for thread, begin processing
    PanoramaSamplerStructureCheck.new(sampler_config).do_check_internal(domain) # Check data structure preconditions for domain
    sampler_config.set_structure_check(domain, :finished)                       # set semaphore for thread, finished processing
  rescue Exception => e
    sampler_config.set_structure_check(domain, :error)                          # Mark erroneous, execute again at next try
    Rails.logger.error('PanoramaSamplerStructureCheck.do_check') { "#{e.class} for ID=#{sampler_config.get_id} (#{sampler_config.get_name}): #{e.message} " }
    sampler_config.set_error_message("Error #{e.class}:#{e.message} during PanoramaSamplerStructureCheck.do_check")
    raise e
  end

  def self.remove_tables(sampler_config)
    PanoramaSamplerStructureCheck.new(sampler_config).remove_tables_internal
  end

  def self.tables
    TABLES
  end

  # Schemas with valid Panorama-Sampler structures for start
  def self.panorama_sampler_schemas(option = nil)
    check_tables = ['PANORAMA_SNAPSHOT', 'PANORAMA_WR_CONTROL', 'PANORAMA_OBJECT_SIZES', 'PANORAMA_CACHE_OBJECTS', 'PANORAMA_BLOCKING_LOCKS', 'LONGTERM_TREND']
    sql = "\
           WITH Tab_Columns AS (
                                SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_Name
                                FROM   All_Tab_Columns
                                WHERE  Table_Name IN (#{check_tables.map{|t| "'#{t}'"}.join(',')})
                               )
           SELECT Owner,
                  NVL(SUM(CASE WHEN Table_Name = 'PANORAMA_SNAPSHOT'        THEN 1 END), 0) snapshot_count,
                  NVL(SUM(CASE WHEN Table_Name = 'PANORAMA_WR_CONTROL'      THEN 1 END), 0) wr_control_count,
                  NVL(SUM(CASE WHEN Table_Name = 'PANORAMA_OBJECT_SIZES'    THEN 1 END), 0) object_sizes_count,
                  NVL(SUM(CASE WHEN Table_Name = 'PANORAMA_CACHE_OBJECTS'   THEN 1 END), 0) cache_objects_count,
                  NVL(SUM(CASE WHEN Table_Name = 'PANORAMA_BLOCKING_LOCKS'  THEN 1 END), 0) blocking_locks_count,
                  NVL(SUM(CASE WHEN Table_Name = 'LONGTERM_TREND'           THEN 1 END), 0) longterm_trend_count
           FROM ("

    # check existence of table with full set of columns
    check_tables.each do |test_table|
      sql << "\nUNION ALL\n" if test_table != 'PANORAMA_SNAPSHOT'                 # not the first table
      sql << "SELECT Owner, Table_Name
              FROM   Tab_Columns
              WHERE  Table_Name = '#{test_table}'
              AND    Column_Name IN ("
      TABLES.each do |table|
        if table[:table_name].upcase == test_table
          table[:columns].each do |column|
            sql << "'#{column[:column_name].upcase}',"
          end
          sql[(sql.length) - 1] = ' '                                           # remove last ,
          sql << ")
          GROUP BY Owner, Table_Name HAVING COUNT(*) = #{table[:columns].count}"  # all columns exists in tables?
        end
      end
    end
    sql << ") GROUP BY Owner"

    panorama_sampler_data = PanoramaConnection.sql_select_all sql

    if option == :full
      panorama_sampler_data.each do |ps|

        if ps.snapshot_count > 0
          dbids = PanoramaConnection.sql_select_first_row "SELECT MAX(DBID) KEEP (DENSE_RANK LAST ORDER BY End_Interval_Time) Last_DBID,
                                                                  COUNT(DISTINCT DBID)                                        DBID_Cnt
                                                           FROM #{ps.owner}.PANORAMA_SNAPSHOT"
          ps[:last_dbid]  = dbids.last_dbid
          ps[:dbid_cnt]   = dbids.dbid_cnt
          unless ps[:last_dbid].nil?
            max_dbid_data = PanoramaConnection.sql_select_first_row ["SELECT COUNT(DISTINCT Instance_Number)  Instances,
                                                                             MIN(Begin_Interval_Time)         Min_Interval_Time,
                                                                             MAX(End_Interval_Time)           Max_interval_time
                                                                      FROM #{ps.owner}.PANORAMA_SNAPSHOT
                                                                      WHERE DBID = ?", ps[:last_dbid]]
            ps[:instances]  = max_dbid_data.instances
            ps[:min_time]   = max_dbid_data.min_interval_time
            ps[:max_time]   = max_dbid_data.max_interval_time
          end
        end

        if ps.wr_control_count > 0
          ps_wr = PanoramaConnection.sql_select_first_row ["SELECT MIN(EXTRACT(HOUR FROM Snap_Interval))*60 + MIN(EXTRACT(MINUTE FROM Snap_Interval)) Snap_Interval_Minutes, MIN(EXTRACT(DAY FROM Retention)) Snap_Retention_Days FROM #{ps.owner}.PANORAMA_WR_Control WHERE DBID = ?", ps[:last_dbid]] if !ps[:last_dbid].nil?
          ps[:snap_interval]  = ps_wr.snap_interval_minutes if ps_wr
          ps[:snap_retention] = ps_wr.snap_retention_days   if ps_wr
        end

        if ps.object_sizes_count > 0
          ps[:object_sizes_min_gather_date] = PanoramaConnection.sql_select_one "SELECT MIN(Gather_Date) FROM #{ps.owner}.PANORAMA_OBJECT_SIZES"
          ps[:object_sizes_max_gather_date] = PanoramaConnection.sql_select_one "SELECT MAX(Gather_Date) FROM #{ps.owner}.PANORAMA_OBJECT_SIZES"
        end

        if ps.cache_objects_count > 0
          ps[:cache_objects_min_snapshot] = PanoramaConnection.sql_select_one "SELECT MIN(Snapshot_Timestamp) FROM #{ps.owner}.PANORAMA_CACHE_OBJECTS"
          ps[:cache_objects_max_snapshot] = PanoramaConnection.sql_select_one "SELECT MAX(Snapshot_Timestamp) FROM #{ps.owner}.PANORAMA_CACHE_OBJECTS"
        end

        if ps.blocking_locks_count > 0
          ps[:blocking_locks_min_snapshot] = PanoramaConnection.sql_select_one "SELECT MIN(Snapshot_Timestamp) FROM #{ps.owner}.PANORAMA_BLOCKING_LOCKS"
          ps[:blocking_locks_max_snapshot] = PanoramaConnection.sql_select_one "SELECT MAX(Snapshot_Timestamp) FROM #{ps.owner}.PANORAMA_BLOCKING_LOCKS"
        end

        if ps.longterm_trend_count > 0
          ps[:longterm_trend_min_snapshot] = PanoramaConnection.sql_select_one "SELECT MIN(Snapshot_Timestamp) FROM #{ps.owner}.LONGTERM_TREND"
          ps[:longterm_trend_max_snapshot] = PanoramaConnection.sql_select_one "SELECT MAX(Snapshot_Timestamp) FROM #{ps.owner}.LONGTERM_TREND"
        end
      end
    end

    panorama_sampler_data
  end

  def self.panorama_table_exists?(table_name)
    return false if PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].nil?
    PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM All_Tables WHERE Table_Name=? and Owner = '#{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].upcase}'", table_name.upcase]) > 0
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config
    @sampler_config = PanoramaSamplerConfig.new(@sampler_config) if @sampler_config.class == Hash
    raise "PanoramaSamplerStructureCheck.intialize: Parameter class Hash or PanoramaSamplerConfig required, got #{@sampler_config.class}" if @sampler_config.class != PanoramaSamplerConfig
  end

  def log(message)
    Rails.logger.info "PanoramaSamplerStructureCheck: #{message} for config ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) "
  end

=begin
  Expexted structure, should contain structure of highest Oracle version:
  [
      {
        table_name: ,
        domain:,
        comment:,
        temporary: empty for regular heap table or 'ON COMMIT DELETE ROWS' or 'ON COMMIT PRESERVE ROWS',
        columns: [
            {
              column_name:
              column_type:
              not_null:
              precision:
              scale:
            }
        ],
        primary_key: { columns: ['col1', 'col2'], compress: 3 }
      }
  ]
=end

  TABLES = [
      {
          table_name: 'Longterm_Trend',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'Snapshot_Timestamp',             column_type:   'DATE',      not_null: true },
              { column_name:  'Instance_Number',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Wait_Class_ID',              column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Wait_Event_ID',              column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_User_ID',                    column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Service_ID',                 column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Machine_ID',                 column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Module_ID',                  column_type:   'NUMBER',    not_null: true },
              { column_name:  'LTT_Action_ID',                  column_type:   'NUMBER',    not_null: true },
              { column_name:  'Seconds_Active',                 column_type:   'NUMBER',    not_null: true },
              { column_name:  'Snapshot_Cycle_Hours',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: false }, # Additional info about source DBID
          ],
          primary_key: { columns: ['Snapshot_Timestamp', 'Instance_Number', 'LTT_Wait_Class_ID', 'LTT_Wait_Event_ID', 'LTT_User_ID', 'LTT_Service_ID', 'LTT_Machine_ID', 'LTT_Module_ID', 'LTT_Action_ID'], compress: 1 },
      },
      {
          table_name: 'Longterm_Trend_Temp',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'Snapshot_Timestamp',             column_type:   'DATE',                      not_null: true },
              { column_name:  'Instance_Number',                column_type:   'NUMBER',                    not_null: true },
              { column_name:  'Wait_Class',                     column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Wait_Event',                     column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'User_ID',                        column_type:   'NUMBER',                    not_null: true },
              { column_name:  'Service_Hash',                   column_type:   'NUMBER',                    not_null: true },
              { column_name:  'Machine',                        column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Module',                         column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Action',                         column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Seconds_Active',                 column_type:   'NUMBER',                    not_null: true },
          ],
      },
      {
          table_name: 'LTT_Wait_Class',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Wait_Class_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_Wait_Event',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Wait_Event_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_User',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_User_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_Service',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Service_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_Machine',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Machine_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_Module',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Module_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'LTT_Action',
          domain: :LONGTERM_TREND,
          columns: [
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128,  not_null: true },
          ],
          primary_key: { columns: ['ID'] },
          indexes: [ {index_name: 'LTT_Action_Name', columns: ['Name'] } ]
      },
      {
          table_name: 'Internal_V$Active_Sess_History',
          domain: :ASH,
          columns: [
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'SAMPLE_ID',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'SAMPLE_TIME',                    column_type:  'TIMESTAMP',  not_null: true, precision: 3 },
              { column_name:  'IS_AWR_SAMPLE',                  column_type:  'VARCHAR2',   precision: 1 },
              { column_name:  'SESSION_ID',                     column_type:  'NUMBER',     not_null: true },
              { column_name:  'SESSION_SERIAL#',                column_type:  'NUMBER' },
              { column_name:  'SESSION_TYPE',                   column_type:  'VARCHAR2',  precision: 10 },
              { column_name:  'FLAGS',                          column_type:  'NUMBER' },
              { column_name:  'USER_ID',                        column_type:  'NUMBER' },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'IS_SQLID_CURRENT',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SQL_CHILD_NUMBER',               column_type:  'NUMBER' },
              { column_name:  'SQL_OPCODE',                     column_type:  'NUMBER' },
              { column_name:  'SQL_OPNAME',                     column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_SQL_ID',               column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'TOP_LEVEL_SQL_OPCODE',           column_type:  'NUMBER' },
              #{ column_name:  'SQL_ADAPTIVE_PLAN_RESOLVED',     column_type:  'NUMBER' },
              #{ column_name:  'SQL_FULL_PLAN_HASH_VALUE',       column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_HASH_VALUE',            column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_LINE_ID',               column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_OPERATION',             column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'SQL_PLAN_OPTIONS',               column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'SQL_EXEC_ID',                    column_type:  'NUMBER' },
              { column_name:  'SQL_EXEC_START',                 column_type:  'DATE' },
              { column_name:  'PLSQL_ENTRY_OBJECT_ID',          column_type:  'NUMBER' },
              { column_name:  'PLSQL_ENTRY_SUBPROGRAM_ID',      column_type:  'NUMBER' },
              { column_name:  'PLSQL_OBJECT_ID',                column_type:  'NUMBER' },
              { column_name:  'PLSQL_SUBPROGRAM_ID',            column_type:  'NUMBER' },
              { column_name:  'QC_INSTANCE_ID',                 column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_ID',                  column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_SERIAL#',             column_type:  'NUMBER' },
              { column_name:  'PX_FLAGS',                       column_type:  'NUMBER' },
              { column_name:  'EVENT',                          column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'EVENT_ID',                       column_type:  'NUMBER' },
              #{ column_name:  'EVENT#',                         column_type:  'NUMBER' },
              { column_name:  'SEQ#',                           column_type:  'NUMBER' },
              { column_name:  'P1TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P1',                             column_type:  'NUMBER' },
              { column_name:  'P2TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P2',                             column_type:  'NUMBER' },
              { column_name:  'P3TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P3',                             column_type:  'NUMBER' },
              { column_name:  'WAIT_CLASS',                     column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'WAIT_CLASS_ID',                  column_type:  'NUMBER' },
              { column_name:  'WAIT_TIME',                      column_type:  'NUMBER' },
              { column_name:  'SESSION_STATE',                  column_type:  'VARCHAR2', precision: 7 },
              { column_name:  'TIME_WAITED',                    column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_STATUS',        column_type:  'VARCHAR2', precision: 11 },
              { column_name:  'BLOCKING_SESSION',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_SERIAL#',       column_type:  'NUMBER' },
              { column_name:  'BLOCKING_INST_ID',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_HANGCHAIN_INFO',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CURRENT_OBJ#',                   column_type:  'NUMBER' },
              { column_name:  'CURRENT_FILE#',                  column_type:  'NUMBER' },
              { column_name:  'CURRENT_BLOCK#',                 column_type:  'NUMBER' },
              { column_name:  'CURRENT_ROW#',                   column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_CALL#',                column_type:  'NUMBER' },
              { column_name:  'CONSUMER_GROUP_ID',              column_type:  'NUMBER' },
              { column_name:  'XID',                            column_type:  'RAW', precision: 8 },
              { column_name:  'REMOTE_INSTANCE#',               column_type:  'NUMBER' },
              { column_name:  'TIME_MODEL',                     column_type:  'NUMBER' },
              { column_name:  'IN_CONNECTION_MGMT',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PARSE',                       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_HARD_PARSE',                  column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SQL_EXECUTION',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_EXECUTION',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_RPC',                   column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_COMPILATION',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_JAVA_EXECUTION',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_BIND',                        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_CURSOR_CLOSE',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SEQUENCE_LOAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_QUERY',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_POPULATE',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_PREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_REPOPULATE',         column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_TREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_TABLESPACE_ENCRYPTION',       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CAPTURE_OVERHEAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'REPLAY_OVERHEAD',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_CAPTURED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_REPLAYED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SERVICE_HASH',                   column_type:  'NUMBER' },
              { column_name:  'PROGRAM',                        column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'MODULE',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'ACTION',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'CLIENT_ID',                      column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'MACHINE',                        column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'PORT',                           column_type:  'NUMBER' },
              { column_name:  'ECID',                           column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'DBREPLAY_FILE_ID',               column_type:  'NUMBER' },
              { column_name:  'DBREPLAY_CALL_COUNTER',          column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_TIME',                  column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_CPU_TIME',              column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_DB_TIME',               column_type:  'NUMBER' },
              { column_name:  'DELTA_TIME',                     column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_REQUESTS',         column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_REQUESTS',        column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_BYTES',            column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_BYTES',           column_type:  'NUMBER' },
              { column_name:  'DELTA_INTERCONNECT_IO_BYTES',    column_type:  'NUMBER' },
              { column_name:  'PGA_ALLOCATED',                  column_type:  'NUMBER' },
              { column_name:  'TEMP_SPACE_ALLOCATED',           column_type:  'NUMBER' },
              { column_name:  'Con_ID',                         column_type:  'NUMBER', not_null: true  },
              { column_name:  'Preserve_10Secs',                column_type:  'VARCHAR2', precision: 1  },  # Marker for long term preservation
              #{ column_name:  'DBOP_NAME',                      column_type:  'VARCHAR2', precision: 30 },
              #{ column_name:  'DBOP_EXEC_ID',                   column_type:  'NUMBER' },
          ],
          primary_key: { columns: ['INSTANCE_NUMBER', 'SESSION_ID', 'SAMPLE_ID'] },    # ensure that copying data into Panorama_Active_Sess_History does never raise PK-violation
      },
      {
          table_name: 'Internal_Active_Sess_History',
          domain: :AWR,
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'SAMPLE_ID',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'SAMPLE_TIME',                    column_type:  'TIMESTAMP',  not_null: true, precision: 3 },
              { column_name:  'SESSION_ID',                     column_type:  'NUMBER',     not_null: true },
              { column_name:  'SESSION_SERIAL#',                column_type:  'NUMBER' },
              { column_name:  'SESSION_TYPE',                   column_type:  'VARCHAR2',  precision: 10 },
              { column_name:  'FLAGS',                          column_type:  'NUMBER' },
              { column_name:  'USER_ID',                        column_type:  'NUMBER' },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'IS_SQLID_CURRENT',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SQL_CHILD_NUMBER',               column_type:  'NUMBER' },
              { column_name:  'SQL_OPCODE',                     column_type:  'NUMBER' },
              { column_name:  'SQL_OPNAME',                     column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_SQL_ID',               column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'TOP_LEVEL_SQL_OPCODE',           column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_HASH_VALUE',            column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_LINE_ID',               column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_OPERATION',             column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'SQL_PLAN_OPTIONS',               column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'SQL_EXEC_ID',                    column_type:  'NUMBER' },
              { column_name:  'SQL_EXEC_START',                 column_type:  'DATE' },
              { column_name:  'PLSQL_ENTRY_OBJECT_ID',          column_type:  'NUMBER' },
              { column_name:  'PLSQL_ENTRY_SUBPROGRAM_ID',      column_type:  'NUMBER' },
              { column_name:  'PLSQL_OBJECT_ID',                column_type:  'NUMBER' },
              { column_name:  'PLSQL_SUBPROGRAM_ID',            column_type:  'NUMBER' },
              { column_name:  'QC_INSTANCE_ID',                 column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_ID',                  column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_SERIAL#',             column_type:  'NUMBER' },
              { column_name:  'PX_FLAGS',                       column_type:  'NUMBER' },
              { column_name:  'EVENT',                          column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'EVENT_ID',                       column_type:  'NUMBER' },
              { column_name:  'SEQ#',                           column_type:  'NUMBER' },
              { column_name:  'P1TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P1',                             column_type:  'NUMBER' },
              { column_name:  'P2TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P2',                             column_type:  'NUMBER' },
              { column_name:  'P3TEXT',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'P3',                             column_type:  'NUMBER' },
              { column_name:  'WAIT_CLASS',                     column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'WAIT_CLASS_ID',                  column_type:  'NUMBER' },
              { column_name:  'WAIT_TIME',                      column_type:  'NUMBER' },
              { column_name:  'SESSION_STATE',                  column_type:  'VARCHAR2', precision: 7 },
              { column_name:  'TIME_WAITED',                    column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_STATUS',        column_type:  'VARCHAR2', precision: 11 },
              { column_name:  'BLOCKING_SESSION',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_SERIAL#',       column_type:  'NUMBER' },
              { column_name:  'BLOCKING_INST_ID',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_HANGCHAIN_INFO',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CURRENT_OBJ#',                   column_type:  'NUMBER' },
              { column_name:  'CURRENT_FILE#',                  column_type:  'NUMBER' },
              { column_name:  'CURRENT_BLOCK#',                 column_type:  'NUMBER' },
              { column_name:  'CURRENT_ROW#',                   column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_CALL#',                column_type:  'NUMBER' },
              { column_name:  'CONSUMER_GROUP_ID',              column_type:  'NUMBER' },
              { column_name:  'XID',                            column_type:  'RAW', precision: 8 },
              { column_name:  'REMOTE_INSTANCE#',               column_type:  'NUMBER' },
              { column_name:  'TIME_MODEL',                     column_type:  'NUMBER' },
              { column_name:  'IN_CONNECTION_MGMT',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PARSE',                       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_HARD_PARSE',                  column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SQL_EXECUTION',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_EXECUTION',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_RPC',                   column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_COMPILATION',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_JAVA_EXECUTION',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_BIND',                        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_CURSOR_CLOSE',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SEQUENCE_LOAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_QUERY',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_POPULATE',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_PREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_REPOPULATE',         column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_TREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_TABLESPACE_ENCRYPTION',       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CAPTURE_OVERHEAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'REPLAY_OVERHEAD',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_CAPTURED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_REPLAYED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SERVICE_HASH',                   column_type:  'NUMBER' },
              { column_name:  'PROGRAM',                        column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'MODULE',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'ACTION',                         column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'CLIENT_ID',                      column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'MACHINE',                        column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'PORT',                           column_type:  'NUMBER' },
              { column_name:  'ECID',                           column_type:  'VARCHAR2', precision: 128 },
              { column_name:  'DBREPLAY_FILE_ID',               column_type:  'NUMBER' },
              { column_name:  'DBREPLAY_CALL_COUNTER',          column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_TIME',                  column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_CPU_TIME',              column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_DB_TIME',               column_type:  'NUMBER' },
              { column_name:  'DELTA_TIME',                     column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_REQUESTS',         column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_REQUESTS',        column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_BYTES',            column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_BYTES',           column_type:  'NUMBER' },
              { column_name:  'DELTA_INTERCONNECT_IO_BYTES',    column_type:  'NUMBER' },
              { column_name:  'PGA_ALLOCATED',                  column_type:  'NUMBER' },
              { column_name:  'TEMP_SPACE_ALLOCATED',           column_type:  'NUMBER' },
              { column_name:  'Con_DBID',                       column_type:  'NUMBER',     not_null: true },
              { column_name:  'Con_ID',                         column_type:  'NUMBER',     not_null: true },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'SAMPLE_ID', 'SESSION_ID', 'Con_DBID'], compress: 2 },
      },
      {
        table_name: 'Panorama_ASH_Counter',
        domain: :ASH,
        comment: 'Simple counter table to increment session overarching counters',
        columns: [
          { column_name:  'Instance_Number',                column_type:   'NUMBER',    not_null: true },
          { column_name:  'ASH_Run_ID',                     column_type:   'NUMBER',    not_null: true, comment: 'Run ID of current ASH daemon (cycles with AWR snapshots)' },
          { column_name:  'Last_Snap_Max_Ash_Sample_ID',    column_type:   'NUMBER',    not_null: false, comment: 'Sample_ID of ASH up to which all 1-second samples are already transferred to 10-second samples table' },
        ],
        primary_key: { columns: ['Instance_Number'] }
      },
      {
          table_name: 'Panorama_Blocking_Locks',
          domain: :BLOCKING_LOCKS,
          columns: [
              { column_name:  'Snapshot_Timestamp',             column_type:   'DATE',      not_null: true,                 comment: 'Timestamp of recognition of blocking lock'},
              { column_name:  'Instance_Number',                column_type:   'NUMBER',    not_null: true,                 comment: 'RAC-instance' },
              { column_name:  'SID',                            column_type:   'NUMBER',    not_null: true,                 comment: 'SID of blocked session' },
              { column_name:  'Serial_No',                      column_type:   'NUMBER',    not_null: false,                comment: 'Serial number of blocked session. Nullable due to backward compatibility.' },
              { column_name:  'SQL_ID',                         column_type:   'VARCHAR2',  precision: 13,                  comment: 'SQL-ID of active statement' },
              { column_name:  'SQL_Child_Number',               column_type:   'NUMBER',                                    comment: 'Child number of active statement' },
              { column_name:  'Prev_SQL_ID',                    column_type:   'VARCHAR2',  precision: 13,                  comment: 'Previously executed SQL-ID' },
              { column_name:  'Prev_Child_Number',              column_type:   'NUMBER',                                    comment: 'Previously executed child number' },
              { column_name:  'Status',                         column_type:   'VARCHAR2',  precision: 8,                   comment: 'Status of blocked session' },
              { column_name:  'Event',                          column_type:   'VARCHAR2',  precision: 128,                 comment: 'Wait event of blocked session' },
              { column_name:  'Client_Info',                    column_type:   'VARCHAR2',  precision: 128,                 comment: 'Client info of blocked session'},
              { column_name:  'Module',                         column_type:   'VARCHAR2',  precision: 128,                 comment: 'Module of blocked session' },
              { column_name:  'Action',                         column_type:   'VARCHAR2',  precision: 128,                 comment: 'Action of blocked session' },
              { column_name:  'Object_Owner',                   column_type:   'VARCHAR2',  precision: 128,                 comment: 'Owner of object waiting for lock' },
              { column_name:  'Object_Name',                    column_type:   'VARCHAR2',  precision: 128,                 comment: 'Name of object waiting for lock' },
              { column_name:  'User_Name',                      column_type:   'VARCHAR2',  precision: 128,                 comment: 'Owner of blocked session' },
              { column_name:  'Machine',                        column_type:   'VARCHAR2',  precision: 128,                 comment: 'Machine of blocked session' },
              { column_name:  'OS_User',                        column_type:   'VARCHAR2',  precision: 128,                 comment: 'OS-user of blocked session' },
              { column_name:  'Process',                        column_type:   'VARCHAR2',  precision: 128,                 comment: 'Process-ID of blocked session' },
              { column_name:  'Program',                        column_type:   'VARCHAR2',  precision: 128,                 comment: 'Program of blocked session' },
              { column_name:  'Lock_Type',                      column_type:   'VARCHAR2',  precision: 2,                   comment: 'Lock type of blocked session' },
              { column_name:  'Seconds_In_Wait',                column_type:   'NUMBER',                                    comment: 'Number of seconds in current wait state' },
              { column_name:  'ID1',                            column_type:   'NUMBER',                                    comment: 'ID1 of lock' },
              { column_name:  'ID2',                            column_type:   'NUMBER',                                    comment: 'ID2 of lock' },
              { column_name:  'Request',                        column_type:   'NUMBER',    precision: 1,                   comment: 'Requested lock mode' },
              { column_name:  'Lock_Mode',                      column_type:   'NUMBER',    precision: 1,                   comment: 'Held lock mode' },
              { column_name:  'Blocking_Object_Owner',          column_type:   'VARCHAR2',  precision: 128,                 comment: 'Owner of object session waits for unblocking' },
              { column_name:  'Blocking_Object_Name',           column_type:   'VARCHAR2',  precision: 128,                 comment: 'Name of object session waits for unblocking' },
              { column_name:  'Blocking_RowID',                 column_type:   'UROWID',                                    comment: 'RowID of record blocked session is waiting for' },
              { column_name:  'Blocking_Instance_Number',       column_type:   'NUMBER',                                    comment: 'Instance of blocking session' },
              { column_name:  'Blocking_SID',                   column_type:   'NUMBER',                                    comment: 'Session-ID of blocking session' },
              { column_name:  'Blocking_Serial_No',             column_type:   'NUMBER',                                    comment: 'Serial number of blocking session' },
              { column_name:  'Blocking_SQL_ID',                column_type:   'VARCHAR2',  precision: 13,                  comment: 'SQL-ID of active statement of blocking session' },
              { column_name:  'Blocking_SQL_Child_Number',      column_type:   'NUMBER',                                    comment: 'Child number of active statement of blocking session' },
              { column_name:  'Blocking_Prev_SQL_ID',           column_type:   'VARCHAR2',  precision: 13,                  comment: 'Previously executed SQL-ID of blocking session' },
              { column_name:  'Blocking_Prev_Child_Number',     column_type:   'NUMBER',                                    comment: 'Previously executed child number of blocking session' },
              { column_name:  'Blocking_Status',                column_type:   'VARCHAR2',  precision: 8,                   comment: 'Status of blocking session' },
              { column_name:  'Blocking_Event',                 column_type:   'VARCHAR2',  precision: 128,                 comment: 'Wait event of blocking session' },
              { column_name:  'Blocking_Client_Info',           column_type:   'VARCHAR2',  precision: 128,                 comment: 'Client info of blocking session'},
              { column_name:  'Blocking_Module',                column_type:   'VARCHAR2',  precision: 128,                 comment: 'Module of blocking session' },
              { column_name:  'Blocking_Action',                column_type:   'VARCHAR2',  precision: 128,                 comment: 'Action of blocking session' },
              { column_name:  'Blocking_User_Name',             column_type:   'VARCHAR2',  precision: 128,                 comment: 'Owner of blocking session' },
              { column_name:  'Blocking_Machine',               column_type:   'VARCHAR2',  precision: 128,                 comment: 'Machine of blocking session' },
              { column_name:  'Blocking_OS_User',               column_type:   'VARCHAR2',  precision: 128,                 comment: 'OS-user of blocking session' },
              { column_name:  'Blocking_Process',               column_type:   'VARCHAR2',  precision: 12,                  comment: 'Process-ID of blocking session' },
              { column_name:  'Blocking_Program',               column_type:   'VARCHAR2',  precision: 128,                 comment: 'Program of blocking session' },
              { column_name:  'Waiting_For_PK_Column_Name',     column_type:   'VARCHAR2',  precision: 300,                 comment: 'Column name(s) of primary key of table waiting for unblocking' },
              { column_name:  'Waiting_For_PK_Value',           column_type:   'VARCHAR2',  precision: 128,                 comment: 'Primary key content of table-record waiting for unblocking' },
          ],
          indexes: [ {index_name: 'Panorama_Blocking_Locks_TS', columns: ['Snapshot_Timestamp'], compress: 1 } ]
      },
      {
          table_name: 'Panorama_Cache_Objects',
          domain: :CACHE_OBJECTS,
          columns: [
              { column_name:  'Snapshot_Timestamp',             column_type:   'DATE',      not_null: true },
              { column_name:  'Instance_Number',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'Owner',                          column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128, not_null: true },
              { column_name:  'Partition_Name',                 column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'Blocks_Total',                   column_type:   'NUMBER',    not_null: true },
              { column_name:  'Blocks_Dirty',                   column_type:   'NUMBER',    not_null: true },
          ],
          indexes: [ {index_name: 'Panorama_Cache_Objects_TS', columns: ['Snapshot_Timestamp', 'Instance_Number'], compress: 1 } ]
      },
      {
        table_name: 'Panorama_Database_Instance',
        domain: :AWR,
        columns: [
          { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
          { column_name:  'Instance_Number',                column_type:   'NUMBER',    not_null: true },
          { column_name:  'Startup_Time',                   column_type:   'TIMESTAMP', not_null: true, precision: 3 },
          { column_name:  'Parallel',                       column_type:   'VARCHAR2',  not_null: true, precision: 3 },
          { column_name:  'Version',                        column_type:   'VARCHAR2',  not_null: true, precision: 17 },
          { column_name:  'DB_Name',                        column_type:   'VARCHAR2',  precision: 9 },
          { column_name:  'Instance_Name',                  column_type:   'VARCHAR2',  precision: 16},
          { column_name:  'Host_Name',                      column_type:   'VARCHAR2',  precision: 64},
          { column_name:  'Last_ASH_Sample_ID',             column_type:   'NUMBER' },
          { column_name:  'Platform_Name',                  column_type:   'VARCHAR2',  precision: 101},
          { column_name:  'CDB',                            column_type:   'VARCHAR2',  precision: 3},
          { column_name:  'Edition',                        column_type:   'VARCHAR2',  precision: 7},
          { column_name:  'DB_Unique_Name',                 column_type:   'VARCHAR2',  precision: 30},
          { column_name:  'Database_Role',                  column_type:   'VARCHAR2',  precision: 16},
          { column_name:  'CDB_Root_DBID',                  column_type:   'NUMBER' },
          { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          { column_name:  'Startup_Time_TZ',           column_type:  'TIMESTAMP (3) WITH TIME ZONE' },
        ],
        primary_key: { columns: ['DBID', 'Instance_Number', 'Startup_Time'] },
      },
      {
          table_name: 'Panorama_Datafile',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILE#',                          column_type:   'NUMBER',    not_null: true },
              { column_name:  'CREATION_CHANGE#',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILENAME',                       column_type:   'VARCHAR2',  not_null: true, precision: 513 },
              { column_name:  'TS#',                            column_type:   'NUMBER',    not_null: true },
              { column_name:  'TSNAME',                         column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'BLOCK_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'FILE#', 'CREATION_CHANGE#', 'CON_DBID'] },
      },
      {
          table_name: 'Panorama_DB_Cache_Advice',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'BPID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'BUFFERS_FOR_ESTIMATE',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'NAME',                           column_type:   'VARCHAR2',  precision: 20 },
              { column_name:  'BLOCK_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'ADVICE_STATUS',                  column_type:   'VARCHAR2',  precision: 3 },
              { column_name:  'SIZE_FOR_ESTIMATE',              column_type:   'NUMBER' },
              { column_name:  'SIZE_FACTOR',                    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS',                 column_type:   'NUMBER' },
              { column_name:  'BASE_PHYSICAL_READS',            column_type:   'NUMBER' },
              { column_name:  'ACTUAL_PHYSICAL_READS',          column_type:   'NUMBER' },
              { column_name:  'ESTD_PHYSICAL_READ_TIME',        column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER', not_null: true  },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'BPID', 'BUFFERS_FOR_ESTIMATE', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_Enqueue_Stat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'EQ_TYPE',                        column_type:   'VARCHAR2',  not_null: true, precision: 2 },
              { column_name:  'REQ_REASON',                     column_type:   'VARCHAR2',  not_null: true, precision: 64 },
              { column_name:  'TOTAL_REQ#',                     column_type:   'NUMBER' },
              { column_name:  'TOTAL_WAIT#',                    column_type:   'NUMBER' },
              { column_name:  'SUCC_REQ#',                      column_type:   'NUMBER' },
              { column_name:  'FAILED_REQ#',                    column_type:   'NUMBER' },
              { column_name:  'CUM_WAIT_TIME',                  column_type:   'NUMBER' },
              { column_name:  'EVENT#',                         column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'EQ_TYPE', 'REQ_REASON', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Internal_FileStatXS',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILE#',                          column_type:   'NUMBER',    not_null: true },
              { column_name:  'CREATION_CHANGE#',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'PHYRDS',                         column_type:   'NUMBER' },
              { column_name:  'PHYWRTS',                        column_type:   'NUMBER' },
              { column_name:  'SINGLEBLKRDS',                   column_type:   'NUMBER' },
              { column_name:  'READTIM',                        column_type:   'NUMBER' },
              { column_name:  'WRITETIM',                       column_type:   'NUMBER' },
              { column_name:  'SINGLEBLKRDTIM',                 column_type:   'NUMBER' },
              { column_name:  'PHYBLKRD',                       column_type:   'NUMBER' },
              { column_name:  'PHYBLKWRT',                      column_type:   'NUMBER' },
              { column_name:  'WAIT_COUNT',                     column_type:   'NUMBER' },
              { column_name:  'TIME',                           column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYBLKRD',             column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'FILE#', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_IOStat_Detail',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'FUNCTION_ID',                    column_type:   'NUMBER',    not_null: true },
              { column_name:  'FUNCTION_NAME',                  column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'FILETYPE_ID',                    column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILETYPE_NAME',                  column_type:   'VARCHAR2',  not_null: true, precision: 30 },
              { column_name:  'SMALL_READ_MEGABYTES',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_WRITE_MEGABYTES',          column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_READ_MEGABYTES',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_WRITE_MEGABYTES',          column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_READ_REQS',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_WRITE_REQS',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_READ_REQS',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_WRITE_REQS',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'NUMBER_OF_WAITS',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'WAIT_TIME',                      column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'FUNCTION_ID', 'FILETYPE_ID', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_IOStat_Filetype',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILETYPE_ID',                    column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILETYPE_NAME',                  column_type:   'VARCHAR2',  not_null: true, precision: 30 },
              { column_name:  'SMALL_READ_MEGABYTES',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_WRITE_MEGABYTES',          column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_READ_MEGABYTES',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_WRITE_MEGABYTES',          column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_READ_REQS',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_WRITE_REQS',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_SYNC_READ_REQS',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_READ_REQS',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_WRITE_REQS',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_READ_SERVICETIME',         column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_WRITE_SERVICETIME',        column_type:   'NUMBER',    not_null: true },
              { column_name:  'SMALL_SYNC_READ_LATENCY',        column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_READ_SERVICETIME',         column_type:   'NUMBER',    not_null: true },
              { column_name:  'LARGE_WRITE_SERVICETIME',        column_type:   'NUMBER',    not_null: true },
              { column_name:  'RETRIES_ON_ERROR',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'FILETYPE_ID', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_Latch',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'LATCH_HASH',                     column_type:   'NUMBER',    not_null: true },
              { column_name:  'LATCH_NAME',                     column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'LEVEL#',                         column_type:   'NUMBER' },
              { column_name:  'GETS',                           column_type:   'NUMBER' },
              { column_name:  'MISSES',                         column_type:   'NUMBER' },
              { column_name:  'SLEEPS',                         column_type:   'NUMBER' },
              { column_name:  'IMMEDIATE_GETS',                 column_type:   'NUMBER' },
              { column_name:  'IMMEDIATE_MISSES',               column_type:   'NUMBER' },
              { column_name:  'SPIN_GETS',                      column_type:   'NUMBER' },
              { column_name:  'SLEEP1',                         column_type:   'NUMBER' },
              { column_name:  'SLEEP2',                         column_type:   'NUMBER' },
              { column_name:  'SLEEP3',                         column_type:   'NUMBER' },
              { column_name:  'SLEEP4',                         column_type:   'NUMBER' },
              { column_name:  'WAIT_TIME',                      column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',     not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'LATCH_HASH', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_Log',
          domain: :AWR,
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true },
              { column_name:  'Group#',                         column_type:  'NUMBER',     not_null: true },
              { column_name:  'Thread#',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'Sequence#',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'Bytes',                          column_type:  'NUMBER' },
              { column_name:  'Members',                        column_type:  'NUMBER' },
              { column_name:  'Archived',                       column_type:  'VARCHAR2', precision: 3 },
              { column_name:  'Status',                         column_type:  'VARCHAR2', precision: 16 },
              { column_name:  'First_Change#',                  column_type:  'NUMBER' },
              { column_name:  'First_Time',                     column_type:  'DATE' },
              { column_name:  'Con_DBID',                       column_type:  'NUMBER',     not_null: true  },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'Snap_ID', 'Instance_Number', 'Group#', 'Thread#', 'Sequence#', 'Con_DBID'], compress: 2 }
      },
      {
          table_name: 'Panorama_Memory_Resize_Ops',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'COMPONENT',                      column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'OPER_TYPE',                      column_type:   'VARCHAR2',  not_null: true, precision: 13 },
              { column_name:  'START_TIME',                     column_type:   'DATE',      not_null: true },
              { column_name:  'END_TIME',                       column_type:   'DATE',      not_null: true },
              { column_name:  'TARGET_SIZE',                    column_type:   'NUMBER',    not_null: true },
              { column_name:  'OPER_MODE',                      column_type:   'VARCHAR2',  precision: 9 },
              { column_name:  'PARAMETER',                      column_type:   'VARCHAR2',  precision: 80 },
              { column_name:  'INITIAL_SIZE',                   column_type:   'NUMBER' },
              { column_name:  'FINAL_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'STATUS',                         column_type:   'VARCHAR2',  precision: 9 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'COMPONENT', 'OPER_TYPE', 'START_TIME', 'TARGET_SIZE', 'CON_DBID'], compress: 2 }
      },
      {
          table_name: 'Panorama_Metric_Name',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'GROUP_ID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'GROUP_NAME',                     column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'METRIC_ID',                      column_type:   'NUMBER',    not_null: true },
              { column_name:  'METRIC_NAME',                    column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'METRIC_UNIT',                    column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'Group_ID', 'Metric_ID', 'Con_DBID'], compress: 2 }
      },
      {
          table_name: 'Panorama_Object_Sizes',
          domain: :OBJECT_SIZE,
          columns: [
              { column_name:  'Owner',                          column_type:  'VARCHAR2', precision: 128,  not_null: true },
              { column_name:  'Segment_Name',                   column_type:  'VARCHAR2', precision: 128,  not_null: true },
              { column_name:  'Segment_Type',                   column_type:  'VARCHAR2', precision: 128,  not_null: true },
              { column_name:  'Tablespace_Name',                column_type:  'VARCHAR2', precision: 128,  not_null: true },
              { column_name:  'Gather_Date',                    column_type:  'DATE',     not_null: true },
              { column_name:  'Bytes',                          column_type:  'NUMBER',   not_null: true },
              { column_name:  'Num_Rows',                       column_type:  'NUMBER'   },
          ],
          primary_key: { columns: ['Owner', 'Segment_Name', 'Segment_Type', 'Tablespace_Name', 'Gather_Date'], compress: 4 },
          indexes: [ {index_name: 'Panorama_Object_Sizes_Gather', columns: ['Gather_Date'], compress: 1 } ]
      },
      {
          table_name: 'Internal_OSStat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:  'NUMBER',  not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',  not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:  'NUMBER',  not_null: true },
              { column_name:  'Stat_ID',                        column_type:  'NUMBER',  not_null: true },
              { column_name:  'Value',                          column_type:  'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:  'NUMBER',  not_null: true },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'STAT_ID', 'CON_DBID'], compress: 3 },
      },
      {
          table_name: 'Panorama_OSStat_Name',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:  'NUMBER',  not_null: true },
              { column_name:  'Stat_ID',                        column_type:  'NUMBER',  not_null: true },
              { column_name:  'Stat_Name',                      column_type:  'VARCHAR2', precision: 128,  not_null: true },
              { column_name:  'CON_DBID',                       column_type:  'NUMBER',  not_null: true },
          ],
          primary_key: { columns: ['DBID', 'STAT_ID', 'CON_DBID'], compress: 1 },
      },
      {
          table_name: 'Panorama_Parameter',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                      column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                         column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',              column_type:   'NUMBER',    not_null: true },
              { column_name:  'PARAMETER_HASH',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'PARAMETER_NAME',               column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'VALUE',                        column_type:   'VARCHAR2',  precision: 512 },
              { column_name:  'ISDEFAULT',                    column_type:   'VARCHAR2',  precision: 9 },
              { column_name:  'ISMODIFIED',                   column_type:   'VARCHAR2',  precision: 10 },
              { column_name:  'CON_DBID',                     column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                       column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'PARAMETER_HASH', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_PGAStat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'NAME',                           column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'VALUE',                          column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID', 'Snap_ID', 'Instance_Number', 'Name', 'Con_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_Process_Mem_Summary',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'CATEGORY',                       column_type:   'VARCHAR2',  not_null: true, precision: 15 },
              { column_name:  'IS_INSTANCE_WIDE',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'NUM_PROCESSES',                  column_type:   'NUMBER' },
              { column_name:  'NON_ZERO_ALLOCS',                column_type:   'NUMBER' },
              { column_name:  'USED_TOTAL',                     column_type:   'NUMBER' },
              { column_name:  'ALLOCATED_TOTAL',                column_type:   'NUMBER' },
              { column_name:  'ALLOCATED_AVG',                  column_type:   'NUMBER' },
              { column_name:  'ALLOCATED_STDDEV',               column_type:   'NUMBER' },
              { column_name:  'ALLOCATED_MAX',                  column_type:   'NUMBER' },
              { column_name:  'MAX_ALLOCATED_MAX',              column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'CATEGORY', 'CON_DBID', 'IS_INSTANCE_WIDE'], compress: 2 },
      },
      {
          table_name: 'Panorama_Resource_Limit',
          domain: :AWR,
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',                     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',                     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',                     not_null: true },
              { column_name:  'Resource_Name',                  column_type:  'VARCHAR2',   precision: 30,  not_null: true },
              { column_name:  'Current_Utilization',            column_type:  'NUMBER'  },
              { column_name:  'Max_Utilization',                column_type:  'NUMBER'  },
              { column_name:  'Initial_Allocation',             column_type:  'VARCHAR2',   precision: 10,  not_null: true },
              { column_name:  'Limit_Value',                    column_type:  'VARCHAR2',   precision: 10,  not_null: true },
              { column_name:  'Con_DBID',                       column_type:  'NUMBER',     not_null: true  },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'RESOURCE_NAME', 'CON_DBID'], compress: 2 }
      },
      {
          table_name: 'Panorama_Seg_Stat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'TS#',                            column_type:   'NUMBER',    not_null: true },
              { column_name:  'OBJ#',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'DATAOBJ#',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'LOGICAL_READS_TOTAL',            column_type:   'NUMBER' },
              { column_name:  'LOGICAL_READS_DELTA',            column_type:   'NUMBER' },
              { column_name:  'BUFFER_BUSY_WAITS_TOTAL',        column_type:   'NUMBER' },
              { column_name:  'BUFFER_BUSY_WAITS_DELTA',        column_type:   'NUMBER' },
              { column_name:  'DB_BLOCK_CHANGES_TOTAL',         column_type:   'NUMBER' },
              { column_name:  'DB_BLOCK_CHANGES_DELTA',         column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS_TOTAL',           column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS_DELTA',           column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITES_TOTAL',          column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITES_DELTA',          column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS_DIRECT_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS_DIRECT_DELTA',    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITES_DIRECT_TOTAL',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITES_DIRECT_DELTA',   column_type:   'NUMBER' },
              { column_name:  'ITL_WAITS_TOTAL',                column_type:   'NUMBER' },
              { column_name:  'ITL_WAITS_DELTA',                column_type:   'NUMBER' },
              { column_name:  'ROW_LOCK_WAITS_TOTAL',           column_type:   'NUMBER' },
              { column_name:  'ROW_LOCK_WAITS_DELTA',           column_type:   'NUMBER' },
              { column_name:  'GC_CR_BLOCKS_SERVED_TOTAL',      column_type:   'NUMBER' },
              { column_name:  'GC_CR_BLOCKS_SERVED_DELTA',      column_type:   'NUMBER' },
              { column_name:  'GC_CU_BLOCKS_SERVED_TOTAL',      column_type:   'NUMBER' },
              { column_name:  'GC_CU_BLOCKS_SERVED_DELTA',      column_type:   'NUMBER' },
              { column_name:  'GC_BUFFER_BUSY_TOTAL',           column_type:   'NUMBER' },
              { column_name:  'GC_BUFFER_BUSY_DELTA',           column_type:   'NUMBER' },
              { column_name:  'GC_CR_BLOCKS_RECEIVED_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'GC_CR_BLOCKS_RECEIVED_DELTA',    column_type:   'NUMBER' },
              { column_name:  'GC_CU_BLOCKS_RECEIVED_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'GC_CU_BLOCKS_RECEIVED_DELTA',    column_type:   'NUMBER' },
              { column_name:  'SPACE_USED_TOTAL',               column_type:   'NUMBER' },
              { column_name:  'SPACE_USED_DELTA',               column_type:   'NUMBER' },
              { column_name:  'SPACE_ALLOCATED_TOTAL',          column_type:   'NUMBER' },
              { column_name:  'SPACE_ALLOCATED_DELTA',          column_type:   'NUMBER' },
              { column_name:  'TABLE_SCANS_TOTAL',              column_type:   'NUMBER' },
              { column_name:  'TABLE_SCANS_DELTA',              column_type:   'NUMBER' },
              { column_name:  'CHAIN_ROW_EXCESS_TOTAL',         column_type:   'NUMBER' },
              { column_name:  'CHAIN_ROW_EXCESS_DELTA',         column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_TOTAL',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_DELTA',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_DELTA',  column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_TOTAL', column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_DELTA', column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'TS#', 'OBJ#', 'DATAOBJ#', 'CON_DBID'], compress: 4 },
          indexes: [ {index_name: 'Panorama_Seg_Stat_Max_Snap_ID', columns: ['DBID', 'INSTANCE_NUMBER', 'TS#', 'OBJ#', 'DATAOBJ#', 'CON_DBID', 'SNAP_ID'], compress: 3 } ]
      },
      {
          table_name: 'Panorama_Service_Name',
          domain: :ASH,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'SERVICE_NAME_HASH',              column_type:   'NUMBER',    not_null: true },
              { column_name:  'SERVICE_NAME',                   column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER',    not_null: true },
          ],
          primary_key: { columns: ['DBID', 'Service_Name', 'Con_DBID'] },
      },
      {
        table_name: 'Panorama_SGAStat',
        domain: :AWR,
        columns: [
          { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
          { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
          { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
          { column_name:  'Name',                           column_type:   'VARCHAR2',  not_null: true, precision: 64 },
          { column_name:  'Pool',                           column_type:   'VARCHAR2',  not_null: false, precision: 30 },
          { column_name:  'Bytes',                          column_type:   'NUMBER',    not_null: true },
          { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
          { column_name:  'CON_ID',                         column_type:   'NUMBER' },
        ],
        # Pool can be NULL therefore no PK is possible
        indexes: [ {index_name: 'Panorama_SGAStat_Unique', columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'Name', 'Pool', 'CON_DBID'], compress: 3, unique: true } ]
      },
      {
          table_name: 'Panorama_Snapshot',
          domain: :AWR,
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'Startup_Time',                   column_type:  'TIMESTAMP',  precision: 3  },  # no not_null because added later (27.03.2018)
              { column_name:  'Begin_Interval_Time',            column_type:  'TIMESTAMP',  not_null: true, precision: 3  },
              { column_name:  'End_Interval_Time',              column_type:  'TIMESTAMP',  not_null: true, precision: 3  },
              { column_name:  'End_Interval_Time_TZ',           column_type:  'TIMESTAMP (3) WITH TIME ZONE',  not_null: false },
              { column_name:  'Snap_Timezone',                  column_type:  'INTERVAL DAY(0) TO SECOND(0)',  not_null: false },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'Snap_ID', 'Instance_Number'], compress: 2 },
          indexes: [ {index_name: 'Panorama_Snapshot_MaxID_IX', columns: ['DBID', 'Instance_Number'], compress: 1 } ]
      },
      {
          table_name: 'Panorama_SQLBind',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'SQL_ID',                         column_type:   'VARCHAR2',  not_null: true, precision: 13 },
              { column_name:  'NAME',                           column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'POSITION',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'DUP_POSITION',                   column_type:   'NUMBER' },
              { column_name:  'DATATYPE',                       column_type:   'NUMBER' },
              { column_name:  'DATATYPE_STRING',                column_type:   'VARCHAR2',  precision: 15 },
              { column_name:  'CHARACTER_SID',                  column_type:   'NUMBER' },
              { column_name:  'PRECISION',                      column_type:   'NUMBER' },
              { column_name:  'SCALE',                          column_type:   'NUMBER' },
              { column_name:  'MAX_LENGTH',                     column_type:   'NUMBER' },
              { column_name:  'WAS_CAPTURED',                   column_type:   'VARCHAR2',  precision: 3 },
              { column_name:  'LAST_CAPTURED',                  column_type:   'DATE' },
              { column_name:  'VALUE_STRING',                   column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'VALUE_ANYDATA',                  column_type:   'ANYDATA' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ], # No primary key because some times there are doublettes
          indexes:  [ {index_name: 'Panorama_SQLBind_IX', columns: ['DBID', 'Snap_ID', 'Instance_Number', 'SQL_ID', 'POSITION', 'CON_DBID'], compress: 4 } ]
      },
      {
          table_name: 'Panorama_SQL_Plan',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'SQL_ID',                         column_type:   'VARCHAR2',  not_null: true, precision: 13 },
              { column_name:  'PLAN_HASH_VALUE',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'ID',                             column_type:   'NUMBER',    not_null: true },
              { column_name:  'OPERATION',                      column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'OPTIONS',                        column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'OBJECT_NODE',                    column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'OBJECT#',                        column_type:   'NUMBER' },
              { column_name:  'OBJECT_OWNER',                   column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'OBJECT_NAME',                    column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'OBJECT_ALIAS',                   column_type:   'VARCHAR2',  precision: 261 },
              { column_name:  'OBJECT_TYPE',                    column_type:   'VARCHAR2',  precision: 20 },
              { column_name:  'OPTIMIZER',                      column_type:   'VARCHAR2',  precision: 20 },
              { column_name:  'PARENT_ID',                      column_type:   'NUMBER' },
              { column_name:  'DEPTH',                          column_type:   'NUMBER' },
              { column_name:  'POSITION',                       column_type:   'NUMBER' },
              { column_name:  'SEARCH_COLUMNS',                 column_type:   'NUMBER' },
              { column_name:  'COST',                           column_type:   'NUMBER' },
              { column_name:  'CARDINALITY',                    column_type:   'NUMBER' },
              { column_name:  'BYTES',                          column_type:   'NUMBER' },
              { column_name:  'OTHER_TAG',                      column_type:   'VARCHAR2',  precision: 35 },
              { column_name:  'PARTITION_START',                column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'PARTITION_STOP',                 column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'PARTITION_ID',                   column_type:   'NUMBER' },
              { column_name:  'OTHER',                          column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'DISTRIBUTION',                   column_type:   'VARCHAR2',  precision: 20 },
              { column_name:  'CPU_COST',                       column_type:   'NUMBER' },
              { column_name:  'IO_COST',                        column_type:   'NUMBER' },
              { column_name:  'TEMP_SPACE',                     column_type:   'NUMBER' },
              { column_name:  'ACCESS_PREDICATES',              column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'FILTER_PREDICATES',              column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'PROJECTION',                     column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'TIME',                           column_type:   'NUMBER' },
              { column_name:  'QBLOCK_NAME',                    column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'REMARKS',                        column_type:   'VARCHAR2',  precision: 4000 },
              { column_name:  'TIMESTAMP',                      column_type:   'DATE' },
              { column_name:  'OTHER_XML',                      column_type:   'CLOB' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SQL_ID', 'PLAN_HASH_VALUE', 'ID', 'CON_DBID'], compress: 3 },
      },
      {
          table_name: 'Panorama_SQLStat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'SQL_ID',                         column_type:   'VARCHAR2',  not_null: true, precision: 13 },
              { column_name:  'PLAN_HASH_VALUE',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'OPTIMIZER_COST',                 column_type:   'NUMBER' },
              { column_name:  'OPTIMIZER_MODE',                 column_type:   'VARCHAR2',  precision: 10 },
              { column_name:  'OPTIMIZER_ENV_HASH_VALUE',       column_type:   'NUMBER' },
              { column_name:  'SHARABLE_MEM',                   column_type:   'NUMBER' },
              { column_name:  'LOADED_VERSIONS',                column_type:   'NUMBER' },
              { column_name:  'VERSION_COUNT',                  column_type:   'NUMBER' },
              { column_name:  'MODULE',                         column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'ACTION',                         column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'SQL_PROFILE',                    column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:   'NUMBER' },
              { column_name:  'PARSING_SCHEMA_ID',              column_type:   'NUMBER' },
              { column_name:  'PARSING_SCHEMA_NAME',            column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'PARSING_USER_ID',                column_type:   'NUMBER' },
              { column_name:  'FETCHES_TOTAL',                  column_type:   'NUMBER' },
              { column_name:  'FETCHES_DELTA',                  column_type:   'NUMBER' },
              { column_name:  'END_OF_FETCH_COUNT_TOTAL',       column_type:   'NUMBER' },
              { column_name:  'END_OF_FETCH_COUNT_DELTA',       column_type:   'NUMBER' },
              { column_name:  'SORTS_TOTAL',                    column_type:   'NUMBER' },
              { column_name:  'SORTS_DELTA',                    column_type:   'NUMBER' },
              { column_name:  'EXECUTIONS_TOTAL',               column_type:   'NUMBER' },
              { column_name:  'EXECUTIONS_DELTA',               column_type:   'NUMBER' },
              { column_name:  'PX_SERVERS_EXECS_TOTAL',         column_type:   'NUMBER' },
              { column_name:  'PX_SERVERS_EXECS_DELTA',         column_type:   'NUMBER' },
              { column_name:  'LOADS_TOTAL',                    column_type:   'NUMBER' },
              { column_name:  'LOADS_DELTA',                    column_type:   'NUMBER' },
              { column_name:  'INVALIDATIONS_TOTAL',            column_type:   'NUMBER' },
              { column_name:  'INVALIDATIONS_DELTA',            column_type:   'NUMBER' },
              { column_name:  'PARSE_CALLS_TOTAL',              column_type:   'NUMBER' },
              { column_name:  'PARSE_CALLS_DELTA',              column_type:   'NUMBER' },
              { column_name:  'DISK_READS_TOTAL',               column_type:   'NUMBER' },
              { column_name:  'DISK_READS_DELTA',               column_type:   'NUMBER' },
              { column_name:  'BUFFER_GETS_TOTAL',              column_type:   'NUMBER' },
              { column_name:  'BUFFER_GETS_DELTA',              column_type:   'NUMBER' },
              { column_name:  'ROWS_PROCESSED_TOTAL',           column_type:   'NUMBER' },
              { column_name:  'ROWS_PROCESSED_DELTA',           column_type:   'NUMBER' },
              { column_name:  'CPU_TIME_TOTAL',                 column_type:   'NUMBER' },
              { column_name:  'CPU_TIME_DELTA',                 column_type:   'NUMBER' },
              { column_name:  'ELAPSED_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'ELAPSED_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'IOWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'IOWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'CLWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'CLWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'APWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'APWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'CCWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'CCWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'DIRECT_WRITES_TOTAL',            column_type:   'NUMBER' },
              { column_name:  'DIRECT_WRITES_DELTA',            column_type:   'NUMBER' },
              { column_name:  'PLSEXEC_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'PLSEXEC_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'JAVEXEC_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'JAVEXEC_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_ELIG_BYTES_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_ELIG_BYTES_DELTA',    column_type:   'NUMBER' },
              { column_name:  'IO_INTERCONNECT_BYTES_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'IO_INTERCONNECT_BYTES_DELTA',    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_TOTAL',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_DELTA',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_BYTES_TOTAL',      column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_BYTES_DELTA',      column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_DELTA',  column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_BYTES_TOTAL',     column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_BYTES_DELTA',     column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_TOTAL', column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_DELTA', column_type:   'NUMBER' },
              { column_name:  'CELL_UNCOMPRESSED_BYTES_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'CELL_UNCOMPRESSED_BYTES_DELTA',  column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_RETURN_BYTES_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_RETURN_BYTES_DELTA',  column_type:   'NUMBER' },
              { column_name:  'BIND_DATA',                      column_type:   'RAW',       precision: 2000 },
              { column_name:  'FLAG',                           column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'SQL_ID', 'PLAN_HASH_VALUE', 'CON_DBID'], compress: 3 },
          indexes: [ {index_name: 'Panorama_SQLStat_SQLID_IX', columns: ['SQL_ID', 'DBID', 'CON_DBID'], compress: 3 } ]
      },
      {
          table_name: 'Panorama_SQLText',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2',   not_null: true, precision: 13  },
              { column_name:  'SQL_Text',                       column_type:  'CLOB'    },
              { column_name:  'Command_Type',                   column_type:  'NUMBER'    },
              { column_name:  'CON_DBID',                       column_type:  'NUMBER',     not_null: true },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SQL_ID', 'Con_DBID'], compress: 1 },
      },
      {
          table_name: 'Internal_StatName',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'STAT_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'Name',                           column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'STAT_ID', 'Con_DBID'] },
      },
      {
          table_name: 'Internal_Sysmetric_History',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'BEGIN_TIME',                     column_type:   'DATE',      not_null: true },
              { column_name:  'END_TIME',                       column_type:   'DATE',      not_null: true },
              { column_name:  'INTSIZE',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'GROUP_ID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'METRIC_ID',                      column_type:   'NUMBER',    not_null: true },
              { column_name:  'VALUE',                          column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'GROUP_ID', 'METRIC_ID', 'BEGIN_TIME', 'CON_DBID'], compress: 5 },
      },
      {
          table_name: 'Internal_Sysmetric_Summary',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'BEGIN_TIME',                     column_type:   'DATE',      not_null: true },
              { column_name:  'END_TIME',                       column_type:   'DATE',      not_null: true },
              { column_name:  'INTSIZE',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'GROUP_ID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'METRIC_ID',                      column_type:   'NUMBER',    not_null: true },
              { column_name:  'NUM_INTERVAL',                   column_type:   'NUMBER',    not_null: true },
              { column_name:  'MINVAL',                         column_type:   'NUMBER',    not_null: true },
              { column_name:  'MAXVAL',                         column_type:   'NUMBER',    not_null: true },
              { column_name:  'AVERAGE',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'STANDARD_DEVIATION',             column_type:   'NUMBER',    not_null: true },
              { column_name:  'SUM_SQUARES',                    column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'GROUP_ID', 'METRIC_ID', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_System_Event',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'EVENT_ID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'EVENT_NAME',                     column_type:   'VARCHAR2',  not_null: true, precision: 128 },
              { column_name:  'WAIT_CLASS_ID',                  column_type:   'NUMBER' },
              { column_name:  'WAIT_CLASS',                     column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'TOTAL_WAITS',                    column_type:   'NUMBER' },
              { column_name:  'TOTAL_TIMEOUTS',                 column_type:   'NUMBER' },
              { column_name:  'TIME_WAITED_MICRO',              column_type:   'NUMBER' },
              { column_name:  'TOTAL_WAITS_FG',                 column_type:   'NUMBER' },
              { column_name:  'TOTAL_TIMEOUTS_FG',              column_type:   'NUMBER' },
              { column_name:  'TIME_WAITED_MICRO_FG',           column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'EVENT_ID', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Internal_SysStat',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'STAT_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'VALUE',                          column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'STAT_ID', 'CON_DBID'], compress: 2 },
      },
      {
          table_name: 'Panorama_Tablespace',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'TS#',                            column_type:   'NUMBER',    not_null: true },
              { column_name:  'TSNAME',                         column_type:   'VARCHAR2',  not_null: true, precision: 30 },
              { column_name:  'CONTENTS',                       column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'SEGMENT_SPACE_MANAGEMENT',       column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'EXTENT_MANAGEMENT',              column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'BLOCK_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'TS#', 'CON_DBID'] },
      },
      {
          table_name: 'Panorama_Tempfile',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILE#',                          column_type:   'NUMBER',    not_null: true },
              { column_name:  'CREATION_CHANGE#',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILENAME',                       column_type:   'VARCHAR2',  not_null: true, precision: 513 },
              { column_name:  'TS#',                            column_type:   'NUMBER',    not_null: true },
              { column_name:  'TSNAME',                         column_type:   'VARCHAR2',  precision: 30 },
              { column_name:  'BLOCK_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['DBID', 'FILE#', 'CREATION_CHANGE#', 'CON_DBID'] },
      },
      {
          table_name: 'Internal_TempStatXS',
          domain: :AWR,
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'FILE#',                          column_type:   'NUMBER',    not_null: true },
              { column_name:  'CREATION_CHANGE#',               column_type:   'NUMBER',    not_null: true },
              { column_name:  'PHYRDS',                         column_type:   'NUMBER' },
              { column_name:  'PHYWRTS',                        column_type:   'NUMBER' },
              { column_name:  'SINGLEBLKRDS',                   column_type:   'NUMBER' },
              { column_name:  'READTIM',                        column_type:   'NUMBER' },
              { column_name:  'WRITETIM',                       column_type:   'NUMBER' },
              { column_name:  'SINGLEBLKRDTIM',                 column_type:   'NUMBER' },
              { column_name:  'PHYBLKRD',                       column_type:   'NUMBER' },
              { column_name:  'PHYBLKWRT',                      column_type:   'NUMBER' },
              { column_name:  'WAIT_COUNT',                     column_type:   'NUMBER' },
              { column_name:  'TIME',                           column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'FILE#', 'CON_DBID'], compress: 2 },
      },
      {   # Table used for both domains ASH and AWR, therefore duplicated. Structure must be identical !!!
          table_name: 'Panorama_TopLevelCall_Name',
          domain: :ASH,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'Top_Level_Call#',                column_type:   'NUMBER',    not_null: true},
              { column_name:  'Top_Level_Call_Name',            column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER',    not_null: true },
          ],
          primary_key: { columns: ['DBID', 'Top_Level_Call#', 'Con_DBID'] },
      },
      {   # Table used for both domains ASH and AWR, therefore duplicated. Structure must be identical !!!
          table_name: 'Panorama_TopLevelCall_Name',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'Top_Level_Call#',                column_type:   'NUMBER',    not_null: true},
              { column_name:  'Top_Level_Call_Name',            column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER',    not_null: true },
          ],
          primary_key: { columns: ['DBID', 'Top_Level_Call#', 'Con_DBID'] },
      },
      {
          table_name: 'Panorama_UndoStat',
          domain: :AWR,
          columns: [
              { column_name:  'BEGIN_TIME',                   column_type:   'DATE',        not_null: true },
              { column_name:  'END_TIME',                     column_type:   'DATE',        not_null: true },
              { column_name:  'DBID',                         column_type:   'NUMBER',      not_null: true },
              { column_name:  'INSTANCE_NUMBER',              column_type:   'NUMBER',      not_null: true },
              { column_name:  'SNAP_ID',                      column_type:   'NUMBER',      not_null: true },
              { column_name:  'UNDOTSN',                      column_type:   'NUMBER',      not_null: true },
              { column_name:  'UNDOBLKS',                     column_type:   'NUMBER' },
              { column_name:  'TXNCOUNT',                     column_type:   'NUMBER' },
              { column_name:  'MAXQUERYLEN',                  column_type:   'NUMBER' },
              { column_name:  'MAXQUERYSQLID',                column_type:   'VARCHAR2',    precision: 13 },
              { column_name:  'MAXCONCURRENCY',               column_type:   'NUMBER' },
              { column_name:  'UNXPSTEALCNT',                 column_type:   'NUMBER' },
              { column_name:  'UNXPBLKRELCNT',                column_type:   'NUMBER' },
              { column_name:  'UNXPBLKREUCNT',                column_type:   'NUMBER' },
              { column_name:  'EXPSTEALCNT',                  column_type:   'NUMBER' },
              { column_name:  'EXPBLKRELCNT',                 column_type:   'NUMBER' },
              { column_name:  'EXPBLKREUCNT',                 column_type:   'NUMBER' },
              { column_name:  'SSOLDERRCNT',                  column_type:   'NUMBER' },
              { column_name:  'NOSPACEERRCNT',                column_type:   'NUMBER' },
              { column_name:  'ACTIVEBLKS',                   column_type:   'NUMBER' },
              { column_name:  'UNEXPIREDBLKS',                column_type:   'NUMBER' },
              { column_name:  'EXPIREDBLKS',                  column_type:   'NUMBER' },
              { column_name:  'TUNED_UNDORETENTION',          column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                     column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                       column_type:   'NUMBER' },
          ],
          primary_key: { columns: ['BEGIN_TIME', 'END_TIME', 'DBID', 'INSTANCE_NUMBER', 'CON_DBID'] },
      },
      {
          table_name: 'Panorama_WR_Control',
          domain: :AWR,
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',                        not_null: true },
              { column_name:  'SNAP_INTERVAL',                  column_type:   'INTERVAL DAY(5) TO SECOND(1)',  not_null: true},
              { column_name:  'RETENTION',                      column_type:   'INTERVAL DAY(5) TO SECOND(1)',  not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: { columns: ['DBID'] },
      },


  ]

=begin

Generator-Selects:

######### Structure
SELECT '              { column_name:  '''||Column_Name||''',     column_type:   '''||Data_Type||''''||
       CASE WHEN Nullable = 'N' THEN ', not_null: true' END ||
       CASE WHEN (Data_Type != 'NUMBER' OR Data_Length != 22) AND Data_Type NOT IN ('DATE') THEN ', precision: '||Data_Length  END ||
       ' },'
FROM   DBA_Tab_Columns
WHERE  Table_Name = 'DBA_HIST_SQLSTAT'
ORDER BY Column_ID
;

######### Field-List
SELECT Column_Name||','
FROM   DBA_Tab_Columns
WHERE  Table_Name = 'DBA_HIST_SQLSTAT'
ORDER BY Column_ID
;

=end


=begin
  Expexted structure, should contain structure of highest Oracle version:
 [
     {
         view_name: ,
         domain: ,
         view_select: ""
     }
 ]
=end
  # Dynamic declaration of view_select to allow adjustment to current database version, use view[:view_select].call
  VIEWS =
    [
        {
            view_name: 'Panorama_V$Active_Sess_History',
            domain: :ASH,
            view_select: proc{"SELECT h.INSTANCE_NUMBER Inst_ID, h.SAMPLE_ID, h.SAMPLE_TIME, h.IS_AWR_SAMPLE, h.SESSION_ID, h.SESSION_SERIAL#, h.SESSION_TYPE, h.FLAGS, h.USER_ID, h.SQL_ID, h.IS_SQLID_CURRENT, h.SQL_CHILD_NUMBER,
                                      h.SQL_OPCODE, h.SQL_OPNAME, h.FORCE_MATCHING_SIGNATURE, h.TOP_LEVEL_SQL_ID, h.TOP_LEVEL_SQL_OPCODE, h.SQL_PLAN_HASH_VALUE, h.SQL_PLAN_LINE_ID, h.SQL_PLAN_OPERATION, h.SQL_PLAN_OPTIONS,
                                      h.SQL_EXEC_ID, h.SQL_EXEC_START, h.PLSQL_ENTRY_OBJECT_ID, h.PLSQL_ENTRY_SUBPROGRAM_ID, h.PLSQL_OBJECT_ID, h.PLSQL_SUBPROGRAM_ID, h.QC_INSTANCE_ID, h.QC_SESSION_ID, h.QC_SESSION_SERIAL#, h.PX_FLAGS,
                                      h.EVENT, h.EVENT_ID, h.SEQ#, h.P1TEXT, h.P1, h.P2TEXT, h.P2, h.P3TEXT, h.P3,h.WAIT_CLASS, h.WAIT_CLASS_ID, h.WAIT_TIME, h.SESSION_STATE, h.TIME_WAITED,
                                      h.BLOCKING_SESSION_STATUS, h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL#, h.BLOCKING_INST_ID, h.BLOCKING_HANGCHAIN_INFO, h.CURRENT_OBJ#, h.CURRENT_FILE#, h.CURRENT_BLOCK#, h.CURRENT_ROW#,
                                      h.TOP_LEVEL_CALL#,
                                      #{PanoramaConnection.db_version >= '11.2' ? "tlcn.Top_Level_Call_Name" : "NULL Top_Level_Call_Name"},
                                      h.CONSUMER_GROUP_ID, h.XID,h.REMOTE_INSTANCE#, h.TIME_MODEL, h.IN_CONNECTION_MGMT, h.IN_PARSE, h.IN_HARD_PARSE, h.IN_SQL_EXECUTION, h.IN_PLSQL_EXECUTION,
                                      h.IN_PLSQL_RPC, h.IN_PLSQL_COMPILATION, h.IN_JAVA_EXECUTION, h.IN_BIND, h.IN_CURSOR_CLOSE, h.IN_SEQUENCE_LOAD, h.IN_INMEMORY_QUERY, h.IN_INMEMORY_POPULATE, h.IN_INMEMORY_PREPOPULATE, h.IN_INMEMORY_REPOPULATE,
                                      h.IN_INMEMORY_TREPOPULATE, h.IN_TABLESPACE_ENCRYPTION, h.CAPTURE_OVERHEAD, h.REPLAY_OVERHEAD, h.IS_CAPTURED, h.IS_REPLAYED, h.SERVICE_HASH, h.PROGRAM,h.MODULE, h.ACTION, h.CLIENT_ID, h.MACHINE, h.PORT,
                                      h.ECID, h.DBREPLAY_FILE_ID, h.DBREPLAY_CALL_COUNTER, h.TM_DELTA_TIME, h.TM_DELTA_CPU_TIME, h.TM_DELTA_DB_TIME, h.DELTA_TIME, h.DELTA_READ_IO_REQUESTS, h.DELTA_WRITE_IO_REQUESTS, h.DELTA_READ_IO_BYTES,
                                      h.DELTA_WRITE_IO_BYTES, h.DELTA_INTERCONNECT_IO_BYTES, h.PGA_ALLOCATED, h.TEMP_SPACE_ALLOCATED, h.CON_ID
                               FROM   Internal_V$Active_Sess_History h
                               #{"LEFT OUTER JOIN Panorama_TopLevelCall_Name tlcn ON tlcn.DBID = #{PanoramaConnection.login_container_dbid} AND tlcn.Top_Level_Call# = h.Top_Level_Call# AND tlcn.Con_DBID = #{PanoramaConnection.login_container_dbid}" if PanoramaConnection.db_version >= '11.2'}
                              "}
        },
        {
            view_name: 'Panorama_Active_Sess_History',
            domain: :AWR,
            view_select: proc{"SELECT h.SNAP_ID, h.DBID, h.INSTANCE_NUMBER, h.CON_DBID, h.CON_ID, h.SAMPLE_ID, h.SAMPLE_TIME, h.SESSION_ID, h.SESSION_SERIAL#, h.SESSION_TYPE, h.FLAGS, h.USER_ID, h.SQL_ID, h.IS_SQLID_CURRENT, h.SQL_CHILD_NUMBER, h.SQL_OPCODE, h.SQL_OPNAME,
                                      h.FORCE_MATCHING_SIGNATURE, h.TOP_LEVEL_SQL_ID, h.TOP_LEVEL_SQL_OPCODE, h.SQL_PLAN_HASH_VALUE, h.SQL_PLAN_LINE_ID, h.SQL_PLAN_OPERATION, h.SQL_PLAN_OPTIONS, h.SQL_EXEC_ID, h.SQL_EXEC_START, h.PLSQL_ENTRY_OBJECT_ID,
                                      h.PLSQL_ENTRY_SUBPROGRAM_ID, h.PLSQL_OBJECT_ID, h.PLSQL_SUBPROGRAM_ID, h.QC_INSTANCE_ID, h.QC_SESSION_ID, h.QC_SESSION_SERIAL#, h.PX_FLAGS, h.EVENT, h.EVENT_ID, h.SEQ#, h.P1TEXT, h.P1, h.P2TEXT, h.P2, h.P3TEXT, h.P3, h.WAIT_CLASS,
                                      h.WAIT_CLASS_ID, h.WAIT_TIME, h.SESSION_STATE, h.TIME_WAITED, h.BLOCKING_SESSION_STATUS, h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL#, h.BLOCKING_INST_ID, h.BLOCKING_HANGCHAIN_INFO, h.CURRENT_OBJ#, h.CURRENT_FILE#,
                                      h.CURRENT_BLOCK#, h.CURRENT_ROW#, h.TOP_LEVEL_CALL#,
                                      #{PanoramaConnection.db_version >= '11.2' ? "tlcn.Top_Level_Call_Name" : "NULL Top_Level_Call_Name"},
                                      h.CONSUMER_GROUP_ID, h.XID, h.REMOTE_INSTANCE#, h.TIME_MODEL, h.IN_CONNECTION_MGMT, h.IN_PARSE, h.IN_HARD_PARSE, h.IN_SQL_EXECUTION, h.IN_PLSQL_EXECUTION,
                                      h.IN_PLSQL_RPC, h.IN_PLSQL_COMPILATION, h.IN_JAVA_EXECUTION, h.IN_BIND, h.IN_CURSOR_CLOSE, h.IN_SEQUENCE_LOAD, h.CAPTURE_OVERHEAD, h.REPLAY_OVERHEAD, h.IS_CAPTURED, h.IS_REPLAYED, h.SERVICE_HASH, h.PROGRAM, h.MODULE, h.ACTION, h.CLIENT_ID,
                                      h.MACHINE, h.PORT, h.ECID, h.DBREPLAY_FILE_ID, h.DBREPLAY_CALL_COUNTER, h.TM_DELTA_TIME, h.TM_DELTA_CPU_TIME, h.TM_DELTA_DB_TIME, h.DELTA_TIME, h.DELTA_READ_IO_REQUESTS, h.DELTA_WRITE_IO_REQUESTS, h.DELTA_READ_IO_BYTES,
                                      h.DELTA_WRITE_IO_BYTES, h.DELTA_INTERCONNECT_IO_BYTES, h.PGA_ALLOCATED, h.TEMP_SPACE_ALLOCATED, h.IN_INMEMORY_QUERY, h.IN_INMEMORY_POPULATE, h.IN_INMEMORY_PREPOPULATE, h.IN_INMEMORY_REPOPULATE, h.IN_INMEMORY_TREPOPULATE,
                                      h.IN_TABLESPACE_ENCRYPTION
                               FROM   Internal_Active_Sess_History h
                               #{"LEFT OUTER JOIN Panorama_TopLevelCall_Name tlcn ON tlcn.DBID = h.DBID AND tlcn.Top_Level_Call# = h.Top_Level_Call# AND tlcn.Con_DBID = h.Con_DBID" if PanoramaConnection.db_version >= '11.2'}
                              "}
        },
        {
            view_name: 'Panorama_FileStatXS',
            domain: :AWR,
            view_select: proc{"SELECT f.SNAP_ID, f.DBID, f.INSTANCE_NUMBER, f.FILE#, f.CREATION_CHANGE#, d.FILENAME, d.TS#, d.TSNAME, d.BLOCK_SIZE,
                                      f.PHYRDS, f.PHYWRTS, f.SINGLEBLKRDS, f.READTIM, f.WRITETIM, f.SINGLEBLKRDTIM, f.PHYBLKRD, f.PHYBLKWRT, f.WAIT_COUNT, f.TIME,
                                      f.OPTIMIZED_PHYBLKRD, f.CON_DBID, f.CON_ID
                               FROM   Internal_FileStatXS f
                               JOIN   Panorama_DataFile d ON d.DBID = f.DBID AND d.File# = f.File# AND d.Creation_Change# = f.Creation_Change# AND d.Con_DBID = f.Con_DBID
                              "}
        },
        {
            view_name: 'Panorama_OSStat',
            domain: :AWR,
            view_select: proc{"SELECT s.Snap_ID, s.DBID, s.Instance_Number, s.STAT_ID, n.Stat_Name, s.Value, s.CON_DBID, 0 CON_ID
                               FROM   Internal_OSStat s
                               JOIN   Panorama_OSStat_Name n ON n.DBID = s.DBID AND n.Stat_ID = s.Stat_ID
                              "}
        },
        {
            view_name: 'Panorama_Stat_Name',
            domain: :AWR,
            view_select: proc{"SELECT s.DBID, s.STAT_ID, s.NAME Stat_Name, s.CON_DBID, s.CON_ID
                               FROM   Internal_StatName s
                              "}
        },
        {
            view_name: 'Panorama_Sysmetric_History',
            domain: :AWR,
            view_select: proc{"SELECT s.Snap_ID, s.DBID, s.Instance_Number, s.Begin_Time, s.End_Time, s.IntSize, s.Group_ID, s.Metric_ID, n.Metric_Name, s.Value, n.Metric_Unit, s.Con_DBID, s.Con_ID
                               FROM   Internal_Sysmetric_History s
                               JOIN   Panorama_Metric_Name n ON n.DBID = s.DBID AND n.Group_ID = s.Group_ID AND n.Metric_ID = s.Metric_ID AND n.Con_DBID = s.Con_DBID
                              "}
        },
        {
            view_name: 'Panorama_Sysmetric_Summary',
            domain: :AWR,
            view_select: proc{"SELECT s.Snap_ID, s.DBID, s.Instance_Number, s.Begin_Time, s.End_Time, s.IntSize, s.Group_ID, s.Metric_ID, n.Metric_Name, n.Metric_Unit, s.Num_Interval, s.MinVal, s.MaxVal, s.Average, s.Standard_Deviation, s.Sum_Squares, s.Con_DBID, s.Con_ID
                               FROM   Internal_Sysmetric_Summary s
                               JOIN   Panorama_Metric_Name n ON n.DBID = s.DBID AND n.Group_ID = s.Group_ID AND n.Metric_ID = s.Metric_ID AND n.Con_DBID = s.Con_DBID
                              "}
        },
        {
            view_name: 'Panorama_SysStat',
            domain: :AWR,
            view_select: proc{"SELECT s.SNAP_ID, s.DBID, s.INSTANCE_NUMBER, s.STAT_ID, n.NAME Stat_Name, s.VALUE, s.CON_DBID, s.CON_ID
                               FROM   Internal_SysStat s
                               LEFT OUTER JOIN Internal_StatName n ON n.Stat_ID = s.Stat_ID
                              "}
        },
        {
            view_name: 'Panorama_TempStatXS',
            domain: :AWR,
            view_select: proc{"SELECT f.SNAP_ID, f.DBID, f.INSTANCE_NUMBER, f.FILE#, f.CREATION_CHANGE#, d.FILENAME, d.TS#, d.TSNAME, d.BLOCK_SIZE,
                                      f.PHYRDS, f.PHYWRTS, f.SINGLEBLKRDS, f.READTIM, f.WRITETIM, f.SINGLEBLKRDTIM, f.PHYBLKRD, f.PHYBLKWRT, f.WAIT_COUNT, f.TIME,
                                      f.CON_DBID, f.CON_ID
                               FROM   Internal_TempStatXS f
                               JOIN   Panorama_DataFile d ON d.DBID = f.DBID AND d.File# = f.File# AND d.Creation_Change# = f.Creation_Change# AND d.Con_DBID = f.Con_DBID
                              "}
        },
    ]

  # Replace DBA_Hist in SQL with corresponding Panorama-Sampler table
  def self.transform_sql_for_sampler(org_sql)
    sql = org_sql.clone

    # fake gv$Active_Session_History in SQL so translation will hit it
    sql.gsub!(/gv\$Active_Session_History/i, 'DBA_HIST_V$Active_Sess_History')

    up_sql = sql.upcase

    start_index = up_sql.index('DBA_HIST')
    while start_index
#      Rails.logger.info "######################### #{start_index} #{sql[start_index, sql.length-start_index]}"
      get_table_and_view_names.each do |table|                                  # Check if table might be replaced by Panorama-Sampler
        if table[:table_name].upcase == up_sql[start_index, table[:table_name].length].gsub(/DBA_HIST/, 'PANORAMA')
          sql   .insert(start_index, "#{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.")       # Add schema name before table_name
          up_sql.insert(start_index, "#{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.")       # Increase size synchronously with sql
          start_index += PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].length+1                 # Increase Pointer by schemaname
          7.downto(0) do |pos|                                                                            # Copy replacement table_name char by char into sql (DBA_HIST -> Panorama)
            sql[start_index+pos] = table[:table_name][pos]
          end
        end
      end


      start_index = up_sql.index('DBA_HIST', start_index + 8)                   # Look for next occurrence
    end
    sql
  end

  def self.has_column?(table_name, column_name)
    TABLES.each do |table|
      if table[:table_name].upcase == table_name.upcase                         # table exists
        table[:columns].each do |column|
          return true if column[:column_name].upcase == column_name.upcase
        end
      end
    end
    false
  end

  # Check data structures, for ASH-Thread or snapshot thread
  # @param [Symbol] domain
  def do_check_internal(domain)
    Rails.logger.debug('PanoramaSampleStructureCheck.do_check_internal') { "Execute structure check for domain #{domain} in config ID=#{@sampler_config.get_id} #{@sampler_config.get_name}"}
    @ora_tables       = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config.get_owner.upcase]
    @ora_tab_privs    = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM ALL_TAB_PRIVS WHERE Table_Schema = ?  AND Privilege = 'SELECT'  AND Grantee = 'PUBLIC'",  @sampler_config.get_owner.upcase]

    TABLES.each do |table|
      check_table_existence(table) if table[:domain] == domain
    end

    @ora_tab_columns  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Column_Name, Data_Precision, Char_Length FROM All_Tab_Columns WHERE Owner = ? ORDER BY Table_Name, Column_ID", @sampler_config.get_owner.upcase]
    @ora_tab_colnull  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Column_Name, Nullable FROM All_Tab_Columns WHERE Owner = ? ORDER BY Table_Name, Column_ID", @sampler_config.get_owner.upcase]
    TABLES.each do |table|
      check_table_columns(table) if table[:domain] == domain
    end

    @ora_tab_pkeys    = {}
    ora_tab_pkeys = PanoramaConnection.sql_select_all ["SELECT /*+ NOPARALLEL */ Table_Name, Constraint_Name, Index_Name FROM All_Constraints WHERE Owner = ? AND Constraint_Type='P'", @sampler_config.get_owner.upcase]
    ora_tab_pkeys.each do |p|
      @ora_tab_pkeys[p.table_name] = p
    end

    @ora_tab_pk_cols  = PanoramaConnection.sql_select_all ["SELECT cc.Table_Name, cc.Column_Name, cc.Position
                                                            FROM All_Cons_Columns cc
                                                            JOIN All_Constraints c ON c.Owner = cc.Owner AND c.Table_Name = cc.Table_Name AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'P'
                                                            WHERE cc.Owner = ?
                                                          ", @sampler_config.get_owner.upcase]

    # Existing index-structure
    @ora_indexes = {}
    indexes      = PanoramaConnection.sql_select_all ["SELECT Table_Name, Index_Name, Compression, Prefix_Length, Status FROM All_Indexes WHERE Owner = ? AND Table_Name NOT LIKE 'BIN$%'", @sampler_config.get_owner.upcase]
    indexes.each do |i|
      @ora_indexes[i.index_name] = i
      @ora_indexes[i.index_name][:columns] = []
    end
    ind_columns  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Index_Name, Column_Name, Column_Position FROM All_Ind_Columns WHERE Table_Owner = ? AND Table_Name NOT LIKE 'BIN$%'", @sampler_config.get_owner.upcase]
    ind_columns.each do |c|
      @ora_indexes[c.index_name][:columns] << c if @ora_indexes[c.index_name]  # All_Ind_Columns also contains columns of dropped tables (BIN$) but All_Indexes does not
    end


    TABLES.each do |table|
      check_table_pkey(table) if table[:domain] == domain
    end

    TABLES.each do |table|
      check_table_indexes(table) if table[:domain] == domain
    end


    @ora_views        = PanoramaConnection.sql_select_all ["SELECT View_Name FROM All_Views WHERE Owner = ?",  @sampler_config.get_owner.upcase]
    @ora_view_texts   = PanoramaConnection.sql_select_all ["SELECT View_Name, Text FROM All_Views WHERE Owner = ?",  @sampler_config.get_owner.upcase]
    @ora_tables       = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config.get_owner.upcase]
    VIEWS.each do |view|
      check_view(view) if view[:domain] == domain
    end

    Rails.logger.info("Running test with @sampler_config.get_select_any_table = #{@sampler_config.get_select_any_table?}")  if  Rails.env.test?

    # globallly used packages
    case domain
    when :AWR then
      filename = PanoramaSampler::PackageConDbidFromConId.instance_method(:con_dbid_from_con_id_spec).source_location[0]
      create_or_check_package(filename, con_dbid_from_con_id_spec, 'CON_DBID_FROM_CON_ID', :spec)
      create_or_check_package(filename, con_dbid_from_con_id_body, 'CON_DBID_FROM_CON_ID', :body)
    end

    if @sampler_config.get_select_any_table?                                     # call PL/SQL package? v$Tables with SELECT_ANY_CATALOG-role are accessible in PL/SQL only if SELECT ANY TABLE is granted
      case domain
        when :AWR then
          filename = PanoramaSampler::PackagePanoramaSamplerSnapshot.instance_method(:panorama_sampler_snapshot_spec).source_location[0]
          create_or_check_package(filename, panorama_sampler_snapshot_spec, 'PANORAMA_SAMPLER_SNAPSHOT', :spec)
          create_or_check_package(filename, panorama_sampler_snapshot_body, 'PANORAMA_SAMPLER_SNAPSHOT', :body)
        when :ASH then
          filename = PanoramaSampler::PackagePanoramaSamplerAsh.instance_method(:panorama_sampler_ash_spec).source_location[0]
          create_or_check_package(filename, panorama_sampler_ash_spec, 'PANORAMA_SAMPLER_ASH', :spec)
          create_or_check_package(filename, panorama_sampler_ash_body, 'PANORAMA_SAMPLER_ASH', :body)
        when :BLOCKING_LOCKS then
          filename = PanoramaSampler::PackagePanoramaSamplerBlockingLocks.instance_method(:panorama_sampler_blocking_locks_spec).source_location[0]
          create_or_check_package(filename, panorama_sampler_blocking_locks_spec, 'PANORAMA_SAMPLER_BLOCK_LOCKS', :spec)
          create_or_check_package(filename, panorama_sampler_blocking_locks_body, 'PANORAMA_SAMPLER_BLOCK_LOCKS', :body)
        else
      end
    end
    Rails.logger.debug('PanoramaSampleStructureCheck.do_check_internal') { "Finished structure check for domain #{domain} in config ID=#{@sampler_config.get_id} #{@sampler_config.get_name}"}
  end

  def   remove_tables_internal
    PanoramaConnection.sql_execute "ALTER SESSION SET DDL_LOCK_TIMEOUT=30"      # Ensure short locks at DROP do not lead to error
    packages = PanoramaConnection.sql_select_all [ "SELECT Object_Name
                                                    FROM   All_Objects
                                                    WHERE  Owner=? AND Object_Type = 'PACKAGE'
                                                    AND    Object_Name IN ('PANORAMA_SAMPLER_SNAPSHOT', 'PANORAMA_SAMPLER_ASH')
                                                   ", @sampler_config.get_owner.upcase]
    packages.each do |package|
      PanoramaConnection.sql_execute("DROP PACKAGE #{@sampler_config.get_owner}.#{package.object_name}")
    end

    TABLES.each do |table|
      if 0 < PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM All_Tables WHERE Owner = ? AND Table_Name = ?", @sampler_config.get_owner.upcase, table[:table_name].upcase])
        begin
          ############# Drop Table
          sql = "DROP TABLE #{@sampler_config.get_owner}.#{table[:table_name]}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
          log "Table #{table[:table_name]} dropped"
        rescue Exception => e
          Rails.logger.error('PanoramaSamplerStructureCheck.remove_tables_internal') { "Error #{e.message} dropping table #{@sampler_config.get_owner}.#{table[:table_name]}" }
          log_exception_backtrace(e, 40)
          raise e
        end
      end
    end

    begin
      PanoramaConnection.sql_execute "PURGE RECYCLEBIN"                           # Free ressources after drop table, avoid ORA-10632 especially for 19.10-SE2
    rescue Exception => e
      Rails.logger.error('PanoramaSamplerStructureCheck.remove_tables_internal') { "#{e.class}:#{e.message} at PURGE RECYCLEBIN"}
    end
  end

  def self.translate_plsql_aliases(config, source_buffer)
#    translated_source_buffer = source_buffer.gsub(/PANORAMA\./i, "#{config.get_owner.upcase}.")    # replace PANORAMA. with the real owner
    translated_source_buffer = source_buffer.gsub(/PANORAMA_OWNER/i, "#{config.get_owner.upcase}")    # replace PANORAMA_OWNER with the real owner
    translated_source_buffer.gsub!(/COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME/, Time.now.to_s) # change source to provocate change of LAST_DDL_TIME even content is still the same
    translated_source_buffer.gsub!(/PANORAMA_VERSION/, PanoramaGem::VERSION) # stamp version to file
    translated_source_buffer.gsub!(/DBMS_LOCK.SLEEP/i, 'DBMS_SESSION.SLEEP') if PanoramaConnection.db_version >= '18.0'
    # Expand macro to exception handler
    translated_source_buffer.gsub!(/CATCH_START/, "BEGIN\n     ")
    translated_source_buffer.gsub!(/CATCH_END/, "\n    EXCEPTION\n      WHEN OTHERS THEN\n        ErrMsg := SQLErrM||' '||DBMS_UTILITY.FORMAT_ERROR_STACK();\n    END;\n")
    translated_source_buffer
  end

  private

  # get array of tables ans view
  def self.get_table_and_view_names
    compare_objects = TABLES.clone                                            # Add tables to compare-objects
    VIEWS.each do |view|                                                      # Add views to compare-objects
      compare_objects << { :table_name => view[:view_name]}
    end
    compare_objects
  end

  def get_package_obj(package_name, type)
    PanoramaConnection.sql_select_first_row [ "SELECT Status, Last_DDL_Time
                                               FROM   All_Objects
                                               WHERE  Object_Type = ?
                                               AND    Owner       = ?
                                               AND    Object_Name = ?
                                              ", (type == :spec ? 'PACKAGE' : 'PACKAGE BODY'), @sampler_config.get_owner.upcase, package_name.upcase]
  end

  # Ensure existence of most recent version of package
  # @param {String} file_for_time_check File name of helper file
  # @param {String} source_buffer Package code
  # @param {String} package_name Name of package
  # @param {Symbol} type :spec or :body
  def create_or_check_package(file_for_time_check, source_buffer, package_name, type)
    package_obj = get_package_obj(package_name, type)
    package_version = PanoramaConnection.sql_select_one ["SELECT TRIM(SUBSTR(Text, INSTR(Text, 'Panorama-Version: ')+18))
                                                          FROM   All_Source
                                                          WHERE  Owner = ?
                                                          AND    Name  = ?
                                                          AND    Type  = ?
                                                          AND    Text LIKE '%Panorama-Version%'
                                                         ", @sampler_config.get_owner.upcase, package_name.upcase, (type==:spec ? 'PACKAGE' : 'PACKAGE BODY')]
    package_version.delete!("\n") if !package_version.nil?                      # remove trailing line feed

    if package_obj.nil? ||
        package_obj.last_ddl_time < File.ctime(file_for_time_check) ||
        package_obj.status != 'VALID' ||
        package_version != PanoramaGem::VERSION
      # Compile package
      Rails.logger.info('PanoramaSamplerStructureCheck.create_or_check_package') { "Package #{'body ' if type==:body}#{@sampler_config.get_owner.upcase}.#{package_name} needs #{package_obj.nil? ? 'creation' : 'recompile'}" }

      translated_source_buffer = PanoramaSamplerStructureCheck.translate_plsql_aliases(@sampler_config, source_buffer)

      Rails.logger.info('PanoramaSamplerStructureCheck.create_or_check_package') { translated_source_buffer }
      PanoramaConnection.sql_execute translated_source_buffer
      package_obj = get_package_obj(package_name, type)                         # repeat check on ALL_Objects
      if package_obj.nil? || package_obj.status != 'VALID'
        errors = PanoramaConnection.sql_select_all ["SELECT * FROM User_Errors WHERE Name = ? AND Type = ? ORDER BY Sequence", package_name.upcase, (type==:spec ? 'PACKAGE' : 'PACKAGE BODY')]
        errors.each do |e|
          Rails.logger.error('PanoramaSamplerStructureCheck.create_or_check_package') { "Line=#{e.line} position=#{e.position}: #{e.text}" }
        end
        raise "Error compiling package #{'body ' if type==:body}#{@sampler_config.get_owner.upcase}.#{package_name}. See previous lines"
      end
    end
  end

  # get column type expression for CREATE TABLE or ALTER TABLE
  # @param [Hash] column
  # @return [String]
  def column_type_expr(column)
    expr = "#{column[:column_name]} "
    expr << case column[:column_type].upcase
            when 'VARCHAR2' then "#{column[:column_type]} (#{column[:precision]} CHAR)"
            else
              "#{column[:column_type]} #{"(#{column[:precision]}#{", #{column[:scale]}" if column[:scale]})" if column[:precision]}"
            end
    expr << " #{column[:addition]}" if column[:addition]
    expr << " NOT NULL" if column[:not_null]
    expr
  end

  def check_table_existence(table)
    @ora_tables       = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config.get_owner.upcase] unless @ora_tables
    @ora_tab_privs    = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM ALL_TAB_PRIVS WHERE Table_Schema = ?  AND Privilege = 'SELECT'  AND Grantee = 'PUBLIC'",  @sampler_config.get_owner.upcase] unless @ora_tab_privs

    if !@ora_tables.include?({'table_name' => table[:table_name].upcase})
      ############# Check Table existence
      log "Table #{table[:table_name]} does not exist"
      sql = "CREATE #{'GLOBAL TEMPORARY ' if table[:temporary]}TABLE #{@sampler_config.get_owner}.#{table[:table_name]} ("
      sql << table[:columns].map { |column| column_type_expr(column) }.join(",\n")
      sql << ") #{'PCTFREE 0' if table[:temporary].nil?} #{table[:temporary]}"                                 # pctfree 0 because there's no need for updates on this tables
      log(sql)
      PanoramaConnection.sql_execute(sql)
      PanoramaConnection.sql_execute("ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} ENABLE ROW MOVEMENT")
      log "Table #{table[:table_name]} created"
    end

    ############ Check table privileges
    check_object_privs(table[:table_name])                                      # check SELECT grant to PUBLIC
  end

  def check_table_columns(table)
    table[:columns].each do |column|
      # Check column existence
      if @ora_tab_columns.select{|c| c['table_name'] == table[:table_name].upcase && c['column_name'] == column[:column_name].upcase}.length == 0
        sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} ADD (#{column_type_expr(column)})"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      else                                                                      # Check NULL state for existing columns
        if !@ora_tab_colnull.include?({'table_name' => table[:table_name].upcase, 'column_name' => column[:column_name].upcase, 'nullable' => (column[:not_null] ? 'N' : 'Y')})
          sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} MODIFY (#{column[:column_name]} "
          if column[:not_null]
            sql << 'NOT NULL'

            # Ensure that Columns doesn't contain NULL-values
            del_sql = "DELETE FROM #{@sampler_config.get_owner}.#{table[:table_name]} WHERE #{column[:column_name]} IS NULL"
            log(del_sql)
            PanoramaConnection.sql_execute(del_sql)
          else
            sql << 'NULL'
          end
          sql << ")"
          log(sql)
          PanoramaConnection.sql_execute(sql)
        end
        # Check column length
        ora_tab_col = @ora_tab_columns.select{|c| c['table_name'] == table[:table_name].upcase && c['column_name'] == column[:column_name].upcase}.first
        if column[:precision] && column[:column_type] == 'VARCHAR2' && column[:precision] != ora_tab_col.char_length
          sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} MODIFY #{column[:column_name]} VARCHAR2(#{column[:precision]} CHAR)"
          log(sql)
          PanoramaConnection.sql_execute(sql)
        end
      end
    end

    # Check existence of obsolete columns
    @ora_tab_columns.each do |tcol|
      if tcol.table_name == table[:table_name].upcase
        should_exist = false
        table[:columns].each do |column|
          if tcol.column_name == column[:column_name].upcase
            should_exist = true
            break
          end
        end
        if !should_exist
          sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} DROP COLUMN #{tcol.column_name}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
        end
      end
    end
  end

  def check_table_pkey(table)
    ############ Check Primary Key
    if table[:primary_key]
      pk_name = "#{table[:table_name][0,27]}_PK"
      if @ora_tab_pkeys[table[:table_name].upcase]                              # PKey exists for table
        ########### Check columns of primary key
        existing_pk_columns_count = 0
        @ora_tab_pk_cols.each {|pk| existing_pk_columns_count += 1 if pk.table_name == table[:table_name].upcase }

        table[:primary_key][:columns].each_index do |index|
          column = table[:primary_key][:columns][index]
          if !@ora_tab_pk_cols.include?({'table_name' => table[:table_name].upcase, 'column_name' => column.upcase, 'position' => index+1}) || existing_pk_columns_count != table[:primary_key][:columns].count
            sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} DROP CONSTRAINT #{pk_name}"
            log(sql)
            PanoramaConnection.sql_execute(sql)

            # Check if pk-Index remains and should be dropped separately
            if 0 < PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM All_Indexes WHERE Owner = ? AND Index_Name = ?",  @sampler_config.get_owner.upcase, pk_name.upcase])
              sql = "DROP INDEX #{@sampler_config.get_owner}.#{pk_name}"
              log(sql)
              PanoramaConnection.sql_execute(sql)
            end
            break
          end
        end
      end


      ########### Check PK-Index existence
      check_index(table[:table_name], pk_name, table[:primary_key][:columns], table[:primary_key][:compress], true)

      ######## Check existence of PK-Constraint
      if !@ora_tab_pkeys[table[:table_name].upcase]   # PKey does not exist
        sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} ADD CONSTRAINT #{pk_name} PRIMARY KEY ("
        table[:primary_key][:columns].each do |pk|
          sql << "#{pk},"

          # Ensure that PK-Columns doesn't contain NULL-values
          del_sql = "DELETE FROM #{@sampler_config.get_owner}.#{table[:table_name]} WHERE #{pk} IS NULL"
          log(del_sql)
          PanoramaConnection.sql_execute(del_sql)
        end
        sql[(sql.length) - 1] = ' '                                               # remove last ,
        sql << ") USING INDEX #{@sampler_config.get_owner}.#{pk_name}"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end
    end

    if table[:primary_key].nil? &&  @ora_tab_pkeys[table[:table_name].upcase]   # PKey exists but should not
      sql = "ALTER TABLE #{@sampler_config.get_owner}.#{table[:table_name]} DROP CONSTRAINT #{@ora_tab_pkeys[table[:table_name].upcase].constraint_name}"
      log(sql)
      PanoramaConnection.sql_execute(sql)

      sql = "DROP INDEX #{@sampler_config.get_owner}.#{@ora_tab_pkeys[table[:table_name].upcase].index_name}"
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end
  end

  def check_table_indexes(table)
  ############ Check Indexes
    if table[:indexes]
      table[:indexes].each do |index|
        check_index(table[:table_name], index[:index_name], index[:columns], index[:compress], index[:unique])
      end
    end

  end

  # compress - Number of columns to compress
  def check_index(table_name, index_name, columns, compress, uniqueness)
    if @ora_indexes[index_name.upcase] && @ora_indexes[index_name.upcase].table_name == table_name.upcase # Index exists
      # if @ora_indexes.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase})  # Index exists

      # Check Status of index
      if @ora_indexes[index_name.upcase].status != 'VALID'
        sql = "ALTER INDEX #{@sampler_config.get_owner}.#{index_name} REBUILD"           # Force recreation of index
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end

      ########### Check columns of index
      columns.each_index do |i|
        column = columns[i]

        if !@ora_indexes[index_name.upcase][:columns].detect {|e| e.column_name == column.upcase && e.column_position = i+1} || @ora_indexes[index_name.upcase][:columns].count != columns.count
          #if !@ora_ind_columns.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase, 'column_name' => column.upcase, 'column_position' => i+1}) || @ora_indexes[index_name.upcase][:columns].count != columns.count
          sql = "DROP INDEX #{@sampler_config.get_owner}.#{index_name}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
          break
        end
      end
    end

    ########### Check existence of index
    if @ora_indexes[index_name.upcase].nil? || @ora_indexes[index_name.upcase].table_name != table_name.upcase
    #if !@ora_indexes.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase}) # Index does not exists
      sql = "CREATE #{'UNIQUE ' if uniqueness}INDEX #{@sampler_config.get_owner}.#{index_name} ON #{@sampler_config.get_owner}.#{table_name}("
      columns.each do |column|
        sql << "#{column},"
      end
      sql[(sql.length) - 1] = ' '                                               # remove last ,
      sql << ") PCTFREE 10"
      unless compress.nil?
        sql << " COMPRESS #{compress}"
      end
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end

    # Check compress state for already existing indexes
    if @ora_indexes[index_name.upcase] && compress != @ora_indexes[index_name.upcase].prefix_length
      sql = "ALTER INDEX #{@sampler_config.get_owner}.#{index_name} REBUILD "
      if compress.nil?
        sql << "NOCOMPRESS"
      else
        sql << "COMPRESS #{compress}"
      end

      log(sql)
      PanoramaConnection.sql_execute(sql)
    end
  end

  # Check existence and structure of view
  def check_view(view)
    if @ora_tables.include?({'table_name' => view[:view_name].upcase})
      sql = "DROP TABLE #{@sampler_config.get_owner}.#{view[:view_name]}"         # Remove table from previous releases with same name
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end

    if @ora_views.include?({'view_name' => view[:view_name].upcase})            # View already exists
      index = @ora_view_texts.find_index { |view_text| view_text.view_name ==  view[:view_name].upcase}
      select = @ora_view_texts[index].text
      if select != view[:view_select].call                                      # Recreate view
        sql = "DROP VIEW #{@sampler_config.get_owner}.#{view[:view_name]}"
        log(sql)
        PanoramaConnection.sql_execute(sql)
        create_view(view)
      end
    else                                                                        # View dow not exist
      create_view(view)
    end
    check_object_privs(view[:view_name])                                        # check SELECT grant to PUBLIC
  end

  def create_view(view)
    sql = "CREATE VIEW #{@sampler_config.get_owner}.#{view[:view_name]} AS\n#{view[:view_select].call}"
    log(sql)
    PanoramaConnection.sql_execute(sql)
  end

  def check_object_privs(object_name)
    ############ Check table or view privileges
    if !@ora_tab_privs.include?({'table_name' => object_name.upcase})
      sql = "GRANT SELECT ON #{@sampler_config.get_owner}.#{object_name} TO PUBLIC"
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end

  end
end