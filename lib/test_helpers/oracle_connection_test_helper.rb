# requires config/environment.rb loaded a'la: require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
require 'encryption'

class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include ActionView::Helpers::TranslationHelper
  include ExceptionHelper

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # Sicherstellen, dass immer auf ein aktuelles Sessin-Objekt zurückgegriffern werden kann
  def session
    @session
  end

  def controller_name                                                           # Dummy to fulfill requirements of set_connection_info_for_request
    'oracle_connection_test_helper.rb'
  end

  def action_name                                                               # Dummy to fulfill requirements of set_connection_info_for_request
    'Test'
  end

  def cookies
    {
        client_salt: 100,
        client_key: Encryption.encrypt_value(100, 100)
    }
  end

  def management_pack_license
    if ENV['MANAGEMENT_PACK_LICENSE']
      raise "Wrong environment value MANAGEMENT_PACK_LICENSE=#{ENV['MANAGEMENT_PACK_LICENSE']}" if !['diagnostics_pack', 'diagnostics_and_tuning_pack', 'panorama_sampler', 'none'].include?(ENV['MANAGEMENT_PACK_LICENSE'])
      ENV['MANAGEMENT_PACK_LICENSE'].to_sym
    else
      :diagnostics_and_tuning_pack  # Allow access on management packs, Default if nothing else specified
    end
  end

  # Method shared with Panorama children
  def connect_oracle_db_internal(current_database)
    # Config im Cachestore ablegen
    # Sicherstellen, dass ApplicationHelper.get_cached_client_key nicht erneut den client_key entschlüsseln will
    initialize_client_key_cookie

    # Passwort verschlüsseln in session
    current_database[:password] = Encryption.encrypt_value(current_database[:password_decrypted], cookies['client_salt'])

    @browser_tab_id = 1
    browser_tab_ids = { @browser_tab_id => {
        current_database: current_database,
        last_used: Time.now
    }
    }
    write_to_client_info_store(:browser_tab_ids, browser_tab_ids)

    set_connection_info_for_request(current_database)

    # DBID is set at first request after login normally
    set_cached_dbid(PanoramaConnection.select_initial_dbid)                    # Use Container-DB because SELECT FROM DBA_Hist_Active_Sess_History may kill session in autonomous DB

    set_I18n_locale('de')
  end

  def set_session_test_db_context(ensure_sampler_tables_if_needed: true)
    # 2017/07/26 cookies are reset in ActionDispatch::IntegrationTest if using initialize_client_key_cookie
    # possibly redundant to def cookies above
    cookies['client_salt'] = 100
    cookies['client_key']  = Encryption.encrypt_value(100, cookies['client_salt'])

    connect_oracle_db

    ensure_panorama_sampler_tables_exist_with_content if management_pack_license == :panorama_sampler && ensure_sampler_tables_if_needed

    yield if block_given?                                                       # Ausführen optionaler Blöcke mit Anweisungen, die gegen die Oracle-Connection verarbeitet werden
  end

  def ensure_panorama_sampler_tables_exist_with_content
    sampler_config = prepare_panorama_sampler_thread_db_config

    begin
      snapshots = sql_select_one "SELECT COUNT(*) FROM Panorama_Snapshot"
    rescue Exception                                                                     # Table does not yet exist
      PanoramaSamplerStructureCheck.do_check(sampler_config, :ASH)              # Must be first if tables do not exist, but packages
      PanoramaSamplerStructureCheck.do_check(sampler_config, :AWR)              # AWR package depends on ASH tables, so check ASH first
      snapshots = sql_select_one "SELECT COUNT(*) FROM Panorama_Snapshot"
    end
    if snapshots < 4
      saved_config = Thread.current[:panorama_connection_connect_info]        # store current config before being reset by WorkerThread.create_snapshot_internal

      WorkerThread.new(sampler_config, 'ensure_panorama_sampler_tables_exist_with_content').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called
      3.times do
        sleep(20)
        WorkerThread.new(sampler_config, 'ensure_panorama_sampler_tables_exist_with_content').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called
      end

      PanoramaConnection.set_connection_info_for_request(saved_config)          # reconnect because create_snapshot_internal freed the connection
      set_cached_dbid(PanoramaConnection.select_initial_dbid)                   # Determine the DBID again because Panorama_Snapshot is filled now
    end
  end

end
