Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  # Erzwinge Anzeige der vollen Fehlermeldung mit Trace im Production mode, Ramm, 07.01.2011
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  #config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  # Ramm, 26.10.2016 Ensure routing and access to /public/* in production mode
  config.public_file_server.enabled = true

  # Compress JavaScripts and CSS.
  # config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  #config.log_level = :debug
  # config.log_level = :info
  config.log_level = (ENV['PANORAMA_LOG_LEVEL'] ||= 'info').to_sym

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "Panorama_App_#{Rails.env}"
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  # config.log_formatter = ::Logger::Formatter.new
  config.log_formatter = proc do |severity, datetime, progname, msg|
    date_format = datetime.strftime("%Y-%m-%d %H:%M:%S.%3N")
    "[#{date_format}] #{severity} (#{Thread.current.object_id}#{' ' if progname}#{progname}): #{msg}\n"
  end

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  if ENV["RAILS_LOG_TO_STDOUT_AND_FILE"].present?
    console_logger = ActiveSupport::Logger.new(STDOUT)
    console_logger.formatter = config.log_formatter
    tagged_console_logger = ActiveSupport::TaggedLogging.new(console_logger)
    file_logger = ActiveSupport::Logger.new( Rails.root.join("log", Rails.env + ".log" ), 5 , 10*1024*1024 )  # max. 50 MB logfile ( 5 files á 10 MB)
    file_logger.formatter = config.log_formatter
    combined_logger = tagged_console_logger.extend(ActiveSupport::Logger.broadcast(file_logger))
    config.logger = combined_logger
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Don't colorize ActiveRecord SQL log
  config.colorize_logging = false


  # Additions for running Panorama via Jetty
  # config.serve_static_assets = false

end
