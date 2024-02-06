class UsageInfo

  # Write usage info to file
  # @param request [ActionDispatch::Request] The request object
  # @param real_controller_name [String] The controller name
  # @param real_action_name [String] The action name
  # @param tns [String] The TNS name
  # @return [void]
  def self.write_record(request, real_controller_name, real_action_name, tns)
    return if Panorama::Application.config.usage_info_max_age == 0
    # Ausgabe Logging-Info in File für Usage-Auswertung
    filename = Panorama::Application.config.usage_info_filename
    client_ip = request.remote_ip
    client_ip = 'localhost'                       if request.remote_ip.nil?
    client_ip = request.env['HTTP_X_REAL_IP']     if request.env['HTTP_X_REAL_IP'] # original address behind reverse proxy

    File.open(filename, 'a') { |file| file.write("#{client_ip} #{PanoramaConnection.database_name} #{Time.now.year}/#{'%02d' % Time.now.month} #{real_controller_name} #{real_action_name} #{Time.now.strftime('%Y/%m/%d-%H:%M:%S')} #{tns}\n") }
  rescue Exception => e
    Rails.logger.warn('UsageInfo.write_record') { "#{e.class} while writing in #{filename}: #{e.message}" }
  end

  def self.file_for_read
    File.open(Panorama::Application.config.usage_info_filename, "r")
  rescue Exception => e
    Rails.logger.error('UsageController.fill_usage_info') { "Error opening file #{Panorama::Application.config.usage_info_filename}: #{e.message}. PWD = #{Dir.pwd}" }
    raise
  end

  def self.housekeeping
    filename = Panorama::Application.config.usage_info_filename
    temp_filename = filename + '.tmp'

    if File.exist?(filename)
      # Open the file in write mode with exclusive lock
      File.open(filename, 'r+') do |file|
        file.flock(File::LOCK_EX) # Acquire an exclusive lock

        FileUtils.cp(filename, temp_filename)                                     # create a copy of original file with full content

        # Truncate the original file
        file.rewind
        file.truncate(0)

        temp_file = File.open(temp_filename, 'r')
        begin
          min_age = DateTime.now - 180
          while true
            line = temp_file.readline
            begin
              date = DateTime.parse(line.split[5])
              file.puts(line) if date > min_age                                   # copy all lines from temp file to original file with younger date
            rescue Exception => e
              Rails.logger.error('UsageInfo.housekeeping') { "#{e.class}:#{e.message} while writing the following line in #{filename}: #{line}" }
            end
          end
        rescue EOFError
          temp_file.close
        end
      end
    else
      Rails.logger.warn('UsageInfo.housekeeping') { "File #{filename} does not exist" }
    end
  rescue RuntimeError => e
    Rails.logger.error('UsageInfo.housekeeping') { "#{e.class} while housekeeping #{filename}: #{e.message}" }
    raise
  rescue Exception => e
    Rails.logger.error('UsageInfo.housekeeping') { "#{e.class} while housekeeping #{filename}: #{e.message}" }
    raise
  ensure
    File.delete(temp_filename) if File.exist?(temp_filename)
  end
end