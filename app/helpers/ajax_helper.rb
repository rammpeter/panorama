# encoding: utf-8

require 'resolv'

# Diverse Ajax-Aufrufe und fachliche Code-Schnipsel
module AjaxHelper

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
    output = String.new
    div_id = get_unique_area_id                                                 # Basis for DOM-IDs
    output << "<span style=\"margin-left:5px;   \" class=\"slick-shadow\" >"
    output << "<span id=\"#{div_id}\" style=\"padding-left: 10px; padding-right: 10px; background-color: #E0E0E0; cursor: pointer; \">"
    output << "\u2261" # 3 waagerechte Striche ≡
    output << "</span></span>"
    output << "&nbsp;\n"   # Space before following icons
    # Construction context-menu
    output << "<script type=\"text/javascript\">\n"

    output << "jQuery(\"##{div_id}\").bind('click' , function( event) {
                                jQuery(\"##{div_id}\").trigger(\"contextmenu\", event);
                                return false;
                    });\n"
    output << "\jQuery('##{div_id}').parent().contextMenu({
                                           selector: '##{div_id}',
                                           build: function ($trigger, e) {
                let items = {};\n"

    print_entry_list = proc do |entries|
      entries.each do |entry|
        if entry[:name] == :separator
          output << "items['separator_#{entry[:caption]}'] = { name: '---' };\n"
        else
          output << "items['#{entry[:name]}'] = {
                     name: \"<span class='"+entry[:icon_class]+"' style='float:left'></span><span title='"+entry[:hint].gsub(/\n/, '\n')+ "'>&nbsp;"+entry[:caption]+"</span>\",
                     isHtmlName: true,\n"
          if entry[:entries]
            output << "    items: [\n"
            print_entry_list.call(entry[:entries])
            output << "    ]\n"
          else
            output << "callback: function(){ #{entry[:action]} }\n"
          end
          output << "};\n"
        end
      end
    end

    print_entry_list.call(command_array)

    output << "return {items: items};\n"
    output << "}});\n"
    output << "</script>\n"
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
  #             Add separator like this:
  #               { name: :separator, show_icon_in_caption: true },
  #             left_addition:    insert html-content at left side after menu and icons
  #             right_addition:   insert html-content at right side before icons
  def render_page_caption(caption, command_array=nil, left_addition=nil, right_addition=nil)

    command_array = [command_array] if command_array.class == Hash              # Construct Array if only single entry

    output = String.new
    output << "<div class=\"page_caption\">"
    output << "<span>"

    unless command_array.nil?                                                   # render command button and list
      output << render_command_array_menu(command_array)                        # render the Hamburger menu
      command_array.each do |cmd|
        if cmd[:show_icon_in_caption] && cmd[:show_icon_in_caption] != :right
          if cmd[:name] == :separator
            # vertical line as separator
            output << "&nbsp;&nbsp;<span style=\"font-size: larger; border-left: 1px solid #000; height: 100%;\"></span>&nbsp;"
          else
            output << "<div style='margin-left:5px; margin-top:4px; cursor: pointer; display: inline-block;#{cmd[:icon_style]}'
                          title='#{cmd[:hint]}' onclick='#{cmd[:action]}'>
                       <span class='#{cmd[:icon_class]}'></span>
                     </div>"
          end
        end
      end
    end

    output << "#{left_addition}</span>"                                         # End of left block
    output << "<span style='font-weight: bold;'>#{my_html_escape(caption)}</span>"                         # Middle block

    output << "<span>#{right_addition}</span>"                                  # Right block
    # Remove the whole block including the page caption if the user clicks on the X
    output << "<span class=\"cui-x\" style=\"cursor: pointer; float: right;\" title=\"Remove this block from page\n(Including all its children)\" onclick=\"jQuery(this).parent().parent().empty();\"></span>"

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
    options = String.new

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
    "<a href=\"#\" onclick=\"ajax_html('#{url[:update_area]}', '#{url[:controller]}', '#{url[:action]}', #{json_data}, { element: this}); #{local_additional_onclick_js} return false; \"  #{options}>#{my_html_escape(caption, false)}</a>".html_safe
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
    ExceptionHelper.log_exception_backtrace(e)
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

  def link_username(update_area, username)
    ajax_link(username,
              { controller: :dba_schema,
                action:      :list_db_users,
                username:     username,
                update_area: update_area,
              },
              title: "Show details for user '#{username}'"
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

  # create a link to show the object description
  # @param [String] update_area the div id to update the content after clcking the link
  # @param [String] owner the owner of the object
  # @param [String] segment_name the name of the object
  # @param [String] print_value the text to print in the link
  # @param [String] object_type the type of the object
  # @return [String] the link
  def link_object_description(update_area, owner, object_name, print_value=nil, object_type=nil, additional_tooltip: nil)
    owner         = owner.upcase        if owner
    print_value = "#{owner}#{'.&#8203;' if owner && owner != ''}#{object_name}" unless print_value
    ajax_link(print_value, {
               :controller   => :dba_schema,
               :action       => :list_object_description,
               :owner        => owner,
               :object_name  => object_name,
               :object_type  => object_type,
               :update_area  => update_area  # TODO: Ensure additional_tooltip is shown with linefeeds
    }, :title=>"#{"#{additional_tooltip}\n\nClick link to: " if additional_tooltip}#{t(:ajax_helper_link_object_description_hint, :default=>"Show object structure and details for")} #{owner}.#{object_name}"
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
