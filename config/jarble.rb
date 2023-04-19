# Jarbler configuration, see https://github.com/rammpeter/jarbler
# values in comments are the default values
# uncomment and adjust if needed

Jarbler::Config.new do |config|
  # Name of the generated jar file 
  # config.jar_name = 'Panorama.jar'
 
  # Application directories or files to include in the jar file
  # config.includes = ["app", "bin", "config", "config.ru", "db", "Gemfile", "Gemfile.lock", "lib", "log", "script", "vendor", "tmp"]
 
  # Application directories or files to exclude from the jar file
  # config.excludes = []

  # The network port used by the application
  config.port = 8080
 
end
