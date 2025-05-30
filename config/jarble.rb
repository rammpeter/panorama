# Jarbler configuration, see https://github.com/rammpeter/jarbler
# values in comments are the default values
# uncomment and adjust if needed

Jarbler::Config.new do |config|
  config.compile_ruby_files = false

  # Name of the generated jar file 
  config.jar_name = 'Panorama.jar'

  # Compile JarMain class so that the resulting Panorama.jar is compatible with Java 8 and above
  # Works only up to JRuby < 10.0.0.0 which requires Java 21 or above
  config.java_opts = '-source 1.8 -target 1.8'

  # Application directories or files to include in the jar file
  # config.includes = ["app", "bin", "config", "config.ru", "db", "Gemfile", "Gemfile.lock", "lib", "log", "public", "script", "vendor", "tmp"]
  # config.includes << "additional"

  # Application directories or files to exclude from the jar file
  # config.excludes = ["tmp/cache", "tmp/pids", "tmp/sockets", "vendor/bundle", "vendor/cache", "vendor/ruby"]
  # vendor/assets is not needed because duplicate in public
  config.excludes << 'vendor'

  # jRuby version to use if not the latest or the version from .ruby-version is used
  # config.jruby_version = "9.2.3.0"
  # config.jruby_version = ''

end
