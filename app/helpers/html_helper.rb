# encoding: utf-8

# Diverse Methoden für Client-GUI
module HtmlHelper

  # Anzeige eines start und ende-datetimepickers (neue Variante für display:flex)
  def include_start_end_timepicker(id_suffix: "default", additional_title:  nil, line_feed_after_lable: false)
    start_id = "time_selection_start_#{id_suffix}"
    end_id   = "time_selection_end_#{id_suffix}"

    additional_title = "\n#{additional_title}" unless additional_title.nil?

    "
    <div class='flex-row-element' title=\"#{t :time_selection_start_hint, :default=>"Start of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{'&nbsp;' if line_feed_after_lable}#{t :time_selection_start_caption, :default=>"Start"}#{'<br/>' if line_feed_after_lable}
    #{ text_field_tag(:time_selection_start, default_time_selection_start, :size=>16, :id=>start_id) }
    </div>
    <div class='flex-row-element' title=\"#{t :time_selection_end_hint, :default=>"End of considered time period in format"} '#{human_datetime_minute_mask}'#{additional_title}\">
      #{'&nbsp;' if line_feed_after_lable}#{t :time_selection_end_caption, :default=>"End"}#{'<br/>' if line_feed_after_lable}
    #{ text_field_tag(:time_selection_end, default_time_selection_end, :size=>16, :id=>end_id) }
    </div>

    <script type='text/javascript'>
       $('##{start_id}').datetimepicker();
       $('##{end_id}').datetimepicker();
    </script>
    ".html_safe
  end

  def instance_tag(required: false, line_feed: false, rac_only: false)
    return '' if rac_only && !PanoramaConnection.rac?
    if required
      instance = read_from_client_info_store(:instance)
      instance = PanoramaConnection.instance_number if instance.nil?
    end

    "<div class='flex-row-element' title='#{t(:instance_filter_hint, default: 'Filter on specific RAC instance')} (#{required ? "#{t(:mandatory, default: 'mandatory')}" : 'Optional'})'>
       #{'&nbsp;' if line_feed}Inst.#{'<br/>' if line_feed}
       #{text_field_tag(:instance, instance, size: 1, style: "text-align:right;")}
    </div>".html_safe
  end

  # Select DBID from different sources
  def dbid_selection(select_element_id: nil, onchange: nil)
    result = ''
    dbids = []
=begin
    dbids = [{dbid: PanoramaConnection.dbid, title: "DBID of instance / container DB"}]
    current_dbids = Set[PanoramaConnection.dbid]
    PanoramaConnection.pdbs.each do |p|
      # Add possibly existing pluggable databases
      current_dbids.add(p[:dbid])
      dbids << {dbid: p[:dbid], title: "PDB #{p[:con_id]}: #{p[:name]}"}
    end
=end
    # Add possibly existing previously recorded databases
    PanoramaConnection.all_awr_dbids.each do |a|
      #      unless current_dbids.include? a.dbid                                      # List AWR DBIDs not already known as current
        dbids << {dbid: a.dbid, title: "#{a.db_name}/#{a.con_id} #{localeDateTime(a.start_ts, :days)} .. #{localeDateTime(a.end_ts, :days)}"}
      #end
    end

    # Don't show choice if only one DBID available
    result << "<div class=\"flex-row-element\" #{"style=\"display:none;\"" if dbids.count < 2 } title=\"The requested info can be recorded for different database IDs as well as global and per PDB.\nSelect for which DBID values should be to evaluated.\">"
    result << "  <label>DB-ID</label>"
    result << "  <select name=\"dbid\" #{"id=\"#{select_element_id}\"" if select_element_id} #{"onchange=\"#{onchange}\"" if onchange}>"
    selected_dbid = get_dbid                                                    # Default
    selected_dbid = @dbid.to_i if defined? @dbid                                # use previously used value if exists
    dbids.each do |d|
      result << "    <option value=\"#{d[:dbid]}\"#{" selected" if d[:dbid] == selected_dbid}>#{d[:title]} (#{d[:dbid]})</option>"
    end
    result << "</select>"
    result << "</div>"

    result.html_safe
  end

end

