# Diverse Hilfsmethoden zum Zeichnen von Diagrammen
module DiagramHelper

  # Anzeigen Werteliste in Diagramm
  # Parameter als Hash mit folgenden Inhalten:
  #   :data_array:        Array von Hashes mit 3 Werten:
  #                       - Zeitbezug als DateTime
  #                       - Kurve als String oder Number
  #                       - Value als Number
  #   :time_key_name:     Keyname des Zeitbezuges im Hash
  #   :curve_key_name:    Keyname der Kurve im Hash
  #   :value_key_name:    Keyname des Wertes im Hash
  #   :top_x:             Anzahl darstellbare Kurven
  #   :caption:           Überschrift des Diagrammes
  #   :update_area:       DIV zur Darstellung des Diagrammes
  #   :null_points_cycle: Zyklus in Sekunden, aller derer ein 0-Punkt eingefügt wird, wenn nicht ein valider Wert existiert, keine Anwendung der Funktion, wenn nicht angegeben

  def plot_top_x_diagramm(param)
    origin_data_array = param[:data_array]
    time_key_name     = param[:time_key_name]
    curve_key_name    = param[:curve_key_name]
    value_key_name    = param[:value_key_name]
    top_x             = param[:top_x]
    caption           = param[:caption]
    update_area       = param[:update_area]
    null_points_cycle = param[:null_points_cycle]


    # Sortieren wenn die gesamte Menge an Daten bereits vor der Iteration bekannt ist (wie im Array)
    origin_data_array.sort!{ |a,b| a[time_key_name] <=> b[time_key_name] } if origin_data_array.class == Array

    # Pivot-Tabelle anlegen
    graph_sums          = {}                                                    # Unterschiedliche Kurven die zu zeichnen sind mit Summen je Graph
    result_data_array   = []                                                    # Result-Array
    record              = {}
    first_timestamp     = nil                                                   # Begrenzer des Zeitraumes mit gültigen Werten
    origin_data_array.each do |s|                                               # Iteration über einzelwerte
      first_timestamp = s[time_key_name] if first_timestamp.nil?                # Merken des ersten Zeitwertes

      record[:timestamp] = s[time_key_name] unless record[:timestamp]           # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record[:timestamp] != s[time_key_name]                                 # Neuer Zeitpunkt
        result_data_array << record                                                          # Wegschreiben des alten Zeitpunkt-Records
        record = {}                                                             # Neuer Record bis naechsten Gruppenwechsel
        record[:timestamp] = s[time_key_name]                                   # Zeitpunkt merken im Record
      end
      record[s[curve_key_name]] = s[value_key_name]
      graph_sums[s[curve_key_name]] = 0 unless graph_sums[s[curve_key_name]]    # Existenz der Kurve merken
      graph_sums[s[curve_key_name]] += record[s[curve_key_name]] ||= 0          # Summe kumulieren
    end
    result_data_array << record unless record.empty?                            # Letzten Record in Array schreiben wenn Daten vorhanden

    if null_points_cycle                                                        # Austasten der Lücken mit NullPunkten
      current_timestamp = first_timestamp
      index = 0
      while index < result_data_array.length do
        rec = result_data_array[index]
        if rec[:timestamp] > current_timestamp                                  # Zwischenschritt fehlt
          rec = {:timestamp => current_timestamp }
          result_data_array.insert(index, rec)
        end
        graph_sums.each do |key, val|                                           # Iteration über die Spalten
          rec[key] = 0 unless rec[key]                                          # Spalte als 0 deklarieren wenn nicht belegt im Record
        end

        index = index + 1
        current_timestamp = current_timestamp + null_points_cycle               # Nächster erwarteter Zeitpunkt
      end

    end

    graph_array = graph_sums.sort_by(&:last)                                    # Wandeln des Hashes in aufsteigend sortiertes Array

    others_name = '[ Others ]'                                                  # Name der Kurve für den Rest

    # Limitieren auf top x
    while graph_array.length > top_x-1 do
      # Others-Kurve kumulieren
      result_data_array.each do |r|
        r[others_name] = 0 unless r[others_name]                                # Initialisieren bei erstem Zugriff
        r[others_name] += r[graph_array[0][0]] if r[graph_array[0][0]]          # Kumulieren der nicht zu Top x gehörenden Werte unter others
      end

      graph_array.delete_at(0)                                                  # jeweils ersten (kleinsten) Eintrag entfernen aus Array, solange Anzahl noch zu groß
    end

    graph_array.insert(0, [others_name, 0])

    # Initialisieren aller anzuzeigenden Werte (Top x) zum Zeitpunkt mit 0, falls kein Sample existiert
    graph_array.each do |g|
      result_data_array.each do |r|
        r[g[0]] = 0 unless r[g[0]]
      end
    end


    # JavaScript-Array aufbauen mit Daten
    output = ""
    output << "jQuery(function($){"
    output << "var data_array = ["
    graph_array.each do |g|                                             # Ausgabe mit groesstem beginnen
      output << "  { label: '#{g[0]}',"
      output << "    data: ["
      result_data_array.each do |s|
        output << "[#{milliSec1970(s[:timestamp])}, #{s[g[0]]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    unique_area_id = get_unique_area_id

    plot_area_id = "plot_area_#{unique_area_id}"
    output << "var options = {plot_diagram: {locale: '#{get_locale}'},
                              yaxis: { min: 0 },
                              legend:{sorted: 'reverse'}
                             };"
    output << "plot_diagram('#{unique_area_id}', '#{plot_area_id}', '#{caption}', data_array, options);"

    output << "});"

    html="<div id='#{plot_area_id}'></div>"
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j html}');
                                #{ output}"
      }
    end


  end
end