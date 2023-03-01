# hold open SQL-Cursor and iterate over SQL-result without storing whole result in Array
# Peter Ramm, 02.03.2016


# resolve ActiveRecord::ConnectionAdapters::NullPool in active_record/connection_adapters/abstract_adapter:90
require 'active_record/connection_adapters/abstract/connection_pool'

require 'active_record/connection_adapters/abstract_adapter'

require 'active_record/connection_adapters/oracle_enhanced/connection'
require 'active_record/connection_adapters/oracle_enhanced_adapter'
require 'active_record/connection_adapters/oracle_enhanced/quoting'
require 'encryption'
require 'pack_license'
require 'select_hash_helper'
require 'java'

# Helper-class to allow usage of method "type_cast"
class TypeMapper < ActiveRecord::ConnectionAdapters::AbstractAdapter
    include ActiveRecord::ConnectionAdapters::OracleEnhanced::Quoting
  def initialize                                                                # fake parameter "connection"
    super('Dummy')
  end
end

# expand class by getter to allow access on internal variable @raw_statement
ActiveRecord::ConnectionAdapters::OracleEnhanced::JDBCConnection::Cursor.class_eval do
  def get_raw_statement
    @raw_statement
  end
end

# Class extension by Module-Declaration : module ActiveRecord, module ConnectionAdapters, module OracleEnhancedDatabaseStatements
# does not work as Engine with Winstone application server, therefore hard manipulation of class ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
# and extension with method iterate_query

ActiveRecord::ConnectionAdapters::OracleEnhanced::JDBCConnection.class_eval do

  def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = '[not defined]')
    ActiveSupport::Notifications.instrumenter.instrument(
        "sql.active_record",
        :sql                => sql,
        :name               => name,
        :connection_id      => object_id,
        :statement_name     => statement_name,
        :binds              => binds,
        :type_casted_binds  => type_casted_binds
    ) { yield }
  end

  # Method comparable with ActiveRecord::ConnectionAdapters::OracleEnhancedDatabaseStatements.exec_query,
  # but without storing whole result in memory
  def iterate_query(sql, name = 'SQL', binds = [], modifier = nil, query_timeout = nil, &block)
    # Variante für Rails 5
    type_casted_binds = binds.map { |attr| TypeMapper.new.type_cast(attr.value_for_database) }

    log(sql, name, binds, type_casted_binds) do
      cursor = nil
      cursor = prepare(sql)
      cursor.bind_params(type_casted_binds) if !binds.empty?

      cursor.get_raw_statement.setQueryTimeout(query_timeout.to_i) if query_timeout          # Erweiterunge gegenüber exec_query

      cursor.exec

      columns = cursor.get_col_names.map do |col_name|
        # @connection.oracle_downcase(col_name)                               # Rails 5-Variante
        # oracle_downcase(col_name) moved to private _oracle_downcase
        #col_name =~ /[a-z]/ ? col_name : col_name.downcase!
        col_name.downcase!.freeze
      end
      fetch_options = {:get_lob_value => (name != 'Writable Large Object')}
      # noinspection RubyAssignmentExpressionInConditionalInspection
      row_count = 0
      while row = cursor.fetch(fetch_options)
        row_count += 1
        result_hash = {}
        columns.each_index do |index|
          result_hash[columns[index]] = row[index]
          row[index] = row[index].strip if row[index].class == String   # Remove possible 0x00 at end of string, this leads to error in Internet Explorer
        end
        result_hash.extend SelectHashHelper
        modifier.call(result_hash)  unless modifier.nil?
        yield result_hash
      end

      Rails.logger.debug "#{row_count} records "
      nil
    ensure
      cursor.close if defined?(cursor) && !cursor.nil?
    end
  end #iterate_query

  # Method comparable to ActiveRecord::ConnectionAdapters::OracleEnhancedDatabaseStatements.exec_update
  def exec_update(sql, name, binds)
    type_casted_binds = binds.map { |attr| TypeMapper.new.type_cast(attr.value_for_database) }

    log(sql, name, binds, type_casted_binds) do
      cursor = prepare(sql)
      cursor.bind_params(type_casted_binds) if !binds.empty?
      res = cursor.exec_update
      res
    ensure
      cursor.close if defined?(cursor) && !cursor.nil?
    end
  end
end #class_eval

# Holds DB-Connection(s) to several Oracle-targets thread-safe apart from ActiveRecord

# Config for DB connection for current threads request is stored in Thread.current[:]

MAX_CONNECTION_POOL_SIZE = ENV['MAX_CONNECTION_POOL_SIZE'] || 100               # Number of pooled connections, may be more than max. threads

# noinspection RubyClassVariableUsageInspection
class PanoramaConnection

  attr_accessor :used_in_thread
  attr_accessor :last_used_time
  attr_accessor :last_used_query_timeout
  attr_accessor :sql_errors_count
  attr_reader :block_common_header_size
  attr_reader :cdb
  attr_reader :con_id
  attr_reader :database_name
  attr_reader :data_header_size
  attr_reader :dbid
  attr_reader :db_blocksize
  attr_reader :db_wordsize
  attr_reader :db_version
  attr_reader :edition
  attr_reader :instance_count
  attr_reader :instance_number
  attr_reader :jdbc_connection
  attr_reader :last_used_action_name
  attr_reader :login_container_dbid                                             # DBID of the PDB where user is connected to
  attr_reader :logon_time
  attr_reader :password_hash
  attr_reader :pid
  attr_reader :rowid_size
  attr_reader :saddr
  attr_reader :serial_no
  attr_reader :sid
  attr_reader :sql_stmt_in_execution
  attr_reader :table_directory_entry_size
  attr_reader :transaction_fixed_header_size
  attr_reader :transaction_variable_header_size
  attr_reader :unsigned_byte_4_size


  # Array of PanoramaConnection instances, elements consists of:
  #   @jdbc_connection
  #   @used_in_thread
  #   @last_used_time
  @@connection_pool = []

  @@connection_pool_mutex = Mutex.new                                           # Ensure synchronized operations on @@connection_pool

  public

  ############################ instance methods #########################
  def initialize(new_jdbc_connection)                                    # Object instantiation is always done within working thread
    @jdbc_connection          = new_jdbc_connection
    @used_in_thread           = true
    @last_used_query_timeout  = 600                                             # initial value, should be overwritten in check_for_open_connection
    @last_used_time           = Time.now
    @password_hash            = PanoramaConnection.get_decrypted_password.hash
    @sql_errors_count         = 0                                               # No errors counted for this SQL
  end

  def read_initial_attributes
    db_config   = PanoramaConnection.direct_select_one(@jdbc_connection,
                  "SELECT i.Instance_Number, i.Version, d.DBID, d.Name Database_Name, SYS_CONTEXT('USERENV', 'SID') SID,
                          (SELECT /*+ NO_MERGE */ TO_NUMBER(Value) FROM v$parameter WHERE UPPER(Name) = 'DB_BLOCK_SIZE')                                    db_blocksize,
                          (SELECT /*+ NO_MERGE */ DECODE (INSTR (banner, '64bit'), 0, 4, 8) Word_Size FROM v$version WHERE Banner LIKE '%Oracle Database%') db_wordsize,
                          (SELECT /*+ NO_MERGE */ COUNT(*) FROM v$version WHERE Banner LIKE '%Enterprise Edition%' OR Banner LIKE '%EE%')                   enterprise_edition_count,
                          (SELECT /*+ NO_MERGE */ COUNT(*) FROM v$version WHERE Banner LIKE '%Express Edition%')                                            express_edition_count,
                          (SELECT /*+ NO_MERGE */ COUNT(*) FROM gv$Instance)                                                                                instance_count,
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'KCBH')                                                                           Block_Common_Header_Size,
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'UB4')                                                                            Unsigned_Byte_4_Size,
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'KTBBH')                                                                          Transaction_Fixed_Header_Size,
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'KTBIT')                                                                          Transaction_Var_Header_Size, /* Size of ITL entry */
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'KDBH')                                                                           Data_Header_Size,
                          (SELECT Type_Size FROM v$Type_Size WHERE Type = 'KDBT')                                                                           Table_Directory_Entry_Size,
                          (SELECT VSIZE(rowid) FROM Dual)                                                                                                   RowID_Size,
                          SYSDATE                                                                                                                           Logon_time
                   FROM   v$Instance i
                   CROSS JOIN v$Database d
                  ")
    @block_common_header_size         = db_config['block_common_header_size']
    @data_header_size                 = db_config['data_header_size']
    @db_version                       = db_config['version']
    @dbid                             = db_config['dbid']
    @database_name                    = db_config['database_name']
    @db_blocksize                     = db_config['db_blocksize']
    @db_wordsize                      = db_config['db_wordsize']
    @edition                          = (db_config['enterprise_edition_count'] > 0  ? :enterprise : (db_config['express_edition_count'] > 0 ?  :express : :standard) )
    @instance_count                   = db_config['instance_count']
    @instance_number                  = db_config['instance_number']
    @login_container_dbid             = db_config['dbid']                       # Default is DB's DBID, specified later for CDBs
    @logon_time                       = db_config['logon_time']
    @rowid_size                       = db_config['rowid_size']
    @sid                              = db_config['sid']                          # Session-ID on DB-Server
    @table_directory_entry_size       = db_config['table_directory_entry_size']
    @table_directory_entry_size       = @unsigned_byte_4_size if @table_directory_entry_size.nil? # not set in any releases
    @transaction_fixed_header_size    = db_config['transaction_fixed_header_size']
    @transaction_variable_header_size = db_config['transaction_var_header_size']
    @unsigned_byte_4_size             = db_config['unsigned_byte_4_size']

    @db_version = PanoramaConnection.direct_select_one(@jdbc_connection, "SELECT Version_Full FROM v$Instance")['version_full'] if @db_version >= '19'

    session_info = PanoramaConnection.direct_select_one(@jdbc_connection, "SELECT s.Serial# Serial_No #{", s.Con_ID" if @db_version >= '12.1'},
                                                                                  RawToHex(s.Saddr) Saddr, p.PID
                                                                           FROM   v$Session s
                                                                           JOIN   v$Process p ON p.Addr = s.pAddr
                                                                           WHERE s.audsid = SYS_CONTEXT('USERENV', 'sessionid')")
    @serial_no  = session_info['serial_no']
    @saddr      = session_info['saddr']
    @pid        = session_info['pid']

    if @db_version >= '12.1'
      @con_id               = session_info['con_id']
      @cdb                  = PanoramaConnection.direct_select_one(@jdbc_connection, "SELECT CDB FROM v$Database")['cdb']
      @login_container_dbid = PanoramaConnection.direct_select_one(@jdbc_connection, "SELECT DBID FROM v$Containers WHERE Con_ID = (SELECT Con_ID FROM v$Session WHERE SID = SYS_CONTEXT('userenv', 'sid'))")['dbid']
    else
      @con_id        = 0
      @cdb           = 'NO'
    end
  end

  def register_sql_execution(stmt)
    @sql_stmt_in_execution = stmt
  end

  def unregister_sql_execution
    @sql_stmt_in_execution = nil
  end

  def set_module_action(action_name)
    if !defined?(@last_used_action_name) || @last_used_action_name != action_name
      @jdbc_connection.exec_update("call dbms_application_info.set_Module('Panorama', :action)", 'set_application_info',
                                   [ActiveRecord::Relation::QueryAttribute.new(':action', action_name, ActiveRecord::Type::Value.new)]
      )
    end
    @last_used_action_name = action_name
  end

  def get_config_from_jdbc_connection
    @jdbc_connection.instance_variable_get(:@config)
  end

  #### Lazy cached values

  # nil if no autonomous DB
  def autonomous_database
    if !defined?(@autonomous_database) || @autonomous_database.nil?
      @autonomous_database = false                                              # assume autonomous if next selection fails
      begin
        PanoramaConnection.direct_select_one(@jdbc_connection, "SELECT ts# FROM sys.TS$ WHERE RowNum < 2")
      rescue Exception => e
        @autonomous_database = true                                             # autonomous database because sys.TS$ is not readable
      end
    end
    @autonomous_database
  end

  # Select PDBs each time they are requested because number of PDBs may change during lifetime of PanoramaConnection
  def pdbs
    if !defined?(@pdbs) || @pdbs.nil?
      if db_version >= '12.1'
        @pdbs = PanoramaConnection.direct_select(@jdbc_connection, "SELECT DISTINCT Con_ID, DBID, Name FROM gv$Containers WHERE Con_ID != 0").map do |p|
          { con_id: p['con_id'], dbid: p['dbid'], name: p['name']}
        end
      else
        @pdbs = []
      end
    end
    @pdbs
  end

  # Cache existing DBIDs once per connection
  def all_awr_dbids
    if !defined?(@awr_dbids) || @awr_dbids.nil?
      @awr_dbids = case PanoramaConnection.get_threadlocal_config[:management_pack_license]
                   when 'NONE' then []                                          # suppress access violations on AWR tables
                   else
                     PanoramaConnection.sql_select_all "\
                      SELECT s.DBID, n.DB_Name, s.Start_TS, s.End_TS, Con_ID
                      FROM   (
                               SELECT DBID, MIN(Begin_Interval_Time) Start_TS, MAX(End_Interval_Time) End_TS,
                               #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"} Con_ID
                      FROM   DBA_Hist_Snapshot ss
                      GROUP BY DBID, #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
                      ) s
                      JOIN   (SELECT /*+ NO_MERGE */ DBID,
                                     MAX(DB_Name) KEEP (DENSE_RANK LAST ORDER BY Startup_Time) DB_Name
                              FROM   DBA_Hist_Database_Instance d
                              GROUP BY DBID
                             ) n ON n.DBID = s.DBID"
                   end
    end
    @awr_dbids
  end

  def stat_id_consistent_gets
    if !defined?(@stat_id_consistent_gets)
      @stat_id_consistent_gets = PanoramaConnection.sql_select_one "SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets'"
    end
    @stat_id_consistent_gets
  end
  ########################### class methods #############################
  # Store connection redentials for this request in thread, marks begin of request
  def self.set_connection_info_for_request(config)
    reset_thread_local_attributes
    Thread.current[:panorama_connection_connect_info] = config
  end

  # Ensure initialized values if thread is reused
  def self.reset_thread_local_attributes
    Thread.current[:panorama_connection_app_info_set] = nil
    Thread.current[:panorama_connection_connect_info] = nil
  end

  # set the initial value for used dbid at login time (DB's DBID or CDB's DBID)
  def self.select_initial_dbid
    unless PanoramaConnection.is_cdb?            # used DB's DBID if not CDB
      Rails.logger.debug('PanoramaConnection.select_initial_dbid') { "Choosen #{PanoramaConnection.dbid} beacuse DB is not a CDB"}
      return PanoramaConnection.dbid
    end
    begin
      login_container_snapshot_count=  sql_select_one(["SELECT COUNT(*) FROM DBA_Hist_Snapshot WHERE DBID = ?", PanoramaConnection.login_container_dbid])
    rescue Exception => e
      if e.message['ORA-00942']
        Rails.logger.debug('PanoramaConnection.select_initial_dbid') { "Choosen #{PanoramaConnection.dbid} beacuse selecting xxx_Sanpshot ended up in ORA-00942"}
        return PanoramaConnection.dbid                                          # DBA_Hist_Snapshot does not already exists! Should happen only if Panorama_Snapshot is used for sampler and DB structures are not yet created
      else
        raise
      end
    end
    if login_container_snapshot_count == 0                                      # Check if AWR for container is really sampled
      Rails.logger.debug('PanoramaConnection.select_initial_dbid') { "Choosen #{PanoramaConnection.dbid} beacuse there are no snapshots for #{PanoramaConnection.login_container_dbid}"}
      return PanoramaConnection.dbid                                            # Use connections DBID if container has no AWR data
    else
      Rails.logger.debug('PanoramaConnection.select_initial_dbid') { "Choosen #{PanoramaConnection.login_container_dbid} beacuse there are snapshots for that DBID"}
      return PanoramaConnection.login_container_dbid                            # Use containers DBID if container has AWR data
    end
  end

  # Release connection at the end of request to mark free in pool or destroy
  def self.release_connection
    if Thread.current[:panorama_connection_connection_object]
      @@connection_pool_mutex.synchronize do
        Thread.current[:panorama_connection_connection_object].used_in_thread = false
      end
      Thread.current[:panorama_connection_connection_object] = nil
    end
    PanoramaConnection.reset_thread_local_attributes                            # Ensure fresh thread attributes if thread is reused from pool
  end

  def self.destroy_connection
    if !Thread.current[:panorama_connection_connection_object].nil?
      @@connection_pool_mutex.synchronize do
        destroy_connection_in_mutexed_pool(Thread.current[:panorama_connection_connection_object])
      end
      Thread.current[:panorama_connection_connection_object] = nil
    end
  end

  # disconnect connections that are not used for x seconds
  # Active connections are observed by socket timeout set during connect by setNetworkTimeout
  # There's no way to logoff a working connection because logoff blocks until end of statement execution
  def self.disconnect_aged_connections(min_age_for_disconnect_idle)
    @@connection_pool_mutex.synchronize do
      @@connection_pool.clone.each do |conn|                                    # clone to ensure eqch connection is checked even if Array-nodes are removed between
        config = conn.jdbc_connection.instance_variable_get(:@config)
        if !conn.used_in_thread && conn.last_used_time < Time.now - min_age_for_disconnect_idle
          Rails.logger.info "Disconnect DB connection because last used is older than #{min_age_for_disconnect_idle} seconds: URL='#{config[:url]}' user='#{config[:username]}' last used=#{conn.last_used_time} last action='#{conn.last_used_action_name}' SID=#{conn.sid}"
          destroy_connection_in_mutexed_pool(conn)
        end

        # Ensure that cancelled network connections are removed from connection pool
        # Cancelling should be done by setNetworkTimeout, Exception handling due to socket read error should remove connection from pool
        min_age_for_active_disconnect = conn.last_used_query_timeout * 2
        if conn.used_in_thread && conn.last_used_time < Time.now - min_age_for_active_disconnect
          Rails.logger.error('PanoramaConnection.disconnect_aged_connections') { "Long running active DB connection should have been cancelled yet by socket read timeout after #{min_age_for_active_disconnect} seconds: URL='#{config[:url]}' User='#{config[:username]}', last used=#{conn.last_used_time}, last action='#{conn.last_used_action_name}', last query timeout=#{conn.last_used_query_timeout}" }
        end
      end
    end
  rescue Exception => e
    Rails.logger.error('PanoramaConnection.disconnect_aged_connections') { "Exception #{e.class}:\n#{e.message}" }
    log_exception_backtrace(e, 40)
    raise e
  end


  def self.get_connection_pool                                                  # get pool info, for read access only
    @@connection_pool
  end


  def self.all_awr_dbids;                   check_for_open_connection;        Thread.current[:panorama_connection_connection_object].all_awr_dbids;                     end
  def self.autonomous_database?;            check_for_open_connection;        Thread.current[:panorama_connection_connection_object].autonomous_database;               end
  def self.block_common_header_size;        check_for_open_connection;        Thread.current[:panorama_connection_connection_object].block_common_header_size;          end
  def self.con_id;                          check_for_open_connection;        Thread.current[:panorama_connection_connection_object].con_id;                            end  # Container-ID for PDBs or 0
  def self.data_header_size;                check_for_open_connection;        Thread.current[:panorama_connection_connection_object].data_header_size;                  end
  def self.db_version;                      check_for_open_connection;        Thread.current[:panorama_connection_connection_object].db_version;                        end
  def self.dbid;                            check_for_open_connection;        Thread.current[:panorama_connection_connection_object].dbid;                              end
  def self.database_name;                   check_for_open_connection;        Thread.current[:panorama_connection_connection_object].database_name;                     end
  def self.db_blocksize;                    check_for_open_connection;        Thread.current[:panorama_connection_connection_object].db_blocksize;                      end
  def self.db_wordsize;                     check_for_open_connection;        Thread.current[:panorama_connection_connection_object].db_wordsize;                       end
  def self.edition;                         check_for_open_connection;        Thread.current[:panorama_connection_connection_object].edition;                           end
  def self.instance_number;                 check_for_open_connection;        Thread.current[:panorama_connection_connection_object].instance_number;                   end
  def self.is_cdb?;                         check_for_open_connection;        Thread.current[:panorama_connection_connection_object].cdb == 'YES';                      end
  def self.last_used_action_name;           check_for_open_connection;        Thread.current[:panorama_connection_connection_object].last_used_action_name;             end
  def self.login_container_dbid;            check_for_open_connection(false); Thread.current[:panorama_connection_connection_object].login_container_dbid;              end
  def self.pdbs;                            check_for_open_connection;        Thread.current[:panorama_connection_connection_object].pdbs;                              end
  def self.pid;                             check_for_open_connection;        Thread.current[:panorama_connection_connection_object].pid;                               end
  def self.rac?;                            check_for_open_connection;        Thread.current[:panorama_connection_connection_object].instance_count > 1;                end
  def self.rowid_size;                      check_for_open_connection;        Thread.current[:panorama_connection_connection_object].rowid_size;                        end
  def self.saddr;                           check_for_open_connection;        Thread.current[:panorama_connection_connection_object].saddr;                             end
  def self.serial_no;                       check_for_open_connection;        Thread.current[:panorama_connection_connection_object].serial_no;                         end
  def self.sid;                             check_for_open_connection;        Thread.current[:panorama_connection_connection_object].sid;                               end
  def self.stat_id_consistent_gets;         check_for_open_connection;        Thread.current[:panorama_connection_connection_object].stat_id_consistent_gets;           end
  def self.table_directory_entry_size;      check_for_open_connection;        Thread.current[:panorama_connection_connection_object].table_directory_entry_size;        end
  def self.table_directory_entry_size;      check_for_open_connection;        Thread.current[:panorama_connection_connection_object].table_directory_entry_size;        end
  def self.transaction_fixed_header_size;   check_for_open_connection;        Thread.current[:panorama_connection_connection_object].transaction_fixed_header_size;     end
  def self.transaction_variable_header_size;check_for_open_connection;        Thread.current[:panorama_connection_connection_object].transaction_variable_header_size;  end
  def self.unsigned_byte_4_size;            check_for_open_connection;        Thread.current[:panorama_connection_connection_object].unsigned_byte_4_size;              end
  def self.username;                        check_for_open_connection;        get_threadlocal_config[:user].upcase;    end

  private

  # should be called from within synchronized mutex
  def self.destroy_connection_in_mutexed_pool(destroy_conn)
    config = destroy_conn.jdbc_connection.instance_variable_get(:@config)
    thread = Thread.new{PanoramaConnection.destroy_jdbc_connection_in_thread(destroy_conn, config)}  # Schedule disconnect of connection in separate thread because it may block
    thread.name = 'PanoramaConnection.destroy_jdbc_connection_in_thread'
    @@connection_pool.delete(destroy_conn)
    Rails.logger.info "Database connection scheduled in thread to destroy: URL='#{config[:url]}' User='#{config[:username]}' Last used=#{destroy_conn.last_used_time} SID=#{destroy_conn.sid} Remaining pool size=#{@@connection_pool.count}"
  end

  # Should be called in separate thread because it may block until TCP read timeout
  def self.destroy_jdbc_connection_in_thread(destroy_conn, config)
    destroy_conn.jdbc_connection.logoff
    Rails.logger.info "destroy_jdbc_connection_in_thread: Database connection destroyed: URL='#{config[:url]}' User='#{config[:username]}' Last used=#{destroy_conn.last_used_time} SID=#{destroy_conn.sid} Remaining pool size=#{@@connection_pool.count}"
  rescue Exception => e
    Rails.logger.info "destroy_jdbc_connection_in_thread: #{e.class} #{e.message} during logoff. URL='#{config[:url]}' User='#{config[:username]}' Last used=#{destroy_conn.last_used_time} SID=#{destroy_conn.sid}"
  end

  def self.get_host_tns(current_database)                                            # JDBC-URL for host/port/sid
    sid_separator = case current_database[:sid_usage].to_sym
                      when :SID then          ':'
                      when :SERVICE_NAME then '/'
                      else raise "Unknown value '#{current_database[:sid_usage]}' for :sid_usage"
                    end
    connect_prefix = current_database[:sid_usage].to_sym==:SERVICE_NAME ? '//' : ''                 # only for service name // is needed at first
    "#{connect_prefix}#{current_database[:host]}:#{current_database[:port]}#{sid_separator}#{current_database[:sid]}"   # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
  end

  def self.jdbc_thin_url
    "jdbc:oracle:thin:@#{get_threadlocal_config[:tns]}"
  end

  def self.get_jdbc_raw_connection
    check_for_open_connection
    Thread.current[:panorama_connection_connection_object].jdbc_connection.raw_connection
  end

  def self.get_jdbc_driver_version
    get_jdbc_raw_connection.getMetaData.getDriverVersion
  rescue Exception => e
    e.message                                                                   # return Exception message instead of raising exeption
  end


  def self.sql_prepare_binds(sql)
    binds = []
    if sql.class == Array
      stmt =sql[0].clone      # Kopieren, da im Stmt nachfolgend Ersetzung von ? durch :A1 .. :A<n> durchgeführt wird
      # Aufbereiten SQL: Ersetzen Bind-Aliases
      bind_index = 0
      while stmt['?']                   # Iteration über Binds
        bind_index = bind_index + 1
        bind_alias = ":A#{bind_index}"
        stmt['?'] = bind_alias          # Ersetzen ? durch Host-Variable

        raise "bind value at position #{bind_index} missing for '#{bind_alias}' in binds-array!\nBinds: #{sql.drop(1)}\nSQL:\n #{stmt}" if sql.count <= bind_index
        raise "bind value at position #{bind_index} is NULL for '#{bind_alias}' in binds-array!\nBinds: #{sql.drop(1)}\nSQL:\n #{stmt}" unless sql[bind_index]

        binds << ActiveRecord::Relation::QueryAttribute.new(bind_alias, sql[bind_index], ActiveRecord::Type::Value.new)   # Ab Rails 5
        # binds << [ ActiveRecord::ConnectionAdapters::Column.new(bind_alias, nil, ActiveRecord::Type::Value.new), sql[bind_index]] # Neu ab Rails 4.2.0, Abstrakter Typ muss angegeben werden
      end
    else
      if sql.class == String
        stmt = sql
      else
        raise "Unsupported Parameter-Class '#{sql.class.name}' for parameter sql of sql_select_all(sql)"
      end
    end
    [stmt, binds]
  end

  public

  # Replace table_name according to license, used for view captions
  def self.adjust_table_name(table_name)
    PackLicense.translate_sql_table_names(table_name, get_threadlocal_config[:management_pack_license])
  end

  def self.get_nested_exception_message(exception)
    if exception.cause                                                          # exception class supports cause
      message = ''
      cause = exception
      while cause = cause.cause                                                 # dig into nested causes
        message << "#{cause.class}:\n#{cause.message}"
      end
      message
    else
      "#{exception.class}:\n#{exception.message}"                               # direct use of exception's message
    end
  end

  # Analog sql_select all, jedoch return ResultIterator mit each-Method
  # liefert Objekt zur späteren Iteration per each, erst dann wird SQL-Select ausgeführt (jedesmal erneut)
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  def self.sql_select_iterator(sql, modifier=nil, query_name = 'sql_select_iterator')
    check_for_open_connection                                                   # ensure opened Oracle-connection
    stmt, binds = sql_prepare_binds(PackLicense.filter_sql_for_pack_license(sql))   # Transform SQL and split SQL and binds
    SqlSelectIterator.new(
      stmt:           translate_sql(stmt),
      binds:          binds,
      modifier:       modifier,
      query_name:     query_name
    )      # kann per Aufruf von each die einzelnen Records liefern
  end

  # Helper fuer Ausführung SQL-Select-Query,
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  # return Array of Hash mit Columns des Records
  def self.sql_select_all(sql, modifier=nil, query_name = 'sql_select_all')   # Parameter String mit SQL oder Array mit SQL und Bindevariablen
    result = []
    PanoramaConnection::sql_select_iterator(sql, modifier, query_name).each do |r|
      result << r
    end
    result
  end

  # Select genau erste Zeile
  def self.sql_select_first_row(sql, query_name = 'sql_select_first_row')
    result = sql_select_all(sql, nil, query_name)
    return nil if result.empty?
    result[0]     #.extend SelectHashHelper      # Erweitern Hash um Methodenzugriff auf Elemente
  end

  # Select genau einen Wert der ersten Zeile des Result
  def self.sql_select_one(sql, query_name = 'sql_select_one')
    result = sql_select_first_row(sql, query_name)
    return nil unless result
    result.first[1]           # Value des Key/Value-Tupels des ersten Elememtes im Hash
  end

  def self.sql_execute(sql, query_name = 'sql_execute')
    # raise 'binds are not yet supported for sql_execute' if sql.class != String
    transformed_sql = PackLicense.filter_sql_for_pack_license(sql)  # Check for lincense violation and possible statement transformation
    stmt, binds = sql_prepare_binds(transformed_sql)   # Transform SQL and split SQL and binds
    sql_execute_native(sql: stmt, binds: binds, query_name: query_name)
  end

  # Execute with direct AR binds
  def self.sql_execute_native(sql:, binds:, query_name: 'sql_execute_native')
    check_for_open_connection                                                   # ensure opened Oracle-connection
    # Without query_timeout because long lasting ASH sampling is executed with this method
    Thread.current[:panorama_connection_connection_object].register_sql_execution(sql)
    begin
      get_connection.exec_update(sql, query_name, binds)
    rescue Exception => e
      if e.message['ORA-10632']
        Rails.logger.error('PanoramaConnection.sql_execute_native') { "#{e.class}:#{e.message}! Retrying execution of SQL\n#{sql}" }
        sleep(10)
        # reexecute the SQL in case of ORA-10632: invalid rowid
        # this can happen at CREATE TABLE with ENABLE ROW MOVEMENT, especially for 19.10 SE2
        get_connection.exec_update(sql, query_name, binds)
      else
        raise
      end
    end
  rescue Exception => e
    PanoramaConnection.check_for_erroneous_connection_removal(e)                # check if too much errors occurred for this connection

    bind_text = ''
    unless binds.nil?
      binds.each do |b|
        bind_text << "#{b.name} = #{b.value}\n"
      end
    end


    # Ensure stacktrace of first exception is show
    msg = "Error while executing SQL:\n#{PanoramaConnection.get_nested_exception_message(e)}\nSQL-Statement:\n#{sql}\n#{bind_text.length > 0 ? "Bind-Values:\n#{bind_text}" : ''}"
    new_ex = Exception.new(msg)
    new_ex.set_backtrace(e.backtrace)
    raise new_ex
  ensure
    Thread.current[:panorama_connection_connection_object]&.unregister_sql_execution
  end

  def self.commit                                                               # only relevant if autocommit is switched off
    PanoramaConnection.get_connection.commit
  end

  def self.rollback
    PanoramaConnection.get_connection.rollback                                  # only relevant if autocommit is switched off
  end

  # @return JDBC connection object
  def self.get_connection
    check_for_open_connection
    Thread.current[:panorama_connection_connection_object].jdbc_connection
  end

  def self.get_threadlocal_config

    unless Thread.current[:panorama_connection_connect_info]
      Rails.logger.error('PanoramaConnection.get_threadlocal_config') { "Thread.current[:panorama_connection_connect_info] does not exist" }
      Rails.logger.error('PanoramaConnection.get_threadlocal_config') { "Stack trace:\n#{Thread.current.backtrace.join("\n")}" }
      raise 'No current DB connect info set! Please reconnect to DB or restart Panorama in browser!'
    end
    Thread.current[:panorama_connection_connect_info]
  end

  def self.user_table_exists?(table_name)
    self.sql_select_one(["SELECT COUNT(*) FROM User_Tables WHERE Table_Name = UPPER(?)", table_name]) > 0
  end

  private
  # ensure that Oracle-Connection exists and DBMS__Application_Info is executed
  def self.check_for_open_connection(register_module_action = true)
    if Thread.current[:panorama_connection_connection_object].nil?                # No JDBC-Connection allocated for thread
      Thread.current[:panorama_connection_connection_object] = retrieve_from_pool_or_create_new_connection
    end

    if register_module_action && Thread.current[:panorama_connection_app_info_set].nil?  # dbms_application_info not yet set in thread
      begin
        set_application_info
      rescue Exception => e
        Rails.logger.error('PanoramaConnection.check_for_open_connection') { "Error #{e.class}:'#{e.message}'! Drop connection and look for next one from pool" }
        destroy_connection                                                      # Remove erroneous connection from pool
        Thread.current[:panorama_connection_connection_object] = retrieve_from_pool_or_create_new_connection  # get new connection from pool or create
        set_application_info                                                    # Set application info again and throw exception if error persists
      end
      Thread.current[:panorama_connection_app_info_set] = true
    end

    # remember last used query timeout for usage in connection_terminate_job
    Thread.current[:panorama_connection_connection_object].last_used_query_timeout = get_threadlocal_config[:query_timeout]
  end

  # Test if connection should be closed after too many errors during SQL execution
  # This should prevent from repeated usage of sessions with persisting problems like 'ORA-16000: database or pluggable database open for read-only access'
  MAX_CONNECTION_SQL_ERRORS_BEFORE_CLOSE=10
  def self.check_for_erroneous_connection_removal(exception)
    immediate_destroy_reasons = [
      'Closed Connection'
    ]
    conn = Thread.current[:panorama_connection_connection_object]
    immediate_destroy_reasons.each do |reason|
      if exception.message[reason]                                              # Exception message contains searched string
        Rails.logger.error('PanoramaConnection.check_for_erroneous_connection_removal') { "DB-Connection '#{conn.sid},#{conn.serial_no}' immediately destroyed after SQL error because of '#{reason}' in exception message"}
        PanoramaConnection.destroy_connection                                     # Force reconnect at next operation
      end
    end
    conn.sql_errors_count =  conn.sql_errors_count + 1                          # remember the error during SQL
    if conn.sql_errors_count > MAX_CONNECTION_SQL_ERRORS_BEFORE_CLOSE
      Rails.logger.error('PanoramaConnection.check_for_erroneous_connection_removal') { "DB-Connection '#{conn.sid},#{conn.serial_no}' destroyed due to more than #{MAX_CONNECTION_SQL_ERRORS_BEFORE_CLOSE} SQL errors during this DB session"}
      PanoramaConnection.destroy_connection                                     # Force reconnect at next operation
    end
  end

  # get existing free connection from pool or create new connection
  def self.retrieve_from_pool_or_create_new_connection
    retval = nil
    @@connection_pool_mutex.synchronize do
      # Check if there is a free connection in pool
      @@connection_pool.each do |conn|                                          # Iterate over connections in pool
        connection_config = conn.jdbc_connection.instance_variable_get(:@config)  # Active JDBC connection config
        if retval.nil? &&                                                       # Searched connection, not already in use
            !conn.used_in_thread &&
            connection_config[:url] == jdbc_thin_url &&
            connection_config[:username] == get_threadlocal_config[:user] &&
            conn.password_hash == get_decrypted_password.hash                   # Password must be equal to that used in pooled connection
          Rails.logger.info "Using existing database connection from pool: URL='#{jdbc_thin_url}' User='#{get_threadlocal_config[:user]}' SID=#{conn.sid} Last used=#{conn.last_used_time} Pool size=#{@@connection_pool.count}"
          conn.used_in_thread = true                                          # Mark as used in pool and leave loop
          conn.last_used_time = Time.now                                      # Reset ast used time
          retval = conn
        end
      end
    end
    # Create new connection if not found in pool
    if retval.nil?
      raise "Native ruby (RUBY_ENGINE=#{RUBY_ENGINE}) is no longer supported! Please use JRuby runtime environment! Call contact for support request if needed." if !defined?(RUBY_ENGINE) || RUBY_ENGINE != "jruby"
      # Shrink connection pool / reuse connection from pool if size exceeds limit
      retry_count = 0
      while @@connection_pool.count >= MAX_CONNECTION_POOL_SIZE
        # find oldest idle connection and free it
        @@connection_pool_mutex.synchronize do
          idle_conns =  @@connection_pool.select {|e| !e.used_in_thread }.sort { |a, b| a.last_used_time <=> b.last_used_time }
          destroy_connection_in_mutexed_pool(idle_conns[0]) if !idle_conns.empty?               # Free oldest connection

          if @@connection_pool.count >= MAX_CONNECTION_POOL_SIZE
            if retry_count < 5
              Rails.logger.info('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Maximum number of active concurrent database sessions for Panorama reached (#{MAX_CONNECTION_POOL_SIZE})!\nWaiting one second until retry." }
              retry_count += 1
              sleep 1
            else
              Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Maximum number of active concurrent database sessions for Panorama reached (#{MAX_CONNECTION_POOL_SIZE})!" }
              dump_connection_pool_to_log
              raise "Maximum number of active concurrent database sessions for Panorama exceeded (#{MAX_CONNECTION_POOL_SIZE})!\nPlease try again later."
            end
          end
        end
      end

      begin
        jdbc_connection = do_login
        if get_threadlocal_config[:modus] == 'tns'
          begin
            PanoramaConnection.direct_select_one(jdbc_connection, "SELECT /* Panorama first connection test for tns */ SYSDATE FROM DUAL")    # Connect with TNS-Alias has second try if does not function
          rescue Exception => e                                                   # Switch to host/port/sid instead
            Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Error connecting to database in first try: URL='#{PanoramaConnection.jdbc_thin_url}' TNSName='#{get_threadlocal_config[:tns]}' User='#{get_threadlocal_config[:user]}'" }
            Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "#{e.class.name} #{e.message}" }
            log_exception_backtrace(e, 30)

            jdbc_connection.logoff if !jdbc_connection.nil?                     # close/free wrong connection
            get_threadlocal_config[:modus] = 'host'
            get_threadlocal_config[:tns]   = PanoramaConnection.get_host_tns(get_threadlocal_config)
            Rails.logger.info "Second try to connect with host/port/sid instead of TNS-alias: URL='#{PanoramaConnection.jdbc_thin_url}' TNSName='#{get_threadlocal_config[:tns]}' User='#{get_threadlocal_config[:user]}'"
            jdbc_connection = do_login
            PanoramaConnection.direct_select_one(jdbc_connection, "SELECT /* Panorama second connection test for tns */ SYSDATE FROM DUAL")    # Connect with host/port/sid as second try if does not function
          end
        else
          PanoramaConnection.direct_select_one(jdbc_connection, "SELECT /* Panorama connection test for host/port/sid */ SYSDATE FROM DUAL")      # Connect with host/port/sid should function at first try
        end
      rescue Exception => e
        jdbc_connection.logoff if !jdbc_connection.nil?                     # close/free wrong connection
        Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Error connecting to database in second try: URL='#{PanoramaConnection.jdbc_thin_url}' TNSName='#{get_threadlocal_config[:tns]}' User='#{get_threadlocal_config[:user]}'" }
        Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "#{e.class.name} #{e.message}" }
        log_exception_backtrace(e, 30)
        raise
      end

      retval = PanoramaConnection.new(jdbc_connection)

      # prevent from ORA-12850: Could not allocate slaves on all specified instances: 2 needed, 1 allocated
      # Parallel slave failing with ORA-12850 with parallel_degree_policy set to AUTO (Doc ID 2663486.1)
      # Requested by Wolfgang Konz, 2021-05-21
      parallel_degree_policy_stmt = "ALTER SESSION SET parallel_degree_policy = MANUAL"
      begin
        jdbc_connection.exec_update(parallel_degree_policy_stmt, 'set parallel_degree_policy', [])
      rescue Exception => e
        Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Error '#{e.message}' while setting parallel_degree_policy with '#{parallel_degree_policy_stmt}'" }
      end

      tz_stmt = "ALTER SESSION SET Time_Zone = '#{java.util.TimeZone.get_default.get_id}'"
      begin
        jdbc_connection.exec_update(tz_stmt, 'set timezone', [])
      rescue Exception => e
          Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "Error '#{e.message}' while setting client timezone with '#{tz_stmt}'" }
      end

      begin
        retval.read_initial_attributes
      rescue Exception => e
        jdbc_connection.logoff if !jdbc_connection.nil?                     # close/free wrong connection
        Rails.logger.error('PanoramaConnection.retrieve_from_pool_or_create_new_connection') { "#{e.class.name} #{e.message}" }
        log_exception_backtrace(e, 20)
        raise "Your user needs SELECT ANY DICTIONARY or equivalent rights to login to Panorama!\n\n\n#{e.class.name} #{e.message}"
      end

      # All checks succeeded, put in connection pool now
      @@connection_pool_mutex.synchronize do
        @@connection_pool << retval
      end
    end
    retval
  end

  def self.get_decrypted_password
    decrypted_password = Encryption.decrypt_value(get_threadlocal_config[:password], get_threadlocal_config[:client_salt])
    raise "PanoramaConenction.get_decrypted_password: Result = nil after decryption" if decrypted_password.nil?
    decrypted_password
  rescue Exception => e
    msg = "Error in PanoramaConnection.get_decrypted_password decrypting pasword: #{e.class} #{e.message}"
    Rails.logger.warn('PanoramaConnection.get_decrypted_password') { msg }
    raise "One part of encryption key for stored password has changed at server side!\nPlease connect again with full connection info including username and password.\n\n#{msg}"
  end

  def self.do_login
    if (!ENV['TNS_ADMIN'] || ENV['TNS_ADMIN'] == '') && ENV['ORACLE_HOME'] && ENV['ORACLE_HOME'] != ''
      # tnsadmin = "#{ENV['ORACLE_HOME']}/network/admin" is not yet supported by Oracle_Enhanced-Adapter so we must ensure ourself that oracle.net.tns_admin is set
      # Otherwise JDBC-Error is raised when connecting with TNS-Alias: java.sql.SQLRecoverableException: I/O-Error: Unknown host specified
      if !java.lang.System.get_property("oracle.net.tns_admin") || java.lang.System.get_property("oracle.net.tns_admin") == ''
        java.lang.System.set_property("oracle.net.tns_admin", "#{ENV['ORACLE_HOME']}/network/admin")
      end
    end

    url           = jdbc_thin_url
    username      = get_threadlocal_config[:user]
    password      = get_decrypted_password
    privilege     = get_threadlocal_config[:privilege]
    query_timeout = get_threadlocal_config[:query_timeout]
    if query_timeout.nil?
      Rails.logger.info('PanoramaConnection.do_login') { "query_timeout not set in thread, assuming default value = 300" }
      query_timeout = 300
    end

    raise "PanoramaConnection.do_login: url missing"            if  url.nil?
    raise "PanoramaConnection.do_login: username missing"       if  username.nil?
    raise "PanoramaConnection.do_login: password missing"       if  password.nil?
    privilege = 'normal'                                        if  privilege.nil?
    jdbc_connection = ActiveRecord::ConnectionAdapters::OracleEnhanced::JDBCConnection.new(
        adapter:          "oracle_enhanced",
        driver:           "oracle.jdbc.driver.OracleDriver",
        url:              url,
        username:         username,
        password:         password,
        privilege:        privilege,
        cursor_sharing:  :exact,                                                # oracle_enhanced_adapter setzt cursor_sharing per Default auf force
        jdbc_connect_properties: {                                              # Needs acceptance of Pull-request for oracle_enhanced_adapter: https://github.com/rsim/oracle-enhanced/pull/2284
          'oracle.net.encryption_client'      => 'REQUESTED',
          'oracle.net.crypto_checksum_client' => 'REQUESTED'
        }
    )
    Rails.logger.info('PanoramaConnection.do_login') { "New database connection created: URL='#{jdbc_thin_url}' User='#{get_threadlocal_config[:user]}' Pool size=#{@@connection_pool.count+1}" }

    # Schedule socket timeout to cancel connection in case of network stuck after twice of query timeout
    jdbc_connection.raw_connection.setNetworkTimeout(java.util.concurrent.Executors.newSingleThreadExecutor, query_timeout*2*1000);

    # Allow Oracle JDBC driver to cache cursors
    jdbc_connection.raw_connection.setImplicitCachingEnabled(true)

    # hold up to 100 cursors open
    jdbc_connection.raw_connection.setStatementCacheSize(100)

    jdbc_connection
  rescue Exception => e
    Rails.logger.error('PanoramaConnection.do_login') { "Exception #{e.class}:#{e.message} while connecting to URL='#{url}', user='#{username}'" }
    raise
  end

  def self.dump_connection_pool_to_log
    pos = 0
    Rails.logger.info "Connection pool contains #{@@connection_pool.count} entries:"
    @@connection_pool.each do |conn|
      config = conn.jdbc_connection.instance_variable_get(:@config)
      Rails.logger.info "#{pos}: URL = '#{config[:url]}' User = '#{config[:username]}' Last used = '#{conn.last_used_time}' Used in thread = #{conn.used_in_thread}"
      pos += 1
    end
  end

  def self.set_application_info
    # This method raises connection exception at first database access
    Thread.current[:panorama_connection_connection_object].set_module_action("#{get_threadlocal_config[:current_controller_name]}/#{get_threadlocal_config[:current_action_name]}")
  end

  # Translate text in SQL-statement
  def self.translate_sql(stmt)
    stmt.gsub!(/\n[ \n]*\n/, "\n")                                                  # Remove empty lines in SQL-text
    stmt
  end

  def self.log_exception_backtrace(exception, line_number_limit=nil)
    curr_line_no=0
    output = ''
    exception.backtrace.each do |bt|
      output << "#{bt}\n" if line_number_limit.nil? || curr_line_no < line_number_limit # report First x lines of stacktrace in log
      curr_line_no += 1
    end

    Rails.logger.error('PanoramaConnection.log_exception_backtrace') { "Stack-Trace for #{exception.class}:\n#{output}" }
  end

  # Execute select direct on JDBC-Connection with logging
  def self.direct_select(jdbc_connection, sql)
    retval = nil
    ActiveSupport::Notifications.instrumenter.instrument(
        "sql.active_record",
        :sql            => sql,
        :name           => 'direct_select_one',
        :connection_id  => object_id,
        :statement_name => nil,
        :binds          => []) do
      retval = jdbc_connection.select sql
    end
    retval
  rescue Exception => e
    raise "Error '#{e.class}:#{e.message}' executing SQL: #{sql}"
  end

  def self.direct_select_one(jdbc_connection, sql)
    PanoramaConnection.direct_select(jdbc_connection, sql)&.first
  end

  class SqlSelectIterator

    # Remember this parameters for execution at method each
    # stmt - SQL-String
    # binds - Parameter-Array
    def initialize(stmt:, binds:, modifier: nil, query_timeout: PanoramaConnection.get_threadlocal_config[:query_timeout], query_name: 'SqlSelectIterator')
      @stmt           = stmt
      @binds          = binds
      @modifier       = modifier              # proc for modifikation of record
      @query_timeout  = query_timeout
      @query_name     = query_name
    end

    def each(&block)
      # Execute SQL and call block for every record of result
      Thread.current[:panorama_connection_connection_object].register_sql_execution(@stmt)    # Allows to show SQL in usage/connection_pool
      Thread.current[:panorama_connection_connection_object].jdbc_connection.iterate_query(@stmt, @query_name, @binds, @modifier, @query_timeout, &block)
    rescue Exception => e
      PanoramaConnection.check_for_erroneous_connection_removal(e)              # check if too much errors occurred for this connection

      bind_text = ''
      @binds.each do |b|
        bind_text << "#{b.name} = #{b.value}\n"
      end

      # Ensure stacktrace of first exception is show
      msg = "Error while executing SQL:\n#{PanoramaConnection.get_nested_exception_message(e)}\nSQL-Statement:\n#{@stmt}\n#{bind_text.length > 0 ? "Bind-Values:\n#{bind_text}" : ''}"
      Rails.logger.error('SqlSelectIterator.each') { msg }
      new_ex = Exception.new(msg)
      new_ex.set_backtrace(e.backtrace)
      raise new_ex
    ensure
      Thread.current[:panorama_connection_connection_object]&.unregister_sql_execution   # free current SQL info for usage/connection_pool
    end

  end

end