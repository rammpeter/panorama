# hold open SQL-Cursor and iterate over SQL-result without storing whole result in Array
# Peter Ramm, 02.03.2016

# expand class by getter to allow access on internal variable @raw_statement
ActiveRecord::ConnectionAdapters::OracleEnhancedJDBCConnection::Cursor.class_eval do
  def get_raw_statement
    @raw_statement
  end
end

# Class extension by Module-Declaration : module ActiveRecord, module ConnectionAdapters, module OracleEnhancedDatabaseStatements
# does not work as Engine with Winstone application server, therefore hard manipulation of class ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
# and extension with method iterate_query

ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do

  # Method comparable with ActiveRecord::ConnectionAdapters::OracleEnhancedDatabaseStatements.exec_query,
  # but without storing whole result in memory
  def iterate_query(sql, name = 'SQL', binds = [], modifier = nil, query_timeout = nil, &block)
    type_casted_binds = binds.map { |col, val|
      [col, type_cast(val, col)]
    }
    log(sql, name, type_casted_binds) do
      cursor = nil
      cached = false
      if without_prepared_statement?(binds)
        cursor = @connection.prepare(sql)
      else
        unless @statements.key? sql
          @statements[sql] = @connection.prepare(sql)
        end

        cursor = @statements[sql]

        binds.each_with_index do |bind, i|
          col, val = bind
          cursor.bind_param(i + 1, type_cast(val, col), col)
        end

        cached = true
      end

      cursor.get_raw_statement.setQueryTimeout(query_timeout) if query_timeout

      cursor.exec

      if name == 'EXPLAIN' and sql =~ /^EXPLAIN/
        res = true
      else
        columns = cursor.get_col_names.map do |col_name|
          @connection.oracle_downcase(col_name).freeze
        end
        fetch_options = {:get_lob_value => (name != 'Writable Large Object')}
        while row = cursor.fetch(fetch_options)
          result_hash = {}
          columns.each_index do |index|
            result_hash[columns[index]] = row[index]
            row[index] = row[index].strip if row[index].class == String   # Remove possible 0x00 at end of string, this leads to error in Internet Explorer
          end
          result_hash.extend SelectHashHelper
          modifier.call(result_hash)  unless modifier.nil?
          yield result_hash
        end
      end

      cursor.close unless cached
      nil
    end
  end #iterate_query


end #class_eval




class SqlSelectIterator

  def initialize(stmt, binds, modifier, query_timeout, query_name = 'SqlSelectIterator')
    @stmt           = stmt
    @binds          = binds
    @modifier       = modifier              # proc for modifikation of record
    @query_timeout  = query_timeout
    @query_name     = query_name
  end

  def each(&block)
    # Execute SQL and call block for every record of result
    ConnectionHolder.connection.iterate_query(@stmt, @query_name, @binds, @modifier, @query_timeout, &block)
  rescue Exception => e
    bind_text = ''
    @binds.each do |b|
      bind_text << "#{b[0].name} = #{b[1]}\n"
    end

    # Ensure stacktrace of first exception is show
    new_ex = Exception.new("Error while executing SQL:\n\n#{e.message}\n\n#{bind_text.length > 0 ? "Bind-Values:\n#{bind_text}" : ''}")
    new_ex.set_backtrace(e.backtrace)
    raise new_ex
  end

end
