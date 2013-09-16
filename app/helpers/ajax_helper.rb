# encoding: utf-8

# Diverse Ajax-Aufrufe und fachliche Code-Schnipsel
module AjaxHelper

  # Ajax-Formular definieren mit Indikator-Anzeige während Ausführung
  # Parameter url notfalls mit url_for formatieren
  def my_ajax_form_tag url, html_options={}
    html_options = prepare_html_options(html_options)
    (form_tag url, html_options do            # internen Rails-Helper verwenden
      yield
    end )
  end # my_ajax_form_tag

  # Ajax-Link definieren mit Indikator-Anzeige während Ausführung
  # Parameter url notfalls mit url_for formatieren
  def my_ajax_link_to caption, url, html_options={}
    html_options = prepare_html_options(html_options)
    link_to(caption ? caption : "", url, html_options)  # internen Rails-Helper verwenden
  end # my_ajax_link_to

  # Ajax-formular mit einzelnem Submit-Button erzeugen
  def my_ajax_submit_tag caption, url, html_options={}
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
                       :title=>'Anzeige der Details zu den Wait-Parametern des Events'
                     ) +
         " #{quick_wait_params_info(event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw)}" +
         "<span id=\"#{unique_div_identifier}\"></span>").html_safe
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  # time_selection_end und time_selection_start können als nil übergeben werden
  def link_historic_sql_id(instance, sql_id, time_selection_start, time_selection_end, update_area, parsing_schema_name=nil, value=nil)
    parsing_schema_name="[UNKNOWN]" if parsing_schema_name.nil?                 # Zweiter pass findet dann Treffer, wenn SQL-ID unter anderem User existiert
    id = session[:link_historic_sql_id_sequence]
    id = 0 unless id
    id = id + 1
    session[:link_historic_sql_id_sequence] = id
    id = "link_historic_sql_id_#{id}"
    prefix = "#{t(:link_historic_sql_id_hint_prefix, :default=>"Show details of")} SQL-ID=#{sql_id} : "
    my_ajax_link_to(value ? value : sql_id,
     url_for( :controller => :DbaHistory,
              :action     => :show_sql_info_for_interval,
              :update_area=> update_area,
              :instance   => instance,
              :sql_id     => sql_id,
              :time_selection_start  => time_selection_start,
              :time_selection_end  => time_selection_end,
              :parsing_schema_name => parsing_schema_name   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
            ),
     {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
      :id          =>  id,
      :prefix      => prefix,
      :onmouseover => "expand_sql_id_hint('#{id}', '#{sql_id}');"
     }
    )
  end

  # Erzeugen eines Links aus den Parametern auf Detail-Darstellung des SQL
  # Aktualisieren des title(hint) erst, wenn das erste mal mit Maus darüber gefahren wird
  def link_sql_id(update_area, instance, sql_id, childno=nil, parsing_schema_name=nil, object_status=nil)
    id = session[:link_sql_id_sequence]
    id = 0 unless id
    id = id + 1
    session[:link_sql_id_sequence] = id
    id = "link_sql_id_#{id}"
    prefix = "#{t(:ajax_helper_link_sql_id_title_prefix, :default=>"Show details in SGA for")} SQL-ID=#{sql_id} : "
    prefix << "ChildNo=#{childno} : " if childno
    my_ajax_link_to(sql_id,
     url_for( :controller   => :dba_sga,
              :action       => childno ? :list_sql_detail_sql_id_childno : :list_sql_detail_sql_id,
              :update_area  => update_area,
              :instance     => instance,
              :sql_id       => sql_id,
              :child_number => childno,
              :parsing_schema_name => parsing_schema_name,   # Sichern der Eindeutigkeit bei mehrfachem Vorkommen identischer SQL in verschiedenen Schemata
              :object_status=> object_status
            ),
     {:title       => "#{prefix} <#{t :link_historic_sql_id_coming_soon, :default=>"Text of SQL is loading, please hold mouse over object again"}>",
      :id          =>  id,
      :prefix      => prefix,
      :onmouseover => "expand_sql_id_hint('#{id}', '#{sql_id}');"
     }
    )
  end

  def link_table_structure(update_area, owner, segment_name, print_value=nil)
    owner         = owner.upcase        if owner
    segment_name  = segment_name.upcase if segment_name
    print_value = "#{owner}.#{segment_name}" unless print_value
    my_ajax_link_to(print_value,
       url_for(:controller   => :dba_schema,
               :action       => :list_table_description,
               :owner        => owner,
               :segment_name => segment_name,
               :update_area  => update_area
              ),
      :title=> "Show object structure and details for #{owner}.#{segment_name}")
  end


private
  # Aufbereiten der HTML-Options für Ajax
  def prepare_html_options(html_options)
    html_options[:remote] = true              # Ajax-Call verwenden
    html_options[:onclick] = "bind_special_ajax_callbacks(jQuery(this));"   # Erst bei Klicken auf Link die Objekt-spezifischen Ajax-Callbacks registrieren nur für diesen Link/Form
    html_options
  end



end