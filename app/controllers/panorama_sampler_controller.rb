require 'json'

class PanoramaSamplerController < ApplicationController

  def list_config
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @sampler_config = PanoramaSamplerConfig.get_config_array.map{|config| config.get_cloned_config_hash}
    render_partial :list_config
  end

  def show_new_config_form
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @modus = :new
    @config = PanoramaSamplerConfig.new.get_cloned_config_hash
    render_partial :edit_config
  end

  def show_edit_config_form
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @modus = :edit
    @config = PanoramaSamplerConfig.get_config_entry_by_id(params[:id].to_i).get_cloned_config_hash
    @config[:password] = nil                                                    # Password set only if changed
    render_partial :edit_config
  end

  def save_config
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    config_entry                          = params[:config].to_unsafe_h.symbolize_keys
    config_entry[:id]                     = params[:id].to_i
    config_entry[:awr_ash_active]         = config_entry[:awr_ash_active]         == '1'
    config_entry[:object_size_active]     = config_entry[:object_size_active]     == '1'
    config_entry[:cache_objects_active]   = config_entry[:cache_objects_active]   == '1'
    config_entry[:blocking_locks_active]  = config_entry[:blocking_locks_active]  == '1'
    config_entry[:longterm_trend_active]  = config_entry[:longterm_trend_active]  == '1'

    PanoramaSamplerConfig.prepare_saved_entry!(config_entry)      # Password encryption called here

    if PanoramaSamplerConfig.config_entry_exists?(config_entry[:id])            # entry already saved?
      org_entry = PanoramaSamplerConfig.get_config_entry_by_id(config_entry[:id]).get_cloned_config_hash  # Test with copy
      config_entry.replace(org_entry.merge(config_entry))                       # Replace content, but preserve object
    end

    dbid = WorkerThread.check_connection(PanoramaSamplerConfig.new(config_entry), self, params[:commit] != 'Save')  # Tests connection and writes back some state in config_hash. Ignore exceptions if "Save" pressed

    config_entry[:dbid] = dbid unless dbid.nil?                                 # Save dbid if real value
    config_entry[:last_successful_connect] = Time.now unless dbid.nil?

    store_config(config_entry)                                                  # add or modify entry in persistence
  end

  def store_config(config_entry)
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    old_min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    existing_config = PanoramaSamplerConfig.get_config_entry_by_id_or_nil(config_entry[:id])  # Check if config already exists

    unless Panorama::Application.config.panorama_var_home_user_defined
      add_popup_message("There's no storage location defined for persistent config data!
That means, this config data will be lost at next restart of Panorama backend application!
To fix this, set environment variable PANORAMA_VAR_HOME to the desired location before starting the backend application.")
    end

    # warn if ASH is activated first time
    if (existing_config.nil? || !existing_config.get_config_value(:awr_ash_active)) && config_entry[:awr_ash_active]
      add_popup_message("You've activated ASH sampling for the first time.
Sampling of ASH data now only starts at the next configured AWR snapshot.
If you want to start ASH sampling immediately, please restart the Panorama backend application once.")
    end

    if existing_config.nil?
      PanoramaSamplerConfig.add_config_entry(config_entry)
    else
      existing_config.modify(config_entry)
    end

    new_min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    if new_min_snapshot_cycle < old_min_snapshot_cycle
      add_popup_message("Sampling currently starts each #{old_min_snapshot_cycle} minutes, but you've requested sampling each #{new_min_snapshot_cycle} minutes now.
That means, your configured action will be executed now only after next full #{old_min_snapshot_cycle} minutes.
If you want it executed in the configured cycle, please restart the Panorama backend application once.")
    end

    list_config
  end

  def delete_config
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    PanoramaSamplerConfig.delete_config_entry(params[:id])
    list_config
  end

  def clear_config_error
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    PanoramaSamplerConfig.get_config_entry_by_id(params[:id]).clear_error_message
    list_config
  end

  # Access without admin logon possible for monitoring
  def monitor_sampler_status
    status = 200                                                                # Default

    config_array = PanoramaSamplerConfig.get_reduced_config_array_for_status_monitor
    config_list = []
    # retval = "{\n\"config_list\": ["
    config_array.each do |config|
      status = 500 if config[:error_active]
      #retval << "\n#{JSON.pretty_generate(config, {indent: '  '}).gsub(/\\\\n/, "\n")},"
      config_list << config
    end
    # retval << "\n]\n}"
    retval = { config_list: config_list}
    render json: JSON.pretty_generate(retval, {indent: '  '}).gsub(/\\\\n/, "\\n"), status: status
  end

  def export_config
    @json_data = PanoramaSamplerConfig.export_config
    render_partial
  end

  def show_import_config
    render_partial
  end

  def import_config
    json_data = prepare_param :json_data
    import_count = PanoramaSamplerConfig.import_config(json_data)
    show_popup_message("#{import_count} configuration entries successfully imported. Please refresh the page to see the new entries.")
  end
end
