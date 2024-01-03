# encoding: utf-8

module ExplainPlanHelper

  def calculate_execution_order_in_plan(plan_array)
    pos_array = []

    # Vergabe der exec-Order im Explain
    # iteratives neu durchsuchen der Liste nach folgenden erfuellten Kriterien
    # - ID tritt nicht als Parent auf
    # - alle Children als Parent sind bereits mit ExecOrder versehen
    # gefundene Records werden mit aufteigender Folge versehen und im folgenden nicht mehr betrachtet

    # Array mit den Positionen der Objekte in plans anlegen
    0.upto(plan_array.length-1) {|i|  pos_array << i }

    plan_array.each do |p|
      p[:is_parent] = false                                                     # Vorbelegung
    end

    curr_execorder = 1                                             # Startwert
    while pos_array.length > 0                                     # Bis alle Records im PosArray mit Folge versehen sind
      pos_array.each {|i|                                          # Iteration ueber Verbliebene Records
        is_parent = false                                          # Default-Annahme, wenn kein Child gefunden
        pos_array.each {|x|                                        # Suchen, ob noch ein Child zum Parent existiert in verbliebener Menge
          if plan_array[i].id == plan_array[x].parent_id           # Doch noch ein Child zum Parent gefunden
            is_parent = true
            plan_array[i][:is_parent] = true                       # Merken Status als Knoten
            break                                                  # Braucht nicht weiter gesucht werden
          end
        }
        unless is_parent
          plan_array[i].execorder = curr_execorder                      # Vergabe Folge
          curr_execorder = curr_execorder + 1
          pos_array.delete(i)                                      # entwerten der verarbeiten Zeile fuer Folgebetrachtung
          pos_array = pos_array.compact                            # Entfernen der gelöschten Einträge (eventuell unnötig)
          break                                                    # Neue Suche vom Beginn an
        end
      }
    end
  end

  # @param plan_lines Array with plan lines
  # @param display_map_records XML structure of display maps in array records
  # @return plan line ids to process and show
  def ajust_plan_records_for_adaptive(plan:, plan_lines:, display_map_records:, show_adaptive_plans:)
    display_map = {}                                                            # Hash with key=operation ID
    # Calculate rows to skip due to adaptive plan
    display_map_records.each do |m|
      if m.plan_hash_value == plan.plan_hash_value
        display_map[m['op']] = m                                                # remember skip info for plan line id
        plan[:adaptive_plan] = true unless m.dis.nil?                          # Mark plan as adaptive only if there are adaptive plan lines which could be mapped to real plan lines
      end
    end

    filtered_plan_lines = []                                                    # Konkreter Ausführungsplan, aus Gesamtmenge aller Pläne auszufiltern
    plan_lines.each do |p|                                                      # Iterate over all plan lines
      use_this_line = true                                                      # assume to use it if no contra
      use_this_line = false if plan['dbid']                && p.dbid                 != plan.dbid
      use_this_line = false if plan['plan_hash_value']     && p.plan_hash_value      != plan.plan_hash_value
      use_this_line = false if plan['parsing_schema_name'] && p.parsing_schema_name  != plan.parsing_schema_name
      use_this_line = false if plan['min_child_number']    && p.child_number         != plan.min_child_number

      if use_this_line
        p['original_id'] = p.id                                                 # remember the plan line id for matching with ASH before adaptive move of IDs
        dm = display_map[p.id]                                                  # possible entry in display map for that plan line
        if dm
          case show_adaptive_plans
          when nil then
            if p['id'] != dm.dis
              p['id_hint'] = "\nID and parent_ID are adjusted due to adaptive plans!\nOriginal plan line ID in DBA_Hist_SQL_Plan is #{p.id}\nOriginal parent ID in DBA_Hist_SQL_Plan is #{p.parent_id}"
              p['id']         = dm.dis
              p['parent_id']  = dm.par
              p['depth']      = dm.dep
            end
            filtered_plan_lines << p if dm.skp != 1
          when 1 then
            p[:skipped_adaptive_plan] = dm.skp == 1
            filtered_plan_lines << p
          when 2 then
            # TODO: Evaluate display map so that it can be used to determine and remove the plan lines only relevant for the used plan
            p[:skipped_adaptive_plan] = dm.skp == 1
            filtered_plan_lines << p
          end
        else
          filtered_plan_lines << p if dm.nil?                                   # show line in any case no matter if adative or not
        end
        plan[:timestamp] = p.timestamp                                          # Timestamp of parse
      end
    end
    filtered_plan_lines
  end

  # Build tree with tabbed inserts for column operation
  def list_tree_column_operation(rec, indent_vector, plan_array)
    tab = ""
    toggle_id = "#{get_unique_area_id}_#{rec.id}"

    unless rec.depth.nil?
      if rec.depth > indent_vector.count                                        # Einrückung gegenüber Vorgänger
        last_exists_id = 0                                                       # ID des letzten Records, für den die selbe parent_id existiert
        plan_array.each do |p|
          if p.id > rec.id &&  p.parent_id == rec.parent_id                      # nur Nachfolger des aktuellen testen, letzte Existenz des parent_id suchen
            last_exists_id = p.id
          end
        end
        indent_vector << {:parent_id => rec.parent_id, :last_exists_id => last_exists_id}
      end

      while rec.depth < indent_vector.count                                   # Einrückung gegenüber Vorgänger
        indent_vector.delete_at(indent_vector.count-1);
      end

      #rec.depth.downto(1) {
      #  tab << "<span class=\"toggle\"></span>&nbsp;"
      #}
    end

    indent_vector.each_index do |i|
      if i < indent_vector.count-1                                          # den letzten Eintrag unterdrücken, wird relevant beim nächsten, wenn der einen weiter rechts eingerückt ist
        v = indent_vector[i]
        tab << "<span class=\"toggle #{'vertical-line' if rec.id < v[:last_exists_id]}\" title=\"parent_id=#{v[:parent_id]} last_exists_id=#{v[:last_exists_id]}\">#{'' if rec.id < v[:last_exists_id]}</span>&nbsp;"
      end
    end


    if rec[:is_parent]                                                       # Über hash ansprechen, da in bestimmten Konstellationen der Wert nicht im hash enthalten ist => false
      if rec.id > 0                                                          # 1. und 2. Zeile haben gleiche Einrückung durch weglassen des letzten Eintrages von indent_vector, hiermit bleibt 1. Zeile trotzde, weiter links
        tab << "<a class=\"toggle collapse\" id=\"#{toggle_id}\" onclick=\"explain_plan_toggle_expand('#{toggle_id}', #{rec.id}, #{rec.depth}, '#{@grid_id}');\"></a>"
      end
    else
      if plan_array.count > rec.id+1 && plan_array[rec.id+1].parent_id == rec.parent_id # Es gibt noch einen unmittelbaren Nachfolger mit selber Parent-ID
        tab << "<span class=\"toggle vertical-corner-line\"></span>"         # durchgehende Linie mit abzweig
      else
        tab << "<span class=\"toggle corner-line\"></span>"                  # Nur Linie mit Abzweig
      end
    end
    tab << "&nbsp;"
    "<span style=\"color: lightgray;\">#{tab}</span>#{rec.operation} #{rec.options}".html_safe

  end

  # Create a mapping between the short names of query blocks (like SEL$4) and the long names (like SEL$4A5A5A5A) which are used in the plan lines
  # @param other_xml [Nokogiri::XML::Document] XML document with other_xml
  # @param qb_names_in_plan [Hash] hash with query block names used in the plan
  # @return [Hash] mapping between short and long names
  def extract_qb_mapping(other_xml, qb_names_in_plan)
    result = {}
    other_xml.xpath('//qb_registry/q').each do |q|
      qblock_longname = nil
      q.xpath('*').each do |np|
        case np.name
        when 'n' then qblock_longname = np.content
        when 'p' then
          result[np.content] = qblock_longname                                  # Add mapping from short name to long name
          # result[qblock_longname] = np.content                                  # Add mapping from long name to short name
        end
      end
    end

    # reduce the tree relation to the both endpoints
    # the value must be in qb_names_in_plan
    reduced_result = {}

    find_root = proc do |key, value|
      if result.has_key?(value)                                                 # value is a key in result
        find_root.call(key, result[value])
      else
        reduced_result[key] = value if qb_names_in_plan.has_key?(value)         # add the root entry if the value is in qb_names_in_plan
      end
    end

    result.each do |key, value|                                                 # all entries where value is not in qb_names_in_plan
      if qb_names_in_plan.has_key?(value)
        reduced_result[key] = value                                             # add the root entry if the value is in qb_names_in_plan
      else
        find_root.call(key, value)
      end
    end
    reduced_result
  end

  # Extract additional info as array from other_xml
  # @param other_xml [String] XML document with other_xml
  # @return [Array] array with additional info records
  def extract_additional_info_from_other_xml(other_xml)
    plan_additions = []
    xml_doc = Nokogiri::XML(other_xml)
    xml_doc.xpath('//other_xml/*').each do |rec|
      begin
        case rec.name
        when 'info' then
          plan_additions << ({
            :record_type  => 'Info',
            :attribute    => rec.attributes['type'].to_s,
            :value        => rec.children.text,
            description: other_xml_info_type(rec.attributes['type'].to_s)
          }.extend SelectHashHelper)
        when 'bind' then
          attributes = ''
          rec.attributes.each do |key, val|
            attributes << "#{key}=#{val} "
          end
          plan_additions << ({
            :record_type  => 'Peeked bind',
            #              :attribute    => Hash[bind.attributes.map {|key, val| [key, val.to_s]}].to_s,
            :attribute    => attributes,
            :value        => rec.children.text
          }.extend SelectHashHelper)
        when 'hint' then
          plan_additions << ({
            record_type: 'Hint',
            attribute:   nil,
            value:       rec.children.text
          }.extend SelectHashHelper)
        when 'hint_usage' then
          rec.children.each do |hint|
            plan_additions << ({
              :record_type  => 'Hint_Usage',
              :attribute    => my_html_escape("<#{hint.name}>"),
              :value        => my_html_escape(hint.children.to_s)
            }.extend SelectHashHelper)
          end
        when 'display_map' then
          rec.xpath('row').each do |dm|
            attributes = ''
            dm.attributes.each do |key, val|
              attributes << "#{key}=#{val} "
            end

            plan_additions << ({
              :record_type  => 'Display Map',
              :attribute    => nil,
              :value        => attributes
            }.extend SelectHashHelper)
          end
        when 'qb_registry' then
          rec.xpath('q').each do |qb|
            plan_additions << ({
              :record_type  => 'QB Registry',
              :attribute    => nil,
              :value        => my_html_escape(qb.children.to_s)
            }.extend SelectHashHelper)
          end
        else
          plan_additions << ({
            record_type: rec.name,
            attribute:   nil,
            value:       my_html_escape(rec.children.to_s)
          }.extend SelectHashHelper)
        end
      rescue Exception => e
        plan_additions << ({
          :record_type  => 'Exception while processing XML document',
          :attribute => e.message,
          :value => my_html_escape(other_xml).gsub(/&lt;info/, "<br/>&lt;info").gsub(/&lt;hint/, "<br/>&lt;hint")
        }.extend SelectHashHelper)
      end
    end
    plan_additions
  end

  # Add the hint usage to the plan lines based on column other_xml
  # @param plan_array [Array] array with plan lines
  # @return void
  def hint_usage_from_other_xml(plan_array)
    return if plan_array.nil? || plan_array.count == 0

    # Process a single h tag content into given result structure
    # @param h_tag [Nokogiri::XML::Element] h tag element
    # @param type [String] type of hint (h, t, m, s
    # @param hint_usage [Hash] hint usage structure to add the hint to
    process_h_tag = proc do |h_tag, type,  hint_usage|
      hint = {
        hint_text:    '',
        hint_reason:  '',
        type:         type,
        attributes:   []
      }
      h_tag.children.each do |child|                                            # Add all children to the hint
        case child.name
        when 'x' then hint[:hint_text] << child.content
        when 'r' then hint[:hint_reason] << child.content
        else
          hint[:hint_reason] << "Unknown element '#{child.name}' with content '#{child.content}' in other_xml/hint_usage"
        end
      end
      h_tag.parent.attributes.each do |name, value|                             # Add all attributes to the hint at the parent of the h-tag level (t|m|s)
        hint[:attributes] << {name: name, value: value.to_s}
      end
      h_tag.attributes.each do |name, value|                                    # Add all attributes to the hint at h-tag level
        hint[:attributes] << {name: name, value: value.to_s}
      end
      hint_usage << hint
    end

    other_xml = nil
    qb_names_in_plan = {}
    qb_plus_object_aliases_in_plan = {}
    plan_array.each do |p|
      other_xml = p.other_xml if !p.other_xml.nil?
      qb_names_in_plan[p.qblock_name] = true if !p.qblock_name.nil?             # remember the used query block names
      qb_plus_object_aliases_in_plan["#{p.qblock_name}:#{p.object_alias}"]  = true if !p.object_alias.nil?    # remember the used combination of qb name and  object aliases
    end

    if other_xml.nil?
      Rails.logger.warn("No other_xml found in plan lines")
      return
    end
    xml_doc = Nokogiri::XML(other_xml)
    # Temporary hash with all hint usages
    # { qblock_name:object_alias => [
    #     hint_text: "USE_NL(c)"
    #     type => h|m|s|t,
    #     attributes: [  {name: 'st', value: 'EU'} ]
    #   ]
    # }
    hint_usages = {}
    qb_names_in_hints = {}                                                      # Query block names used in hints
    qb_mapping = extract_qb_mapping(xml_doc, qb_names_in_plan)
    xml_doc.xpath('//hint_usage/*').each do |q|                               # Iterate over all toplevel q tags
      qblock_name = nil
      q.xpath('*').each do |nhmst|
        case nhmst.name
        when 'n' then                                                           # Contains the query block name
          qblock_name = nhmst.content                                           # Query block name (n) should be the first element in q
          qb_names_in_hints[qblock_name] = true                                 # Remember the used native query block name
          qblock_name = qb_mapping[qblock_name] if !qb_names_in_plan.has_key?(qblock_name) && qb_mapping.has_key?(qblock_name)  # Use the corresponding long name from QB mapping
          qblock_name = 'force_row_0' if !qb_names_in_plan.has_key?(qblock_name)  # Force relation to row 0 if query block name is not known in plan rows
        else
          hint_usage = []
          object_alias = nil
          if nhmst.name == 'h'
            process_h_tag.call(nhmst, nhmst.name, hint_usage)                   # Directly process the h-tag
          else
            nhmst.xpath('*').each do |fh|                                       # Process all children of m|s|t
              case fh.name
              when 'f' then
                if qb_plus_object_aliases_in_plan.has_key?("#{qblock_name}:#{fh.content}")  # Map hint to the query block without object alias, if combination of qb and alias isn't in the plan (happens e.g. if a CTE is resolved inside the plan)
                  object_alias = fh.content                                     # Object alias (f) should be the first element in hmst, but it is not always present
                end
              when 'h' then process_h_tag.call(fh, nhmst.name, hint_usage)
              else
                Rails.logger.warn('ExplainPlanHelper.hint_usage_from_other_xml'){ "Unknown element 'q/#{fh.name}' with content '#{fh.content}' in other_xml/hint_usage" }
              end
            end
          end
          hint_usage_key = "#{qblock_name}:#{object_alias}"                     # Use the QB name as is
          if hint_usages.has_key?(hint_usage_key)
            hint_usages[hint_usage_key].concat(hint_usage)                      # Add to existing result
          else
            hint_usages[hint_usage_key] = hint_usage                            # Put to result and tag with query block name and object alias
          end
        end
      end
    end

    qb_mapping_reverse = {}                                                     # Reverse mapping from long name to short name for display in view column
    qb_mapping.each do |key, value|
      if qb_names_in_plan.has_key?(value) &&                                    # Only add the mapping if the long query block name is really used in plan_table.QBLOCK_NAME
        ( qb_names_in_hints.has_key?(key)  ||                                   # the short query block name mus be used in hints
          qb_mapping.values.select{|v| v==value}.count == 1                # or the long query block name must be unique in the qb_registry
        )
        qb_mapping_reverse[value] = key
      end
    end

    process_hint_usage = proc do |hint_usage, p|
      hint_usage.each do |hint|
        p['wrong_hint_usage'] = true if hint[:attributes].select{|attr| ['EU', 'NU', 'PE', 'UR'].include?(attr[:value].to_s)}.count > 0
        p['hint_usage'] << "<s>" if p['wrong_hint_usage']                   # Strike through hint if it is not used
        p['hint_usage'] << my_html_escape(hint[:hint_text])                 # Escape special characters in hint text to avoid XSS
        p['hint_usage'] << "</s>" if p['wrong_hint_usage']                  # Strike through hint if it is not used
        p['hint_usage'] << "\n"
        p['hint_usage'] << "#{my_html_escape(hint[:hint_reason])}\n" if !hint[:hint_reason].nil? && hint[:hint_reason] != ''
        hint[:attributes].each do |attr|
          p['hint_usage'] << case attr[:value].to_s
                             when 'EM' then ''  # Hint supplied by user (EM) is not shown
                             when 'EU' then "This hint is not used (EU)!\n"
                             when 'NU' then "This hint is not used (NU)!\n"
                             when 'OU' then "This hint is supplied internally by Oracle (OU)\n"
                             when 'PE' then "Syntax parsing error (PE)!\n"
                             when 'SH' then "related to MMON stats advisor auto task (SH)\n"
                             when 'SR' then "Hint is supplied by a SQL profile (SR)\n"
                             when 'UR' then "This hint is unresolved (UR)!\n"
                             else "Unknown attribute for hint usage (#{attr[:value]})\n"
                             end
        end
        p['hint_usage'] << "\n"
      end
    end

    # Add the hint usage to the plan lines
    plan_array.each do |p|
      p['hint_usage'] = ''
      p['wrong_hint_usage'] = false
      if !p.qblock_name.nil? || p.id == 0                                       # Only process plan lines with a query block name or the first line
        # process hints for query block only (no object alias)
        hint_usage = hint_usages["#{p.qblock_name}:"]                           # Look for hints that are not related to an object alias
        unless hint_usage.nil?
          process_hint_usage.call(hint_usage, p)
          hint_usages.delete("#{p.qblock_name}:")                          # Remove the entry from the hash to avoid processing it again
        end

        # process hints for query block and alias
        hint_usage = hint_usages["#{p.qblock_name}:#{p.object_alias}"]
        hint_usage = hint_usages["force_row_0:"] if p.id == 0                   # Look for global hints that are not related to a query block
        process_hint_usage.call(hint_usage, p) unless hint_usage.nil?           # Hint-Usages exist for that query block and object alias
      end
      p['hint_usage'] = nil if p['hint_usage'] == ''                            # nothing added to hint_usage
      p['qblock_name_short'] = qb_mapping_reverse[p.qblock_name]                # The query block name as set by hint QB_NAME
    end
  end

  # build data title for columns cost and cardinality
  def cost_card_data_title(rec)
    "%t\n#{"
Optimizer mode = #{rec.optimizer}"          if rec.optimizer}#{"
CPU cost = #{fn rec.cpu_cost}"              if rec.cpu_cost}#{"
IO cost = #{fn rec.io_cost}"                if rec.io_cost}#{"
estimated bytes = #{fn rec.bytes}"          if rec.bytes}#{"
estimated time (secs.) = #{fn rec.time}"    if rec.time}#{"
partition start = #{rec.partition_start}"   if rec.partition_start}#{"
partition stop = #{rec.partition_stop}"     if rec.partition_stop}#{"
partition ID = #{rec.partition_id}"         if rec.partition_id}
    "
  end

  def parallel_short(rec)
    case rec.other_tag
    when 'PARALLEL_COMBINED_WITH_PARENT' then 'PCWP'
    when 'PARALLEL_COMBINED_WITH_CHILD'  then 'PCWC'
    when 'PARALLEL_FROM_SERIAL'          then 'S > P'
    when 'PARALLEL_TO_PARALLEL'          then 'P > P'
    when 'PARALLEL_TO_SERIAL'            then 'P > S'
    when 'SERIAL_FROM_REMOTE'            then 'SFR'
    when 'SINGLE_COMBINED_WITH_CHILD'    then 'SCWC'
    when 'SINGLE_COMBINED_WITH_PARENT'   then 'SCWP'
    else
      rec.other_tag
    end
  end

  # The context menu extension with Javascript code to execute to show or hide the additional columns
  # Uses the param of the current request
  # @param [String] header column header text in slickgrid
  # @return [Hash] context menu entry
  def toggle_column(header:)
    raise "header must be given" unless header
    col_setting = read_from_client_info_store('additional_explain_plan_columns', default: {})
    show_hide = col_setting[header] ? 'Hide' : 'Show'
    js = ''
    js << "jQuery.ajax({\n"
    js << "              method: 'POST',\n"
    js << "              dataType: 'html',\n"
    js << "              success: function (data, status, xhr) {\n"
    js << "                ajax_html('#{params[:update_area]}', '#{controller_name}', '#{action_name}',\n {"
    js << "               " + params.permit!.to_h.map{|key, value| "'#{key}': `#{value.gsub('`', '\\\\`')}`"}.join(",\n")
    js << "                });\n"
    js << "              },\n"
    js << "              url: 'env/remember_client_setting?window_width='+jQuery(window).width()+'&browser_tab_id='+browser_tab_id,\n"
    js << "              data: { 'container_key': 'additional_explain_plan_columns', 'key': '#{header}', 'value': '#{!col_setting[header]}'}\n"
    js << "            });\n"

    {
      caption: "#{show_hide} #{header}",
      icon_class: 'cui-columns',
      action: "#{js} ",
      hint: "#{show_hide} view of attribute '#{header}' as own column in execution plan"
    }
  end

  # The additional context menu entries for the explain plan
  def explain_plan_context_menu_entries
    [
      { caption: 'Toggle additional columns for plan', icon_class: 'cui-columns', node_type: 'node', hint: 'Toggle additional columns in explain plan',
        items: [
          toggle_column(header: 'Optimizer hint usage'),
          toggle_column(header: 'Partition attributes'),
          toggle_column(header: 'Projection'),
          toggle_column(header: 'Query block'),
        ]
      }
    ]
  end

  # get the current user-specific setting for the additional columns in the explain plan
  # Set defaults for columns that should be initially shown
  def explain_plan_col_setting
    read_from_client_info_store('additional_explain_plan_columns', default: {
      'Projection' => true,
    })
  end
end


