# encoding: utf-8

# Methods added to this helper will be available to all templates in the application.
module SlickgridHelper

  private

  # Entfernen aller umhüllenden Tags, umwandeln html-Ersetzungen
  def strip_inner_html(content)
    content = content.dup if content.frozen?      # Prevent RuntimeError (can't modify frozen string): if content is frozen (Symbol etc.)

    #
    # Stripping html from string is expensive operation
    # Rails provides santitize and strip_tags which is slightly slow
    # Nokogiri is 2 times faster than strip_tags, but should only be called if string contains tags
    content = Nokogiri::HTML(content).text if content['<'] && content['>']

    # Regular expression is 2 times faster than Nokogiri
    # content.gsub(%r{</?[^>]+?>}, '').
    #    gsub('&nbsp;', ' ').
    #    gsub('&amp;', '&')
    content.gsub('&nbsp;', ' ').gsub('&amp;', '&')
  end

  def internal_escape(input)
    return nil unless input
    input = input.dup  if input.frozen?                                         # Kopie des Objektes verwenden für Umgehung runtime-Error, wenn object frozen

    input.gsub("'", '&#39;')                                                      # ' im Text fuer html escapen für weitere Verwendung, da sonst ParseError
  end

  def ecape_js_chars_without_br(input)
    return nil unless input
    internal_escape(input).gsub("\n", '\n')                                     # Linefeed für tooltip als \n erhalten
  end

  def escape_js_chars(input)                                                    # Javascript-kritische Zeichen escapen in Strings
    return nil unless input
    internal_escape(input).gsub("\n", '<br>')                                   # Linefeed im Text fuer html escapen für weitere Verwendung, da sonst ParseError
  end

  def eval_with_rec (input, rec)  # Ausführen eval mit Ausgabe des Inputs in Exception
    eval input
  rescue Exception=>e
    ExceptionHelper.reraise_extended_exception(e, "during eval of '#{input}'")
  end

  # Aufbauen Javascipt-Strunktur mit columns für slickgrid
  def prepare_js_columns_for_slickgrid(table_id, column_options)
    col_index = 0
    output = '['
    column_options.each do |col|
      begin

        cssClass = ''
        cssClass << ' align-right' if col[:align].to_s == 'right'
        cssClass << " #{col[:css_class]}" if col[:css_class]
        output << "{id:           '#{col[:name]}',
                  name:         '#{col[:caption]}',
                  toolTip:      '#{col[:title]}',
                  index:        '#{col[:index]}',
                 "
        output << " cssClass:     '#{cssClass}',"   if cssClass != ''
        output << " style:        '#{col[:style]}'," if col[:style]
        output << ' no_wrap:      1,'               if col[:no_wrap]
        output << ' plot_master:  1,'               if col[:plot_master]
        output << ' show_pct_hint:  1,'             if col[:show_pct_hint]
        output << ' show_pct_background:  1,'       if col[:show_pct_background]
        output << ' hidden:       1,'               if col[:hidden]

        # field_decorator_function: Übergeben wird Funktionskörper mit folgenden Variablen:
        #   slickGrid           Referenz auf SlickGridExtended-Objekt
        #   row_no,cell_no      Nr. beginnend mit 0
        #   cell_value:         Wert der Zelle in data
        #   full_cell_value     Wert der Zelle in dataContext['metadata']['columns'][columnDef['field']['fulldata'], sonst identisch mit cell_value
        #   columnDef:    Spaltendefinition
        #   dataContext:  komplette Zeile aus data-Array
        output << " field_decorator_function: function(slickGrid, row_no, cell_no, cell_value, full_cell_value, columnDef, dataContext){ #{col[:field_decorator_function]}}," if col[:field_decorator_function]

        output << ' plot_master_time: 1,'           if col[:plot_master_time]
        output << " max_wrap_width_allowed: #{col[:max_wrap_width]}," if col[:max_wrap_width]
        if col[:isFloat]
          output << " sort_type: 'float',"
        else
          if col[:isDate]
            output << " sort_type: 'date',"
          else
            output << " sort_type: 'string',"
          end
        end

        output << '},'
        col_index = col_index+1
      rescue Exception => e
        ExceptionHelper.reraise_extended_exception(e, "processing prepare_js_columns_for_slickgrid for column #{col[:caption]}")
      end
    end
    output << ']'
    output
  end

  def prepare_js_global_options_for_slickgrid(table_id, global_options)
    output = '{'
    output << "\n  caption:                 '#{global_options[:caption]}',"
    output << "\n  command_menu_entries:    #{global_options[:command_menu_entries].to_json},"    if global_options[:command_menu_entries]
    output << "\n  data_filter:             #{global_options[:data_filter]},"      if global_options[:data_filter]
    output << "\n  line_height_single:      #{global_options[:line_height_single]},"
    output << "\n  locale:                  '#{get_locale}',"
    output << "\n  maxHeight:               #{global_options[:max_height]},"       if global_options[:max_height]      # max. Höhe in Pixel
    output << "\n  multiple_y_axes:         #{global_options[:multiple_y_axes]},"
    output << "\n  plot_area:               '#{global_options[:plot_area_id]}',"   if global_options[:plot_area_id]    # DIV-ID für Diagramm
    output << "\n  show_pin_icon:           #{global_options[:show_pin_icon]},"    if global_options[:show_pin_icon]
    output << "\n  show_y_axes:             #{global_options[:show_y_axes]},"
    output << "\n  top_level_container_id:  'content_for_layout',"
    output << "\n  direct_update_area:      '#{global_options[:direct_update_area]}'," if global_options[:direct_update_area]
    output << "\n  update_area:             '#{global_options[:update_area]}',"    if global_options[:update_area]
    output << "\n  width:                   '#{global_options[:width].to_s}',"
    output << "\n}"
    output

  end


# Berechnen diverser Column-Parameter
  def calculate_column_options(column_options, data)
    col_index = 0
    # Berechnung von Spaltensummen
    column_options.each do |col|
      col[:caption] = escape_js_chars(col[:caption])  # Sonderzeichen in caption escapen
      col[:title]   = ecape_js_chars_without_br(col[:title])    # Sonderzeichen in title escapen, ausser \n, das vom tooltip so datgestellt werden kann
      col[:name]  = "col#{col_index}";   # Eindeutiger Spaltenname
      col[:index] = col_index            # mit 0 beginnende Numerierung der Spalten
      col_index = col_index+1
    end

  end

  public


  # Ausgabe einer Table per SlickGrid
  # Parameter:
  #   data:     Array mit Objekt je auszugebende Zeile
  #   column_options:  Array mit Hash je Spalte
  #     :align                => Ausrichtung
  #     :caption              => Spalten-Header
  #     :css_class            => class für Feld
  #     :data                 => Ausdruch für Ausgabe der Daten (rec = aktuelles Zeilen-Objekt
  #     :data_style           => Style für Spaltendaten (:style genutzt, wenn nicht definiert)
  #     :data_title           => MouseOver-Hint für Spaltendaten (:title genutzt, wenn nicht definiert), "%t" innerhalb des data_title wird mit Inhalt von :title ersetzt
  #     :field_decorator_function => Javascript-Funktionskörper, return cell-html, folgenden Variablen sind belegt:
  #         slickGrid           Referenz auf SlickGridExtended-Objekt
  #         row_no,cell_no      Nr. beginnend mit 0
  #         cell_value:         Wert der Zelle in data
  #         full_cell_value     Wert der Zelle in dataContext['metadata']['columns'][columnDef['field']['fulldata'], sonst identisch mit cell_value
  #         columnDef:    Spaltendefinition
  #         dataContext:  komplette Zeile aus data-Array
  #     :hidden               => true für Unterdrücken Anzeige der Spalte
  #     :header_class         => class-Ausdruck für <th> Spaltenheader
  #     :max_wrap_width       => Maximale Breite der Spalte in Pixel im Umbruchmodus (Es wird versucht, durch Reduktion der Spaltenbreiten die Tabelle ohne hor. Scrollbar darzustellen)
  #     :no_wrap              => Keinen Umbruch in Spalte akzeptieren <true|false>, Default = false
  #     :plot_master          => Spalte ist X-Achse für Diagramm-Darstellung <true>
  #     :plot_master_time     => Spalte ist x-Achse mit Datum/Zeit, die als Zeitstrahl dargestellt werden soll <true>
  #     :show_pct_background  => true für Anzeige des %-Anteil des Feldes an der Summe aller Records als transparenter horizontaler Füllstand
  #     :show_pct_hint        => true für Anzeige des %-Anteil des Feldes an der Summe aller Records als Zusatz zum MouseOver-Hint
  #     :style                => Style für Spaltenheader und Spaltendaten
  #     :title                => MouseOver-Hint für Spaltenheader und Spaltendaten
  #   global_options: Hash mit globalen Optionen
  #     :caption              => Titel vor Anzeige der Tabelle, darf keine "'" enthalten
  #     :caption_style        => Style-Attribute für caption der Tabelle
  #     :caption_title        => MouseOver-Hint for table caption
  #     :command_menu_entries => Array with hashes or single hash for actions available in caption bar: :name, :caption, :hint, :icon_class=>"cui-xxx", :show_icon_in_caption=>true|false|:only\:right ,  :action=>javascript
  #     :context_menu_entries => Array mit Hashes bzw. einzelner Hash mit weiterem Eintrag für Context-Menu: :caption, :icon_class, :action (only if no sub-entries defined), :hint, items: Array with hashes for sub-entries if entry is a node (no action)
  #     :div_style            => Einpacken der Tabelle in Div mit diesem Style
  #     :data_filter          => Name der JavaScript-Methode für filtern der angezeigten Zeilen: Methode muss einen Parameter "item" besitzen mit aktuell zu prüfender Zeile
  #     :grid_id              => DOM-ID des DIV-Elementes für slickgrid
  #     :height               => Höhe der Tabelle in Pixel oder '100%' für Parent ausfüllen oder :auto für dynam. Hoehe in Anhaengigkeit der Anzahl Zeilen, Default=:auto
  #     :line_height_single   => Einzeilige Anzeige in Zeile der Tabelle oder mehrzeilige Anzeige wenn durch Umburch im Feld nötig (true|false)
  #     :max_height           => max. Höhe Höhe der Tabelle in Pixel (px) als numerischen Wert, oder JavaScript-Ausdruck
  #     :multiple_y_axes      => Jedem Wert im Diagramm seinen eigenen 100%-Wertebereich der y-Achse zuweisen (true|false)
  #     :no_wrap              => Keinen Umbruch aller Spalten akzeptieren <true|false>, Default = false
  #     :plot_area_id         => div für Anzeige des Diagrammes (überschreibt Default hinter table)
  #     :show_pin_icon        => Show pin icon at right header box to prevent grid from being overwritten by parent refresh: 0..n for number of parents to step up in DOM until moving content to new div
  #     :show_y_axes          => Anzeige der y-Achsen links im Diagramm? (true|false)
  #     :direct_update_area   => Render target DIV for links within Slickgrid container before :update_area. Ensures that pinned grids will preserve the link target
  #     :update_area          => Render target DIV for links within Slickgrid container. Ensures that pinned grids will preserve the link target
  #     :width                => Weite der Tabelle (Default="100%", :auto=nicht volle Breite)

  def gen_slickgrid(data, column_options, global_options={})

    # Test auf numerische Werte, nil und "" als numerisch annehmen
    def numeric?(object)
      return true unless object
      return true if object==''
      true if Float(object) rescue false
    end

    raise "gen_slickgrid: Parameter-Type #{data.class.name} found for parameter data, but Array or SqlSelectIterator expected" unless ['Array', 'PanoramaConnection::SqlSelectIterator'].include? data.class.name
    raise "gen_slickgrid: Parameter-Type #{column_options.class.name} found for parameter column_options, but Array expected"  unless column_options.class == Array

    # Defaults für global_options
    global_options[:caption]            = escape_js_chars(global_options[:caption])    # Sonderzeichen in caption escapen
    if global_options[:caption]
      global_options[:caption_style]    = 'font-weight: bold;' unless global_options[:caption_style]
      global_options[:caption]          = "<span style=\"#{global_options[:caption_style]}\" title=\"#{global_options[:caption_title]}\">#{global_options[:caption]}</span>"
    end

    global_options[:command_menu_entries] = [global_options[:command_menu_entries]] if global_options[:command_menu_entries] && global_options[:command_menu_entries].class == Hash

    global_options[:width]              = '100%'                                unless global_options[:width]         # Default für Weite wenn nichts anderes angegeben
    global_options[:width]              = :auto                                 if global_options[:width] == 'auto'   # Symbol verwenden
    global_options[:height]             = :auto                                 unless global_options[:height]
    global_options[:multiple_y_axes]    = true                                  if global_options[:multiple_y_axes] == nil
    global_options[:show_y_axes]        = true                                  unless global_options[:show_y_axes]
    global_options[:line_height_single] = false                                 unless global_options[:line_height_single]



    calculate_column_options(column_options, data)    # Berechnen diverser Spaltenparameter

    if global_options[:grid_id]
      table_id = global_options[:grid_id]
    else
      table_id  = "grid_#{rand(99999999)}"                                      # Zufallszahl für html-ID
    end

    output = ''
    output << "<div id='#{table_id}' style='"
    output << "height:#{global_options[:height]};" unless global_options[:max_height]
    output << "'></div>\n"

    output << "<script type='text/javascript'>\n"
    output << "jQuery(function($){\n"                                           # Beginn anonyme Funktion
    # Ermitteln Typ der Spalte für Sortierung
    column_options.each do |col|
      col[:isFloat] = true                                                      # Default-Annahme, die nachfolgend zu prüfen ist
      col[:isDate]  = true                                                      # Default-Annahme, die nachfolgend zu prüfen ist
      col[:no_wrap] = true if global_options[:no_wrap]                          # Vererben Eigenschaft an alle Spalten
    end
    # erstellen JS-ata
    output << "var data=[\n"
    data.each do |rec|
      output << '{'
      metadata = ''
      column_options.each do |col|
        begin
          if col[:data].class == Proc
            celldata = (col[:data].call(rec)).to_s                              # Inhalt eines Feldes incl. html-Code für Link, Style etc., Ressourcen-Intensiv
          else
            celldata = eval_with_rec("#{col[:data]}.to_s", rec)                 # Inhalt eines Feldes incl. html-Code für Link, Style etc.
          end
        rescue Exception => e
          ExceptionHelper.reraise_extended_exception(e, "evaluating :data-expression for column '#{col[:caption]}'")
        end
        begin
          # Clone celldata while encoding to avoid "can't modify frozen String" if using encode!
          celldata = celldata.encode(Encoding::UTF_8) if celldata.encoding != Encoding::UTF_8 # Ensure that other content is translated to UTF-8
        rescue Exception => e
          celldata = "Error #{e.class}: #{e.message} converting result for column '#{col[:caption]}'".gsub(/\\x/, '0x')
          # raise "Error #{e.class}: '#{e.message}' converting result for column '#{col[:caption]}' from #{celldata.encoding} to #{Encoding::UTF_8}"
        end
        stripped_celldata = strip_inner_html(celldata)                          # Inhalt des Feldes befreit von html-tags, Ressourcen-Intensiv

        # SortType ermitteln
        if col[:isFloat] && stripped_celldata && stripped_celldata.length > 0   # Spalte testen, kann numerisch sein
          Float(stripped_celldata.delete('.').delete(',')) rescue col[:isFloat] = false            # Keine Nummer
        end
        if col[:isDate]  && stripped_celldata && stripped_celldata.length > 0
          if stripped_celldata.length >= 10
            case get_locale
              when 'de' then
                col[:isDate] = false if stripped_celldata[2,1] != '.' || stripped_celldata[5,1] != '.' # Test auf Trennzeichen der Datum-Darstellung
              else
                col[:isDate] = false                                            # Date format does not matter because string-sorting is right for date also
            end
          else
            col[:isDate] = false
          end
        end

        # Title ermitteln
        title = ''
        if col[:data_title]
          begin
            title << col[:data_title].call(rec).to_s if col[:data_title].class == Proc # Ersetzungen im string a'la "#{}" ermoeglichen
            title << eval_with_rec("\"#{col[:data_title]}\"", rec)  unless col[:data_title].class == Proc # Ersetzungen im string a'la "#{}" ermoeglichen
          rescue Exception => e
            ExceptionHelper.reraise_extended_exception(e, "processing data_title-rule for column #{col[:caption]}")
          end
          title['%t'] = col[:title] if title['%t'] && col[:title]   # einbetten :title in :data_title, wenn per %t angewiesen
        end

        # Style ermitteln
        style = nil
        if col[:data_style]
          style = col[:data_style].call(rec).to_s                 if col[:data_style].class == Proc  # Ersetzungen im string "#{}" ermoeglichen
          style = eval_with_rec("\"#{col[:data_style]}\"", rec)   unless col[:data_style].class == Proc  # Ersetzungen im string "#{}" ermoeglichen
        end

        output << "#{col[:name]}: '#{escape_js_chars stripped_celldata}',"
        if (title && title != '') || (style && style != '') || (celldata != stripped_celldata)
          metadata << "#{col[:name]}: {"
          metadata << "title:    '#{ecape_js_chars_without_br title}',"    if title && title != ''    # \n erhalten bei esacpe, da das vom tooltip so dargestellt werden kann
          metadata << "style:    '#{escape_js_chars style}',"    if style && style != ''
          metadata << "fulldata: '#{escape_js_chars celldata}'," if celldata != stripped_celldata  # fulldata nur speichern, wenn html-Tags die Zell-Daten erweitern
          metadata << '},'
        end
      end
      output << "\nmetadata: { columns: { #{metadata} } }," if metadata != ''
      output << "},\n"
    end
    output << '];' # Data

    output << "var options = #{prepare_js_global_options_for_slickgrid(table_id, global_options)};"      # Global Options definieren
    output << "var columns = #{prepare_js_columns_for_slickgrid(table_id, column_options)};"      # JS-columns definieren

    ################### Context-Menu ########################
    output << "let additional_menu_entries = ["
    context_menu_entries = global_options[:context_menu_entries]
    if context_menu_entries
      context_menu_entries = [context_menu_entries] if context_menu_entries.class == Hash  # Einzelnen Hash in Array einbetten, wenn nicht Array üebergeben wurde
      raise "Parameter :context_menu_entries is expected as Hash or Array, not #{context_menu_entries.class.name}" if context_menu_entries.class != Array

      print_entry_list = proc do |entries|
        entries.each do |entry|
          output << "  { caption:   \"#{entry[:caption]}\",\n"
          output << "    hint:    \"#{entry[:hint]}\",\n"
          output << "    icon_class: \"#{entry[:icon_class] ? entry[:icon_class] : 'cui-image'}\",\n"
          if entry[:items]                                    # Entry is a node for subentries
            output << "    items: [\n"
            print_entry_list.call(entry[:items])
            output << "    ]\n"
          else
            output << "    action:  function(t){ #{entry[:action]}}\n"
          end
          output << "  }"
          output << "," unless entry == entries.last
          output << "\n"
        end
      end

      print_entry_list.call(context_menu_entries)
    end
    output << '];' # Ende Context-Menu

    output << "createSlickGridExtended('#{table_id}', data, columns, options, additional_menu_entries);"    # Aufbau des slickGrid

    output << '});' # Ende anonyme function

    output << '</script>'
    output.html_safe
  end
end