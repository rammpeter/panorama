# Test the Panorama jar file
# Should be started in RAILS_ROOT directory

# Raise error if file does not exist
unless File.exist?('Panorama.jar')
  puts "Panorama.jar does not exist in #{Dir.pwd}"
  exit 1
end

# Start Panorama.jar in background
system('java -jar Panorama.jar > panorama.log 2>&1 &')

puts "Waiting for InitializationJob to be performed"
max_wait = 120
loops = 0

while loops < max_wait
  retval = system('grep "Performed InitializationJob" panorama.log > /dev/null')
  break if retval

  loops += 1
  print '.'
  sleep 1
end

if loops == max_wait
  puts "InitializationJob not finished after #{max_wait} seconds"
  puts "===== log output from Panorama.jar ====="
  puts File.read('panorama.log')
  exit 1
else
  puts "InitializationJob finished after #{loops} seconds"
end

loops = 0
while loops < max_wait
  retval = system('curl http://localhost:8080/ > /dev/null 2> /dev/null')
  break if retval

  loops += 1
  print '.'
  sleep 1
end

if loops == max_wait
  puts "No access to port 8080 after #{max_wait} seconds"
  puts "===== log output from Panorama.jar ====="
  puts File.read('panorama.log')
  exit 1
else
  puts "Access to port 8080 after #{loops} seconds"
end

# Check the content