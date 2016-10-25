# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
#ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
#ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"

require 'fileutils'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new


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



#class ActionDispatch::IntegrationTest
class ActiveSupport::TestCase
  include Panorama::ApplicationHelper
  include Panorama::EnvHelper
  include Panorama::MenuHelper

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

  #def cookies
  #  {:client_key => 100 }
  #end

  # Verbindungsparameter der für Test konfigurierten DB als Session-Parameter hinterlegen
  # damit wird bei Connect auf diese DB zurückgegriffen

  def connect_oracle_db

    raise "Environment-Variable DB_VERSION not set" unless ENV['DB_VERSION']
    Rails.logger.info "Starting Test with configuration test_#{ENV['DB_VERSION']}"

    # Array mit Bestandteilen der Vorgabe aus database.yml
    test_config = Dummy::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
    test_url = test_config['test_url'].split(":")

    current_database = {}
    current_database[:sid_usage] = :SERVICE_NAME
    current_database[:host]     = test_url[3].delete "@"
    current_database[:port]     = test_url[4]
    current_database[:sid]      = test_url[5]
    current_database[:user]     = test_config["test_username"]

    # Config im Cachestore ablegen
    # Sicherstellen, dass ApplicationHelper.get_cached_client_key nicht erneut den client_key entschlüsseln will
    @@cached_encrypted_client_key = '100'
    @@cached_decrypted_client_key = '100'
    cookies[:client_key]          = '100'


    # Passwort verschlüsseln in session
    current_database[:password] = database_helper_encrypt_value(test_config["test_password"])
    write_to_client_info_store(:current_database, current_database)


    # puts "Test for #{ENV['DB_VERSION']} with #{database.user}/#{database.password}@#{database.host}:#{database.port}:#{database.sid}"
    begin
      open_oracle_connection                                                    # Connection zur Test-DB aufbauen, um Parameter auszulesen
      read_initial_db_values                                                    # evtl. Exception tritt erst beim ersten Zugriff auf
    rescue Exception => e
      database_helper_switch_sid_usage                                          # Alterantive Service/SID versuchen
      open_oracle_connection                                                    # Oracle-Connection aufbauen mit Wechsel zwischen SID und ServiceName
      read_initial_db_values                                                    # Lesenden DB-Zugriff nochmal durchführen
    end

    set_I18n_locale('de')

    showBlockingLocksMenu     # belegt dba_hist_blocking_locks_owner]
    showDbCacheMenu           # belegt dba_hist_cache_objects_owner]
  end

  def set_session_test_db_context
    Rails.logger.info ""
    Rails.logger.info "=========== test_helper.rb : set_session_test_db_context ==========="

    # Client Info store entfernen, da dieser mit anderem Schlüssel verschlüsselt sein kann
    #FileUtils.rm_rf(Panorama::Application.config.client_info_filename)

    #initialize_client_key_cookie                                                # Ensure browser cookie for client_key exists
    connect_oracle_db
    sql_row = sql_select_first_row "SELECT /* Panorama-Tool Ramm */ SQL_ID, Child_Number, Parsing_Schema_Name
                                          FROM   v$SQL
                                          WHERE  RowNum < 2"
    @sga_sql_id = sql_row.sql_id
    @sga_child_number = sql_row.child_number
    @sga_parsing_schema_Name = sql_row.parsing_schema_name
    db_session = sql_select_first_row "select Inst_ID, SID, Serial# SerialNo, RawToHex(Saddr)Saddr FROM gV$Session s WHERE SID=UserEnv('SID')  AND Inst_ID = USERENV('INSTANCE')"
    @instance = db_session.inst_id
    @sid      = db_session.sid
    @serialno = db_session.serialno
    @saddr    = db_session.saddr

    yield   # Ausführen optionaler Blöcke mit Anweisungen, die gegen die Oracle-Connection verarbeitet werden

    # Rückstellen auf NullDB kann man sich hier sparen
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  def call_controllers_menu_entries_with_actions

    def call_menu_entry_test_helper(menu_entry)
      menu_entry[:content].each do |m|
        call_menu_entry_test_helper(m) if m[:class] == "menu"       # Rekursives Abtauchen in Menüstruktur
        if m[:class] == "item" &&
            controller_action_defined?(m[:controller], m[:action]) &&           # Controller hat eine Action-Methode für diesen Menü-Eintrag
            "#{m[:controller]}_controller".camelize == @controller.class.name   # Nur Menues des aktuellen Controllers testen
          xhr :get, m[:action], :format=>:js
          assert_response :success
        end
      end
    end

    # Iteration über Menues
    menu_content.each do |mo|
      call_menu_entry_test_helper(mo)
    end

  end


end
