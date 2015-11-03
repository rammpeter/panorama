# Klasse dient zum Führen einer Oracle-Connection ohne ActiveRecord::Base.connection zu verändern
# Damit läuft pauschale Aktivierung der DB-Connection üner NullDB-Adapter
class ConnectionHolder < ActiveRecord::Base

  @@current_database_name = nil

  def self.current_database_name
    @@current_database_name = ConnectionHolder.connection.current_database if @@current_database_name.nil?
    @@current_database_name
  end

end
