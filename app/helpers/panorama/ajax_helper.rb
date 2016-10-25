# encoding: utf-8

require 'resolv'

# Diverse Ajax-Aufrufe und fachliche Code-Schnipsel
module Panorama::AjaxHelper

  # Render header line with caption
  # Parameter:  caption text
  #             Array of Hashes with commands for list, Keys: :name, :caption, :hint, :icon_class, :action (JS-function)
  def render_page_caption(caption, command_array=nil)
    output = ''
    output << "<div class=\"page_caption\">"

    unless command_array.nil?                                                   # render command button and list
      div_id = get_unique_area_id                                               # Basis for DOM-IDs
      output << "<div style=\"float:left; margin-left:5px;   \" class=\"slick-shadow\" >"
        output << "<div id=\"#{div_id}\" style=\"padding-left: 10px; padding-right: 10px; background-color: #E0E0E0; cursor: pointer; \">"
          output << "\u2261" # 3 waagerechte Striche ≡
          # Construction context-menu
          context_menu_id = "#{div_id}_context_menu"
          output << "<div class=\"contextMenu\" id=\"#{context_menu_id}\" style=\"display:none;\"><ul>"
          command_array.each do |ca|
            output << "<li id=\"#{context_menu_id}_#{ca[:name]}\" title=\"#{ca[:hint]}\"><span class=\"#{ca[:icon_class]}\" style=\"float:left\"></span><span>#{ca[:caption]}</span></li>"
          end
          output << "</ul></div>"
        output << "</div>"
      output << "</div>"

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
                                console.log('pageX '+event.pageX);
                                jQuery(\"##{div_id}\").trigger(\"contextmenu\", event);
                                return false;
                    });"
      output << "</script>"
    end
    output << my_html_escape(caption)
    output << "</div>"
    output.html_safe
  end


  # Ajax-Formular definieren mit Indikator-Anzeige während Ausführung
  # Parameter url notfalls mit url_for formatieren
  def my_ajax_form_tag(url, html_options={})
    html_options = prepare_html_options(html_options)
    (form_tag url, html_options do            # internen Rails-Helper verwenden
      yield
    end )
  end # my_ajax_form_tag

  # Ajax-Link definieren mit Indikator-Anzeige während Ausführung
  # Parameter url notfalls mit url_for formatieren
  def my_ajax_link_to(caption, url, html_options={})
    html_options = prepare_html_options(html_options)
    link_to(caption ? caption : "", url, html_options)  # internen Rails-Helper verwenden
  end # my_ajax_link_to

  # absetzen eines Ajax-Calls aus Javascript
  def js_ajax_post_call(url_data)
    url = {}
    data = {}

    # Extrahieren der UML-Elemente vom Rest der Daten
    url_data.each do |key, value|
      case
        when key == :controller || key == :action   then url[key] = value
        when key == :title                          then html_options[:title] = value   # title auch akzeptieren, wenn in url_data enthalten
        else
          data[key] = value
      end
    end

    json_data = data.to_json.html_safe

    "jQuery.ajax({method: \"POST\", url: \"#{url_for(url)}\", data: #{json_data}});"
  end

  # Funktion nur brauchbar im Slickgrid oder anderen Funktionen, deren Daten im Browser nochmals per Javascript interpretiert werden
  # wegen doppeltem Escape von single Quote per \\x27
  # Ajax-Link definieren mit Indikator-Anzeige während Ausführung
  def my_ajax_post_link(caption, url_data, html_options={})
    options = ''
    html_options.each do |key, value|
      options << " #{key}=\"#{value}\""
    end

    "<a href=\"#\" #{options} onclick=§SINGLE_QUOTE§#{js_ajax_post_call(url_data)} return false; §SINGLE_QUOTE§>#{my_html_escape(caption)}</a>".html_safe
  end # my_ajax_post_link

  # Ajax-formular mit einzelnem Submit-Button erzeugen
  def my_ajax_submit_tag(caption, url, html_options={})
    my_ajax_form_tag url do
      submit_tag caption, html_options
    end
  end # my_ajax_submit_tag


  # Erzeugen eines Links aus den konkreten Wait-Parametern mit aktueller Erläuterung sowie link auf aufwendige Erklärung
  def link_wait_params(instance, event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw, unique_div_identifier)
      (""+  # Wenn kein String als erster Operand, funktioniert html_safe nicht auf Result !!!
       my_ajax_link_to("P1: #{p1text} = #{p1} P2: #{p2text} = #{p2} P3: #{p3text} = #{p3}",
                       url_for(:controller => :dba,
                               :action     => :show_session_details_waits_object,
                               :update_area => unique_div_identifier,
                               :instance    => instance,
                               :event=>event,
                               :p1=>p1, :p1text=>p1text,
                               :p2=>p2, :p2text=>p2text,
                               :p3=>p3, :p3text=>p3text
                              ),
                       :title=>t(:ajax_helper_link_wait_params_hint, :default=>'Show details of wait-parametern for event')
                     ) +
         " #{quick_wait_params_info(event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw)}" +
         "<span id=\"#{unique_div_identifier}\"></span>").html_safe
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  # time_selection_end und time_selection_start können als nil übergeben werden
  def link_historic_sql_id(instance, sql_id, time_selection_start, time_selection_end, update_area, parsing_schema_name=nil, value=nil)
    parsing_schema_name="[UNKNOWN]" if parsing_schema_name.nil?                 # Zweiter pass findet dann Treffer, wenn SQL-ID unter anderem User existiert
    unique_id = get_unique_area_id
    prefix = "#{t(:link_historic_sql_id_hint_prefix, :default=>"Show details of")} SQL-ID=#{sql_id} : "
    my_ajax_link_to(value ? value : sql_id,
     url_for( :controller => :dba_history,
              :action     => :list_sql_detail_historic,
              :update_area=> update_area,
              :instance   => instance,
              :sql_id     => sql_id,
              :time_selection_start  => time_selection_start,
              :time_selection_end  => time_selection_end,
              :parsing_schema_name => parsing_schema_name   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
            ),
     {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
      :id          =>  unique_id,
      :prefix      => prefix,
      :onmouseover => "expand_sql_id_hint('#{unique_id}', '#{sql_id}');"
     }
    )
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  def link_sql_id(update_area, instance, sql_id, childno=nil, parsing_schema_name=nil, object_status=nil, child_address=nil)
    unique_id = get_unique_area_id
    prefix = "#{t(:ajax_helper_link_sql_id_title_prefix, :default=>"Show details in SGA for")} SQL-ID=#{sql_id} : "
    prefix << "ChildNo=#{childno} : " if childno
    my_ajax_link_to(sql_id,
     url_for( :controller     => :dba_sga,
              :action         => childno ||child_address ? :list_sql_detail_sql_id_childno : :list_sql_detail_sql_id,
              :update_area    => update_area,
              :instance       => instance,
              :sql_id         => sql_id,
              :child_number   => childno,
              :child_address  => child_address,               # mittels RAWTOHEX auslesen
              :parsing_schema_name => parsing_schema_name,   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
              :object_status  => object_status
            ),
     {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
      :id          =>  unique_id,
      :prefix      => prefix,
      :onmouseover => "expand_sql_id_hint('#{unique_id}', '#{sql_id}');"
     }
    )
  end


  def link_session_details(update_area, instance, sid, serialno)
    my_ajax_link_to("#{sid}, #{serialno}",
                    url_for(:controller   => :dba,
                            :action       => :show_session_detail,
                            :instance     => instance,
                            :sid          => sid,
                            :serialno     => serialno,
                            :update_area  => update_area
                    ),
                    :title=>t(:dba_list_sessions_show_session_hint, :default=>'Show session details') )
  end


  def link_machine_ip_info(machine_name)
    my_ajax_link_to(machine_name,
                    url_for(:controller   => :env,
                            :action       => :list_machine_ip_info,
                            :machine_name => machine_name
                    ),
                    :title=>'Show IP name resolution'
    )

  end

  def link_object_description(update_area, owner, segment_name, print_value=nil, object_type=nil)
    owner         = owner.upcase        if owner
    segment_name  = segment_name.upcase if segment_name
    print_value = "#{owner}.#{segment_name}" unless print_value
    my_ajax_link_to(print_value,
       url_for(:controller   => :dba_schema,
               :action       => :list_object_description,
               :owner        => owner,
               :segment_name => segment_name,
               :object_type  => object_type,
               :update_area  => update_area
              ),
      :title=>"#{t(:ajax_helper_link_object_description_hint, :default=>"Show object structure and details for")} #{owner}.#{segment_name}"
    )
  end

  def link_file_block_row(file_no, block_no, row_no, data_object_id, update_area, linefeed_prefix = false)
    if file_no && block_no && row_no && (file_no.to_i > 0 || block_no.to_i > 0)
      value = "#{'<br>' if linefeed_prefix}File#=#{file_no}, Block#=#{block_no}, Row#=#{row_no}".html_safe
      if data_object_id
        my_ajax_link_to(value,
                        url_for(:controller         => :dba,
                                :action             => :convert_to_rowid,
                                :update_area        => update_area,
                                :data_object_id     => data_object_id,
                                :row_wait_file_no   => file_no,
                                :row_wait_block_no  => block_no,
                                :row_wait_row_no    => row_no
                        ),
                        :title=>t(:ajax_helper_link_file_block_row_hint, :default=>"Calculate associated rowid for file/block/row.\nThis allows determination of primary key value in next step.")
        )+"<div id=\"#{update_area}\"></div>".html_safe
      else
        value
      end
    else
      ''
    end
  end


  private
  # Aufbereiten der HTML-Options für Ajax
  def prepare_html_options(html_options)
    html_options[:remote] = true              # Ajax-Call verwenden
    html_options[:onclick] = "bind_special_ajax_callbacks(jQuery(this));"   # Erst bei Klicken auf Link die Objekt-spezifischen Ajax-Callbacks registrieren nur für diesen Link/Form
    html_options
  end



end
