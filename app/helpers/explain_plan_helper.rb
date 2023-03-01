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

end


