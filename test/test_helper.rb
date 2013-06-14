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
    database = Database.new {}

    raise "Environment-Variable DB_VERSION not set" unless ENV['DB_VERSION']
    Rails.logger.info "Starting Test with configuration test_#{ENV['DB_VERSION']}"

    # Array mit Bestandteilen der Vorgabe aus database.yml
    test_config = Panorama::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
    test_url = test_config['test_url'].split(":")

    database.host     = test_url[3].delete "@"
    database.port     = test_url[4]
    database.sid      = test_url[5]
    database.user     = test_config["test_username"]
    database.password = test_config["test_password"]
    #database.tns      = test_config["database"]
    database.open_oracle_connection           # Connection zur Test-DB aufbauen, um Parameter auszulesen
    database.read_initial_db_values
    database.locale = "de"
    session[:database]= database
    session[:dba_hist_blocking_locks_owner] = "journal"
    session[:dba_hist_cache_objects_owner] = "journal"
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
