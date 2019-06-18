# Ensure logging of SQL statements if requested
ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT) if ENV['PANORAMA_LOG_SQL'] && ENV['PANORAMA_LOG_SQL'].upcase == 'TRUE'