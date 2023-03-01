# encoding: utf-8

require 'resolv'

# Diverse Ajax-Aufrufe und fachliche Code-Schnipsel
module AjaxHelper
  include ExceptionHelper

  # call action and render result
  # @param [String] controller
  # @param [String] action
  # @param [Hash] params {update_area:}
  def render_async(controller, action, params={})
    update_area = get_unique_area_id                                            # DIV where result of async call should be rendered in
    params[:update_area] = update_area unless params.has_key?(:update_area)     # render next action in same DIV if no other target is set
    result = "
    <div id=\"#{update_area}\">
    </div>
    <script type=\"text/javascript\">
      ajax_html('#{update_area}', '#{controller}', '#{action}', {
    "
    #result << params.to_a.map {|x| "#{x[0]}: #{surrounding}#{x[1]}#{surrounding}"}.join(", ")

    result << params.to_a.map { |p|
      surrounding = '"'                                                         # Default for Strings etc.
      surrounding = '' if p[1].class == Array                                   # print Arrays native as JS array
      "#{p[0]}: #{surrounding}#{p[1]}#{surrounding}"
    }.join(", ")

    result << "}, {retain_status_message: true});
    </script>
"
    result.html_safe
  end

  # render menu button with submenu
  def render_command_array_menu(command_array)
    output = ''
    div_id = get_unique_area_id                                                 # Basis for DOM-IDs
    output << "<span style=\"margin-left:5px;   \" class=\"slick-shadow\" >"
    output << "<span id=\"#{div_id}\" style=\"padding-left: 10px; padding-right: 10px; background-color: #E0E0E0; cursor: pointer; \">"
    output << "\u2261" # 3 waagerechte Striche ≡
    # Construction context-menu
    context_menu_id = "#{div_id}_context_menu"
    output << "<div class=\"contextMenu\" id=\"#{context_menu_id}\" style=\"display:none;\"><ul>"
    command_array.each do |ca|
      output << "<li id=\"#{context_menu_id}_#{ca[:name]}\" title=\"#{ca[:hint]}\"><div class=\"#{ca[:icon_class]}\" style=\"display: inline-block;\"></div><div style=\"display: inline-block;\">&nbsp;#{ca[:caption]}</div></li>"
    end
    output << "</ul></div>"
    output << "</span>"
    output << "</span>"
    output << "&nbsp;"   # Space before following icons

    output << "<script type=\"text/javascript\">"
    output << "var bindings = {};"
    command_array.each do |ca|
      output << "bindings[\"#{context_menu_id}_#{ca[:name]}\"] = function(){ #{ca[:action]} };"
    end
    output << "jQuery(\"##{div_id}\").contextMenu(\"#{context_menu_id}\", {
                    menuStyle: {  width: '330px' },
                    bindings:   bindings,
                    onContextMenu : function(event, menu)                                   // dynamisches Anpassen des Context-Menü
                    {
                      return true;
                    }
                    });"
    output << "jQuery(\"##{div_id}\").bind('click' , function( event) {
                                jQuery(\"##{div_id}\").trigger(\"contextmenu\", event);
                                return false;
                    });"
    output << "</script>"
    output
  end

  # Render header line with caption
  # Parameter:  caption text
  #             Array of Hashes with commands for list, Keys:
  #                 :name,
  #                 :caption,
  #                 :hint,
  #                 :icon_class,
  #                 :icon_style,
  #                 :action (JS-function)
  #                 :show_icon_in_caption => true|false|:only\:right  :only == only left
  #             left_addition:    insert html-content at left side after menu and icons
  #             right_addition:   insert html-content at right side before icons
  def render_page_caption(caption, command_array=nil, left_addition=nil, right_addition=nil)

    command_array = [command_array] if command_array.class == Hash              # Construct Array if only single entry

    output = ''
    output << "<div class=\"page_caption\">"
    output << "<span>"

    unless command_array.nil?                                                   # render command button and list
      output << render_command_array_menu(command_array)
      command_array.each do |cmd|
        if cmd[:show_icon_in_caption] && cmd[:show_icon_in_caption] != :right
          output << "<div style='margin-left:5px; margin-top:4px; cursor: pointer; display: inline-block;#{cmd[:icon_style]}'
                          title='#{cmd[:hint]}' onclick='#{cmd[:action]}'>
                       <span class='#{cmd[:icon_class]}'></span>
                     </div>"
        end
      end
    end

    output << "#{left_addition}</span>"                                         # End of left block
    output << "<span style='font-weight: bold;'>#{my_html_escape(caption)}</span>"                         # Middle block

    output << "<span>#{right_addition}</span>"                                  # Right block
    output << "</div>"
    output.html_safe
  end

  # Ajax-Formular definieren mit Indikator-Anzeige während Ausführung
  # Parameter:
  #   url:          Hash mit controller, action, update_area
  #   html_options: Hash
  def ajax_form(url, html_options={})
    raise "@browser_tab_id is not set before calling ajax_form" if !defined?(@browser_tab_id) || @browser_tab_id.nil?

    html_options[:remote] = true              # Ajax-Call verwenden
    html_options['data-type'] = :html
    html_options[:onsubmit] = "bind_ajax_html_response(jQuery(this), '#{url[:update_area]}');#{html_options[:onsubmit]}"

    url[:controller] = controller_name unless url[:controller]
    url[:browser_tab_id] = @browser_tab_id                                      # Unique identifier for browser tab

    raise 'ajax_form: key=:controller missing in parameter url'   unless url[:controller]
    raise 'ajax_form: key=:action missing in parameter url'       unless url[:action]
    raise 'ajax_form: key=:update_area missing in parameter url'  unless url[:update_area]

    # update_area should be part of request for additional use in server
    (form_tag url_for(url), html_options do                                     # internen Rails-Helper verwenden
      yield
    end )

  end

  # Ajax-Link definieren mit Indikator-Anzeige während Ausführung
  # Parameter:
  #   caption:      String
  #   url:          Hash with controller, action, update_area, payload
  #   html_options: Hash
  def ajax_link(caption, url, html_options={}, additional_onclick_js=nil)
    data = {}
    options = ''

    # update_area should pe passed to server
    url.each do |key, value|
      data[key] = value if key != :controller && key != :action
    end

    url[:controller] = controller_name unless url[:controller]

    raise 'ajax_link: key=:controller missing in parameter url'   unless url[:controller]
    raise 'ajax_link: key=:action missing in parameter url'       unless url[:action]
    raise 'ajax_link: key=:update_area missing in parameter url'  unless url[:update_area]

    html_options.each do |key, value|
      options << " #{key}=\"#{value}\""
    end

    local_additional_onclick_js = additional_onclick_js.clone
    local_additional_onclick_js << ';' if local_additional_onclick_js && local_additional_onclick_js[local_additional_onclick_js.length-1] != ';'

    json_data =  my_html_escape( data.to_json.gsub(/\\"/, '"+String.fromCharCode(34)+"') )    # Escape possible double quotes in strings to JS code
    "<a href=\"#\" onclick=\"ajax_html('#{url[:update_area]}', '#{url[:controller]}', '#{url[:action]}', #{json_data}, { element: this}); #{local_additional_onclick_js} return false; \"  #{options}>#{my_html_escape(caption)}</a>".html_safe
  end # ajax_link

  # Ajax-Link definieren mit Indikator-Anzeige während Ausführung
  # Parameter:
  #   caption:      String
  #   url:          Hash with controller, action, update_area, payload
  #   html_options: Hash
  def ajax_submit(caption, url, html_options, form_options={})
    ajax_form(url, form_options) do
      #html_options['data-disable-with']=false
      submit_tag caption, html_options
    end
  end

  # Erzeugen eines Links aus den konkreten Wait-Parametern mit aktueller Erläuterung sowie link auf aufwendige Erklärung

  def link_wait_params(instance, event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw, unique_div_identifier)
      (""+  # Wenn kein String als erster Operand, funktioniert html_safe nicht auf Result !!!
       ajax_link("P1: #{p1text} = #{p1} P2: #{p2text} = #{p2} P3: #{p3text} = #{p3}", {
                               :controller => :dba,
                               :action     => :show_session_details_waits_object,
                               :update_area => unique_div_identifier,
                               :instance    => instance,
                               :event=>event,
                               :p1=>p1, :p1text=>p1text,
                               :p2=>p2, :p2text=>p2text,
                               :p3=>p3, :p3text=>p3text
       }, :title=>t(:ajax_helper_link_wait_params_hint, :default=>'Show details of wait-parametern for event')
                     ) +
         " #{quick_wait_params_info(event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw)}" +
         "<span id=\"#{unique_div_identifier}\"></span>").html_safe
  rescue Exception => e
    log_exception_backtrace(e)
    "Exception #{e.class} #{e.message} during evaluation of parameters in link_wait_params"
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  # time_selection_end und time_selection_start können als nil übergeben werden
  def link_historic_sql_id(instance, sql_id, time_selection_start, time_selection_end, update_area, parsing_schema_name=nil, value=nil)
    parsing_schema_name="[UNKNOWN]" if parsing_schema_name.nil?                 # Zweiter pass findet dann Treffer, wenn SQL-ID unter anderem User existiert
    unique_id = get_unique_area_id
    prefix = "#{t(:link_historic_sql_id_hint_prefix, :default=>"Show details from AWR history of")} SQL-ID=#{sql_id} : "
    ajax_link(value ? value : sql_id, {
              :controller => :dba_history,
              :action     => :list_sql_detail_historic,
              :update_area=> update_area,
              :instance   => instance,
              :sql_id     => sql_id,
              :time_selection_start  => time_selection_start,
              :time_selection_end  => time_selection_end,
              :parsing_schema_name => parsing_schema_name   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
    },
     {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
      :id          =>  unique_id,
      :prefix      => prefix,
      :onmouseover => "expand_sql_id_hint('#{unique_id}', '#{sql_id}');"
     }
    )
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  def link_sql_id(update_area, instance, sql_id, childno: nil, parsing_schema_name: nil, object_status: nil, child_address: nil, con_id: nil,
                  additional_onclick_js:  nil,
                  time_selection_start:   nil,                                  # Switch to historic SQL if time range is set and no hit in SGA
                  time_selection_end:     nil
  )
    unique_id = get_unique_area_id
    prefix = "#{t(:ajax_helper_link_sql_id_title_prefix, :default=>"Show details in SGA for")} SQL-ID = '#{sql_id}', Instance = #{instance}"
    prefix << ", ChildNo=#{childno} : " if childno
    ajax_link(sql_id, {
              :controller     => :dba_sga,
              :action         => childno ||child_address ? :list_sql_detail_sql_id_childno : :list_sql_detail_sql_id,
              :update_area    => update_area,
              :instance       => instance,
              :sql_id         => sql_id,
              :child_number   => childno,
              :child_address  => child_address,               # mittels RAWTOHEX auslesen
              :parsing_schema_name => parsing_schema_name,   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
              :object_status  => object_status,
              :con_id         => con_id,
              time_selection_start: time_selection_start,
              time_selection_end:   time_selection_end
              },
               {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
                :id          =>  unique_id,
                :prefix      => prefix,
                :onmouseover => "expand_sql_id_hint('#{unique_id}', '#{sql_id}');"
               },
              additional_onclick_js
    )
  end

  def link_current_or_historic_sql_id(update_area, instance, sql_id, time_selection_start, time_selection_end, parsing_schema_name=nil, con_id=nil)
    unique_id = get_unique_area_id
    prefix = "Show details in SGA or AWR history for SQL-ID = '#{sql_id}'#{", Instance = #{instance}" if instance}"
    ajax_link(sql_id, {
        controller:           :dba_sga,
        action:               :list_sql_detail_sql_id_or_history,
        update_area:          update_area,
        instance:             instance,
        sql_id:               sql_id,
        time_selection_start: time_selection_start,
        time_selection_end:   time_selection_end,
        parsing_schema_name:  parsing_schema_name,   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
        con_id:               con_id
    },
              {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
               :id          =>  unique_id,
               :prefix      => prefix,
               :onmouseover => "expand_sql_id_hint('#{unique_id}', '#{sql_id}');"
              }
    )
  end

  def link_session_details(update_area, instance, sid, serial_no, print_val: nil, additional_onclick_js: nil)
    if instance.nil? || sid.nil? || serial_no.nil?
      ''
    else
      print_val = "#{sid}, #{serial_no}" if print_val.nil?
      ajax_link(print_val,
                {       :controller   => :dba,
                        :action       => :show_session_detail,
                        :instance     => instance,
                        :sid          => sid,
                        :serial_no     => serial_no,
                        :update_area  => update_area
                },
                {:title=>t(:dba_list_sessions_show_session_hint, :default=>'Show current session details in SGA')},
                additional_onclick_js
                )
    end
  end


  def link_machine_ip_info(update_area, machine_name)
    ajax_link(machine_name, {
                            :controller   => :env,
                            :action       => :list_machine_ip_info,
                            :machine_name => machine_name,
                            :update_area  => update_area
    }, :title=>'Show IP name resolution'
    )

  end

  def link_object_description(update_area, owner, segment_name, print_value=nil, object_type=nil)
    owner         = owner.upcase        if owner
    segment_name  = segment_name.upcase if segment_name
    print_value = "#{owner}#{'.' if owner && owner != ''}#{segment_name}" unless print_value
    ajax_link(print_value, {
               :controller   => :dba_schema,
               :action       => :list_object_description,
               :owner        => owner,
               :segment_name => segment_name,
               :object_type  => object_type,
               :update_area  => update_area
    }, :title=>"#{t(:ajax_helper_link_object_description_hint, :default=>"Show object structure and details for")} #{owner}.#{segment_name}"
    )
  end

  def link_file_block_row(file_no, block_no, row_no, data_object_id, update_area, linefeed_prefix = false)
    if file_no && block_no && row_no && (file_no.to_i > 0 || block_no.to_i > 0)
      value = "#{'<br>' if linefeed_prefix}File#=#{file_no}, Block#=#{block_no}, Row#=#{row_no}".html_safe
      if data_object_id
        ajax_link(value, {
                                :controller         => :dba,
                                :action             => :convert_to_rowid,
                                :update_area        => update_area,
                                :data_object_id     => data_object_id,
                                :row_wait_file_no   => file_no,
                                :row_wait_block_no  => block_no,
                                :row_wait_row_no    => row_no
        }, :title=>t(:ajax_helper_link_file_block_row_hint, :default=>"Calculate associated rowid for file/block/row.\nThis allows determination of primary key value in next step.")
        )+"<div id=\"#{update_area}\"></div>".html_safe
      else
        value
      end
    else
      ''
    end
  end


end
