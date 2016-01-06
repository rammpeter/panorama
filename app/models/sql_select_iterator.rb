# Halten eines SQL-Cursors und iterieren durch Result


module ActiveRecord
  module ConnectionAdapters
    module OracleEnhancedDatabaseStatements
      # Analoge Methode zu ActiveRecord::ConnectionAdapters::OracleEnhancedDatabaseStatements.exec_query,
      # jedoch ohne Speicherung des kompletten Results
      def iterate_query(sql, name = 'SQL', binds = [], modifier = nil, &block)
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
                row[index] = row[index].strip if row[index].class == String   # Entfernen eines eventuellen 0x00 am Ende des Strings, dies führt zu Fehlern im Internet Explorer
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
    end
  end
end



class SqlSelectIterator
  #self.table_name   =  "DUAL"         # falls irgendwo die Struktur der zugehörigen Tabelle ermittelt werden soll
  #self.primary_key  = "id"            # Festes übersteuern, da DUAL keine Info zum Primary Key liefert

  def initialize(stmt, binds, modifier)
    @stmt     = stmt
    @binds    = binds
    @modifier = modifier              # proc zur Modifikation eines Records
  end

  def each(&block)
    # Erweitern OracleEnhancedAdapter um Methode iterate_query wenn notwendig
    adapter = ConnectionHolder.connection()

    unless adapter.methods.include?('iterate_query')
      adapter.extend ActiveRecord::ConnectionAdapters::OracleEnhancedDatabaseStatements
    end

    # Ausführen SQL und Aufrufen Block für jeden Record des Results
    result = adapter.iterate_query(@stmt, 'sql_select_iterator', @binds, @modifier, &block)
  end

end
