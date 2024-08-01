require 'date'
require_relative "boot"

require "rails/all"
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Panorama
  # VERSION and RELEASE_DATE should have fix syntax and positions because they are parsed from other sites
  VERSION = '2.17.49'
  RELEASE_DATE = Date.parse('2024-08-01')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year

  MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST = 8.hours

  class Application < Rails::Application

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    logger.info "Panorama for Oracle: Release #{Panorama::VERSION} ( #{Panorama::RELEASE_YEAR}/#{Panorama::RELEASE_MONTH}/#{Panorama::RELEASE_DAY} )"
    logger.info "Used runtime environments and frameworks:"
    logger.info "   - Java:          #{java.lang.System.getProperty("java.runtime.version")} (#{java.lang.System.getProperty("java.runtime.name")}, #{java.lang.System.getProperty("java.vendor")})"
    logger.info "   - JRE location:  #{java.lang.System.getProperty("java.home")}"
    logger.info "   - JRuby:         #{JRUBY_VERSION}"
    logger.info "   - Ruby on Rails: #{Rails.version}"

    # Remove ojdbc11.jar if Panorama is running with Java < 11.x
    # otherwise errors are causewd while loading JDBC driver like
    # NameError:cannot link Java class oracle.jdbc.OracleDriver oracle/jdbc/OracleDriver has been compiled by a more recent version of the Java Runtime (class file version 55.0), this version of the Java Runtime only recognizes class file versions up to 52.0
=begin
    java_version = java.lang.System.getProperty("java.version")
    puts "############### Test for java version #{java_version}"
    if java_version.match(/^1.8./) || java_version.match(/^1.9./) || java_version.match(/^10./)
      begin
        filename = "#{Panorama::Application.root}/lib/ojdbc11.jar"
        puts "Removing file '#{filename}' from working directory because it is incompatible with current Java version #{java_version}"
        File.unlink(filename)
        logger.info "#{filename} removed because Java version is #{java_version}"
      rescue Exception => e
        logger.error('Panorama::Application') { "Error #{e.class}:#{e.message} while removing #{filename} because Java version is #{java_version}" }
      end
    end
=end

    # Verzeichnis für permanent zu schreibende Dateien
    if ENV['PANORAMA_VAR_HOME']
      config.panorama_var_home = ENV['PANORAMA_VAR_HOME']
      config.panorama_var_home_user_defined = true
    else
      config.panorama_var_home = "#{Dir.tmpdir}/Panorama"
      config.panorama_var_home_user_defined = false
    end

    unless File.exist?(config.panorama_var_home)  # Ensure that directory exists
      begin
        Dir.mkdir config.panorama_var_home
        raise "Directory #{config.panorama_var_home} does not exist and could not be created" unless File.exist?(config.panorama_var_home)
      rescue Exception => e
        logger.error('Panorama::Application') { "Error #{e.class}:#{e.message} while creating #{config.panorama_var_home}" }
        exit! 1                                                                 # Ensure application terminates if initialization fails
      end
    end

    logger.info "Panorama writes server side info to folder #{config.panorama_var_home}"

    # Password for access on Admin menu, Panorama-Sampler config etc. : admin menu is activated if password is not empty
    # Backward campatibility for previously used environment entry
    config.panorama_master_password = ENV['PANORAMA_SAMPLER_MASTER_PASSWORD']  ? ENV['PANORAMA_SAMPLER_MASTER_PASSWORD'] : nil
    config.panorama_master_password = ENV['PANORAMA_MASTER_PASSWORD'] if ENV['PANORAMA_MASTER_PASSWORD'] # currently used env. entry overwrites

    # Textdatei zur Erfassung der Panorama-Nutzung
    # Sicherstellen, dass die Datei ausserhalb der Applikation zu liegen kommt und Deployment der Applikation überlebt durch Definition von ENV['PANORAMA_VAR_HOME']
    config.usage_info_filename = "#{config.panorama_var_home}/Usage.log"
    raise "PANORAMA_USAGE_INFO_MAX_AGE ('#{ENV['PANORAMA_USAGE_INFO_MAX_AGE']}') should contain only a number" if ENV['PANORAMA_USAGE_INFO_MAX_AGE'] && !(ENV['PANORAMA_USAGE_INFO_MAX_AGE'].match(/^\d+$/))
    config.usage_info_max_age = (ENV['PANORAMA_USAGE_INFO_MAX_AGE'] || 180).to_i

    # File-Store für ActiveSupport::Cache::FileStore
    config.client_info_filename = "#{config.panorama_var_home}/client_info.store"

    # -- begin rails3 relikt
    # Configure the default encoding used in templates for Ruby 1.9.
    #config.encoding = "utf-8"

    # Added 15.02.2012, utf8-Problem unter MAcOS nicht gelöst
    #Encoding.default_internal, Encoding.default_external = ['utf-8'] * 2

    # Configure sensitive parameters which will be filtered from the log file.
    #config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    #config.active_support.escape_html_entities_in_json = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Addition 2018-09-01 Find fonts in asset pipeline. Location in vendor/assets does not function
    config.assets.paths << Rails.root.join("app", "assets", "fonts")

    # Don't disable submit button after click
    config.action_view.automatically_disable_submit_tag = false

    # Specify cookies SameSite protection level: either :none, :lax, or :strict.
    #
    # This change is not backwards compatible with earlier Rails versions.
    # It's best enabled when your entire app is migrated and stable on 6.1.
    config.action_dispatch.cookies_same_site_protection = :lax

    # Log the used settings from environment
    # @param [String] setting Name of setting
    # @param [Object] used_value Value of setting
    def self.log_env_setting(setting, used_value)
      Rails.logger.info "Environment setting: #{setting} = #{used_value}"
    end
  end
end
