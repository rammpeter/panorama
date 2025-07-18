# encoding: utf-8

# Diverse Methoden für Client-GUI
module HtmlHelper

  # Anzeige eines start und ende-datetimepickers (neue Variante für display:flex)
  def include_start_end_timepicker(additional_title:  nil, line_feed_after_lable: false)
    unique_id = get_unique_area_id
    start_id = "time_selection_start_#{unique_id}"
    end_id   = "time_selection_end_#{unique_id}"

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
      instance = ClientInfoStore.read_for_client_key(get_decrypted_client_key,:instance, default: PanoramaConnection.instance_number)
    end

    "<div class='flex-row-element' title='#{t(:instance_filter_hint, default: 'Filter on specific RAC instance')} (#{required ? "#{t(:mandatory, default: 'mandatory')}" : 'Optional'})'>
       #{'&nbsp;' if line_feed}Inst.#{'<br/>' if line_feed}
       #{text_field_tag(:instance, instance, size: 1, style: "text-align:right;")}
    </div>".html_safe
  end

  # Select DBID from different sources
  # @param select_element_id [String] DOM-ID of the select element
  # @param onchange [String] JavaScript code to be executed on change event
  # @param wrap_label [Boolean] Whether to wrap label and select element in a div
  # @param show_all [Boolean] Whether to show an option for all DBIDs
  # @param show_only_known_awr_dbids [Boolean] Whether to show only known AWR DBIDs or all available DBIDs
  # @return [String] HTML select element with DBID values
  def dbid_selection(select_element_id: nil, onchange: nil, wrap_label: false, show_all: false, show_only_known_awr_dbids: true)
    result = String.new
    dbids = []

    if show_only_known_awr_dbids
      # Add possibly existing previously recorded databases
      PanoramaConnection.all_awr_dbids.each do |a|
        dbids << {dbid: a.dbid, title: "#{a.db_name}/#{a.con_id} #{localeDateTime(a.start_ts, :days)} .. #{localeDateTime(a.end_ts, :days)}"}
      end
    else
      dbids << {dbid: PanoramaConnection.dbid, title: "DBID of instance / container DB"}
      PanoramaConnection.pdbs.each do |p|
        dbids << {dbid: p[:dbid], title: "PDB #{p[:con_id]}: #{p[:name]}"}      # Add possibly existing pluggable databases
      end
    end

    # Don't show choice if only one DBID available
    result << "<div class=\"flex-row-element\" #{"style=\"display:none;\"" if dbids.count < 2 } title=\"The requested info can be recorded for different database IDs as well as global and per PDB.\nSelect for which DBID values should be to evaluated.\">"
    result << "  <label>DB-ID</label>"
    result << "  <br/>" if wrap_label
    result << "  <select name=\"dbid\" #{"id=\"#{select_element_id}\"" if select_element_id} #{"onchange=\"#{onchange}\"" if onchange}>"
    result << "    <option value=\"\">[ #{t(:all, default: 'All')} ]</option>" if show_all
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

