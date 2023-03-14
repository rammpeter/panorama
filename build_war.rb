require 'zip'

Zip::File.open('Panorama.war', Zip::File::CREATE) do |zipfile|
  # Add files to the war file
  zipfile.add('index.html', 'path/to/index.html')
  zipfile.add('WEB-INF/web.xml', 'path/to/web.xml')
  zipfile.add('WEB-INF/lib/jruby.jar', 'path/to/jruby.jar')
  # ...
end