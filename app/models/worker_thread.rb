# contains functions to be executed in separate manual thread
# noinspection RubyClassVariableUsageInspection
require 'panorama_sampler_sampling'

class WorkerThread

  ############################### class methods as public interface ###############################
  # Check if connection may function and return DBID of database
  # raise_exeption_on_error allows to proceeed without exception
  # @param [PanoramaSamplerConfig] sampler_config
  # @param [ApplicationController] controller
  # @param [TrueClass, FalseClass] raise_exeption_on_error
  def self.check_connection(sampler_config, controller, raise_exeption_on_error = true)
    thread = Thread.new{WorkerThread.new(sampler_config, 'check_connection').check_connection_internal(controller)}
    thread.name = 'WorkerThread: check_connection'
    result = thread.value
    result
  rescue Exception => e
    if raise_exeption_on_error
      ExceptionHelper.reraise_extended_exception(e, "", log_location: 'WorkerThread.check_connection')
    else
      Rails.logger.error('WorkerThread.check_connection') { "Exception #{e.message} raised in WorkerThread.check_connection" }
    end
  end

  # Generic create snapshot
  # @param {PanoramaSamplerConfig} sampler_config: configuration object
  # @param {Time} snapshot_time Start time of current snapshot in time zone of Panorama server instance
  # @param {Symbol} domain For which domain the snapshot should be executed
  def self.create_snapshot(sampler_config, snapshot_time, domain)

    if domain == :AWR_ASH
      WorkerThread.run_ash_sampler_daemon(sampler_config, snapshot_time)
      create_snapshot(sampler_config, snapshot_time, :AWR)                      # recall method with changed domain
    else
      name = "create #{domain} snapshot"
      thread = Thread.new{WorkerThread.new(sampler_config, name, domain: domain).create_snapshot_internal(snapshot_time, domain)}  # Excute the snapshot and terminate
      thread.name = "WorkerThread :#{name}"
    end
  rescue Exception => e
    Rails.logger.error('WorkerThread.create_snapshot') { "Exception #{e.message} raised in WorkerThread.create_snapshot for config-ID=#{sampler_config.get_id} and domain=#{domain}" }
    # Don't raise exception because it should not stop calling job processing
  end

  # Used also for running ash daemon at Panorama-startup, snapshot_time must be time according to regular snapshot cycle
  # @param {PanoramaSamplerConfig} sampler_config: configuration object
  # @param {Time} snapshot_time Start time of current snapshot, start time for ASH daemon
  def self.run_ash_sampler_daemon(sampler_config, snapshot_time)
    thread = Thread.new{WorkerThread.new(sampler_config, 'ash_sampler_daemon').create_ash_sampler_daemon(snapshot_time)} # Start PL/SQL daemon that does ASH-sampling, terminates before next snapshot
    thread.name = 'WorkerThread: ash_sampler_daemon'
  end

  # Check if analyze info of DB objects is sufficient
  # @param [PanoramaSamplerConfig] config
  def self.check_analyze(sampler_config)
    thread = Thread.new{WorkerThread.new(sampler_config, 'check_analyze').check_analyze_internal}
    thread.name = 'WorkerThread: check_analyze'
  rescue Exception => e
    Rails.logger.error('WorkerThread.check_analyze') { "Exception #{e.message} raised for config-ID=#{sampler_config.get_id}" }
  end

  ############################### inner implementation ###############################

  # @param [PanoramaSamplerConfig,Hash] sampler_config
  # @param action_name
  # @param domain: allow setting of management_pack_license according to data source of longterm_trend
  def initialize(sampler_config, action_name, domain: nil)
    @sampler_config = sampler_config
    # @sampler_config = PanoramaSamplerConfig.new(@sampler_config) if @sampler_config.class == Hash
    raise "WorkerThread.intialize: Parameter sampler_config of class PanoramaSamplerConfig required, got #{@sampler_config.class}" if @sampler_config.class != PanoramaSamplerConfig


    connection_config = @sampler_config.get_cloned_config_hash                  # Structure similar to database

    connection_config[:client_salt]             = Panorama::Application.config.panorama_master_password
    connection_config[:management_pack_license] = :none                         # assume no management packs are licensed for first steps
    connection_config[:privilege]               = 'normal' if !connection_config.has_key?(:privilege)
    connection_config[:query_timeout]           = connection_config[:awr_ash_snapshot_cycle]*60+60 # 1 minute more than snapshot cycle
    connection_config[:current_controller_name] = 'WorkerThread'
    connection_config[:current_action_name]     = action_name
    connection_config[:management_pack_license] = :none                         # assume no management packs are licensed as default
    # set management_pack_license to :diagnostics_pack if longterm trend uses access an ASH tables
    connection_config[:management_pack_license] = :diagnostics_pack if domain == :LONGTERM_TREND && connection_config[:longterm_trend_data_source] == :oracle_ash

    PanoramaConnection.set_connection_info_for_request(connection_config)

    # management_pack_license should not depend on volatile DB setting !, commented out
    # PanoramaConnection.set_management_pack_license_from_db_in_connection
  rescue Exception => e
    sampler_config.set_error_message e.message
    raise e
  end

  # Check if connection may function and store result in config hash
  def check_connection_internal(controller)
    # Remove all connections from pool for this target to ensure connect with new credentials

    dbid = PanoramaConnection.sql_select_one "SELECT DBID FROM V$Database"

    if dbid.nil?
      controller.add_statusbar_message("Trial connect to '#{@sampler_config.get_name}' not successful, see Panorama-Log for details")
      @sampler_config.set_error_message("Trial connect to '#{@sampler_config.get_name}' not successful, see Panorama-Log for details")
    else
      owner_exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Users WHERE UserName = ?", @sampler_config.get_owner.upcase]
      raise "Schema-owner #{@sampler_config.get_owner} does not exists in database" if owner_exists == 0

      # Check if create table is allowed
      check_table_name = 'Panorama_Resource_Test'
      if PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM DBA_All_Tables WHERE Owner = ? AND Table_Name = ?", @sampler_config.get_owner.upcase, check_table_name.upcase]) > 0
        PanoramaConnection.sql_execute "DROP TABLE #{@sampler_config.get_owner}.#{check_table_name}"  # drop table if remaining from former test
      end
      PanoramaConnection.sql_execute "CREATE TABLE #{@sampler_config.get_owner}.#{check_table_name}(ID NUMBER)"
      PanoramaConnection.sql_execute "INSERT INTO #{@sampler_config.get_owner}.#{check_table_name} VALUES (1)"  # Check if quota exists for tablespace at deferred extent allocation
      PanoramaConnection.sql_execute "DROP TABLE #{@sampler_config.get_owner}.#{check_table_name}"

      controller.add_statusbar_message("Trial connect to '#{@sampler_config.get_name}' successful")
    end
    dbid
  rescue Exception => e
    Rails.logger.error('WorkerThread.check_connection_internal') { "Exception #{e.class}:#{e.message}" }
    controller.add_statusbar_message("Trial connect to '#{@sampler_config.get_name}' not successful!\nExcpetion: #{e.message}\nFor details see Panorama-Log for details")
    @sampler_config.set_error_message(e.message)
    raise e
  ensure
    PanoramaConnection.release_connection                                       # Free DB connection in Pool in any case
  end

  # Create snapshot in database, executed in new Thread
  # @param {Time} snapshot_time Start time of current snapshot, start time for ASH daemon
  def create_ash_sampler_daemon(snapshot_time)
    PanoramaSamplerStructureCheck.do_check(@sampler_config, :ASH)               # check data structure once after startup of Panorama Server
    PanoramaSamplerSampling.run_ash_daemon(@sampler_config, snapshot_time)      # Start ASH daemon
  rescue Exception => e
    @sampler_config.set_error_message("Error #{e.message} during WorkerThread.create_ash_sampler_daemon")
    Rails.logger.error('WorkerThread.create_ash_sampler_daemon') {"Error for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name})\n#{e.class}:#{e.message} " }
    ExceptionHelper.log_exception_backtrace(e, 40)
    PanoramaConnection.destroy_connection                                     # Ensure this connection with errors will not be reused
    PanoramaSamplerStructureCheck.do_check(@sampler_config, :ASH, force_repeated_execution: true) # check data structure again after error
    PanoramaSamplerSampling.new(@sampler_config).exec_shrink_space('Internal_V$Active_Sess_History')   # try to shrink the size of object
    Rails.logger.error('WorkerThread.create_ash_sampler_daemon') {"Retry after error for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name})" }
    PanoramaSamplerSampling.run_ash_daemon(@sampler_config, snapshot_time)      # Start ASH daemon again
  rescue Object => e
    Rails.logger.error('WorkerThread.create_ash_sampler_daemon') { "Exception #{e.class} for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name})" }
    @sampler_config.set_error_message("Exception #{e.class} during WorkerThread.create_ash_sampler_daemon")
    raise e
  ensure
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  end

  @@active_snapshots = {}
  # Generic method to create snapshots
  # @param [Time] snapshot_time Start time of current snapshot in time zone of Panorama server instance
  # @param [Symbol] domain For which domain the snapshot should be executed
  def create_snapshot_internal(snapshot_time, domain)
    snapshot_semaphore_key = "#{@sampler_config.get_id}_#{domain}"
    if @@active_snapshots[snapshot_semaphore_key]                               # Predecessor not correctly finished
      prev_db_session = check_for_really_active_predecessor_in_db
      if prev_db_session
        msg = "A corresponding DB session '#{prev_db_session}' is still active for previous #{domain} snapshot for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) since #{@@active_snapshots[snapshot_semaphore_key]} (due to semaphore), new #{domain} snapshot not started! Restarting Panorama server may possibly fix this problem."
        Rails.logger.error('WorkerThread.create_snapshot_internal') { msg }
        @sampler_config.set_error_message(msg)
        return
      else
        msg = "Previous #{domain} snapshot not yet finshed for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) since #{@@active_snapshots[snapshot_semaphore_key]} due to semaphore, but corresponding DB session is not active no more"
        Rails.logger.error('WorkerThread.create_snapshot_internal') { msg }
        @sampler_config.set_error_message(msg)
        @@active_snapshots.delete(snapshot_semaphore_key)                       # Remove semaphore because
      end
    end

    begin                                                                       # Start observation for already closed semaphore here, previous return should not reset semaphore
      Rails.logger.info('WorkerThread.create_snapshot_internal') { "#{Time.now}: Create new #{domain} snapshot for ID=#{@sampler_config.get_id}, Name='#{@sampler_config.get_name}' SID=#{PanoramaConnection.sid}" }

      @@active_snapshots[snapshot_semaphore_key] = Time.now                     # Create semaphore for thread, begin processing

      @sampler_config.last_successful_connect(domain, PanoramaConnection.instance_number) # Set after first successful SQL

      PanoramaSamplerStructureCheck.do_check(@sampler_config, domain);        # Check data structure preconditions once after startup, but not for ASH-tables

      PanoramaSamplerSampling.do_sampling(@sampler_config, snapshot_time, domain)  # Do Sampling
      PanoramaSamplerSampling.do_housekeeping(@sampler_config, false, domain)   # Do housekeeping without shrink space

      # End activities after finishing snapshot
      @sampler_config.set_domain_last_snapshot_end(domain, Time.now)
      Rails.logger.info('WorkerThread.create_snapshot_internal') { "#{Time.now}: Finished creating new #{domain} snapshot for ID=#{@sampler_config.get_id}, Name='#{@sampler_config.get_name}' and domain=#{domain}" }
    rescue Exception => e
      begin
        Rails.logger.error('WorkerThread.create_snapshot_internal') { "Error in first try for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) and domain=#{domain}\n#{e.message}" }
        ExceptionHelper.log_exception_backtrace(e, 30) if !Rails.env.test?
        PanoramaConnection.destroy_connection                                   # Ensure this connection with errors will not be reused for next steps
        PanoramaSamplerStructureCheck.do_check(@sampler_config, domain, force_repeated_execution: true) # Check data structure preconditions first in case of error
        PanoramaSamplerSampling.do_housekeeping(@sampler_config, true, domain)  # Do housekeeping also in case of exception to clear full tablespace quota etc. + shrink space
        PanoramaSamplerSampling.do_sampling(@sampler_config, snapshot_time, domain)  # Retry sampling

        @sampler_config.set_domain_last_snapshot_end(domain, Time.now)
        Rails.logger.info('WorkerThread.create_snapshot_internal') { "#{Time.now}: Finished creating new #{domain} snapshot in second try for ID=#{@sampler_config.get_id}, Name='#{@sampler_config.get_name}' and domain=#{domain}" }
      rescue Exception => x
        Rails.logger.error('WorkerThread.create_snapshot_internal') { "#{x.class} in exception handler for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) and domain=#{domain}\n#{x.message}" }
        ExceptionHelper.log_exception_backtrace(x, 40)
        @sampler_config.set_error_message("Error #{e.message} during WorkerThread.create_snapshot_internal for domain=#{domain}")
        PanoramaConnection.destroy_connection                                   # Ensure this connection with errors will not be reused
        raise x
      end
    rescue Object => e
      Rails.logger.error('WorkerThread.create_snapshot_internal') { "Exception #{e.class} for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name}) and domain=#{domain}\n#{e.message}" }
      @sampler_config.set_error_message("Exception #{e.class} during WorkerThread.create_snapshot_internal for domain=#{domain}")
      raise e
    ensure
      @@active_snapshots.delete(snapshot_semaphore_key)                         # Remove semaphore only if processing is not terminated due to existing semaphore
    end

  ensure
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  end

  DAYS_BETWEEN_ANALYZE_CHECK = 7
  def check_analyze_internal
    # Check analyze info once a week
    if  @sampler_config.get_last_analyze_check_timestamp.nil? || @sampler_config.get_last_analyze_check_timestamp < Time.now - 86400*DAYS_BETWEEN_ANALYZE_CHECK
      tables = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ? AND (Last_Analyzed IS NULL OR Last_Analyzed < SYSDATE-?)", @sampler_config.get_owner.upcase, DAYS_BETWEEN_ANALYZE_CHECK]
      tables.each do |t|
        start_time = Time.now
        PanoramaConnection.sql_select_all(["SELECT Index_Name FROM All_Indexes WHERE Owner = ? AND Table_Name = ?", @sampler_config.get_owner.upcase, t.table_name]).each do |index|
          PanoramaConnection.sql_execute "ALTER INDEX #{@sampler_config.get_owner.upcase}.#{index.index_name} SHRINK SPACE"
        end

        PanoramaConnection.sql_execute ["BEGIN DBMS_STATS.Gather_Table_Stats(?, ?); END;", @sampler_config.get_owner.upcase, t.table_name]
        Rails.logger.info('WorkerThread.check_analyze_internal') { "Analyzed table #{@sampler_config.get_owner.upcase}.#{t.table_name} and shrink indizes in #{Time.now-start_time} seconds" }
      end
      @sampler_config.set_last_analyze_check_timestamp
    end
  rescue Exception => e
    Rails.logger.error('WorkerThread.check_analyze_internal') { "Exception #{e.class} for ID=#{@sampler_config.get_id} (#{@sampler_config.get_name})" }
    ExceptionHelper.log_exception_backtrace(e, 40)
    raise e
  ensure
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  end

  # is there a DB session active for predecessor?
  # @return [String] nil if no active session or SID/SN of session
  def check_for_really_active_predecessor_in_db
    PanoramaConnection.sql_select_one ["SELECT SID||','||Serial#
                                        FROM   v$Session /* only test the current instance because other instances may also have sampling */
                                        WHERE  Status = 'ACTIVE'
                                        AND    Module = 'Panorama'
                                        AND    Action = ?
                                        AND    SID      != SYS_CONTEXT('USERENV', 'SID') /* Do not check the own session */
                                        AND    UserName = SYS_CONTEXT('USERENV', 'SESSION_USER') /* hide active sampling with other user */
                                        ", PanoramaConnection.last_used_action_name]
  end
end