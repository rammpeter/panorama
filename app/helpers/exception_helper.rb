# Check source auf autoloading if "DEPRECATION WARNING: Initialization autoloaded the constant " occurs
# puts "#####################################"
# pp caller_locations.select { |l| l.to_s.index("config/init") }

module ExceptionHelper

  def log_exception_backtrace(exception, line_number_limit=nil)
    ExceptionHelper.log_memory_state(log_mode: :error)
    curr_line_no=0
    output = ''
    exception.backtrace.each do |bt|
      output << "#{bt}\n" if line_number_limit.nil? || curr_line_no < line_number_limit # report First x lines of stacktrace in log
      curr_line_no += 1
    end

    Rails.logger.error('ExceptionHelper.log_exception_backtrace') { "Stack-Trace for #{exception.class}:\n#{output}" }
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
    memoryBean = java.lang.management.ManagementFactory.getMemoryMXBean
    gb = (1024 * 1024 * 1024).to_f
    {
      total_memory:       { name: 'Total OS Memory (GB)',      value: gb_value_from_proc('MemTotal',      'hw.memsize') },
      available_memory:   { name: 'Available OS Memory (GB)',  value: gb_value_from_proc('MemAvailable',  'hw.memsize') },   # Real avail. mem. for application. Max-OS: phys. mem. used to ensure valid test becaus real mem avail is not available
      free_memory:        { name: 'Free Memory OS (GB)',       value: gb_value_from_proc('MemFree',       'page_free_count') },   # free mem. may be much smaller than real avail. mem. for app.
      total_swap:         { name: 'Total OS Swap (GB)',        value: gb_value_from_proc('SwapTotal',     'vm.swapusage') },
      free_swap:          { name: 'Free OS Swap (GB)',         value: gb_value_from_proc('SwapFree',      'vm.swapusage') },
      initial_java_heap:  { name: 'Initial Java Heap (GB)',    value: (memoryBean.getHeapMemoryUsage.getInit/gb).round(3) },
      maximum_java_heap:  { name: 'Maximum Java Heap (GB)',    value: (memoryBean.getHeapMemoryUsage.getMax/gb).round(3) },
    }
  end

  def self.log_memory_state(log_mode: :info)
    raise "ExceptionHelper.log_memory_state: log_mode '#{log_mode}' is not supported" unless [:info, :error].include? log_mode
    Rails.logger.send(log_mode, "Memory resources:")
    memory_info_hash.each do |key, value|
      Rails.logger.send(log_mode, "#{value[:name].ljust(25)}: #{value[:value]}")
    end
  end

  private
  def self.gb_value_from_proc(key_linux, key_darwin)
    retval = nil
    case RbConfig::CONFIG['host_os']
    when 'linux' then
      cmd = "cat /proc/meminfo 2>/dev/null | grep #{key_linux}"
      output = %x[ #{cmd} ]
      retval = (output.split(' ')[1].to_f/(1024*1024)).round(3) if output[key_linux]
    when 'darwin' then
      cmd = "sysctl -a | grep '#{key_darwin}'"
      output = %x[ #{cmd} ]
      if output[key_darwin]                                                     # anything found?
        if key_darwin == 'vm.swapusage'
          case key_linux
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
    else
      0                                                                         # unknown OS
    end
    retval
  end

end

