# Check source auf autoloading if "DEPRECATION WARNING: Initialization autoloaded the constant " occurs
# puts "#####################################"
# pp caller_locations.select { |l| l.to_s.index("config/init") }

module ExceptionHelper

  # Log the stacktrace of an exception
  # @param [Exception] exception: Exception to log
  # @param [Integer] line_number_limit : Amount of lines to log, nil = all
  # @param [Symbol] log_mode: mode for log outout, :debug, :info or :error
  # @return [Integer] the number of characters logged
  def self.log_exception_backtrace(exception, line_number_limit=nil, log_mode: :error)
    ExceptionHelper.log_memory_state(log_mode: log_mode)
    curr_line_no=0
    output = ''
    exception.backtrace.each do |bt|
      output << "#{bt}\n" if line_number_limit.nil? || curr_line_no < line_number_limit # report First x lines of stacktrace in log
      curr_line_no += 1
    end
    output << "--- end of stacktrace ---\n\n\n"
    Rails.logger.send(log_mode, 'ExceptionHelper.log_exception_backtrace') { "Stack-Trace for #{exception.class}:\n#{output}" }
  end

  # Raise an exception with original backtrace but extended message
  # @param [Exception] exception: Original catched exception
  # @param [String] msg: Message to add to original exception
  # @param [String] log_location: Location info for error logging. Log error only if != nil
  # @return: nothing, raises exception
  def self.reraise_extended_exception(exception, msg, log_location: nil)
    msg = "#{exception.class}:#{exception.message} : #{msg}"
    Rails.logger.error(log_location) { msg } unless log_location.nil?
    new_ex = Exception.new(msg)
    new_ex.set_backtrace(exception.backtrace)
    raise new_ex
  end

  def self.memory_info_hash
    gb = (1024 * 1024 * 1024).to_f

    meminfo = {}
    case RbConfig::CONFIG['host_os']
    when 'linux' then
      meminfo[:total_memory]      = { name: 'Total OS Memory (GB)',      value: gb_value_for_linux('MemTotal') }
      meminfo[:available_memory]  = { name: 'Available OS Memory (GB)',  value: gb_value_for_linux('MemAvailable') }   # Real avail. mem. for application. Max-OS: phys. mem. used to ensure valid test becaus real mem avail is not available
      meminfo[:free_memory]       = { name: 'Free Memory OS (GB)',       value: gb_value_for_linux('MemFree') }   # free mem. may be much smaller than real avail. mem. for app.
      meminfo[:total_swap]        = { name: 'Total OS Swap (GB)',        value: gb_value_for_linux('SwapTotal') }
      meminfo[:free_swap]         = { name: 'Free OS Swap (GB)',         value: gb_value_for_linux('SwapFree') }
    when 'darwin' then
      meminfo[:total_memory]      = { name: 'Total OS Memory (GB)',      value: gb_value_for_darwin('hw.memsize') }
      meminfo[:free_memory]       = { name: 'Free Memory OS (GB)',       value: gb_value_for_darwin('page_free_count') }   # free mem. may be much smaller than real avail. mem. for app.
      meminfo[:total_swap]        = { name: 'Total OS Swap (GB)',        value: gb_value_for_darwin('vm.swapusage', 'SwapTotal') }
      meminfo[:free_swap]         = { name: 'Free OS Swap (GB)',         value: gb_value_for_darwin('vm.swapusage', 'SwapFree') }
    when 'mingw32', 'mingw64', 'mswin32', 'mswin64' then
      begin
        mem_bytes = `wmic memorychip get capacity`.split("\n")[1].to_i
        meminfo[:total_memory]      = { name: 'Total OS Memory (GB)',      value: (mem_bytes/gb).round(3) }
      rescue Exception => e
        Rails.logger.error('ExceptionHelper.memory_info_hash') { "Error #{e.class}:#{e.message} while getting total_memory" }
      end
      begin
        mem_bytes = `wmic OS get FreePhysicalMemory`.split("\n")[1].to_i
        meminfo[:free_memory]      = { name: 'Free Memory OS (GB)',      value: (mem_bytes/gb).round(3) }
      rescue Exception => e
        Rails.logger.error('ExceptionHelper.memory_info_hash') { "Error #{e.class}:#{e.message} while getting free_memory" }
      end
    end

    # Now add Java values
    memoryBean = java.lang.management.ManagementFactory.getMemoryMXBean
    meminfo[:initial_java_heap] = { name: 'Initial Java Heap (GB)',    value: (memoryBean.getHeapMemoryUsage.getInit/gb).round(3) }
    meminfo[:maximum_java_heap] = { name: 'Maximum Java Heap (GB)',    value: (memoryBean.getHeapMemoryUsage.getMax/gb).round(3) }
    meminfo
  end

  def self.log_memory_state(log_mode: :info)
    raise "ExceptionHelper.log_memory_state: log_mode '#{log_mode}' is not supported" unless [:debug, :info, :warn, :error].include? log_mode
    Rails.logger.send(log_mode, "Memory resources:")
    memory_info_hash.each do |key, value|
      Rails.logger.send(log_mode, "#{value[:name].ljust(25)}: #{value[:value]}")
    end
  end

  private

  # get Value from proc file system
  def self.gb_value_for_linux(key)
    cmd = "cat /proc/meminfo 2>/dev/null | grep #{key}"
    output = %x[ #{cmd} ]                                                       # skip_brakeman_check for possible command injection
    (output.split(' ')[1].to_f/(1024*1024)).round(3) if output[key]
  end

  def self.gb_value_for_darwin(key_darwin, swap_key = nil)
    retval = nil
    cmd = "sysctl -a | grep '#{key_darwin}'"
    output = %x[ #{cmd} ]                                                       # skip_brakeman_check for possible command injection
    if output[key_darwin]                                                       # anything found?
      if key_darwin == 'vm.swapusage'
        case swap_key
        when 'SwapTotal' then
          retval = (output.split(' ')[3].to_f / 1024).round(3)
        when 'SwapFree' then
          retval = (output.split(' ')[9].to_f / 1024).round(3)
        end
      else
        page_multitplier = 1                                                  # bytes
        page_multitplier= 4096 if output['vm.page']                           # pages
        retval = (output.split(' ')[1].to_f * page_multitplier / (1024*1024*1024)).round(3)
      end
    end
    retval
  end

end

