ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# Globales Teardown für alle Tests
class ActionController::TestCase

  teardown do
    # Problem: fixtures.rb merkt sich am Start des Tests die aktive Connection und will darauf am Ende des Tests ein Rollback machen
    # zu diesem Zeitpunkt ist die gemerkte Connection jedoch gar nicht mehr aktiv, da mehrfach andere Connection aktiviert wurde
    # Lösung: Leeren des Arrays mit gemerkten Connections von fixture.rb, so dass nichts mehr zurückgerollt wird
    @fixture_connections.clear
  end

end



class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include MenuHelper
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

  # Verbindungsparameter der für Test konfigurierten DB als Session-Parameter hinterlegen
  # damit wird bei Connect auf diese DB zurückgegriffen

  def connect_oracle_db

    raise "Environment-Variable DB_VERSION not set" unless ENV['DB_VERSION']
    Rails.logger.info "Starting Test with configuration test_#{ENV['DB_VERSION']}"

    # Array mit Bestandteilen der Vorgabe aus database.yml
    test_config = Panorama::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
    test_url = test_config['test_url'].split(":")

    current_database = {}
    current_database[:sid_usage] = :SERVICE_NAME
    current_database[:host]     = test_url[3].delete "@"
    current_database[:port]     = test_url[4]
    current_database[:sid]      = test_url[5]
    current_database[:user]     = test_config["test_username"]

    # Config im Cachestora ablegen
    # Sicherstellen, dass ApplicationHelper.get_cached_client_key nicht erneut den client_key entschlüsseln will
    @@cached_encrypted_client_key = 100
    @@cached_decrypted_client_key = 100
    cookies[:client_key]          = 100


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

end
