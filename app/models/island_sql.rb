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

  # Parse a SQL text
  # @param sql_text [String] the SQL text to parse
  # @return [Hash] { dot: String with the parse tree in DOT notation, syntax_errors: Array of Hash with :line, :column, :message }
  def self.parse_tree_as_dot(sql_text)
    load_jars
    doc = Java::ChIslandsqlGrammar::IslandSqlDocument::Builder.new
            .sql(sql_text)
            .dialect(Java::ChIslandsqlGrammar::IslandSqlDialect::ORACLEDB)
            .build
    {
      dot:           Java::ChIslandsqlGrammarUtil::ParseTreeUtil.dotParseTree(doc.getFile),
      syntax_errors: doc.getSyntaxErrors.map { |e| { line: e.getLine, column: e.getCharPositionInLine, message: e.getMessage } }
    }
  end
end
