# Reduce the parse tree of a SQL statement (parsed by IslandSQL) to a Graphviz chart with
# - the used tables / views / inline views / CTEs as frames, grouped by query block
# - the attributes used in conditions as rows of these frames, together with their filter conditions
# - the join conditions as edges between the attributes of the tables
class SqlJoinGraph
  MAX_LABEL_LENGTH = 100
  COMPARISON_OPERATORS = %w[= <> != ^= < > <= >=].freeze
  PSEUDO_COLUMNS = %w[SYSDATE SYSTIMESTAMP CURRENT_DATE CURRENT_TIMESTAMP LOCALTIMESTAMP ROWNUM LEVEL USER UID NULL TRUE FALSE].freeze

  Block     = Struct.new(:id, :ctx, :parent, :role, :nodes, :filters, :link_node, :linked)
  Node      = Struct.new(:id, :block, :name, :alias, :kind, :attributes, :filters) # attributes: Hash normalized name => Attribute
  Attribute = Struct.new(:name, :port, :filters)
  ColumnRef = Struct.new(:node, :column)
  Condition = Struct.new(:ctx, :block, :source)                                 # source: :where, :on, :outer_on

  # @param sql_text [String] the SQL text
  # @return [Hash] { dot: String with the graph in DOT notation, syntax_errors: Array of Hash with :line, :column, :message }
  def self.build(sql_text, rankdir: 'LR')
    new(sql_text).to_dot(rankdir)
  end

  def initialize(sql_text)
    IslandSql.load_jars
    @parser_class = Java::ChIslandsqlGrammar::IslandSqlParser
    doc = Java::ChIslandsqlGrammar::IslandSqlDocument::Builder.new
            .sql(sql_text)
            .dialect(Java::ChIslandsqlGrammar::IslandSqlDialect::ORACLEDB)
            .build
    @syntax_errors = doc.getSyntaxErrors.map { |e| { line: e.getLine, column: e.getCharPositionInLine, message: e.getMessage } }
    @tokens     = doc.getTokenStream
    @blocks     = []
    @nodes      = []
    @conditions = []
    @usings     = []                                                            # [join clause ctx, block]
    @node_by_from_item = {}
    @edges      = {}

    walk(doc.getFile, nil, nil)                                                 # pass 1: collect query blocks, tables and conditions
    @conditions.each { |c| process_condition(c) }                               # pass 2: assign conditions to joins and filters
    @usings.each { |u| process_using(*u) }
    link_remaining_blocks
    order_attributes
  end

  def to_dot(rankdir)
    dot = String.new
    dot << "digraph sql {\n"
    dot << "  graph [rankdir=#{rankdir} compound=true bgcolor=lightyellow fontname=Helvetica fontsize=10];\n"
    dot << "  node [shape=plaintext fontname=Helvetica fontsize=10];\n"
    dot << "  edge [dir=none fontname=Helvetica fontsize=9];\n"
    @blocks.each do |b|
      dot << "  subgraph cluster_#{b.id} {\n"
      dot << "    style=\"rounded,filled\"; fillcolor=\"#fffbe0\"; color=gray;\n"
      dot << "    label=<#{cluster_label(b)}>;\n"
      b.nodes.each do |n|
        if n.kind == :condition
          dot << "    #{n.id} [shape=box style=\"rounded,filled\" fillcolor=white fontsize=9 label=\"#{dot_escape(truncate(n.name))}\" tooltip=\"#{dot_escape(n.name)}\"];\n"
        else
          dot << "    #{n.id} [label=<#{node_label(n)}>];\n"
        end
      end
      dot << "  }\n"
    end
    @edges.each_value do |e|
      attribs = []
      unless e[:labels].empty?
        attribs << "label=\"#{dot_escape(e[:labels].map { |l| truncate(l) }.join("\n"))}\""
        attribs << "tooltip=\"#{dot_escape(e[:labels].join("\n"))}\""
      end
      attribs << 'style=dashed'                 if e[:outer]
      attribs << 'style=dotted dir=forward'     if e[:kind] == :link
      attribs << "ltail=cluster_#{e[:ltail]}"   if e[:ltail]
      dot << "  #{e[:from]} -> #{e[:to]} [#{attribs.join(' ')}];\n"
    end
    dot << "}\n"
    { dot: dot, syntax_errors: @syntax_errors }
  end

  private

  def walk(ctx, block, link_node)
    case ctx
    when @parser_class::QueryBlockContext
      block = new_block(ctx, block, link_node)
      link_node = nil
    when @parser_class::TableReferenceFromItemContext
      node = new_node(ctx, block)
      link_node = node if node.kind == :inline_view                            # the query blocks inside define this inline view
    when @parser_class::WhereClauseContext
      cond = first_rule_child(ctx)
      @conditions << Condition.new(cond, block, :where) if cond
    when @parser_class::InnerCrossJoinClauseContext, @parser_class::OuterJoinClauseContext
      source = ctx.is_a?(@parser_class::OuterJoinClauseContext) ? :outer_on : :on
      @conditions << Condition.new(ctx.cond, block, source) if ctx.cond
      @usings << [ctx, block] if ctx.K_USING
    end

    (0...ctx.getChildCount).each do |i|
      child = ctx.getChild(i)
      walk(child, block, link_node) if child.is_a?(org.antlr.v4.runtime.ParserRuleContext)
    end
  end

  def new_block(ctx, parent, link_node)
    b = Block.new("b#{@blocks.count + 1}", ctx, parent, block_role(ctx, parent), [], [], link_node, false)
    @blocks << b
    b
  end

  # Describe the role of the query block by its position in the parse tree
  def block_role(ctx, parent)
    role = nil
    set_operation = ctx.getParent&.getParent.is_a?(@parser_class::SetSubqueryContext) # queryBlock -> queryBlockSubquery -> setSubquery
    p = ctx.getParent
    while p && !p.is_a?(@parser_class::QueryBlockContext)
      case p
      when @parser_class::SubqueryFactoringClauseContext then role ||= "WITH #{token_text(first_rule_child(p))}"
      when @parser_class::QueryTableExpressionContext then role ||= 'Inline view'
      when @parser_class::SelectListContext then role ||= 'Scalar subquery in SELECT list'
      when @parser_class::WhereClauseContext then role ||= 'Subquery in WHERE'
      when @parser_class::InnerCrossJoinClauseContext, @parser_class::OuterJoinClauseContext then role ||= 'Subquery in ON'
      end
      p = p.getParent
    end
    role ||= parent.nil? ? 'Main query' : 'Subquery'
    role += ' (set operation branch)' if set_operation
    role
  end

  def new_node(ctx, block, kind: nil, name: nil)
    if ctx
      qte       = find_descendant(ctx, @parser_class::QueryTableExpressionContext)
      tab_alias = find_child(ctx, @parser_class::TableAliasContext)
      kind      = qte && find_descendant(qte, @parser_class::QueryBlockContext) ? :inline_view : :table
      name      = kind == :inline_view ? 'inline view' : token_text(qte || ctx)
    end
    node = Node.new("n#{@nodes.count + 1}", block, name, tab_alias ? token_text(tab_alias) : nil, kind, {}, [])
    @nodes << node
    block&.nodes&.<< node
    @node_by_from_item[ctx] = node if ctx
    node
  end

  # Split a condition into its AND-connected parts and assign them to joins or filters
  def process_condition(cond)
    nested_blocks = @blocks.select { |b| b.parent == cond.block && inside?(b.ctx, cond.ctx) }
    split_conjuncts(cond.ctx.getStart.getTokenIndex, cond.ctx.getStop.getTokenIndex).each do |from_idx, to_idx|
      nested = nested_blocks.select { |b| b.ctx.getStart.getTokenIndex >= from_idx && b.ctx.getStop.getTokenIndex <= to_idx }
      text   = conjunct_text(from_idx, to_idx, nested)
      refs   = column_refs(from_idx, to_idx, nested, cond.block)
      nodes  = refs.map(&:node).uniq
      suffix = cond.source == :where ? '' : ' (ON)'                            # filter in ON clause of a join

      if !nested.empty?                                                         # condition with subquery like EXISTS or IN (SELECT ...)
        targets = refs.empty? ? [anchor_node(cond.block).id] : refs.map { |r| endpoint(r) }.uniq
        nested.each do |nb|
          targets.each { |t| add_edge(anchor_node(nb).id, t, :link, text, ltail: nb.id) }
          nb.linked = true
        end
      elsif nodes.count >= 2                                                    # join condition
        outer = cond.source == :outer_on || text['(+)']
        simple = simple_comparison(from_idx, to_idx, cond.block)
        if simple
          add_edge(endpoint(simple[0]), endpoint(simple[2]), :join, simple[1], outer: outer)
        else                                                                    # complex condition: own node connected with all attributes
          cond_node = new_node(nil, cond.block, kind: :condition, name: text)
          refs.each { |r| add_edge(endpoint(r), cond_node.id, :join, nil, outer: outer) }
        end
      elsif nodes.count == 1                                                    # filter condition for one table
        node = nodes[0]
        node_text = strip_qualifiers(text, node)
        columns = refs.map(&:column).uniq { |c| normalize(c) }
        if columns.count == 1
          attribute(node, columns[0]).filters << without_leading_column(node_text, columns[0]) + suffix
        else
          node.filters << node_text + suffix
        end
      elsif cond.block
        cond.block.filters << text + suffix
      end
    end
  end

  # Join with USING (columns): connect the column of the joined item with the first table of the left side of the join
  def process_using(join_ctx, _block)
    right = @node_by_from_item[join_ctx.fromItem]
    join_clause = join_ctx.getParent
    join_clause = join_clause.getParent until join_clause.nil? || join_clause.is_a?(@parser_class::JoinClauseContext)
    left_item = join_clause && find_descendant(join_clause, @parser_class::TableReferenceFromItemContext)
    left = left_item && @node_by_from_item[left_item]
    return unless left && right && left != right
    join_ctx.qualifiedName.each do |q|
      column = token_text(q)
      add_edge(endpoint(ColumnRef.new(left, column)), endpoint(ColumnRef.new(right, column)), :join, 'USING',
               outer: join_ctx.is_a?(@parser_class::OuterJoinClauseContext))
    end
  end

  # Order the attribute rows of the tables to avoid crossing edges (barycenter heuristic):
  # Each attribute is sorted by the average relative position of the attributes it is connected to.
  # Repeated several times, so that attributes joined between two tables get the same order on both sides.
  # Graphviz considers the order of ports when arranging the nodes.
  def order_attributes
    neighbors = Hash.new { |h, k| h[k] = [] }                                   # endpoint => connected endpoints
    @edges.each_value do |e|
      neighbors[e[:from]] << e[:to]
      neighbors[e[:to]] << e[:from]
    end

    nodes_by_id = @nodes.to_h { |n| [n.id, n] }
    # Relative position 0..1 of an attribute row within its table
    port_position = lambda do |endpoint|
      node_id, port = endpoint.split(':')
      ports = nodes_by_id[node_id].attributes.values.map(&:port)
      (ports.index(port) + 0.5) / ports.count
    end
    position = lambda do |endpoint|
      if endpoint[':']
        port_position.call(endpoint)
      elsif nodes_by_id[endpoint].kind == :condition                            # condition node: average position of its attributes
        values = neighbors[endpoint].select { |e| e[':'] }.map { |e| port_position.call(e) }
        values.empty? ? 0.5 : values.sum / values.count
      else
        0.5
      end
    end

    10.times do
      @nodes.select { |n| n.attributes.count > 1 }.each do |node|
        attributes = node.attributes.values
        barycenters = attributes.each_with_index.map do |a, i|
          others = neighbors["#{node.id}:#{a.port}"].reject { |e| e.split(':').first == node.id }
          [a, others.empty? ? nil : others.sum { |e| position.call(e) } / others.count, i]
        end
        connected, unconnected = barycenters.partition { |_a, b, _i| b }        # attributes with filters only are placed at the end
        sorted = connected.sort_by { |_a, b, i| [b, i] } + unconnected
        node.attributes = sorted.to_h { |a, _b, _i| [normalize(a.name), a] }
      end
    end
  end

  # Connect inline views, CTEs and not yet connected subqueries with their usage
  def link_remaining_blocks
    cte_blocks = @blocks.select { |b| b.role.start_with?('WITH ') }
    @nodes.select { |n| n.kind == :table }.each do |n|
      cte = cte_blocks.find { |b| normalize(b.role.split(' ')[1]) == normalize(n.name) }
      next unless cte
      n.kind = :cte
      add_edge(anchor_node(cte).id, n.id, :link, nil, ltail: cte.id)
      cte.linked = true
    end

    @blocks.each do |b|
      next if b.linked
      if b.link_node
        b.role = "Inline view #{b.link_node.alias}".strip + (b.role[' (set operation branch)'] || '')
        add_edge(anchor_node(b).id, b.link_node.id, :link, nil, ltail: b.id)
      elsif b.parent
        add_edge(anchor_node(b).id, anchor_node(b.parent).id, :link, nil, ltail: b.id)
      end
    end
  end

  # Token index ranges of the AND-connected parts of a condition
  # Done on token level because AND is also used in BETWEEN and IslandSQL may nest BETWEEN wrong
  # Parentheses around a whole part are removed and the content is split again
  def split_conjuncts(start_idx, stop_idx)
    start_idx, stop_idx = strip_parentheses(start_idx, stop_idx)
    parts = []
    depth = 0
    in_between = false
    part_start = start_idx
    default_token_indexes(start_idx, stop_idx).each do |i|
      case @tokens.get(i).getText.upcase
      when '(', 'CASE'    then depth += 1
      when ')', 'END'     then depth -= 1
      when 'OR'           then return [[start_idx, stop_idx]] if depth == 0     # OR at top level: whole condition is one part
      when 'BETWEEN'      then in_between = true if depth == 0
      when 'AND'
        if depth == 0
          if in_between
            in_between = false
          else
            parts << [part_start, i - 1]
            part_start = i + 1
          end
        end
      end
    end
    parts << [part_start, stop_idx]
    return parts if parts.count == 1
    parts.flat_map { |from_idx, to_idx| split_conjuncts(from_idx, to_idx) }
  end

  # Remove parentheses enclosing the whole token range
  def strip_parentheses(start_idx, stop_idx)
    loop do
      indexes = default_token_indexes(start_idx, stop_idx)
      break if indexes.count < 2 || @tokens.get(indexes.first).getText != '(' || @tokens.get(indexes.last).getText != ')'
      depth = 0
      closing = indexes.find do |i|
        text = @tokens.get(i).getText
        depth += 1 if text == '('
        depth -= 1 if text == ')'
        depth == 0
      end
      break unless closing == indexes.last                                      # first parenthesis is closed before the end like in (a) = (b)
      start_idx = indexes[1]
      stop_idx  = indexes[-2]
    end
    [start_idx, stop_idx]
  end

  def default_token_indexes(from_idx, to_idx)
    (from_idx..to_idx).select { |i| @tokens.get(i).getChannel == org.antlr.v4.runtime.Token::DEFAULT_CHANNEL }
  end

  # Original text of the condition part with nested subqueries replaced by …
  def conjunct_text(from_idx, to_idx, nested)
    text = String.new
    pos = from_idx
    nested.sort_by { |b| b.ctx.getStart.getTokenIndex }.each do |b|
      text << interval_text(pos, b.ctx.getStart.getTokenIndex - 1) << '…'
      pos = b.ctx.getStop.getTokenIndex + 1
    end
    text << interval_text(pos, to_idx)
    text.gsub(/\s+/, ' ').strip
  end

  # Columns used in the token range, excluding nested subqueries
  # Qualified columns (alias.column) are resolved by the alias, unqualified columns only if there is exactly one table in the query block
  def column_refs(from_idx, to_idx, nested, block)
    indexes = default_token_indexes(from_idx, to_idx)
                .reject { |i| nested.any? { |b| i >= b.ctx.getStart.getTokenIndex && i <= b.ctx.getStop.getTokenIndex } }
    texts = indexes.map { |i| @tokens.get(i).getText }
    single_table = block && block.nodes.count { |n| n.kind != :condition } == 1 ? block.nodes.find { |n| n.kind != :condition } : nil
    refs = []
    texts.each_with_index do |t, i|
      next unless identifier?(t)
      prev_text = i > 0 ? texts[i - 1] : nil
      next if texts[i + 1] == '(' && texts[i + 2] != '+'                        # function call, but not outer join marker (+)
      if prev_text == '.' && i > 1                                              # column qualified by alias or table name
        node = resolve_qualifier(texts[i - 2], block)
        refs << ColumnRef.new(node, t) if node
      elsif texts[i + 1] != '.' && prev_text != ':' && single_table && unqualified_column?(indexes[i])
        refs << ColumnRef.new(single_table, t)
      end
    end
    refs.uniq { |r| [r.node.id, normalize(r.column)] }
  end

  # Check if the token is an unqualified column name in parse tree
  def unqualified_column?(token_index)
    @unqualified_column_token_indexes ||= begin
      result = {}
      collect = lambda do |ctx|
        if ctx.is_a?(@parser_class::SimpleExpressionNameContext) && !ctx.getParent.is_a?(@parser_class::QualifiedExpressionContext)
          result[ctx.getStart.getTokenIndex] = true if ctx.getStart.getTokenIndex == ctx.getStop.getTokenIndex
        end
        (0...ctx.getChildCount).each { |i| c = ctx.getChild(i); collect.call(c) if c.is_a?(org.antlr.v4.runtime.ParserRuleContext) }
      end
      @conditions.each { |c| collect.call(c.ctx) }
      result
    end
    @unqualified_column_token_indexes[token_index] && !PSEUDO_COLUMNS.include?(@tokens.get(token_index).getText.upcase)
  end

  # Comparison of exactly two qualified columns of different tables like a.x = b.y or a.x(+) = b.y
  # @return [Array, nil] [ColumnRef, operator, ColumnRef]
  def simple_comparison(from_idx, to_idx, block)
    texts = default_token_indexes(from_idx, to_idx).map { |i| @tokens.get(i).getText }
    texts = texts.join(' ').gsub('( + )', '').split
    return nil unless texts.count == 7 && texts[1] == '.' && texts[5] == '.' && COMPARISON_OPERATORS.include?(texts[3])
    left  = resolve_qualifier(texts[0], block)
    right = resolve_qualifier(texts[4], block)
    return nil unless left && right && left != right
    [ColumnRef.new(left, texts[2]), texts[3], ColumnRef.new(right, texts[6])]
  end

  # Find the node for an alias or table name in the query block or its parents
  def resolve_qualifier(qualifier, block)
    return nil unless identifier?(qualifier)
    q = normalize(qualifier)
    while block
      node = block.nodes.find { |n| n.kind != :condition && normalize(n.alias || n.name.split('.').last) == q }
      return node if node
      block = block.parent
    end
    nil
  end

  def attribute(node, column)
    node.attributes[normalize(column)] ||= Attribute.new(column, "a#{node.attributes.count + 1}", [])
  end

  # Edge endpoint at the attribute row of the table
  def endpoint(ref)
    "#{ref.node.id}:#{attribute(ref.node, ref.column).port}"
  end

  # Remove the qualifier of the own table from the condition text
  def strip_qualifiers(text, node)
    qualifier = node.alias || node.name.split('.').last
    text.gsub(/(?<![\w$#".])#{Regexp.escape(qualifier)}\s*\.\s*/i, '')
  end

  # Show the condition without the leading column if it starts with the column, e.g. "> 5" for column "x" and condition "x > 5"
  def without_leading_column(text, column)
    rest = text.sub(/\A#{Regexp.escape(column)}(?![\w$#])\s*/i, '')
    rest.empty? || rest == text ? text : rest
  end

  # Node to connect edges to a cluster
  def anchor_node(block)
    node = block.nodes.find { |n| n.kind != :condition }
    node || new_node(nil, block, kind: :placeholder, name: '(no table)')
  end

  def add_edge(from, to, kind, label, outer: false, ltail: nil)
    key = kind == :join ? [from, to].sort + [kind] : [from, to, kind, ltail]
    edge = @edges[key] ||= { from: from, to: to, kind: kind, labels: [], outer: false, ltail: ltail }
    edge[:labels] << label if label && !edge[:labels].include?(label)
    edge[:outer] ||= outer
  end

  def cluster_label(block)
    label = "<B>#{html(block.role)}</B>"
    block.filters.each { |f| label << "<BR ALIGN=\"LEFT\"/>#{html(truncate(f))}" }
    label
  end

  def node_label(node)
    bgcolor = { table: 'lightgray', inline_view: '#bfe6ff', cte: '#bfe6ff', placeholder: 'white' }[node.kind]
    title = node.kind == :cte ? "WITH #{node.name}" : node.name
    label = String.new("<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\" CELLPADDING=\"3\">")
    label << "<TR><TD BGCOLOR=\"#{bgcolor}\"><B>#{html(truncate(title))}</B>#{"&#160;#{html(node.alias)}" if node.alias}</TD></TR>"
    # Attribute and its filters in one cell, so edges can dock at the left or right side of the whole row
    node.attributes.each_value do |a|
      filters = a.filters.map { |f| "&#160;&#160;<FONT COLOR=\"#1f4e9c\">#{html(truncate(f))}</FONT>" }.join('<BR ALIGN="LEFT"/>')
      label << "<TR><TD PORT=\"#{a.port}\" BGCOLOR=\"white\" ALIGN=\"LEFT\">#{html(a.name)}#{filters}</TD></TR>"
    end
    node.filters.each { |f| label << "<TR><TD BGCOLOR=\"white\" ALIGN=\"LEFT\"><FONT COLOR=\"#1f4e9c\">#{html(truncate(f))}</FONT></TD></TR>" }
    label << '</TABLE>'
  end

  def token_text(ctx)
    interval_text(ctx.getStart.getTokenIndex, ctx.getStop.getTokenIndex).gsub(/\s+/, ' ').strip
  end

  def interval_text(from_idx, to_idx)
    return '' if to_idx < from_idx
    @tokens.getText(org.antlr.v4.runtime.misc.Interval.of(from_idx, to_idx))
  end

  def inside?(inner_ctx, outer_ctx)
    inner_ctx.getStart.getTokenIndex >= outer_ctx.getStart.getTokenIndex && inner_ctx.getStop.getTokenIndex <= outer_ctx.getStop.getTokenIndex
  end

  def first_rule_child(ctx)
    (0...ctx.getChildCount).map { |i| ctx.getChild(i) }.find { |c| c.is_a?(org.antlr.v4.runtime.ParserRuleContext) }
  end

  def find_child(ctx, clazz)
    (0...ctx.getChildCount).map { |i| ctx.getChild(i) }.find { |c| c.is_a?(clazz) }
  end

  def find_descendant(ctx, clazz)
    (0...ctx.getChildCount).each do |i|
      child = ctx.getChild(i)
      next unless child.is_a?(org.antlr.v4.runtime.ParserRuleContext)
      return child if child.is_a?(clazz)
      found = find_descendant(child, clazz)
      return found if found
    end
    nil
  end

  def identifier?(text)
    text.match?(/\A("[^"]+"|[A-Za-z][\w$#]*)\z/)
  end

  def normalize(name)
    name.start_with?('"') ? name.delete('"') : name.upcase
  end

  def truncate(text)
    text.length > MAX_LABEL_LENGTH ? "#{text[0, MAX_LABEL_LENGTH - 1]}…" : text
  end

  def html(text)
    ERB::Util.html_escape(text)
  end

  def dot_escape(text)
    text.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }.gsub("\n") { '\\n' }
  end
end
