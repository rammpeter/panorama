class ClientInfoStore
  @@instance = nil
  @@mutex = Mutex.new

    private_class_method :new

  def self.instance
    unless @@instance
      @@mutex.synchronize do
        unless @@instance
          @@instance = new
        end
      end
    end
    @@instance
  end

  # Needed for test purposes only to ensure next access creates the instance again
  def self.reset_instance
    @@instance = nil
  end

  #

  # wrap calls to instance
  def self.read(key)              instance.read(key)          end
  def self.write(key, value)      instance.write(key, value)  end
  def self.exist?(key)            instance.exist?(key)        end
  def self.read_for_client_key(client_key, key, default: nil) instance.read_for_client_key(client_key, key, default: default) end
  def self.write_for_client_key(client_key, key, value, retries: 0) instance.write_for_client_key(client_key, key, value, retries: retries) end
  def self.cleanup()              instance.cleanup            end

  def self.read_from_browser_tab_client_info_store(client_key, browser_tab_id, key)
    browser_tab_ids = ClientInfoStore.read_for_client_key(client_key,:browser_tab_ids) # read full tree with all browser-tab-specific connections
    raise "No session state available at Panorama-Server: Please restart app in browser" if browser_tab_ids.nil? || browser_tab_ids[browser_tab_id].nil?
    browser_tab_ids[browser_tab_id][key]                                        # get current value for current browser tab
  end


  # Write browser-tab-specific info value to server-side cache (add to existing values or overwrite)
  # @param [String] client_key The decrypted client key for identifying client
  # @param [String] browser_tab_id The browser tab id for identifying browser tab
  # @param [Hash] values The values to be written for browser tab
  def self.write_to_browser_tab_client_info_store(client_key, browser_tab_id, values)
    browser_tab_ids = self.read_for_client_key(client_key,:browser_tab_ids)             # read full tree with all browser-tab-specific connections
    raise "No session state available at Panorama-Server: Please restart app in browser" if browser_tab_ids.nil? || browser_tab_ids[browser_tab_id].nil?
    values.each do |key, value|
      browser_tab_ids[browser_tab_id][key] = value                               # set current values for current browser tab
    end
    self.write_for_client_key(client_key,:browser_tab_ids, browser_tab_ids)  # write full tree back to store
  end


  ############### Instance methods

  def initialize
    # Only the synchronized instance methods read, write, exists? and cleanup should access @store directly
    @store = ActiveSupport::Cache::FileStore.new(Panorama::Application.config.client_info_filename)
    Rails.logger.info("Local directory for client-info store is #{Panorama::Application.config.client_info_filename}")
  rescue Exception =>e
    ExceptionHelper.reraise_extended_exception(e, "while creating file store at '#{Panorama::Application.config.client_info_filename}'", log_location: 'ClientInfoStore.initialize')
  end

  # read the content for particular key
  # @param [String] key
  # @return [String] value
  def read(key)
    @@mutex.synchronize do
      @store.read(key)
    end
  end

  # write the content for particular key
  # @param [String] key
  # @param [Hash, Array] value
  def write(key, value)
    @@mutex.synchronize do
      @store.write(key, value)
    end
  end

  def exist?(key)
    @@mutex.synchronize do
      @store.exist?(key)
    end
  end

  def delete(key)
    @@mutex.synchronize do
      @store.delete(key)
    end
  end

  # Read client related data,, ex. read_from_client_info_store
  # @param [String] client_key The decrypted client key for identifying client
  # @param [String] key
  # @param [any] default value if key not found
  def read_for_client_key(client_key, key, default: nil)
    value = read(client_key)                                                    # Read the whole content Hash from cache
    if value.nil? || value.class != Hash || value[key].nil?                     # Abbruch wenn Struktur nicht passt
      Rails.logger.info('ClientInfoStore.read_for_client_key') {"No data found in client specific client_info_store while looking for key=#{key}"}
      return default
    end
    value[key]                                                                  # return value regardless it's nil or not
  end

  # Write client related info value to server-side cache
  # @param [String] client_key The decrypted client key for identifying client
  # @param [String, Symbol] key
  # @param [any] value
  # @param [Integer] retries Should not be used in direct call, for recursive calls only
  def write_for_client_key(client_key, key, value, retries:)
    client_data = read(client_key)                                              # Read the whole content Hash from cache
    client_data = {} if client_data.nil? || client_data.class != Hash           # Neustart wenn Struktur nicht passt
    client_data[key] = value                                                    # Wert in Hash verankern
    client_data[:last_used] = Time.now                                          # Update last_used

    begin
      write(client_key, client_data)  # Überschreiben des kompletten Hashes im Cache
    rescue Exception =>e
      # Especially for test environments, reread the store content if something goes wrong, content has changed etc.
      if retries < 2
        Rails.logger.warn('ClientInfoStore.write_for_client_key') { "Retry after #{e.class} '#{e.message}' while writing file store at '#{Panorama::Application.config.client_info_filename}'" }
        write_for_client_key(client_key, key, value, retries: retries+1)
      else
        ExceptionHelper.reraise_extended_exception(e, "while writing file store at '#{Panorama::Application.config.client_info_filename}'", log_location: 'ClientInfoStore.write_for_client_key')
      end
    end
  end

  # Get the number of elements of levels
  # @return [Array] Array of Hashes with cached_keys, second_level_entries, all_entries
  def get_elements_count
    result = {
      cached_keys: 0,
      second_level_entries: 0,
      all_entries: 0,
      classes: {}           # Hash with class names and counts  { 'Hash' => 123, 'Array' => 456 }
    }.extend(SelectHashHelper)
    cached_keys.each do |key|
      element = read(key)
      result[:cached_keys] += 1
      result[:classes][element.class.name] = 0 unless result[:classes].has_key?(element.class.name)
      result[:classes][element.class.name] += 1
      if [Hash, Array].include?(element.class)
        result[:second_level_entries] += element.count
        result[:all_entries] += get_total_elements_no(element) - 1              # Do not count the first element
      end
    end
    [result]
  end

  # List all cache elements for client_key
  # @param [String] client_key The decrypted client key for identifying client
  # @param [Array] locate_array Array of Hashes with key_name and class_name to locate the element in the client_info_store
  # @return [Array] Array of Hashes with key_name, class_name, elements, total_elements
  def get_client_info_store_elements(client_key, locate_array = [])
    client_info_store = ClientInfoStore.read(client_key)

    locate_array.each do |l|
      # step down in hierarchy
      l[:key_name] = l[:key_name].to_sym if l[:class_name] == 'Symbol'
      l[:key_name] = l[:key_name].to_i   if l[:class_name] == 'Integer'
      client_info_store = client_info_store[l[:key_name]]
    end

    result = []

    # Convert Array to Hash before processing
    client_info_store = client_info_store.map.with_index { |x, i| [i, x] }.to_h  if client_info_store.class == Array

    client_info_store.each do |key, value|
      row =  {
        key_name:       key,
        class_name:     value.class.name,
        elements:       0,
        total_elements: get_total_elements_no(value) - 1                      # Do not count the first element
      }
      row[:elements] = value.count if value.class == Hash || value.class == Array


      result << row.extend(SelectHashHelper)
    end
    result
  end

  # Remove expired entries from cache
  def cleanup
    @@mutex.synchronize do
      # Should be inactive because expiration is handled by ClientInfoStore itself
      @store.cleanup                                                              # Remove expired entries from cache by cache API
    end

    # Remove expired entries from cache by file system
    cached_keys.each do |key|
      value = read(key)
      if value.nil?
        delete(key)                                                             # Remove entry without real content
      else
        if value.class == Hash
          if value.count == 1 && value[:browser_tab_ids]&.count == 0            # Only empty browser_tab_ids left
            delete(key)                                                         # Remove entry without real content
          elsif value.count == 2 && value[:browser_tab_ids]&.count == 0 && value[:last_logins]&.count == 0
            delete(key)                                                         # Remove entry without real content
          elsif !value.has_key?(:last_used)                                     # Add last_used to all Hash entries without it
            value[:last_used] = Time.now
            write(key, value)                                                   # Write back to cache
          elsif value[:last_used] < Time.now - 12.months                        # Remove entries after 1 year of inactivity
            delete(key)                                                         # Remove entry
          elsif value[:browser_tab_ids]
            value[:browser_tab_ids].each do |browser_tab_id, browser_tab_data|
              if !browser_tab_data.has_key?(:last_request) || browser_tab_data[:last_request] < Panorama::MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST.ago
                value[:browser_tab_ids].delete(browser_tab_id)                  # Remove expired browser tab id
                write(key, value)                                               # Write back to cache
              end
            end
          end
        end
      end
    end
  rescue Exception => e
    Rails.logger.error('ClientInfoStore.cleanup') { "Exception #{e.class}\n#{e.message}" }
    ExceptionHelper.log_exception_backtrace(e, 40)
    raise e
  end

  private

  # Get the number of elements in a given Hash or Array
  # @param [Hash, Array] element
  # @return [Integer] number of elements
  def get_total_elements_no(element)
    retval = 1                                                                  # count at least itself

    if element.class == Hash
      element.each do |key, value|
        retval += get_total_elements_no(value)
      end
    end

    if element.class == Array
      element.each do |value|
        retval += get_total_elements_no(value)
      end
    end

    retval
  end

  # Get all keys from cache in recursive dirs
  def cached_keys
    result = []

    process_level = proc do |result, dirname|
      Dir.glob(File.join(dirname, '*')).each do |filename|
        if File.directory?(filename)
          process_level.call(result, filename)
        else
          result << File.basename(filename)
        end
      end
    end

    process_level.call(result, @store.cache_path)
    result
  end
end


