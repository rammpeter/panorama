require 'test_helpers/panorama_test_config'
require 'active_record/connection_adapters/oracle_enhanced/connection'
require 'active_record/connection_adapters/oracle_enhanced/jdbc_connection'

# call syntax: rake -f lib/tasks/wait_for_db_available.rake ci_preparation:wait_for_db_available[1]
namespace :ci_preparation do
  desc "Wait for DB to become available in CI pipeline"

  task :wait_for_db_available, [:max_wait_minutes] do |_, args|
    max_wait_minutes = args[:max_wait_minutes].to_i
    raise "Parameter wait time in minutes expected" if args.count == 0 || max_wait_minutes == 0
    puts "ci_preparation:wait_for_db_available: Waiting max. #{max_wait_minutes} minutes for database to become available"
    start_time = Time.now

    exception_text = nil
    config = PanoramaTestConfig.test_config
    puts "TNS = #{config[:tns]}"
    loop do
      raise "DB not available after waiting #{max_wait_minutes} minutes! Aborting!\nReason: #{exception_text}\n" if Time.now > start_time + max_wait_minutes*60

      begin
        properties = java.util.Properties.new
        properties.put("user", 'sys')
        properties.put("password", config[:syspassword_decrypted])
        properties.put("internal_logon", "SYSDBA")
        url = "jdbc:oracle:thin:@#{config[:tns]}"
        begin
          conn = java.sql.DriverManager.getConnection(url, properties)
        rescue
          # bypass DriverManager to work in cases where ojdbc*.jar
          # is added to the load path at runtime and not on the
          # system classpath
          # ORACLE_DRIVER is declared in jdbc_connection.rb of oracle_enhanced-adapter like:
          # ORACLE_DRIVER = Java::oracle.jdbc.OracleDriver.new
          # java.sql.DriverManager.registerDriver ORACLE_DRIVER
          conn = ORACLE_DRIVER.connect(url, properties)
        end

        stmt = conn.prepareStatement("SELECT 1 FROM DUAL");
        resultSet = stmt.executeQuery;
        resultSet.next
        result = resultSet.getInt(1)
        break                                                                 # finished successful
      rescue Exception=> e
        exception_text = "#{e.class}: #{e.message}"
        print '.'
        sleep 1                                                               # Wait and try again
      ensure
        resultSet&.close
        stmt&.close
        conn&.close
      end
    end
    puts "\n#{Time.now}: DB is available now"
  end
end