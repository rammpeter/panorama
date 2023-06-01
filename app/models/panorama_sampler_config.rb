# Stores Config-object in memory and synchronizes access to session store on disk
# noinspection RubyClassVariableUsageInspection

#require 'popup_message_exception'
require 'json'

class PanoramaSamplerConfig
  include ExceptionHelper

  @@config_array = nil                                                          # First access loads it from session store
  @@config_access_mutex = Mutex.new

  def initialize(config_hash = {})
    @config_hash = config_hash.clone                                            # Store config as instance element

    # Intitalize defaults
    @config_hash[:id]                                 = PanoramaSamplerConfig.get_max_id+1     if !@config_hash.has_key?(:id)

    @config_hash[:awr_ash_snapshot_cycle]             = 60    if !@config_hash.has_key?(:awr_ash_snapshot_cycle)
    @config_hash[:awr_ash_snapshot_retention]         = 32    if !@config_hash.has_key?(:awr_ash_snapshot_retention)
    @config_hash[:sql_min_no_of_execs]                = 2     if !@config_hash.has_key?(:sql_min_no_of_execs)
    @config_hash[:sql_min_runtime_millisecs]          = 10    if !@config_hash.has_key?(:sql_min_runtime_millisecs)
    @config_hash[:awr_ash_active]                     = false if !@config_hash.has_key?(:awr_ash_active)
    @config_hash[:ash_1sec_sample_keep_hours]         = 3     if !@config_hash.has_key?(:ash_1sec_sample_keep_hours)

    @config_hash[:object_size_active]                 = false if !@config_hash.has_key?(:object_size_active)
    @config_hash[:object_size_snapshot_cycle]         = 24    if !@config_hash.has_key?(:object_size_snapshot_cycle)
    @config_hash[:object_size_snapshot_retention]     = 1000  if !@config_hash.has_key?(:object_size_snapshot_retention)

    @config_hash[:cache_objects_active]               = false if !@config_hash.has_key?(:cache_objects_active)
    @config_hash[:cache_objects_snapshot_cycle]       = 30    if !@config_hash.has_key?(:cache_objects_snapshot_cycle)
    @config_hash[:cache_objects_snapshot_retention]   = 60    if !@config_hash.has_key?(:cache_objects_snapshot_retention)

    @config_hash[:blocking_locks_active]              = false if !@config_hash.has_key?(:blocking_locks_active)
    @config_hash[:blocking_locks_snapshot_cycle]      = 2     if !@config_hash.has_key?(:blocking_locks_snapshot_cycle)
    @config_hash[:blocking_locks_snapshot_retention]  = 60    if !@config_hash.has_key?(:blocking_locks_snapshot_retention)
    @config_hash[:blocking_locks_long_locks_limit]    = 10000 if !@config_hash.has_key?(:blocking_locks_long_locks_limit)

    @config_hash[:longterm_trend_active]              = false if !@config_hash.has_key?(:longterm_trend_active)
    @config_hash[:longterm_trend_data_source]         = :oracle_ash if !@config_hash.has_key?(:longterm_trend_data_source)  # or :panorama_sampler
    @config_hash[:longterm_trend_snapshot_cycle]      = 24    if !@config_hash.has_key?(:longterm_trend_snapshot_cycle)     # Hours
    @config_hash[:longterm_trend_snapshot_retention]  = 3650  if !@config_hash.has_key?(:longterm_trend_snapshot_retention) # Days
    @config_hash[:longterm_trend_log_wait_class]      = true  if !@config_hash.has_key?(:longterm_trend_log_wait_class)
    @config_hash[:longterm_trend_log_wait_event]      = true  if !@config_hash.has_key?(:longterm_trend_log_wait_event)
    @config_hash[:longterm_trend_log_user]            = true  if !@config_hash.has_key?(:longterm_trend_log_user)
    @config_hash[:longterm_trend_log_service]         = true  if !@config_hash.has_key?(:longterm_trend_log_service)
    @config_hash[:longterm_trend_log_machine]         = true  if !@config_hash.has_key?(:longterm_trend_log_machine)
    @config_hash[:longterm_trend_log_module]          = true  if !@config_hash.has_key?(:longterm_trend_log_module)
    @config_hash[:longterm_trend_log_action]          = false if !@config_hash.has_key?(:longterm_trend_log_action)
    @config_hash[:longterm_trend_subsume_limit]       = 10    if !@config_hash.has_key?(:longterm_trend_subsume_limit)      # per mille

    @config_hash[:last_analyze_check_timestamp]       = nil   if !@config_hash.has_key?(:last_analyze_check_timestamp)

    @config_hash[:last_awr_ash_snapshot_start]        = nil   if !@config_hash.has_key?(:last_awr_ash_snapshot_start)
    @config_hash[:last_object_size_snapshot_start]    = nil   if !@config_hash.has_key?(:last_object_size_snapshot_start)
    @config_hash[:last_cache_objects_snapshot_start]  = nil   if !@config_hash.has_key?(:last_cache_objects_snapshot_start)
    @config_hash[:last_blocking_locks_snapshot_start] = nil   if !@config_hash.has_key?(:last_blocking_locks_snapshot_start)
    @config_hash[:last_longterm_trend_snapshot_start] = nil   if !@config_hash.has_key?(:last_longterm_trend_snapshot_start)

    # Hash with indicators for each domain if check has occurred since last startup (nil, :running, :finished, :error)
    @config_hash[:structure_checks]                   = {}    if !@config_hash.has_key?(:structure_checks)

  end

  def get_cloned_config_hash
    retval = @config_hash.clone
    retval.delete(:select_any_table)                                            # don't store this value, should be scanned new
    retval
  end

  def get_config_value(key)
    if !@config_hash.has_key?(key)
      Rails.logger.debug "PanoramaSamplerConfig.get_config_value: Missing hash key '#{key}' of class '#{key.class}' for panorama-sampler config with ID=#{get_id}"
    end
    @config_hash[key]
  end

  # route get_xxx to get_config_value(:xxx);
  def method_missing(sym, *args, &block)
    methodname = sym.to_s
    if methodname['get_']                                                       # getter called
      get_config_value(methodname[4, methodname.length-4].to_sym);
    else
      raise "No method #{sym} for #{self.class}"
    end
  end

  # getter in direct declaration. Missing getters are catched by method_missing
  def get_id;                                 get_config_value(:id);                                  end
  def get_awr_ash_active;                     get_config_value(:awr_ash_active);                      end
  def get_awr_ash_snapshot_cycle;             get_config_value(:awr_ash_snapshot_cycle);              end
  def get_awr_ash_snapshot_retention;         get_config_value(:awr_ash_snapshot_retention);          end
  def get_ash_1sec_sample_keep_hours;         get_config_value(:ash_1sec_sample_keep_hours);          end
  def get_blocking_locks_active;              get_config_value(:blocking_locks_active);               end
  def get_blocking_locks_long_locks_limit;    get_config_value(:blocking_locks_long_locks_limit);     end
  def get_blocking_locks_snapshot_cycle;      get_config_value(:blocking_locks_snapshot_cycle);       end
  def get_blocking_locks_snapshot_retention;  get_config_value(:blocking_locks_snapshot_retention);   end
  def get_cache_objects_active;               get_config_value(:cache_objects_active);                end
  def get_cache_objects_snapshot_cycle;       get_config_value(:cache_objects_snapshot_cycle);        end
  def get_cache_objects_snapshot_retention;   get_config_value(:cache_objects_snapshot_retention);    end
  def get_dbid;                               get_config_value(:dbid);                                end
  def get_name;                               get_config_value(:name);                                end
  def get_object_size_active;                 get_config_value(:object_size_active);                  end
  def get_object_size_snapshot_cycle;         get_config_value(:object_size_snapshot_cycle);          end
  def get_object_size_snapshot_retention;     get_config_value(:object_size_snapshot_retention);      end
  def get_owner;                              get_config_value(:owner);                               end
  def get_sql_min_no_of_execs;                get_config_value(:sql_min_no_of_execs);                 end
  def get_sql_min_runtime_millisecs;          get_config_value(:sql_min_runtime_millisecs);           end
  def get_last_analyze_check_timestamp;       get_config_value(:last_analyze_check_timestamp);        end

  def get_domain_active(domain);              get_config_value("#{domain.downcase}_active".to_sym);               end
  def get_domain_snapshot_cycle(domain);      get_config_value("#{domain.downcase}_snapshot_cycle".to_sym);       end
  def get_last_domain_snapshot_start(domain); get_config_value("last_#{domain.downcase}_snapshot_start".to_sym);  end
  def get_last_domain_snapshot_end(domain);   get_config_value("last_#{domain.downcase}_snapshot_end".to_sym);    end

  def get_structure_check(domain);            get_config_value(:structure_checks)[domain];            end

  # Does the user have SELECT ANY TABLE? This ensures that user may select V$-Tables from within packages
  def get_select_any_table?
    if !@config_hash.key?(:select_any_table)
      # Check if accessing v$-tables from within PL/SQL-Package is possible
      # don't persist config change because config may be pending (not saved) for new sampler configuration
      @config_hash[:select_any_table] = (0 < PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM DBA_Sys_Privs WHERE Grantee = ? AND Privilege = 'SELECT ANY TABLE'", @config_hash[:user].upcase]))

      # System does not have SELECT-grant on V$-Tables from within packages! Tested for 18.3-EE and 18.4-XE
      # Ensure using anonymous PL/SQL instead of package if user is system
      @config_hash[:select_any_table] = false if @config_hash[:user].upcase == 'SYSTEM' || @config_hash[:owner].upcase == 'SYSTEM'
      @config_hash[:select_any_table] = true if @config_hash[:user].upcase == 'SYS' # no DBA_Sys_Privs exists for SYS

      if @config_hash[:select_any_table]
        Rails.logger.debug("Panorama-Sampler PL/SQL used as Packages because acccess on V$-tables is possible in packages for user '#{@config_hash[:user]}'")
      else
        Rails.logger.debug("Panorama-Sampler PL/SQL used as anonymous PL/SQL because no acccess on V$-tables is possible in packages for user '#{@config_hash[:user]}'")
      end
    end
    @config_hash[:select_any_table]
  end

  def current_error_exists?
    retval = false
    last_snap = nil
    PanoramaSamplerConfig.get_domains.each do |domain|
      sn_start = get_last_domain_snapshot_start(domain)
      if domain == :AWR_ASH
        sn_end   = get_last_domain_snapshot_end(:AWR)
      else
        sn_end   = get_last_domain_snapshot_end(domain)
      end
      retval = true if get_domain_active(domain) && !sn_start.nil? && (sn_end.nil? || sn_end < sn_start)
      last_snap = sn_start if get_domain_active(domain) && (last_snap.nil? || (!sn_start.nil? && last_snap < sn_start))
      last_snap = sn_end   if get_domain_active(domain) && (last_snap.nil? || (!sn_end.nil?   && last_snap < sn_end))
    end
    retval = true if !last_snap.nil? && !get_config_value(:last_error_time).nil? && last_snap < get_config_value(:last_error_time)  # if last_error is younger than any other timestamp
    retval
  end

  def any_domain_active?
    PanoramaSamplerConfig.get_domains.each do |domain|
      return true if send("get_#{domain.downcase}_active")
    end
    false
  end

  def set_select_any_table(value)
    raise "Method is for test purpose only" if !Rails.env.test?
    @config_hash[:select_any_table] = value
  end

  def set_domain_last_snapshot_start(domain, snapshot_time)
    @@config_access_mutex.synchronize do
      @config_hash["last_#{domain.downcase}_snapshot_start".to_sym] = snapshot_time
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_domain_last_snapshot_end(domain, snapshot_time)
    @@config_access_mutex.synchronize do
      @config_hash["last_#{domain.downcase}_snapshot_end".to_sym] = snapshot_time
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_error_message(message)
    @@config_access_mutex.synchronize do
      @config_hash[:last_error_time]    = Time.now
      @config_hash[:last_error_message] = message
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def clear_error_message
    @@config_access_mutex.synchronize do
      @config_hash[:last_error_time] = nil
      @config_hash[:last_error_message] = nil
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def last_successful_connect(domain, instance)
    @@config_access_mutex.synchronize do
      @config_hash[:last_successful_connect] = Time.now
      @config_hash["last_#{domain.downcase}_snapshot_instance".to_sym] = instance
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_last_analyze_check_timestamp(timestamp = Time.now)
    @@config_access_mutex.synchronize do
      @config_hash[:last_analyze_check_timestamp] = timestamp
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  # set the state of structure check for specific domain
  # @param {Symbol} domain
  # @param {Symbol} state nil, :running, :finished, :error
  def set_structure_check(domain, state)
    @@config_access_mutex.synchronize do
      @config_hash[:structure_checks][domain] = state
      # PanoramaSamplerConfig.write_config_array_to_store is not necessary because content is valid for runtime of Panorama instance only
    end
  end

  # Called once at start of Panorama instance
  def reset_structure_check
    @@config_access_mutex.synchronize do
      @config_hash[:structure_checks] = {}
      # PanoramaSamplerConfig.write_config_array_to_store is not necessary because content is valid for runtime of Panorama instance only
    end
  end

  # Allow snapshot cycle with less than 1 minute for tests
  def set_test_awr_ash_snapshot_cycle(seconds)
    raise "Method only allowed for test purpose" if !Rails.env.test?
    @@config_access_mutex.synchronize do
      @config_hash[:awr_ash_snapshot_cycle] = seconds.to_f/60
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end


  # Modify object with values from hash
  def modify(modified_config_hash)
    @@config_access_mutex.synchronize do
      org_config_hash = get_cloned_config_hash                                  # Use cloned hash for validation test
      PanoramaSamplerConfig.validate_entry(org_config_hash.merge(modified_config_hash)) # Validate resulting merged entry
      @config_hash.merge!(modified_config_hash)                                 # Do real merge if validation passed
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  #----------------------------- class methods -----------------------------------
  # List of config-domains (AWR and ASH are AWR_ASH)
  def self.get_domains
    [:AWR_ASH, :OBJECT_SIZE, :CACHE_OBJECTS, :BLOCKING_LOCKS, :LONGTERM_TREND ]
  end

  # get array initialized from session store. Call inside Mutex.synchronize only
  def self.get_config_array
    if @@config_array.nil?
      @@config_access_mutex.synchronize do
        if Panorama::Application.config.panorama_master_password.nil?
          @@config_array = []                                                     # No config to read if master password is not given
        else
          config_hash_array = ApplicationHelper.get_client_info_store.read(client_info_store_key)  # get stored values as Hash
          config_hash_array = [] if config_hash_array.nil?
          @@config_array = config_hash_array.map{|config_hash| PanoramaSamplerConfig.new(config_hash)} # Store instances in array
        end
      end
    end
    @@config_array
  end

  # Get only values without confidential state
  def self.get_reduced_config_array_for_status_monitor
    retval = []
    @@config_access_mutex.synchronize do
      config_hash_array = ApplicationHelper.get_client_info_store.read(client_info_store_key)  # get stored values as Hash
      config_hash_array = [] if config_hash_array.nil?

      config_hash_array.each do |config_hash|
        retval << { id:                       config_hash[:id],
                    dbid:                     config_hash[:dbid],
                    name:                     config_hash[:name],
                    last_successful_connect:  config_hash[:last_successful_connect],
                    last_error_time:          config_hash[:last_error_time],
                    last_error_message:       config_hash[:last_error_message],
                    error_active:             PanoramaSamplerConfig.new(config_hash).current_error_exists?
        }
      end
    end
    retval
  end

  def self.get_config_entry_by_id(p_id)
    retval = get_config_entry_by_id_or_nil(p_id)
    if retval.nil?
      raise "No Panorama-Sampler config found for ID=#{p_id} class='#{p_id.class}'"
    end
    retval
  end

  def self.get_config_entry_by_id_or_nil(p_id)
    get_config_array.each do |c|
      return c if c.get_id == p_id.to_i
    end
    return nil
  end

  def self.sampler_schema_for_dbid(dbid)
    get_config_array.each do |config|
      return config.get_owner if config.get_dbid == dbid
    end
    nil
  end

  def self.get_max_id
    retval = 0
    get_config_array.each do |config|
      retval = config.get_id if config.get_id > retval
    end
    retval
  end

  def self.min_snapshot_cycle
    min_snapshot_cycle = 60                                                     # at least every hour run job
    get_config_array.each do |config|
      min_snapshot_cycle = config.get_awr_ash_snapshot_cycle            if config.get_awr_ash_active        && config.get_awr_ash_snapshot_cycle          < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_object_size_snapshot_cycle*60     if config.get_object_size_active    && config.get_object_size_snapshot_cycle*60   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_cache_objects_snapshot_cycle      if config.get_cache_objects_active  && config.get_cache_objects_snapshot_cycle    < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_blocking_locks_snapshot_cycle     if config.get_blocking_locks_active && config.get_blocking_locks_snapshot_cycle   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
    end
    min_snapshot_cycle = 1 if min_snapshot_cycle == 0                           # not supported cycle < 1 minute

    # Check if smallest divider matches over all configs
    get_config_array.each do |config|
      while true
        reminder_exists = false                                                   # Assume no reminder exists for all jobs
        reminder_exists = true if config.get_awr_ash_active        && config.get_awr_ash_snapshot_cycle         % min_snapshot_cycle != 0
        reminder_exists = true if config.get_cache_objects_active  && config.get_cache_objects_snapshot_cycle   % min_snapshot_cycle != 0
        reminder_exists = true if config.get_blocking_locks_active && config.get_blocking_locks_snapshot_cycle  % min_snapshot_cycle != 0

        break unless reminder_exists                                              # if all jobs don't have reminders
        min_snapshot_cycle -= 1                                                   # reduce cycle and try again
        raise "PanoramaSamplerConfig.min_snapshot_cycle: min_snapshot_cycle < 1 not allowed" if min_snapshot_cycle < 1
      end
    end

    min_snapshot_cycle
  end

  # Encrypt the connection password with the master password
  # @param native_password [String] password to encrypt
  # @return [String] encrypted password
  def self.encryt_password(native_password)
    Encryption.encrypt_value(native_password, Panorama::Application.config.panorama_master_password) # Encrypt password with master_password
  end

  def self.validate_entry(config_hash, empty_password_allowed = false)
    raise PopupMessageException.new "User name is mandatory" if (config_hash[:user].nil? || config_hash[:user] == '')
    raise PopupMessageException.new "Password is mandatory" if (config_hash[:password].nil? || config_hash[:password] == '') && !empty_password_allowed
    raise PopupMessageException.new "For login with 'system' you should provide a different user schema for storage" if config_hash[:user].upcase == 'SYSTEM' && (config_hash[:owner]&.upcase == 'SYSTEM' || config_hash[:owner].nil? || config_hash[:owner] == '')

    validate_unique_name(config_hash)
    min_value_awr_cycle = 5                                                     # Default for production
    min_value_awr_cycle = 1 if Rails.env.test? || Rails.env.development?        # allow smaller cycle for test runs in CI pipeline and dev
      PanoramaSamplerConfig.validate_cycle_minutes(name: 'AWR/ASH-snapshot', value: config_hash[:awr_ash_snapshot_cycle], min_minutes: min_value_awr_cycle)
    raise PopupMessageException.new "AWR/ASH-napshot retention must be >= 1 day" if config_hash[:awr_ash_snapshot_retention].nil? || config_hash[:awr_ash_snapshot_retention] < 1
    raise PopupMessageException.new "Keep time for 1-second ASH samples must be >= 1 hour" if config_hash[:ash_1sec_sample_keep_hours].nil? || config_hash[:ash_1sec_sample_keep_hours] < 1

    PanoramaSamplerConfig.validate_cycle_hours(name: 'Object size', value: config_hash[:object_size_snapshot_cycle])
    raise PopupMessageException.new "Object size snapshot retention must be >= 1 day" if config_hash[:object_size_snapshot_retention].nil?  || config_hash[:object_size_snapshot_retention] < 1

    PanoramaSamplerConfig.validate_cycle_minutes(name: 'DB-cache snapshot', value: config_hash[:cache_objects_snapshot_cycle])
    raise PopupMessageException.new "DB-cache snapshot retention must be >= 1 day" if config_hash[:cache_objects_snapshot_retention].nil?  || config_hash[:cache_objects_snapshot_retention] < 1

    PanoramaSamplerConfig.validate_cycle_minutes(name: 'Blocking locks snapshot', value: config_hash[:blocking_locks_snapshot_cycle])
    raise PopupMessageException.new "Blocking locks snapshot retention must be >= 1 day" if config_hash[:blocking_locks_snapshot_retention].nil?  || config_hash[:blocking_locks_snapshot_retention] < 1

    raise PopupMessageException.new "You should also activate AWR/ASH-sampling if activating long-term trend with data-source Panorama-Sampler" if config_hash[:longterm_trend_active] && config_hash[:longterm_trend_data_source] == :panorama_sampler && !config_hash[:awr_ash_active]
    min_value_ltt_cycle = 24                                                     # Default for production
    min_value_ltt_cycle = 1 if Rails.env.test?                                  # allow smaller cycle for test runs in CI pipeline
    PanoramaSamplerConfig.validate_cycle_hours(name: 'Long-term trend', value: config_hash[:longterm_trend_snapshot_cycle], min_hours: min_value_ltt_cycle)
    raise PopupMessageException.new "Long-term trend snapshot retention must be >= 1 day" if config_hash[:longterm_trend_snapshot_retention].nil?  || config_hash[:longterm_trend_snapshot_retention] < 1
    raise PopupMessageException.new "Long-term trend subsume limit (per mille) must be between 0 and 1000" if config_hash[:longterm_trend_subsume_limit].nil?  || config_hash[:longterm_trend_subsume_limit] < 0 || config_hash[:longterm_trend_subsume_limit] >= 1000
  end

  def self.config_entry_exists?(p_id)
    return !get_config_entry_by_id_or_nil(p_id).nil?
  end

  # add new entry (parameter already prepared)
  def self.add_config_entry(entry_hash)
    validate_entry(entry_hash)
    @@config_access_mutex.synchronize do
      get_config_array.each do |c|
        raise "ID #{entry_hash[:id]} is already used" if c.get_id == entry_hash[:id].to_i        # Ensure unique IDs
      end
      get_config_array << PanoramaSamplerConfig.new(entry_hash)
      write_config_array_to_store
    end
  end

  def self.delete_config_entry(p_id)
    @@config_access_mutex.synchronize do
      get_config_array.each_index do |i|                                        # Ensures initialization
        @@config_array.delete_at(i) if @@config_array[i].get_id == p_id.to_i
      end
      write_config_array_to_store
    end
  end

  # Delete all entries, used especially in tests
  def self.delete_all_config_entries
    # remove the existing config
    existing_ids = PanoramaSamplerConfig.get_config_array.map{|x| x.get_id}
    existing_ids.each do |id|
      PanoramaSamplerConfig.delete_config_entry(id)
    end
  end

  #-------------- not validated class methods --------------



  # Modify some content after edit and before storage
  def self.prepare_saved_entry!(entry)
    entry[:tns]                                 = PanoramaConnection.get_host_tns(entry) if entry[:modus]&.to_sym == :host
    entry[:id]                                  = entry[:id].to_i
    entry[:awr_ash_snapshot_cycle]              = entry[:awr_ash_snapshot_cycle].to_i
    entry[:awr_ash_snapshot_retention]          = entry[:awr_ash_snapshot_retention].to_i
    entry[:ash_1sec_sample_keep_hours]          = entry[:ash_1sec_sample_keep_hours].to_i
    entry[:owner]                               = entry[:user] if entry[:owner].nil? || entry[:owner] == ''             # User is default for owner
    entry[:object_size_snapshot_cycle]          = entry[:object_size_snapshot_cycle].to_i
    entry[:object_size_snapshot_retention]      = entry[:object_size_snapshot_retention].to_i
    entry[:cache_objects_snapshot_cycle]        = entry[:cache_objects_snapshot_cycle].to_i
    entry[:cache_objects_snapshot_retention]    = entry[:cache_objects_snapshot_retention].to_i
    entry[:blocking_locks_snapshot_cycle]       = entry[:blocking_locks_snapshot_cycle].to_i
    entry[:blocking_locks_snapshot_retention]   = entry[:blocking_locks_snapshot_retention].to_i
    entry[:blocking_locks_long_locks_limit]     = entry[:blocking_locks_long_locks_limit].to_i
    entry[:longterm_trend_data_source]          = entry[:longterm_trend_data_source].to_sym
    entry[:longterm_trend_snapshot_cycle]       = entry[:longterm_trend_snapshot_cycle].to_i
    entry[:longterm_trend_snapshot_retention]   = entry[:longterm_trend_snapshot_retention].to_i
    entry[:longterm_trend_subsume_limit]        = entry[:longterm_trend_subsume_limit].to_i

    # Ensure that SYS always logs in as sysdba
    entry[:privilege]                         = :sysdba if entry[:user].upcase == 'SYS'

    validate_entry(entry, config_entry_exists?(entry[:id]))                     # Password required only for add, not for modify

    if entry[:password].nil? || entry[:password] == ''
      entry.delete(:password)                                                   # Preserve previous password at merge
    else
      entry[:password] = encryt_password(entry[:password])                      # Encrypt password with master_password
    end
    entry
  end

  # Export config as JSON document
  # @return [String] JSON document
  def self.export_config
    export_array = []
    get_config_array.map{|config| config.get_cloned_config_hash}.each do |config_hash|
      config_hash.delete(:adapter)
      config_hash.delete(:choosen_dbid)
      config_hash.delete(:client_salt)
      config_hash.delete(:id)
      config_hash.delete(:last_analyze_check_timestamp)
      config_hash.delete(:last_awr_snapshot_end)
      config_hash.delete(:last_awr_snapshot_instance)
      config_hash.delete(:last_awr_ash_snapshot_start)
      config_hash.delete(:last_awr_snapshot_start)
      config_hash.delete(:last_blocking_locks_snapshot_end)
      config_hash.delete(:last_blocking_locks_snapshot_instance)
      config_hash.delete(:last_blocking_locks_snapshot_start)
      config_hash.delete(:last_cache_objects_snapshot_end)
      config_hash.delete(:last_cache_objects_snapshot_instance)
      config_hash.delete(:last_cache_objects_snapshot_start)
      config_hash.delete(:last_error_time)
      config_hash.delete(:last_error_message)
      config_hash.delete(:last_longterm_trend_snapshot_end)
      config_hash.delete(:last_longterm_trend_snapshot_instance)
      config_hash.delete(:last_longterm_trend_snapshot_start)
      config_hash.delete(:last_object_size_snapshot_end)
      config_hash.delete(:last_object_size_snapshot_instance)
      config_hash.delete(:last_object_size_snapshot_start)
      config_hash.delete(:last_successful_connect)
      config_hash.delete(:management_pack_license)
      config_hash.delete(:privilege)
      config_hash.delete(:query_timeout)
      config_hash.delete(:structure_checks)
      config_hash.delete(:syspassword_decrypted)
      config_hash[:password] = "<please add your password here>"                # Password should never be become visible after input
      export_array << config_hash
    end
    JSON.pretty_generate(export_array)
  end

  # Import config from JSON document
  # @param [String] json_doc JSON document
  # @return [Integer] Number of imported entries
  def self.import_config(json_doc)
    raise "JSON document for import is empty" if json_doc.nil?
    config_array = JSON.parse(json_doc)
    raise "Imported JSON document is not an array" unless config_array.is_a?(Array)
    ActiveRecord::Base.transaction do
      config_array.each do |config_hash|
        raise "Imported JSON document contains an array entry that is not a hash" unless config_hash.is_a?(Hash)
        config_hash.symbolize_keys!
        get_config_array.each do |existing_config|
          raise "Imported JSON document contains an entry with the name '#{config_hash[:name]}' that already exists in the configuration" if existing_config.get_name == config_hash[:name]
        end
        config_hash[:id] = PanoramaSamplerConfig.get_max_id+1
        PanoramaSamplerConfig.prepare_saved_entry!(config_hash)
        PanoramaSamplerConfig.add_config_entry(config_hash)
      end
    end
    config_array.count
  end

  private

  def self.client_info_store_key
    raise "There was no Panorama master password given at server startup (Environment variable PANORAMA_MASTER_PASSWORD)!" if Panorama::Application.config.panorama_master_password.nil?
    "panorama_sampler_master_config_#{Panorama::Application.config.panorama_master_password.to_i(36)}_#{Panorama::Application.config.panorama_master_password.length}"
  end


  #  Call inside Mutex.synchronize only
  def self.write_config_array_to_store
    raise "PanoramaSamplerConfig.write_config_array_to_store: Mutex @@config_access_mutex is not locked before call" unless @@config_access_mutex.locked?
    ApplicationHelper.get_client_info_store.write(client_info_store_key, @@config_array.map{|config| config.get_cloned_config_hash})  # Store config array as Hash-Array
  rescue Exception =>e
    ExceptionHelper.reraise_extended_exception(e, "while writing file store at '#{Panorama::Application.config.client_info_filename}'", log_location: 'PanoramaSamplerConfig.write_config_array_to_store')
  end

  def self.validate_cycle_minutes(name:, value:, min_minutes:1)
    example_values = [1, 2, 4, 5, 10, 15, 30, 60, 120]
    addition = "!
E.g. #{example_values.select{|v| v >= min_minutes}.join(', ')} etc. minutes.
#{value} is not a valid value for #{name}!"
    raise PopupMessageException.new "#{name} cycle must not be empty#{addition}" if value.nil?
    raise PopupMessageException.new "#{name} cycle must not be an integer number#{addition}" if value.to_i != value
    raise PopupMessageException.new "#{name} cycle must be at least #{min_minutes} minutes#{addition}" if value < min_minutes
    raise PopupMessageException.new "60 must be divisible without remainder by the #{name} cycle if value is < 60#{addition}" if value <= 60  && 60 % value != 0
    raise PopupMessageException.new "#{name} cycle must be divisible without remainder by 60 if value is > 60#{addition}"     if value > 60   && value % 60 != 0
    raise PopupMessageException.new "#{name} cycle must be divisible without remainder by 1440 if value is > 1440#{addition}" if value > 1440 && value % 1440 != 0
  end

  def self.validate_cycle_hours(name:, value:, min_hours:1)
    example_values = [1, 2, 3, 4, 6, 8, 12, 24, 48, 72]
    addition = "!
E.g. #{example_values.select{|v| v >= min_hours}.join(', ')} etc. hours.
#{value} is not a valid value for #{name}!"
    raise PopupMessageException.new "#{name} snapshot cycle must be not empty#{addition}" if value.nil?
    raise PopupMessageException.new "#{name} cycle must not be an integer number#{addition}" if value.to_i != value
    raise PopupMessageException.new "#{name} cycle must be at least #{min_hours} hours#{addition}" if value < min_hours
    raise PopupMessageException.new "24 must be divisable without remainder by the #{name} snapshot cycle if value is < 24#{addition}" if value <= 24 && 24 % value != 0
    raise PopupMessageException.new "#{name} snapshot cycle must be divisible without remainder by 24 if value is > 24#{addition}" if value >= 24 && value % 24 != 0
  end

  def self.validate_unique_name(config_hash)
    PanoramaSamplerConfig.get_config_array.each do |c|
      if config_hash[:name] == c.get_config_value(:name) && (config_hash[:id].nil? || config_hash[:id] != c.get_config_value(:id))
        raise PopupMessageException.new("There is already a config existing with name '#{config_hash[:name]}'! Please use another name.")
      end
    end
  end
end
