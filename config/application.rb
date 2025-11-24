require 'date'
require_relative "boot"

# Instead of rails/all, which loads all Rails components, we load only the necessary ones.
# require "rails/all"

# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
# require "action_mailer/railtie"
# require "action_cable/engine" # ActionCable is not used in Panorama, but required by rails/all
# require "rails"


# require "active_storage/engine" # Uncomment if you use Active Storage
# require "action_mailbox/engine"   # Uncomment if you use Action Mailbox
# require "action_text/engine"     # Uncomment if you use Action Text
# require "action_cable/engine"    # <--- REMOVE OR COMMENT THIS LINE
# require "rails/test_unit/railtie" # Uncomment if you use Minitest/Test Unit

require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Panorama
  # VERSION and RELEASE_DATE should have fix syntax and positions because they are parsed from other sites
  VERSION = '2.19.5'
  RELEASE_DATE = Date.parse('2025-11-24')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year

  # How long should a client browser session be kept alive after the last request?
  MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST = 8.hours

  class Application < Rails::Application

    # Log the used settings from environment
    # @param [String] setting Name of setting
    # @param [Object] used_value Value of setting
    def self.log_env_setting(setting, used_value)
      Rails.logger.info "Environment setting: #{setting} = #{used_value}"
    end

    # Log a configuration attribute
    # @param key [String] Name of configuration attribute, should be upper case
    # @param value [String] Value of configuration attribute
    # @return [void]
    def self.log_attribute(key, value, options={})
      return if value.nil? || value == ''
      if key['PASSWORD'] || options[:password]
        outval = '*****'
      else
        outval = value
      end
      puts "#{key.to_s.ljust(40, ' ')} #{outval}"
    end

    # Set the value of a configuration attribute from environment variable if it exists, otherwise from config file
    # @param key [Symbol] Name of configuration attribute
    # @param options [Hash] Options for setting the configuration attribute [:default, :integer, :maximum, :minimum, :accept_empty]
    # @return [String] The value of the configuration attribute to be used as log output
    def self.set_attrib_from_env(key, options={})
      down_key = key.to_s.downcase
      value = options[:default]
      value = Panorama::Application.config.send(down_key) if Panorama::Application.config.respond_to?(down_key) # Value already set by config file
      value = ENV[key] if ENV[key]                                        # Environment over previous config value
      if options[:integer]
        raise "#{key} ('#{value}') should contain only a number" if value.is_a?(String) && !(value.match(/^\d+$/))
        value = value.to_i
      end


      log_value = value
      if !value.nil?
        if !options[:maximum].nil? && value > options[:maximum]
          log_value = "#{options[:maximum]}, configured value #{value} reduced to allowed maximum"
          value = options[:maximum]
        end

        if !options[:minimum].nil? && value < options[:minimum]
          raise "Configuration attribute #{up_key} (#{log_value}) should be at least #{options[:minimum]}"
        end
      end
      Panorama::Application.config.send("#{down_key}=", value)                          # ensure all config methods are defined whether with values or without

      raise "Missing configuration value for '#{key}'! Aborting..." if !options[:accept_empty] && Panorama::Application.config.send(down_key).nil?
      log_value
    end

    # Overwrite attribute by possible environment setting and log the resulting value
    # @param [String|Symbol] key the key
    # @param [Hash] options Options for setting the configuration attribute [:default, :upcase, :downcase, :integer, :maximum, :minimum, :accept_empty]
    def self.set_and_log_attrib_from_env(key, options={})
      key = key.dup.to_s.upcase
      Panorama::Application.log_attribute(key, set_attrib_from_env(key, options), options)
    end

    # Load the YAML configuration defined by environment entry PANORAMA_CONFIG_FILE
    # @param [Logger] logger the logger to use because Rails.logger is not yet active
    def self.load_config_file(logger)
      if ENV['PANORAMA_CONFIG_FILE'] && ENV['PANORAMA_CONFIG_FILE'] != ''
        unless File.exist?(ENV['PANORAMA_CONFIG_FILE'])
          raise "Config file #{ENV['PANORAMA_CONFIG_FILE']} does not exist! Aborting!"
        end

        Panorama::Application.log_attribute('PANORAMA_CONFIG_FILE', ENV['PANORAMA_CONFIG_FILE'])
        run_config = YAML.load_file(ENV['PANORAMA_CONFIG_FILE'])
        run_config = {} if run_config.nil?
        raise "Unable to load and parse file #{ENV['PANORAMA_CONFIG_FILE']}! Content of class #{run_config.class}:\n#{run_config}" if run_config.class != Hash
        run_config.each do |key, value|
          config.send "#{key.downcase}=", value                                     # copy file content to config at first
        end
      else
        logger.debug('Panorama::Application.load_config_file') { "No config file defined" }
      end
    end


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

    Panorama::Application.config.secret_key_base = 'nil'                        # discard auto generated value from Rails to detect if config file will change this value
    Panorama::Application.load_config_file(logger)

    Panorama::Application.set_and_log_attrib_from_env(:MAX_CONNECTION_POOL_SIZE, default: 100, integer: true)

    Panorama::Application.set_and_log_attrib_from_env(:PANORAMA_LOG_LEVEL, default: (Rails.env.production? ? :info : :debug))
    config.log_level = config.panorama_log_level.to_sym

    Panorama::Application.set_and_log_attrib_from_env(:PANORAMA_LOG_SQL, default: 'false')

    def_panorama_var_home = "#{Dir.tmpdir}/Panorama"
    Panorama::Application.set_and_log_attrib_from_env(:PANORAMA_VAR_HOME, default: def_panorama_var_home)
    config.panorama_var_home_user_defined = config.panorama_var_home != def_panorama_var_home

    unless File.directory?(config.panorama_var_home)  # Ensure that directory exists
      begin
        Dir.mkdir config.panorama_var_home
        raise "Directory #{config.panorama_var_home} does not exist and could not be created" unless File.exist?(config.panorama_var_home)
      rescue Exception => e
        logger.error('Panorama::Application') { "Error #{e.class}:#{e.message} while creating the missing directory PANORAMA_VAR_HOME = #{config.panorama_var_home}" }
        exit! 1                                                                 # Ensure application terminates if initialization fails
      end
    end

    # Password for access on Admin menu, Panorama-Sampler config etc. : admin menu is activated if password is not empty
    # Backward campatibility for previously used environment entry
    ENV['PANORAMA_MASTER_PASSWORD'] = ENV['PANORAMA_SAMPLER_MASTER_PASSWORD']  if ENV['PANORAMA_SAMPLER_MASTER_PASSWORD'] && !ENV['PANORAMA_MASTER_PASSWORD']

    Panorama::Application.set_and_log_attrib_from_env(:PANORAMA_MASTER_PASSWORD, accept_empty: true)

    # Textdatei zur Erfassung der Panorama-Nutzung
    # Sicherstellen, dass die Datei ausserhalb der Applikation zu liegen kommt und Deployment der Applikation überlebt durch Definition von PANORAMA_VAR_HOME
    config.usage_info_filename = "#{config.panorama_var_home}/Usage.log"
    Panorama::Application.set_and_log_attrib_from_env(:PANORAMA_USAGE_INFO_MAX_AGE, default: 180, integer: true)

    # File-Store für ActiveSupport::Cache::FileStore
    config.client_info_filename = "#{config.panorama_var_home}/client_info.store"

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

    # Remove dependency on ActionCable, which is not used in Panorama
    # PR, 2025-07-12
    # config.middleware.delete ActionCable::Server::Base
  end
end
