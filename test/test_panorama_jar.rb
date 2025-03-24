# Test the Panorama jar file
# Should be started in RAILS_ROOT directory

require 'open3'
require 'net/http'
require 'uri'

def log_output(stdout, stderr)
  puts "===== stdout of Panorama.jar ====="
  stdout.each_line do |line|
    puts line
  end
  puts "===== stderr of Panorama.jar ====="
  stderr.each_line do |line|
    puts line
  end
end

retcode = 0
begin

  # Raise error if file does not exist
  unless File.exist?('Panorama.jar')
    raise "Panorama.jar does not exist in #{Dir.pwd}"
  end

  # Ensure that envirnment does not contain any GEM_HOME or GEM_PATH etc.
  ENV.delete('BUNDLE_BIN_PATH')
  ENV.delete('BUNDLE_GEMFILE')
  ENV.delete('BUNDLER_SETUP')
  ENV.delete('BUNDLER_VERSION')
  ENV.delete('GEM_HOME')
  ENV.delete('GEM_PATH')
  ENV.delete('RUBYLIB')
  ENV.delete('RUBYOPT')
  # Start Panorama.jar in background
  stdin, stdout, stderr, thread = Open3.popen3(ENV, 'java -jar Panorama.jar')

  puts "Waiting for InitializationJob to be performed"
  max_wait = 60
  loops = 0

  break_outer = false
  while loops < max_wait
    if stdout.closed?
      puts "stdout closed"
    else
      stdout.each_line do |line|
        if line['Performed InitializationJob']
          break_outer = true
          break
        end
      end
    end
    break if break_outer
    loops += 1
    print '.'
    sleep 1
  end

  if loops == max_wait
    raise "InitializationJob not finished after #{max_wait} seconds"
  else
    puts "InitializationJob finished after #{loops} seconds"
  end

  response = nil
  puts "Waiting for access to port 8080 now"
  loops = 0
  while loops < max_wait
    uri = URI.parse('http://localhost:8080/')

    begin
      response = Net::HTTP.get_response(uri)
       # Check if the response is successful (status code 200)
      break if response.is_a?(Net::HTTPSuccess)
    rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    end

    loops += 1
    print '.'
    sleep 1
  end

  if loops == max_wait
    raise "No access to port 8080 after #{max_wait} seconds"
  else
    puts "Access to port 8080 after #{loops} seconds"
  end

  # Check the content
  raise "Response should contain 'Please choose saved connection'" unless response.body['Please choose saved connection']

rescue Exception => e
  puts "Error: #{e.message}"
  retcode = 1
ensure
  # Terminate the java process
  Process.kill('KILL', thread.pid)
  log_output(stdout, stderr)
  stdin.close
  stdout.close
  stderr.close
  puts "Test finished"
end


exit retcode