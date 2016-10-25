module Panorama
  class EngineConfig < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Verzeichnis für permanent zu schreibende Dateien
    config.panorama_var_home = "."
    config.panorama_var_home = ENV['PANORAMA_VAR_HOME'] if ENV['PANORAMA_VAR_HOME']

    # Textdatei zur Erfassung der Panorama-Nutzung
    # Sicherstellen, dass die Datei ausserhalb der Applikation zu liegen kommt und Deployment der Applikation überlebt durch Definition von ENV['PANORAMA_VAR_HOME']
    config.usage_info_filename = "#{config.panorama_var_home}/Usage.log"

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

  end
end
