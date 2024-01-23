class ClientInfoStore
  attr_reader :store  # TODO: remove after conversion
  @@instance = nil

    private_class_method :new

  def self.instance
    @@instance = new unless @@instance
    @@instance
  end

  # wrap calls to instance
  def self.read(key)              instance.read(key)          end
  def self.write(key, value)      instance.write(key, value)  end
  def self.exist?(key)            instance.exist?(key)        end
  def self.read_for_client_key(client_key, key, default: nil) instance.read_for_client_key(client_key, key, default: default) end
  def self.write_for_client_key(client_key, key, value, retries: 0) instance.write_for_client_key(client_key, key, value, retries: retries) end

  # Remove expired entries
  def self.cleanup
    instance.store.cleanup
  end

  def self.read_from_browser_tab_client_info_store(client_key, browser_tab_id, key)
    browser_tab_ids = ClientInfoStore.read_for_client_key(client_key,:browser_tab_ids) # read full tree with all browser-tab-specific connections
    raise "No session state available at Panorama-Server: Please restart app in browser" if browser_tab_ids.nil? || browser_tab_ids[browser_tab_id].nil?
    browser_tab_ids[browser_tab_id][key]                                        # get current value for current browser tab
  end


  # Write browser-tab-specific info value to server-side cache
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
    @store = ActiveSupport::Cache::FileStore.new(Panorama::Application.config.client_info_filename)
    Rails.logger.info("Local directory for client-info store is #{Panorama::Application.config.client_info_filename}")
    @buffered_key = nil
    @buffered_value = nil
  rescue Exception =>e
    ExceptionHelper.reraise_extended_exception(e, "while creating file store at '#{Panorama::Application.config.client_info_filename}'", log_location: 'ClientInfoStore.initialize')
  end

  # read the content for particular key
  # @param [String] key
  # @return [String] value
  def read(key)
    if @buffered_key != key
      @buffered_key = key
      @buffered_value = @store.read(key)
    end
    @buffered_value
  end

  # write the content for particular key
  # @param [String] key
  # @param [String] value
  # @param [Hash] options
  def write(key, value, options = nil)
    @buffered_key = key                                                         # Buffer key and value for next read
    @buffered_value = value                                                     # ensure that new or changed value is returned on next read
    store.write(key, value)
  end

  def exist?(key)
    @store.exist?(key)
  end

  # Read client related data,, ex. read_from_client_info_store
  # @param [String] client_key The decrypted client key for identifying client
  # @param [String] key
  # @param [any] default value if key not found
  def read_for_client_key(client_key, key, default: nil)
    value = read(client_key)                                                    # Read the whole content Hash from cache
    if value.nil? || value.class != Hash || value[key].nil?                     # Abbruch wenn Struktur nicht passt
      Rails.logger.error('ClientInfoStore.read_for_client_key') {"No data found in client specific client_info_store while looking for key=#{key}"}
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

    puts "write_for_client_key #{client_key} #{key} #{value} caller=#{caller(2).first}"

    begin
      write(client_key, client_data, expires_in: 3.months )  # Überschreiben des kompletten Hashes im Cache
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

  def get_client_info_store_elements(locate_array = [])
    client_info_store = ClientInfoStore.read(get_decrypted_client_key)

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

  #
  def get_decrypted_client_key
    if !defined?(@buffered_client_key) || @buffered_client_key.nil?
      #      Rails.logger.debug "get_decrypted_client_key: client_key = #{cookies['client_key']} client_salt = #{cookies['client_salt']}"
      return nil if cookies['client_key'].nil? && cookies['client_salt'].nil?  # Connect vom Job oder monitor
      @buffered_client_key = Encryption.decrypt_value(cookies['client_key'], cookies['client_salt'])      # wirft ActiveSupport::MessageVerifier::InvalidSignature wenn cookies['client_key'] == nil
    end
    @buffered_client_key
  rescue ActiveSupport::MessageVerifier::InvalidSignature => e
    Rails.logger.error('ApplicationHelper.get_decrypted_client_key') { "Exception '#{e.message}' raised while decrypting cookies['client_key'] (#{cookies['client_key']})" }
    #log_exception_backtrace(e, 20)
    if cookies['client_key'].nil?
      raise("Your browser does not allow cookies for this URL!\nPlease enable usage of browser cookies for this URL and reload the page.")
    else
      cookies.delete('client_key')                                               # Verwerfen des nicht entschlüsselbaren Cookies
      cookies.delete('client_salt')
      ExceptionHelper.reraise_extended_exception(e, "while decrypting your client key from browser cookie. \nPlease try again.", log_location: 'ApplictionHelper.get_decrypted_client_key')
    end
  end

end


