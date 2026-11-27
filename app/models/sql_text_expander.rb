# Expand SQL statements by replacing the accessed views with their SQL text
class SqlTextExpander
  MAX_DEPTH = 20                                                                # Maximum nesting level of views to expand

  # Expand a SQL statement by DBMS_UTILITY.expand_sql_text
  # If DBMS_UTILITY.expand_sql_text fails with any error (e.g. ORA-24256 because of missing privileges or not existing objects)
  # then the own implementation by IslandSQL parser is used, that replaces synonyms and views as far as possible
  # Unqualified object names are resolved in the schema of the current Panorama user by DBMS_UTILITY.expand_sql_text
  # @param [String] sql_text The SQL statement to expand
  # @param [String] parsing_schema Schema for resolution of unqualified object names in own implementation, default is current schema
  # @return [String] The expanded SQL statement, nil if sql_text is nil
  def self.expand(sql_text, parsing_schema: nil)
    return nil if sql_text.nil?
    begin
      expand_by_dbms_utility(sql_text)
    rescue Exception => e
      Rails.logger.info('SqlTextExpander.expand') { "DBMS_UTILITY.expand_sql_text failed, using own implementation instead: #{e.message[/ORA-\d+.*/] || e.message.lines.first}" }
      parsing_schema ||= PanoramaConnection.sql_select_one "SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') FROM DUAL"
      new.expand_by_parser(sql_text, parsing_schema)
    end
  end

  def self.expand_by_dbms_utility(sql_text)
    PanoramaConnection.sql_select_one ["\
      WITH
        FUNCTION Expand(p_Org_SQL CLOB) RETURN CLOB
        IS
        v_Expanded_SQL CLOB;
        BEGIN
          DBMS_UTILITY.expand_sql_text(input_sql_text => p_Org_SQL, output_sql_text => v_Expanded_SQL);
          RETURN v_Expanded_SQL;
        END;
      SELECT Expand(?) FROM DUAL", sql_text]
  end

  def initialize
    @objects = {}                                                               # Cache for resolved objects, key = [owner, name, explicit_owner]
  end

  # Replace synonyms by the referenced object and views by their SQL text in parentheses, recursive for nested views
  # @param [String] sql_text The SQL statement to expand
  # @param [String] schema Schema for resolution of unqualified object names
  # @param [Array] path Views that are currently expanded ("OWNER.NAME") to detect circular references
  # @return [String] The expanded SQL statement
  def expand_by_parser(sql_text, schema, path = [])
    IslandSql.load_jars
    parser_class = Java::ChIslandsqlGrammar::IslandSqlParser
    doc = Java::ChIslandsqlGrammar::IslandSqlDocument::Builder.new
            .sql(sql_text)
            .dialect(Java::ChIslandsqlGrammar::IslandSqlDialect::ORACLEDB)
            .build

    ctes  = []                                                                  # Names of WITH clause elements, they are not resolved as objects
    qtes  = []
    find_contexts(doc.getFile) do |ctx|
      ctes << normalize_name(ctx.getChild(0).getText) if ctx.is_a?(parser_class::SubqueryFactoringClauseContext)
      qtes << ctx                                     if ctx.is_a?(parser_class::QueryTableExpressionContext)
    end

    replacements = []                                                           # [start char index, end char index (exclusive), new text]
    qtes.each do |qte|
      names = object_name_children(qte, parser_class)
      next if names.nil?
      owner = names.count == 2 ? normalize_name(names[0].getText) : nil
      name  = normalize_name(names.last.getText)
      next if owner.nil? && ctes.include?(name)

      new_text = replacement_text(owner || schema, name, !owner.nil?, path)
      next if new_text.nil?
      replacements << [names.first.getStart.getStartIndex, names.last.getStop.getStopIndex + 1, new_text]

      # Keep the original name as alias, because the columns may be qualified by the name
      table_reference = qte.getParent
      from_item       = table_reference.getParent
      unless (0...from_item.getChildCount).any? { |i| from_item.getChild(i).is_a?(parser_class::TableAliasContext) }
        replacements << [table_reference.getStop.getStopIndex + 1, table_reference.getStop.getStopIndex + 1, " #{names.last.getText}"]
      end
    end

    result = sql_text.dup
    replacements.sort_by { |r| -r[0] }.each { |from, to, text| result[from...to] = text }
    result
  end

  private

  # Call block for ctx and all descendants
  def find_contexts(ctx, &block)
    return unless ctx.is_a?(org.antlr.v4.runtime.ParserRuleContext)
    block.call(ctx)
    (0...ctx.getChildCount).each { |i| find_contexts(ctx.getChild(i), &block) }
  end

  # Get the SqlName contexts of [owner.]name if the query table expression references a local object
  # @return [Array] SqlName contexts or nil if not a simple object reference (inline view, table function, DB link ...)
  def object_name_children(qte, parser_class)
    return nil unless qte.getParent.is_a?(parser_class::TableReferenceContext) && qte.getParent.getParent.is_a?(parser_class::TableReferenceFromItemContext)
    return nil if qte.COMMAT                                                    # @db_link
    children = (0...qte.getChildCount).map { |i| qte.getChild(i) }
    names = [children[0]]
    names << children[2] if children[1]&.getText == '.' && children[2].is_a?(parser_class::SqlNameContext)
    return nil unless names.all? { |n| n.is_a?(parser_class::SqlNameContext) }
    names
  end

  # Text that replaces the object reference
  # @return [String] the referenced object for synonyms, the view text in parentheses for views, nil if nothing to replace
  def replacement_text(owner, name, explicit_owner, path)
    text    = nil
    visited = []
    obj     = resolve(owner, name, explicit_owner)
    while obj
      key = "#{obj[:owner]}.#{obj[:name]}"
      return text if path.include?(key) || visited.include?(key)               # Circular reference, stop expanding
      visited << key
      case obj[:type]
      when 'SYNONYM'
        text = "#{quote_name(obj[:table_owner])}.#{quote_name(obj[:table_name])}"
        return "#{text}@#{obj[:db_link]}" if obj[:db_link]                     # Remote objects are not expanded
        obj = resolve(obj[:table_owner], obj[:table_name], true)
      when 'VIEW'
        return text if path.count + visited.count > MAX_DEPTH
        view_text = view_text(obj[:owner], obj[:name])
        return text if view_text.nil?
        return "(#{expand_by_parser(view_text.strip, obj[:owner], path + visited)})"
      else
        return text
      end
    end
    text
  end

  # Find the object for a name like Oracle does: object in schema, for unqualified names then public synonym
  # @return [Hash] { owner:, name:, type:, table_owner:, table_name:, db_link: } or nil if no synonym or view
  def resolve(owner, name, explicit_owner)
    key = [owner, name, explicit_owner]
    return @objects[key] if @objects.key?(key)

    @objects[key] = nil
    # Fixed views like V$SESSION are used by SYS views without being listed in DBA_Objects
    return nil if owner == 'SYS' && PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM V$Fixed_Table WHERE Name = ?", name]) > 0

    obj = PanoramaConnection.sql_select_first_row ["\
      SELECT Owner, Object_Type
      FROM   DBA_Objects
      WHERE  Object_Name = ?
      AND    Namespace   = 1
      AND    (Owner = ? OR (Owner = 'PUBLIC' AND ? = 'N'))
      ORDER BY DECODE(Owner, 'PUBLIC', 2, 1)
      ", name, owner, explicit_owner ? 'Y' : 'N']
    return nil if obj.nil?

    case obj['object_type']
    when 'SYNONYM'
      syn = PanoramaConnection.sql_select_first_row ["SELECT Table_Owner, Table_Name, DB_Link FROM DBA_Synonyms WHERE Owner = ? AND Synonym_Name = ?", obj['owner'], name]
      return nil if syn.nil? || syn['table_owner'].nil?
      @objects[key] = { owner: obj['owner'], name: name, type: 'SYNONYM', table_owner: syn['table_owner'], table_name: syn['table_name'], db_link: syn['db_link'] }
    when 'VIEW'
      @objects[key] = { owner: obj['owner'], name: name, type: 'VIEW' }
    end
  end

  # Oracle maintained views may have no Text but only Text_VC, which is truncated at 4000 characters
  # @return [String] the view text or nil if not available
  def view_text(owner, view_name)
    view = PanoramaConnection.sql_select_first_row ["SELECT Text, Text_VC, Text_Length FROM DBA_Views WHERE Owner = ? AND View_Name = ?", owner, view_name]
    return nil if view.nil?
    return view['text'] unless view['text'].nil? || view['text'].empty?
    return view['text_vc'] if view['text_length'] && view['text_length'] <= 4000  # Text_VC is complete
    nil
  end

  # Name as stored in the data dictionary
  def normalize_name(name)
    name.start_with?('"') ? name[1..-2] : name.upcase
  end

  # Name as usable in SQL
  def quote_name(name)
    name.match?(/\A[A-Z][A-Z0-9_$#]*\z/) ? name : "\"#{name}\""
  end
end
