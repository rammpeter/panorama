# Diverse Hilfsmethoden zum Zeichnen von Diagrammen
module DiagramHelper

  # Anzeigen Werteliste in Diagramm
  # Parameter als Hash mit folgenden Inhalten:
  #   :data_array: Array von Hashes mit 3 Werten:
  #               - Zeitbezug als DateTime
  #               - Kurve als String oder Number
  #               - Value als Number
  #   :time_key_name:  Keyname des Zeitbezuges im Hash
  #   :curve_key_name: Keyname der Kurve im Hash
  #   :value_key_name: Keyname des Wertes im Hash
  #   :top_x:          Anzahl darstellbare Kurven
  #   :caption:        Überschrift des Diagrammes
  #   :update_area:    DIV zur Darstellung des Diagrammes

  def plot_top_x_diagramm(param)
    origin_data_array = param[:data_array]
    time_key_name     = param[:time_key_name]
    curve_key_name    = param[:curve_key_name]
    value_key_name    = param[:value_key_name]
    top_x             = param[:top_x]
    caption           = param[:caption]
    update_area       = param[:update_area]


    origin_data_array.sort!{ |a,b| a[time_key_name] <=> b[time_key_name] }

    # Pivot-Tabelle anlegen
    graph_sums   = {}                                                           # Unterschiedliche Kurven die zu zeichnen sind mit Summen je Graph
    result_data_array = []                                                      # Result-Array
    record = {}
    origin_data_array.each do |s|                                               # Iteration über einzelwerte
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
    result_data_array << record if origin_data_array.length > 0                 # Letzten Record in Array schreiben wenn Daten vorhanden

    # Initialisieren aller Werte zum Zeitpunkt mit 0, falls kein Sample existiert
    graph_sums.each do |key, v|
      result_data_array.each do |r|
        r[key] = 0 unless r[key]
      end
    end

    graph_array = graph_sums.sort_by(&:last)                                    # Wandeln des Hashes in aufsteigend sortiertes Array

    # Limitieren auf top x
    while graph_array.length > top_x do
      graph_array.delete_at(0)                                                  # ersten Eintrag entfernen aus Array
    end

    # JavaScript-Array aufbauen mit Daten
    output = ""
    output << "jQuery(function($){"
    output << "var data_array = ["
    graph_array.reverse.each do |g|                                             # Ausgabe mit groesstem beginnen
      output << "  { label: '#{g[0]}',"
      output << "    data: ["
      result_data_array.each do |s|
        output << "[#{milliSec1970(s[:timestamp])}, #{s[g[0]]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    plot_area_id = "plot_area_#{session[:request_counter]}"
    output << "plot_diagram('#{session[:request_counter]}', '#{plot_area_id}', '#{caption}', data_array, {plot_diagram: {locale: '#{session[:locale]}'}, yaxis: { min: 0 }});"

    output << "});"

    html="<div id='#{plot_area_id}'></div>"
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j html}');
                                #{ output}"
      }
    end


  end
end