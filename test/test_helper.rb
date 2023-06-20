# Configure Rails Environment
ENV['RAILS_ENV'] ||= 'test'

# Suppress warning: loading in progress, circular require considered harmful
old_verbose = $VERBOSE
$VERBOSE=nil
require_relative '../config/environment'
$VERBOSE=old_verbose

require "rails/test_help"

require 'fileutils'
require 'json'

#require "minitest/reporters"

# Load own helpers
require File.expand_path("../../lib/test_helpers/oracle_connection_test_helper.rb", __FILE__)       # requires config/environment.rb loaded
require File.expand_path("../../lib/test_helpers/menu_test_helper.rb", __FILE__)
require File.expand_path("../../lib/test_helpers/panorama_test_config.rb", __FILE__)

require File.expand_path("../../lib/test_helpers/playwright_system_test_case", __FILE__)

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.

# Ramm, auskommentiert 02.08.2017
#Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Suppress the following error:
# ArgumentError: wrong number of arguments (1 for 0)
# aggregated_results at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/railties-5.0.1/lib/rails/test_unit/minitest_plugin.rb:597
# report at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:597
# each at org/jruby/RubyArray.java:1733
# report at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:687
# run at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:141
# run at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/railties-5.0.1/lib/rails/test_unit/minitest_plugin.rb:73
# block in autorun at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:63
# rake aborted!

#Minitest::Reporters.use!(
#    Minitest::Reporters::DefaultReporter.new,
#    ENV, Minitest.backtrace_filter
#)

# Load fixtures from the engine
#if ActiveSupport::TestCase.respond_to?(:fixture_path=)
#  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
#  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
#  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
#  ActiveSupport::TestCase.fixtures :all
#end

# Globales Teardown für alle Tests
class ActionController::TestCase

  teardown do
    # Problem: fixtures.rb merkt sich am Start des Tests die aktive Connection und will darauf am Ende des Tests ein Rollback machen
    # zu diesem Zeitpunkt ist die gemerkte Connection jedoch gar nicht mehr aktiv, da mehrfach andere Connection aktiviert wurde
    # Lösung: Leeren des Arrays mit gemerkten Connections von fixture.rb, so dass nichts mehr zurückgerollt wird
    @fixture_connections.clear
  end

end

$first_log_written = false

class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include ActionView::Helpers::TranslationHelper

  # parallelize(workers: 3, with: :threads) # :processes or :threads
  # suspended 09.09.2019

  # Verbindungsparameter der für Test konfigurierten DB als Session-Parameter hinterlegen
  # damit wird bei Connect auf diese DB zurückgegriffen

  def connect_oracle_db
    test_config = PanoramaTestConfig.test_config

    connect_oracle_db_internal(test_config)   # aus lib/test_helpers/oracle_connection_test_helper
    @db_version = PanoramaConnection.db_version                                 # Store db_version outside PanoramaConnection
    Rails.logger.info('ActiveSupport::TestCase.connect_oracle_db') { "#{Time.now} : Starting Test with configuration #{test_config} DB-Version = #{@db_version}" }


    unless $first_log_written
      $first_log_written = true
      puts "Database version    = #{@db_version}"
      puts "JDBC driver version = #{PanoramaConnection.get_jdbc_driver_version}"
      begin
        PanoramaConnection.sql_execute "PURGE RECYCLEBIN"
      rescue Exception=>e
        Rails.logger.error "#{e.class}:#{e.message} during PURGE RECYCLEBIN"
      end
    end
  end

  # Don't use PanoramaConnection.db_version because PanoramaConnection.reset_thread_local_attributes is called at end of each request
  def get_db_version
    @db_version
  end

  # Add defaults for PanoramaSampler to config
  # @param [Hash] sampler_config
  def set_panorama_sampler_config_defaults!(sampler_config)

    sampler_config[:query_timeout]                  = 600                       # single test should not last longer, previous value = 20
    sampler_config[:awr_ash_active]                 = true
    sampler_config[:object_size_active]             = true
    sampler_config[:cache_objects_active]           = true
    sampler_config[:blocking_locks_active]          = true

    sampler_config[:awr_ash_snapshot_cycle]         = 1                         # Ensure small runtime of test run
    sampler_config[:longterm_trend_snapshot_cycle]  = 1                         # one hour
    sampler_config.merge!(PanoramaSamplerConfig.new(sampler_config).get_cloned_config_hash)
  end

  setup do
    @test_start_time = Time.now
    Rails.logger.info('ActiveSupport::TestCase.setup') { "#{@test_start_time} : start of test #{self.class}.#{self.name}" } # set timestamp in test.logs
  end

  teardown do
    @test_end_time = Time.now
    Rails.logger.info('ActiveSupport::TestCase.teardown') { "#{@test_end_time} : end of test #{self.class}.#{self.name}" } # set timestamp in test.logs
    Rails.logger.info('ActiveSupport::TestCase.teardown') { "#{(@test_end_time-@test_start_time).round(2)} seconds for test #{self.class}.#{self.name}" } # set timestamp in test.logs
    Rails.logger.info('ActiveSupport::TestCase.teardown') { '' }
  end

  # Prepare a PanoramaSamplerConfig for a test
  # @param [String] user - user for which the config is prepared
  # @return [PanoramaSamplerConfig]
  def prepare_panorama_sampler_thread_db_config(user = nil)
    Panorama::Application.config.panorama_master_password = 'hugo'

    sampler_config = PanoramaTestConfig.test_config

    sampler_config[:id]                             = 1
    sampler_config[:name]                           = 'Test-Config'
    sampler_config[:client_salt]                    = Panorama::Application.config.panorama_master_password  # identic doubled like WorkerThread.initialized
    sampler_config[:management_pack_license]        = management_pack_license   # use same management_pack_license as all other tests
    sampler_config[:owner]                          = sampler_config[:user]     # assume owner = connected user for test

    if user.nil?
      sampler_config[:password] = sampler_config[:password_decrypted]           # Encryption is done by PanoramaSamplerConfig.prepare_saved_entry!
      #sampler_config[:password] = Encryption.encrypt_value(sampler_config[:password_decrypted], sampler_config[:client_salt])
    else
      sampler_config[:password] = sampler_config[:syspassword_decrypted]        # Encryption is done by PanoramaSamplerConfig.prepare_saved_entry!
      #sampler_config[:password] = Encryption.encrypt_value(sampler_config[:syspassword_decrypted], sampler_config[:client_salt])
      sampler_config[:user]                          = user                     # use SYS or SYSTEM for connect
    end

    set_panorama_sampler_config_defaults!(sampler_config)

    PanoramaSamplerConfig.prepare_saved_entry!(sampler_config)

    config_object = PanoramaSamplerConfig.get_config_entry_by_id_or_nil(sampler_config[:id])

    if config_object.nil?
      PanoramaSamplerConfig.add_config_entry(sampler_config)
    else
      config_object.modify(sampler_config)
    end

    PanoramaConnection.set_connection_info_for_request(sampler_config)
    shrink_table_size_for_always_free_autonomous_db # Reduce size of table for always free autonomous DB
    PanoramaSamplerConfig.get_config_entry_by_id(sampler_config[:id])
  end

  def assert_response_success_or_management_pack_violation(comment = '')
    if management_pack_license == :none
      sleep(0.5)                                                                # ensure moderate allocation of new DB-sessions beacause current session is destroyed
      assert_response(:error, "Expected :error but response is #{@response.response_code}: #{comment}")
    else
      assert_response(:success, "Expected :success but response is #{@response.response_code}: #{comment}")
    end
  end

  # allow assertions failure message to appear in logfile
  # use like: assert_response :success, log_on_failure('should get log file with JWT')
  # @param [String] message
  def log_on_failure(message)
    Proc.new do
      Rails.logger.debug('TestHelper.log_on_failure'){ "Assertion failed: #{message}" }
      message
    end
  end

  # Shrink table size for always free autonomous DB to not reach the size limit
  def shrink_table_size_for_always_free_autonomous_db
    if PanoramaConnection.autonomous_database?
      ['PANORAMA_SQL_PLAN', 'PANORAMA_SQL_BIND', 'PANORAMA_SQLTEXT'].each do |table_name|
        PanoramaConnection.sql_execute("TRUNCATE TABLE #{table_name}") if PanoramaConnection.table_exists?(table_name)
      end
    end
  end

  # Are four valid snapshots found for AWR ?
  # @param [Hash] snaps the result record from test
  # @return [TrueClass, FalseClass]
  def four_valid_snaps_found?(snaps)
    !snaps.nil? && !snaps.min_snap_id.nil? && !snaps.max_snap_id.nil? && !snaps.start_time.nil? && !snaps.end_time.nil?
  end

  # Ensure that AWR snapshots exist and time period is according to existing snapshots
  # @param [Symbol] time_format
  def initialize_min_max_snap_id_and_times(time_format = :minutes)
    two_snaps_sql = "WITH Hist_Snapshot AS (SELECT /*+ NO_MERGE MATERIALIZE OPT_ESTIMATE(TABLE DBA_Hist_Snapshot ROWS=10000) */ DBID, Snap_ID, Begin_Interval_Time, End_Interval_Time, Startup_Time
                                            FROM   DBA_Hist_Snapshot
                                            WHERE  Instance_Number = #{PanoramaConnection.instance_number}
                                            AND    DBID            = ?  /* Check AWR for the same DBID like following test will use */
                      )
                     SELECT s1.DBID, s2.Snap_ID Max_Snap_ID, s3.Snap_ID Min_Snap_ID, s2.Begin_Interval_Time End_Time, s3.Begin_Interval_Time Start_Time
                     FROM   Hist_Snapshot s1
                     JOIN   Hist_Snapshot s2 ON s2.Snap_ID = s1.Snap_ID -1 AND s2.Startup_Time = s1.Startup_Time
                     JOIN   Hist_Snapshot s3 ON s3.Snap_ID = s1.Snap_ID -2 AND s3.Startup_Time = s1.Startup_Time
                     JOIN   Hist_Snapshot s4 ON s4.Snap_ID = s1.Snap_ID -3 AND s4.Startup_Time = s1.Startup_Time
                     WHERE  EXTRACT (MINUTE FROM s2.End_Interval_Time-s3.Begin_Interval_Time) > 0  /* At least one minute should be between the two snapshots */
                     ORDER BY s1.Snap_ID DESC"

    all_awr_dbids = PanoramaConnection.all_awr_dbids                             # Initial state before additional AWR snapshots

    # Ensure existence of panorama_sampler_snapshots
    if management_pack_license == :panorama_sampler
      # Ensure existence of structure
      sampler_config = prepare_panorama_sampler_thread_db_config

      PanoramaSamplerStructureCheck.domains.each do |domain|
        PanoramaSamplerStructureCheck.do_check(sampler_config, domain)
      end

      snaps = sql_select_first_row [two_snaps_sql, get_dbid]                    # Look for 2 subsequent snapshots in the middle of 4 snapshots with same startup time
      if all_awr_dbids.count == 0 || !four_valid_snaps_found?(snaps) || (snaps.end_time - snaps.start_time) < 61 # Not enough snapshots exists, create 4 subsequent
        # at least one minute should be between snapshots

        if !snaps.nil? && !snaps.start_time.nil? && !snaps.end_time.nil? && (snaps.end_time - snaps.start_time) < 61
          Rails.logger.info('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') { "new snaps executed because duration between snapshots is only #{} seconds" }
        end

        saved_config = Thread.current[:panorama_connection_connect_info]        # store current config before being reset by WorkerThread.create_snapshot_internal

        WorkerThread.new(sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)

        PanoramaConnection.set_connection_info_for_request(saved_config)        # reconnect because create_snapshot_internal freed the connection
        all_awr_dbids = PanoramaConnection.all_awr_dbids                        # reread the DBIDs after AWR snapshots
      end
    end

    Rails.logger.debug('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') {"DBIDs in AWR are: #{JSON.pretty_generate(all_awr_dbids)}"}


    # Get 2 subsequent snapshots in the middle of 4 snapshots with same startup time
    snaps = sql_select_first_row [two_snaps_sql, get_dbid]

    # Check if another DBID will have four valid AWR snapshots if not already found
    all_awr_dbids.each do |awr_dbid|
      unless four_valid_snaps_found?(snaps)
        Rails.logger.debug('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') { "No four subsequent snapshots with same startup_time found for DBID=#{get_dbid}, trying alternative DBID=#{awr_dbid['dbid']} now." }
        set_cached_dbid(awr_dbid['dbid'])                                       # Set this DBID as current choosen DBID for subsequent tests
        snaps = sql_select_first_row [two_snaps_sql, get_dbid]
      end
    end

    last_10_snaps = sql_select_all "SELECT *
                                    FROM   (SELECT *
                                            FROM   DBA_Hist_Snapshot
                                            WHERE  Instance_Number = #{PanoramaConnection.instance_number}
                                            ORDER BY Begin_Interval_Time DESC
                                           )
                                    WHERE RowNum <= 10"

    Rails.logger.info('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times')  { "Last 10 snapshots of instance #{PanoramaConnection.instance_number} are:" }
    last_10_snaps.each do |s|
      Rails.logger.info('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') { "DBID=#{s.dbid}, Snap_ID=#{s.snap_id}, Instance=#{s.instance_number}, Startup=#{localeDateTime(s.startup_time)}, \
Begin_Interval_Time=#{localeDateTime(s.begin_interval_time)}, End_Interval_Time=#{localeDateTime(s.end_interval_time)} \
#{PanoramaConnection.db_version >= '12.1' ? ", Con_ID=#{s.con_id}" : ''}}" }
    end

    unless four_valid_snaps_found?(snaps)
      message = "No 4 subsequent snapshots with same startup_time found in #{PanoramaConnection.adjust_table_name('DBA_Hist_Snapshot')}: snaps = #{snaps}"
      puts message
      Rails.logger.debug('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') {message}

      raise message
    end

    @min_snap_id = snaps.min_snap_id
    @max_snap_id = snaps.max_snap_id

    @time_selection_start = localeDateTime(snaps.start_time-1, time_format)
    snaps_between = snaps.start_time+60
    @time_selection_between = localeDateTime(snaps_between, time_format)   # a timestamp within the snapshot
    snaps_end = snaps.end_time+(time_format == :minutes ? 60 : 0)
    @time_selection_end   = localeDateTime(snaps_end, time_format)      # Add at least one minute to be sure timestamp is after snaps.end_time even if time_format is :minutes
    raise "@time_selection_between (#{@time_selection_between}) not between @time_selection_start (#{@time_selection_start}) and @time_selection_end (#{@time_selection_end})" if snaps_between >= snaps_end
    Rails.logger.info('ActiveSupport::TestCase.initialize_min_max_snap_id_and_times') { "initialize_min_max_snap_id_and_times: Selected Snap_IDs: #{@min_snap_id}, #{@max_snap_id} Times: #{@time_selection_start}, #{@time_selection_end}" }
  end
end