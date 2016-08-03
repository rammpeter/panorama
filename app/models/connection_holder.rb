# Klasse dient zum Führen einer Oracle-Connection ohne ActiveRecord::Base.connection zu verändern
# Damit läuft pauschale Aktivierung der DB-Connection über NullDB-Adapter

class ConnectionHolder < ActiveRecord::Base
  self.table_name   =  "DUAL"         # falls irgendwo die Struktur der zugehörigen Tabelle ermittelt werden soll
  self.primary_key  = "id"            # Festes übersteuern, da DUAL keine Info zum Primary Key liefert


  # löst SELECT SYS_CONTEXT('userenv', 'db_name') FROM dual; aus, nicht hochfrequent nutzen
  def self.current_database_name
    ConnectionHolder.connection.current_database
  end

  @@current_controller_name  = nil                                              # Controller-Name after call of init_connection_for_new_request from ApplicationController.begin_request
  @@current_action_name      = nil                                              # dito for Action name
  @@request_connection_state = nil                                              # Connection working after begin of request?


  # Registrieren neue Connection für diesen Request
  def self.init_connection_for_new_request(controller_name, action_name)
    @@current_controller_name   = controller_name
    @@current_action_name       = action_name
    @@request_connection_state  = :pending                                      # Oracle connection not guaranteed open
  end

  def self.check_for_open_connection(controller)                                # Check for opened connection, tested from before SQL execution
    if @@request_connection_state != :opened
      controller.open_oracle_connection                                         # start Oracle-Connection if not already exists

      self.connection().exec_update("call dbms_application_info.set_Module('Panorama', :action)", nil,
                                                [[ActiveRecord::ConnectionAdapters::Column.new(':action', nil, ActiveRecord::Type::Value.new), "#{@@current_controller_name}/#{@@current_action_name}"]]
      )
      @@request_connection_state  = :opened                                     # Oracle connection guaranteed from now
    end
  end
end



