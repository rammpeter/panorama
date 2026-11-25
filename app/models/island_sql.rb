# Wrapper for the IslandSQL parser (https://github.com/IslandSQL/IslandSQL)
# The Java libraries are loaded lazily at first usage from lib/
class IslandSql
  JAR_FILES = %w[antlr4-runtime-4.13.2.jar islandsql-0.26.0.jar].freeze

  @load_mutex = Mutex.new
  @jars_loaded = false

  def self.load_jars
    @load_mutex.synchronize do
      return if @jars_loaded
      require 'java'
      JAR_FILES.each { |jar| require File.join(Rails.root, 'lib', jar) }
      @jars_loaded = true
    end
  end
end
