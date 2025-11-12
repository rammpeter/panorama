# Ensure logging of SQL statements if requested
ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT) if Panorama::Application.config.panorama_log_sql&.upcase == 'TRUE'