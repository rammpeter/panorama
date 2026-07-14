# Encapsulates the thread local storage used by Panorama.
#
# Panorama has no static DB connection. Instead the connect info of the current request and the used DB connection
# object are bound to the executing thread (Puma worker thread or WorkerThread of the sampler).
# This class is the only place where these thread local variables are accessed.
# Use the accessors of this class instead of touching Thread.current[] directly.
class ThreadLocalStorage
  CONNECT_INFO_KEY      = :panorama_connection_connect_info                     # Hash with the connect info (credentials etc.) of the current request
  APP_INFO_SET_KEY      = :panorama_connection_app_info_set                     # true if dbms_application_info has already been set for the current thread
  CONNECTION_OBJECT_KEY = :panorama_connection_connection_object                # PanoramaConnection object currently used by this thread

  # Connect info of the current thread without check for existence
  # @return [Hash, nil] the connect info or nil if not set for this thread
  def self.connect_info
    Thread.current[CONNECT_INFO_KEY]
  end

  # Connect info of the current thread, ensured to exist
  # @return [Hash] the connect info of the current thread
  # @raise [RuntimeError] if no connect info is set for the current thread
  def self.connect_info!
    unless connect_info
      Rails.logger.error('ThreadLocalStorage.connect_info!') { "Thread.current[#{CONNECT_INFO_KEY.inspect}] does not exist" }
      Rails.logger.error('ThreadLocalStorage.connect_info!') { "Stack trace:\n#{Thread.current.backtrace.join("\n")}" }
      raise 'No current DB connect info set! Please reconnect to DB or restart Panorama in browser!'
    end
    connect_info
  end

  # Store the connect info for the current thread, marks the begin of a request
  # @param config [Hash] the connect info
  def self.connect_info=(config)
    Thread.current[CONNECT_INFO_KEY] = config
  end

  # @return [Boolean] true if dbms_application_info has already been set for the connection of this thread
  def self.app_info_set?
    Thread.current[APP_INFO_SET_KEY] == true
  end

  # @param value [Boolean, nil] true if dbms_application_info has been set for the connection of this thread
  def self.app_info_set=(value)
    Thread.current[APP_INFO_SET_KEY] = value
  end

  # @return [PanoramaConnection, nil] the connection object of the current thread or nil if not connected
  def self.connection_object
    Thread.current[CONNECTION_OBJECT_KEY]
  end

  # @param value [PanoramaConnection, nil] the connection object to bind to the current thread
  def self.connection_object=(value)
    Thread.current[CONNECTION_OBJECT_KEY] = value
  end

  # Ensure initialized values if the thread is reused for the next request
  def self.reset
    self.app_info_set = nil
    self.connect_info = nil
  end
end
