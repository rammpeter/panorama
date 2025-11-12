require_relative '../../app/helpers/env_helper'                                 # requires so that path is still valid if engine is used in other project

begin
  # create secrets for encryption
  config = Panorama::Application.config                                           # short access
  default_file = File.join(config.panorama_var_home, 'secret_key_base')           # Default location if no secret_key_base or secret_key_base_file given

  # Check if environment overrules possible setting by config file
  Panorama::Application.set_attrib_from_env('SECRET_KEY_BASE', accept_empty: true)
  if config.secret_key_base != 'nil'                        # set by config file or environment
    Panorama::Application.log_attribute(:SECRET_KEY_BASE, 'dont show secret', password: true)
    Rails.logger.info('create_secrets.rb') { "Secret key base read from config attribute SECRET_KEY_BASE (#{config.secret_key_base.length} chars)"}
    Rails.logger.warn('create_secrets.rb') { "Secret key base from SECRET_KEY_BASE config attribute is too short! Should have at least 128 chars!" } if config.secret_key_base.length < 128

  end

  # get file from command line arguments
  ARGV.each_with_index do |arg, index|
    if arg.match(/^\-f/) || arg.match(/^\--file/)
      if arg.match(/^\-f=/) || arg.match(/^\--file=/)
        config.secret_key_base_file = arg.split('=').last
      else
        config.secret_key_base_file = ARGV[index + 1]
      end
      raise "No file declared after command line parameter -f or --file" if config.secret_key_base_file.nil? || config.secret_key_base_file == ''
    end
  end

  Panorama::Application.set_and_log_attrib_from_env(:SECRET_KEY_BASE_FILE, accept_empty: true) # Check if file is set by config or env

  if config.secret_key_base == 'nil' && config.secret_key_base_file               # User-provided secrets file
    if File.exist?(config.secret_key_base_file)
      new_secret_key_base = File.read(config.secret_key_base_file)                # read into temp variable to avoid auto presetting of config.secret_key_base if it is set to nil
      Rails.logger.info('create_secrets.rb') { "Secret key base read from file '#{config.secret_key_base_file}' pointed to by SECRET_KEY_BASE_FILE config attribute (#{new_secret_key_base.length} chars)" }
      Rails.logger.error('create_secrets.rb') { "Secret key base file pointed to by SECRET_KEY_BASE_FILE config attribute is empty!" } if new_secret_key_base.nil? || new_secret_key_base == ''
      Rails.logger.warn('create_secrets.rb') { "Secret key base from file pointed to by SECRET_KEY_BASE_FILE config attribute is too short! Should have at least 128 chars!" } if new_secret_key_base.length < 128
      config.secret_key_base = new_secret_key_base                                # final set of config, will autogenerate random value if set to nil
    else
      raise "Configured secret key base file does not exist; '#{config.secret_key_base_file}'!"
    end
  end

  if config.secret_key_base == 'nil' && File.exist?(default_file)                 # look for generated file
    new_secret_key_base = File.read(default_file)                                 # read into temp variable to avoid auto presetting of config.secret_key_base if it is set to nil
    Rails.logger.info('create_secrets.rb') { "Secret key base read from default file location '#{default_file}' (#{new_secret_key_base.length} chars)" }
    Rails.logger.warn('create_secrets.rb') { "Default location of secret key base file '#{default_file}' points to a temporary folder because you did not provide a value for PANORAMA_VAR_HOME" } unless config.panorama_var_home_user_defined
    Rails.logger.warn('create_secrets.rb') { "Your stored connections and sampler configuration may be lost at next Panorama restart !" } unless config.panorama_var_home_user_defined
    Rails.logger.error('create_secrets.rb') { "Secret key base file at default location '#{default_file}' is empty!" } if new_secret_key_base.nil? || new_secret_key_base == ''
    Rails.logger.warn('create_secrets.rb') { "Secret key base from file at default location '#{default_file}' is too short! Should have at least 128 chars!" } if new_secret_key_base.length < 128
    config.secret_key_base = new_secret_key_base                                  # final set of config, will autogenerate random value if set to nil
  end

  if config.secret_key_base == 'nil' || config.secret_key_base == ''
    Rails.logger.warn('create_secrets.rb') { "Neither SECRET_KEY_BASE nor SECRET_KEY_BASE_FILE provided nor file exists at default location #{default_file}!" }
    Rails.logger.warn('create_secrets.rb') { "Encryption key for SECRET_KEY_BASE is initially generated and stored at #{default_file}!" }
    Rails.logger.warn('create_secrets.rb') { "This key is valid only for the lifetime of this running Panorama instance because you did not provide a value for PANORAMA_VAR_HOME !" } unless config.panorama_var_home_user_defined
    config.secret_key_base = Random.rand(99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999).to_s
    File.write(default_file, config.secret_key_base)
  end
rescue Exception => e
  Rails.logger.error('create_secrets.rb') { "Error setting secret key base: #{e.class}: #{e.message}" }
  raise
end

# Check if this file is not needed anymore
=begin
secrets_file = File.join(Rails.root, 'config', 'secrets.yml')
rails_env = ENV['RAILS_ENV'] || 'production'
content = "
# File generated by config/initializers/create_secrets.rb for compatibility reason only
# This file will be overwritten with the current secret_key_base each time Panorama starts

#{rails_env}:
    secret_key_base: \"#{config.secret_key_base}\"
"

begin
  File.write(secrets_file, content)
rescue Exception => e
  puts "Error creating secrets file '#{secrets_file}'\n#{e.class}: #{e.message}"
end

=end