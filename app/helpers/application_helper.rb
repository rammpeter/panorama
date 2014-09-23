# encoding: utf-8

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include KeyExplanationHelper
  include AjaxHelper
  include DiagramHelper
  include HtmlHelper
  include ActionView::Helpers::SanitizeHelper
  include DatabaseHelper

 #def list_tns_names
 #
 #    if ENV['ORACLE_HOME']
 #       IO.readlines( "#{ENV['ORACLE_HOME']}/network/admin/tnsnames.ora" ).select { |e| /^[A-Z]/.match( e ) }.collect { |e| e.split('=')[0] }.sort
 #    else
 #      IO.readlines( "d:/Programme/ora92/network/admin/tnsnames.ora" ).select { |e| /^[A-Z]/.match( e ) }.collect { |e| e.split('=')[0] }.sort
 #  end
 # end

  # Helper fuer Ausführung SQL-Select-Query,
  # return Array of Hash mit Columns des Records
  def sql_select_all(sql)   # Parameter String mit SQL oder Array mit SQL und Bindevariablen
    binds = []
    if sql.class == Array
      stmt =sql[0].clone      # Kopieren, da im Stmt nachfolgend Ersetzung von ? durch :A1 .. :A<n> durchgeführt wird
      # Aufbereiten SQL: Ersetzen Bind-Aliases
      bind_index = 0
      while stmt['?']                   # Iteration über Binds
        bind_index = bind_index + 1
        bind_alias = ":A#{bind_index}"
        stmt['?'] = bind_alias          # Ersetzen ? durch Host-Variable
        unless sql[bind_index]
          raise "bind value at position #{bind_index} is NULL for '#{bind_alias}' in binds-array for sql: #{stmt}"
        end
        raise "bind value at position #{bind_index} missing for '#{bind_alias}' in binds-array for sql: #{stmt}" if sql.count <= bind_index
        binds << [ActiveRecord::ConnectionAdapters::Column.new(bind_alias, nil), sql[bind_index]]
      end
    else
      if sql.class == String
        stmt = sql
      else
        raise "Unsupported Parameter-Class '#{sql.class.name}' for parameter sql of sql_select_all(sql)"
      end
    end
    result = ActiveRecord::Base.connection().select_all(stmt, 'sql_select_all', binds)
    result.each do |h|
      h.each do |key, value|
        h[key] = value.strip if value.class == String   # Entfernen eines eventuellen 0x00 am Ende des Strings, dies führt zu Fehlern im Internet Explorer
      end
      h.extend SelectHashHelper    # erlaubt, dass Element per Methode statt als Hash-Element zugegriffen werden können
    end
    result.to_ary                                                               # Ab Rails 4 ist result nicht mehr vom Typ Array, sondern ActiveRecord::Result
  end

  # Select genau erste Zeile
  def sql_select_first_row(sql)
    result = sql_select_all(sql)
    return nil if result.empty?
    result[0].extend SelectHashHelper      # Erweitern Hash um Methodenzugriff auf Elemente
  end

  # Select genau einen Wert der ersten Zeile des Result
  def sql_select_one(sql)
    result = sql_select_first_row(sql)
    return nil unless result
    result.first[1]           # Value des Key/Value-Tupels des ersten Elememtes im Hash
  end

  # Einlesen und strukturieren der Datei tnsnames.ora
  def read_tnsnames

    tnsnames = {}

    if ENV['TNS_ADMIN']
      tnsadmin = ENV['TNS_ADMIN']
    else
      if ENV['ORACLE_HOME']
        tnsadmin = "#{ENV['ORACLE_HOME']}/network/admin"
      else
        logger.warn 'read_tnsnames: TNS_ADMIN or ORACLE_HOME not set in environment, no TNS names provided'
        return tnsnames # Leerer Hash
      end
    end

    fullstring = IO.read( "#{tnsadmin}/tnsnames.ora" )
    
    while true 
      # Ermitteln TNSName
      start_pos_description = fullstring.index('DESCRIPTION')
      break unless start_pos_description                               # Abbruch, wenn kein weitere DESCRIPTION im String
      tns_name = fullstring[0..start_pos_description-1]
      while tns_name[tns_name.length-1,1].match '[=,\(, ,\n,\r]'            # Zeichen nach dem TNSName entfernen
        tns_name = tns_name[0, tns_name.length-1]                         # Letztes Zeichen des Strings entfernen
      end
      while tns_name.index("\n")                                        # Alle Zeilen vor der mit DESCRIPTION entfernen
        tns_name = tns_name[tns_name.index("\n")+1, 10000]                # Wert akzeptieren nach Linefeed wenn enthalten
      end
      fullstring = fullstring[start_pos_description + 10, 1000000]     # Rest des Strings fuer weitere Verarbeitung

      next if tns_name[0,1] == "#"                                              # Auskommentierte Zeile

      # ermitteln Hostname
      start_pos_host = fullstring.index('HOST')
      # Naechster Block mit Description beginnen wenn kein Host enthalten oder in naechster Description gefunden
      next if start_pos_host==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_host)    # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_host + 5, 1000000]
      hostName = fullstring[0..fullstring.index(')')-1]
      hostName = hostName.delete(' ').delete('=') # Entfernen Blank u.s.w
      
      # ermitteln Port
      start_pos_port = fullstring.index('PORT')
      # Naechster Block mit Description beginnen wenn kein Port enthalten oder in naechster Description gefunden
      next if start_pos_port==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_port) # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_port + 5, 1000000]
      port = fullstring[0..fullstring.index(')')-1]
      port = port.delete(' ').delete('=')      # Entfernen Blank u.s.w.

      # ermitteln SID oder alternativ Instance_Name oder Service_Name
      sid_tag_length = 4
      sid_usage = :SID
      start_pos_sid = fullstring.index('SID=')                                  # i.d.R. folgt unmittelbar ein "="
      start_pos_sid = fullstring.index('SID ') if start_pos_sid.nil?            # evtl. " " zwischen SID und "="
      if start_pos_sid.nil? || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
        sid_tag_length = 12
        sid_usage = :SERVICE_NAME
        start_pos_sid = fullstring.index('SERVICE_NAME')
      end
      # Naechster Block mit Description beginnen wenn kein SID enthalten oder in naechster Description gefunden
      next if start_pos_sid==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_sid + sid_tag_length, 1000000]               # Rest des Strings fuer weitere Verarbeitung
      
      sidName = fullstring[0..fullstring.index(')')-1]
      sidName = sidName.delete(' ').delete('=')   # Entfernen Blank u.s.w.
   
      # Kompletter Record gefunden
      tnsnames[tns_name] = {:hostName => hostName, :port => port, :sidName => sidName, :sidUsage =>sid_usage }
    end
    tnsnames
  rescue Exception => e
    Rails.logger.error "Error processing tnsnames.ora: #{e.message}"
    tnsnames
  end

  # Genutzt zur Anzeige im zentralen Screen
  def current_tns 
    if session[:database] && session[:database].class.name == 'Database'
      database_helper_tns
    else
      '[Keine]'
    end
  end 

  # ID der Instance auf der der User angemeldet ist
  def current_instance_number
    sql_select_one 'SELECT Instance_Number FROM v$Instance'
  end

  def formattedNumber(number,                 # Auszugebende Zahl (Integer oder Float)
                      decimalCount=0,         # Anzahl Dezimalstellen
                      supress_0_value=false   # Unterdrücken der Ausgabe bei number=0 ?
                     )
    decimal_delimiter   = numeric_decimal_separator
    thousands_delimiter = numeric_thousands_separator
    return '' unless number;  # Leere Ausgabe bei nil
    number = number.to_f if number.instance_of?(String) || number.instance_of?(BigDecimal)   # Numerisches Format erzwingen
    number = number.round(decimalCount) if number.instance_of?(Float) # Ueberlauf von Stellen kompensieren

    raise "formattedNumber: unsupported datatype #{number.class}" if !(number.instance_of?(Float) || number.instance_of?(Fixnum) || number.instance_of?(Bignum))

    return if supress_0_value && number == 0  # Leere Ausgabe bei Wert 0 und Unterdrückung Ausgabe angefordert

    if decimalCount > 0 
      decimal = number.abs-number.abs.floor  # Dezimalanteil ermitteln
      decimalCount.times do
        decimal *= 10
      end
      output = decimal_delimiter+sprintf('%.*d', decimalCount, decimal.round) # Dezimale mit Vornullen
    else
      output = '' # Keine Dezimalausgabe
    end
    stringNumber = number.abs.to_i.to_s     # mit ganzzahligem Rest weiter
    tausender = 0
    (stringNumber.length-1).downto(0) { |i|
      tausender+= 1
      if tausender > 3
        output = thousands_delimiter + output
        tausender = 1
      end
      output = stringNumber[i].chr + output 
     }
    output = '-'+output if number < 0
    output
  end

  alias fn formattedNumber

  # Sichere Division / 0 absichern
  def secure_div(divident, divisor)
    return nil if divisor == 0
    divident.to_f/divisor
  end


  # Zeistempel in sprach-lokaler Notation ausgeben
  def localeDateTime(timestamp, format = :seconds)
    return '' unless timestamp                    # Leere Ausgabe, wenn nil
    timestamp = timestamp.to_datetime             # Sicherstellen, dass vom Typ DateTime
    case format
      when :seconds then timestamp.strftime(strftime_format_with_seconds)
      when :minutes then timestamp.strftime(strftime_format_with_minutes)
    else
      raise "Unknown parameter format = #{format} in localeDateTime"
    end
  end

  # Milli-Sekunden seit 1970
  def milliSec1970(timestamp)
    timestamp.strftime('%s').to_i * 1000
  end

  # Maskieren von html-special chars incl. NewLine
  def my_html_escape(org_value)
    '' if org_value.nil?
    ERB::Util.html_escape(org_value).   # Standard-Escape kann kein NewLine-><BR>
      gsub(/\n/, '<br>').  # Alle vorkommenden NewLine ersetzen
      gsub(/\r/, '')      # Alle vorkommenden CR ersetzen, führt sonst bei Javascript zu Error String not closed
  end

  # Ermitteln prozentualen Anteil
  def percentage(single, sum)
    single && sum && sum != 0 ? single.to_f/sum*100 : 0
  end

  # Anzeige eines Prozentwertes mit unterlegter Balkengrafik, JS muss ohne Linefeed ausgegeben werden, sonst Fehlinterpretation <BR> im Browser
  def show_percentage(single, sum)
    if single && sum && sum != 0
      "<div \
            style=\"background-image: -webkit-linear-gradient(left, gray 0%, lightgray #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) 100%);  \
                   background-image: -moz-linear-gradient(left, gray 0%, lightgray #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) 100%);     \
                   background-image: linear-gradient(left, gray 0%, lightgray #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) #{fn(percentage(single, sum))}%, rgba(255, 255, 255, 0) 100%);          \
                  \"                                                                                                                                                                                           \
       >#{fn(percentage(single, sum),1)}%</div>".html_safe
    else
      ''
    end
  end

  # Aufbereiten des Parameters "instance" aus Request, return nil wenn kein plausibler Wert
  def prepare_param_instance
    retval = params[:instance].to_i
    retval = nil if retval == 0
    session[:instance]  = retval      # Werte puffern fuer spaetere Wiederverwendung
    retval
  end

  # Aufbereiten des Parameters "dbid" aus Request, return session-default wenn kein plausibler Wert
  def prepare_param_dbid
    retval = params[:dbid]
    retval = session[:database][:dbid] unless retval
    retval
  end

  # Ermitteln der minimalen und maximalen Snap-ID zu gebenen Zeiten einer Instance
  # Format "DD.MM.YYYY HH:MI" bzw.sql_datetime_minute_mask (locale)
  # Belegt die Instance-Variablen @min_snap_id und @max_snap_id
  def get_instance_min_max_snap_id(time_selection_start, time_selection_end, instance)
    additional_where = ''
    additional_binds = []
    if instance && instance != 0
      additional_where << ' AND Instance_Number = ?'
      additional_binds << instance
    end

    snaps = sql_select_all ["
      SELECT /* Panorama-Tool Ramm */ Min(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
      FROM   DBA_Hist_Snapshot
      WHERE  Begin_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      AND    Begin_Interval_Time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      AND    DBID            = ?
      #{additional_where}",
                            time_selection_start, time_selection_end, prepare_param_dbid].concat(additional_binds)
    raise "Kein Snapshot gefunden zwischen #{time_selection_start} und #{time_selection_end} für Instance #{instance}" if snaps.length == 0
    @min_snap_id = snaps[0].min_snap_id      # Kleinste ID
    @max_snap_id = snaps[0].max_snap_id      # Groesste ID
    raise "Kein Snapshot gefunden zwischen #{time_selection_start} und #{time_selection_end} für Instance #{instance}" unless @min_snap_id
  end

  # Generische Methode zum Fuellen von Collections
  # liefert Array mit Results
  # Aufruf z.B.: @employees = fill_collection Employee, "[Keiner]"
  # Klasse muss id und name enthalten
  def fill_default_collection(classtype, dummy_name='[Alle]', show_id=true)
    colls = []
    dummy = classtype.new :name => dummy_name
    dummy.id = nil
    colls << dummy
    dbcolls = classtype.all :order => (show_id ? 'id' : 'name')
    dbcolls.each { |d| colls << d }
    colls
  end

  # Sichern der Parameter time_selection_start und time_selection_end in session, Prüfen auf Valides Format
  def save_session_time_selection
    def check_timestamp_picture(ts)    # Test auf struktur DD.MM.YYYY HH:MM
      # Test auf Identität der Trennzeichen zwischen Maske und Prüftext
      index = 0
      sql_datetime_minute_mask.split(//).each do |m|
        unless m.count 'DMYH24I:' # Maskenzeichen an Position enthält nicht einen der Werte
          raise "Trenner an Position #{index} ist nicht '#{m}'" if ts[index,1] != m
        end
        index = index+1
      end

      daypos = sql_datetime_minute_mask.index 'DD'
      raise 'Länge des Ausdrucks != 16' if ts.length != 16
      raise 'Tag nicht zwischen 01 und 31'        if  ts[daypos,1] < '0' || ts[daypos,1] > '3' ||      # Tag
                                                      ts[daypos+1,1] < '0' || ts[daypos+1,1] > '9' ||
                                                      ts[daypos,2].to_i < 1  ||
                                                      ts[daypos,2].to_i > 31

      monthpos = sql_datetime_minute_mask.index 'MM'
      raise 'Monat nicht zwischen 01 und 12'      if ts[monthpos,1] < '0' || ts[monthpos,1] > '1' ||      # Monat
                                                     ts[monthpos+1,1] < '0' || ts[monthpos+1,1] > '9' ||
                                                     ts[monthpos,2].to_i < 1  ||
                                                     ts[monthpos,2].to_i > 12

      yearpos = sql_datetime_minute_mask.index 'YYYY'
      raise 'Jahr ist nicht zwischen 1000 und 2999' if ts[yearpos,1] < '1' || ts[yearpos,1] > '2' ||      #Jahr
                                                       ts[yearpos+1,1] < '0' || ts[yearpos+1,1] > '9' ||
                                                       ts[yearpos+2,1] < '0' || ts[yearpos+2,1] > '9' ||
                                                       ts[yearpos+3,1] < '0' || ts[yearpos+3,1] > '9'

      hourpos = sql_datetime_minute_mask.index 'HH24'
      raise 'Stunde ist nicht zwischen 00 und 23' if ts[hourpos,1] < '0' || ts[hourpos,1] > '2' ||    # Stunde
                                                       ts[hourpos+1,1] < '0' || ts[hourpos+1,1] > '9' ||
                                                       ts[hourpos,2].to_i > 23

      minutepos = sql_datetime_minute_mask.index('MI') - 2    # HH24 verbraucht 2 stellen mehr als in Realität
      raise 'Minute ist nicht zwischen 00 und 59' if ts[minutepos,1] < '0' || ts[minutepos,1] > '5' ||    # Minute
                                                       ts[minutepos+1,1] < '0' || ts[minutepos+1,1] > '9' ||
                                                       ts[minutepos,2].to_i > 59

      ts      # Return-wert
    rescue Exception => e
      raise "Ungültiges Format des Zeitstempels '#{ts}'. Erwartet wird '#{human_datetime_minute_mask}'! Problem: #{e.message}"
    end

    raise "Parameter 'time_selection_start' missung in hash 'params'" unless params[:time_selection_start]
    raise "Parameter 'time_selection_end' missung in hash 'params'"   unless params[:time_selection_end]
    @time_selection_start = params[:time_selection_start].rstrip
    @time_selection_end   = params[:time_selection_end].rstrip

    if @time_selection_start && @time_selection_start != ''
      session[:time_selection_start] = check_timestamp_picture(@time_selection_start)
    end
    if @time_selection_end && @time_selection_end != ''
      session[:time_selection_end] = check_timestamp_picture(@time_selection_end)
    end
  end

  # Vorbelegung fuer Eingabefeld
  def default_time_selection_start
    if session[:time_selection_start] && session[:time_selection_start] != ''
      session[:time_selection_start]
    else
      "#{Date.today.strftime(strftime_format_with_days)} 00:00"
    end
  end

  # Vorbelegung fuer Eingabefeld
  def default_time_selection_end
    if session[:time_selection_end] && session[:time_selection_end] != ''
      session[:time_selection_end]
    else
      "#{Date.today.strftime(strftime_format_with_days)} 13:00"
    end
  end


  # Entfernen aller umhüllenden Tags, umwandeln html-Ersetzungen
  def strip_inner_html(content)
    ActionController::Base.helpers.strip_tags(content).
        gsub('&nbsp;', ' ').
        gsub('&amp;', '&')
  end

private


  def escape_js_chars(input)      # Javascript-kritische Zeichen escapen in Strings
    return nil unless input
    input = input.dup  if input.frozen?          # Kopie des Objektes verwenden für Umgehung runtime-Error, wenn object frozen
    input.gsub!("'", '&#39;')    # einfache Hochkommas im Text fuer html als doppelte escapen für weitere Verwendung
    input.gsub!("\n", '<br>')    # Linefeed im Text fuer html escapen für weitere Verwendung, da sonst ParseError
    #input.gsub!("<", "&lt;")
    #input.gsub!(">", "&gt;")
    input
  end

private
  def eval_with_rec (input, rec)  # Ausführen eval mit Ausgabe des Inputs in Exception
    eval input
  rescue Exception=>e; raise "#{e.message} during eval of '#{input}'"
  end

public

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
      output << ' plot_master_time: 1,'           if col[:plot_master_time]
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
        raise "#{e.class.name}: #{e.message} Error processing prepare_js_columns_for_slickgrid for column #{col[:caption]}"
      end
    end
    output << ']'
    output
  end

  def prepare_js_global_options_for_slickgrid(table_id, global_options)
    output = '{'
    output << "  maxHeight:            #{global_options[:max_height]},"       if global_options[:max_height]      # max. Höhe in Pixel
    output << "  plot_area:            '#{global_options[:plot_area_id]}',"   if global_options[:plot_area_id]    # DIV-ID für Diagramm
    output << "  caption:              '#{global_options[:caption]}',"
    output << "  width:                '#{global_options[:width].to_s}',"
    output << "  multiple_y_axes:      #{global_options[:multiple_y_axes]},"
    output << "  show_y_axes:          #{global_options[:show_y_axes]},"
    output << "  line_height_single:   #{global_options[:line_height_single]},"
    output << "  locale:               '#{session[:locale]}',"
    output << '}'
    output

  end


    # Berechnen diverser Column-Parameter
  def calculate_column_options(column_options, data)
    col_index = 0
    # Berechnung von Spaltensummen
    column_options.each do |col|
      col[:caption] = escape_js_chars(col[:caption])  # Sonderzeichen in caption escapen
      col[:title]   = escape_js_chars(col[:title])    # Sonderzeichen in title escapen
      col[:name]  = "col#{col_index}";   # Eindeutiger Spaltenname
      col[:index] = col_index            # mit 0 beginnende Numerierung der Spalten
      if col[:show_pct_hint]
        col[:sum] = 0             # Initialisierung des Summenfeldes der Spalte
        data.each do |rec|
          val = col[:show_pct_hint].call(rec)   # Spaltenwert ermitteln
          col[:sum] = col[:sum] + (val ? val : 0)
        end
      end
      col_index = col_index+1
    end

  end

  # Ausgabe einer Table per SlickGrid
  # Parameter:
  #   data:     Array mit Objekt je auszugebende Zeile
  #   column_options:  Array mit Hash je Spalte
  #     :caption              => Spalten-Header
  #     :data                 => Ausdruch für Ausgabe der Daten (rec = aktuelles Zeilen-Objekt
  #     :title                => MouseOver-Hint für Spaltenheader und Spaltendaten
  #     :data_title           => MouseOver-Hint für Spaltendaten (:title genutzt, wenn nicht definiert), "%t" innerhalb des data_title wird mit Inhalt von :title ersetzt
  #     :style                => Style für Spaltenheader und Spaltendaten
  #     :data_style           => Style für Spaltendaten (:style genutzt, wenn nicht definiert)
  #     :align                => Ausrichtung
  #     :plot_master          => Spalte ist X-Achse für Diagramm-Darstellung <true>
  #     :plot_master_time     => Spalte ist x-Achse mit Datum/Zeit, die als Zeitstrahl dargestellt werden soll <true>
  #     :header_class         => class-Ausdruck für <th> Spaltenheader
  #     :show_pct_hint        => proc{|rec| xxx }-Ausdruck für Anzeige %-Anteil des Feldes an der Summe aller Records, muss numerischen Wert zurückgeben
  #     :no_wrap              => Keinen Umbruch in Spalte akzeptieren <true|false>, Default = false
  #   global_options: Hash mit globalen Optionen
  #     :caption              => Titel vor Anzeige der Tabelle, darf keine "'" enthalten
  #     :caption_style        => Style-Attribute für caption der Tabelle
  #     :width                => Weite der Tabelle (Default="100%", :auto=nicht volle Breite)
  #     :height               => Höhe der Tabelle in Pixel oder '100%' für Parent ausfüllen oder :auto für dynam. Hoehe in Anhaengigkeit der Anzahl Zeilen, Default=:auto
  #     :max_height           => max. Höhe Höhe der Tabelle in Pixel
  #     :plot_area_id         => div für Anzeige des Diagrammes (überschreibt Default hinter table)
  #     :div_style            => Einpacken der Tabelle in Div mit diesem Style
  #     :multiple_y_axes      => Jedem Wert im Diagramm seinen eigenen 100%-Wertebereich der y-Achse zuweisen (true|false)
  #     :show_y_axes          => Anzeige der y-Achsen links im Diagramm? (true|false)
  #     :context_menu_entries => Array mit Hashes bzw. einzelner Hash mit weiterem Eintrag für Context-Menu: :label, :icon, :action
  #     :line_height_single   => Einzeilige Anzeige in Zeile der Tabelle oder mehrzeilige Anzeige wenn durch Umburch im Feld nötig (true|false)

  def gen_slickgrid(data, column_options, global_options={})

    # Test auf numerische Werte, nil und "" als numerisch annehmen
    def numeric?(object)
      return true unless object
      return true if object==''
      true if Float(object) rescue false
    end

    raise "gen_slickgrid: Parameter-Type #{data.class.name} found for parameter data, but Array expected" unless data.class == Array
    raise "gen_slickgrid: Parameter-Type #{column_options.class.name} found for parameter column_options, but Array expected"  unless column_options.class == Array
    raise "gen_slickgrid: Parameter max_height should should be set numeric. 'px' this is added by generator" if global_options[:max_height] && global_options[:max_height].class!=Fixnum

    # Defaults für global_options
    global_options[:caption]            = escape_js_chars(global_options[:caption])    # Sonderzeichen in caption escapen
    if global_options[:caption]
      if global_options[:caption_style]
        global_options[:caption]            = "<span style=\"#{global_options[:caption_style]}\">#{global_options[:caption]}</span>"
      else
        global_options[:caption]            = "<span style=\"font-weight: bold;\">#{global_options[:caption]}</span>"
      end
    end
    global_options[:width]              = '100%'                                unless global_options[:width]         # Default für Weite wenn nichts anderes angegeben
    global_options[:width]              = :auto                                 if global_options[:width] == 'auto'   # Symbol verwenden
    global_options[:height]             = :auto                                 unless global_options[:height]
    global_options[:multiple_y_axes]    = true                                  if global_options[:multiple_y_axes] == nil
    global_options[:show_y_axes]        = true                                  unless global_options[:show_y_axes]
    global_options[:line_height_single] = false                                 unless global_options[:line_height_single]

    calculate_column_options(column_options, data)    # Berechnen diverser Spaltenparameter

    id_num = rand(99999999)  # Zufallszahl für html-ID
    table_id  = "grid_#{id_num}"

    output = ''
    output << "<div id='#{table_id}' style='"
    output << "height:#{global_options[:height]};" unless global_options[:max_height]
    output << "'></div>"

    output << "<script type='text/javascript'>"
    output << 'jQuery(function($){'                                             # Beginn anonyme Funktion
    # Ermitteln Typ der Spalte für Sortierung
    column_options.each do |col|
      col[:isFloat] = true                                                        # Default-Annahme, die nachfolgend zu prüfen ist
      col[:isDate]  = true                                                        # Default-Annahme, die nachfolgend zu prüfen ist
    end
    # erstellen JS-ata
    output << 'var data=['
    data.each do |rec|
      output << '{'
      metadata = ''
      column_options.each do |col|
        if col[:data].class == Proc
          celldata = (col[:data].call(rec)).to_s                                # Inhalt eines Feldes incl. html-Code für Link, Style etc.
        else
          celldata = eval_with_rec("#{col[:data]}.to_s", rec)                   # Inhalt eines Feldes incl. html-Code für Link, Style etc.
        end

        stripped_celldata = strip_inner_html(celldata)                          # Inhalt des Feldes befreit von html-tags

        # SortType ermitteln
        if col[:isFloat] && stripped_celldata && stripped_celldata.length > 0   # Spalte testen, kann numerisch sein
          Float(stripped_celldata.delete('.').delete(',')) rescue col[:isFloat] = false            # Keine Nummer
        end
        if col[:isDate]  && stripped_celldata && stripped_celldata.length > 0
          if stripped_celldata.length >= 10
            case session[:locale]
              when 'de' then
                col[:isDate] = false if stripped_celldata[2,1] != '.' || stripped_celldata[5,1] != '.' # Test auf Trennzeichen der Datum-Darstellung
              when 'en' then
                col[:isDate] = false if stripped_celldata[4,1] != '-' || stripped_celldata[7,1] != '-' # Test auf Trennzeichen der Datum-Darstellung
              else
                col[:isDate] = false if stripped_celldata[4,1] != '-' || stripped_celldata[7,1] != '-' # Test auf Trennzeichen der Datum-Darstellung
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
            raise "#{e.class.name}: #{e.message} Error processing :data_title-rule for column #{col[:caption]}"
          end
          title['%t'] = col[:title] if title['%t'] && col[:title]   # einbetten :title in :data_title, wenn per %t angewiesen
        end

        # Title erweitern um %-Anteil von Spaltensumme
        if col[:sum] && col[:sum] != 0    # Ausgabe %-Anteil und spaltensumme im title, title oder data_title sollten dafür gesetzt sein
          title << col[:title] if title == '' && col[:title]    # title einbetten wenn kein data_title gesetzt ist. Ansonsten wird title erst in HTML-Anzeige vom Header geerbt wenn kein data_title oder show_pct_hint gesetzt ist
          recval = col[:show_pct_hint].call(rec)
          title << " #{formattedNumber((recval ? recval : 0) * 100.to_f / col[:sum], 2) } % of column sum: #{formattedNumber(col[:sum])}"
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
          metadata << "title:    '#{escape_js_chars title}',"    if title && title != ''
          metadata << "style:    '#{escape_js_chars style}',"    if style && style != ''
          metadata << "fulldata: '#{escape_js_chars celldata}'," if celldata != stripped_celldata  # fulldata nur speichern, wenn html-Tags die Zell-Daten erweitern
          metadata << '},'
        end
      end
      output << "metadata: { columns: { #{metadata} } }," if metadata != ''
      output << '},'
    end
    output << '];' # Data

    output << "var options = #{prepare_js_global_options_for_slickgrid(table_id, global_options)};"      # Global Options definieren
    output << "var columns = #{prepare_js_columns_for_slickgrid(table_id, column_options)};"      # JS-columns definieren

    ################### Context-Menu ########################
    output << "var additional_menu_entries = ["
    context_menu_entries = global_options[:context_menu_entries]
    if context_menu_entries
      context_menu_entries = [context_menu_entries] if context_menu_entries.class == Hash  # Einzelnen Hash in Array einbetten, wenn nicht Array üebergeben wurde
      raise "Parameter :context_menu_entries is expected as Hash or Array, not #{context_menu_entries.class.name}" if context_menu_entries.class != Array
      context_menu_entries.each_index do |i|
        output << "  { label:   \"#{context_menu_entries[i][:label]}\",
                       hint:    \"#{context_menu_entries[i][:hint]}\",
                       ui_icon: \"#{context_menu_entries[i][:ui_icon] ? context_menu_entries[i][:ui_icon] : 'ui-icon-image'}\",
                       action:  function(t){ #{context_menu_entries[i][:action]}}
                     },"
      end
    end
    output << '];' # Ende Context-Menu

    output << "createSlickGridExtended('#{table_id}', data, columns, options, additional_menu_entries);"    # Aufbau des slickGrid

    output << '});' # Ende anonyme function

    output << '</script>'
    output.html_safe
  end

  @@block_classes = nil
  # Schnell zu selektierende Information zu Wait-Event-Parametern
  def quick_wait_params_info(event, p1, p1text, p1raw, p2, p2text, p2raw, p3, p3text, p3raw)
    def get_wait_stat_class_name(id)  # Ermitteln WaitStat aus x. Position nach Class-ID
      return '' unless id
      id = id.to_i
      unless @@block_classes           # Klassenvariable einmalig mit Daten befüllen wenn leer
        @@block_classes = {}
        sql_select_all('SELECT /* Panorama-Tool Ramm */ RowNum, class ClassName FROM v$WaitStat').each do |w|
          @@block_classes[w.rownum.to_i] = w.classname
        end
      end

      addition = ''

      if id > 19  # Undo-Segemnt mit in ID
        undo_segment = ((id-15)/2).to_i  # ID = 2 * Undo-Segment + 15
        id = id - (undo_segment-1)*2 # Verbleibende ID 17, 18
        addition = "Undo-Segment=#{undo_segment}"
      end
      "Block-Class=#{id} (#{@@block_classes[id]}) #{addition}"
    end


    result = nil # Default

    if (event.include?('gc ') || event == 'buffer busy waits'
       ) && (p3text == 'id#' || p3text == 'class#')
      class_id = case p3text
                   when 'id#' then p3 % 65536
                   when 'class#' then p3
                   else
                     nil
      end
      result = get_wait_stat_class_name(class_id)
    end
    result
  end


  private
    # Ermitteln Kurztext per DB aus SQL-ID
    def get_sql_shorttext_by_sql_id(sql_id)
      # Connect zur DB nachhollen wenn noch auf NullAdapter steht, da Zugriff auf gecachte Werte ohne DB-Connect möglich ist
      open_oracle_connection

      # erster Versuch direkt aus SGA zu lesen
      sqls = sql_select_all ["\
                 SELECT /*+ Panorama-Tool Ramm */ SUBSTR(SQL_FullText, 1, 150) SQL_Text
                 FROM   v$SQLArea
                 WHERE  SQL_ID = ?",
                 sql_id]

      if sqls.size == 0  # Wenn nicht gefunden, dann in AWR-History suchen
        sqls = sql_select_all ["\
                   SELECT /*+ Panorama-Tool Ramm */ SUBSTR(SQL_Text, 1, 150) SQL_Text
                   FROM   DBA_Hist_SQLText
                   WHERE  DBID   = ?
                   AND    SQL_ID = ?",
                   session[:database][:dbid], sql_id]
      end

      if sqls.size == 0
        "< Kein SQL-Text zu ermitteln füer SQL-ID='#{sql_id}' >"
      else
        sqls[0].sql_text
      end
    end # get_sql_shorttext_by_sql_id

  public
  # Cachen von gekürzten SQL-Texten zu SQL-ID's
  def get_cached_sql_shorttext_by_sql_id(sql_id)
    # optional Lebensdauer des Caches mit Option  :expires_in => 5.minutes setzen
    Rails.cache.fetch("SQLShortText_#{sql_id}") {get_sql_shorttext_by_sql_id(sql_id)}
  end

  protected
  # Application-Spezifisch: Extrahieren weiterer Info aus Kurzbezeichnern
  def explain_application_info(org_text)
    retval = {}    # Default
    return retval unless org_text

    if org_text.match('Application = ')
      appl = SyspApplication.get_cached_instance(org_text.split(' ')[2].to_i)
      if appl
        retval[:short_info] = appl.name
        retval[:long_info]  = "#{appl.description}  >> Team: #{appl.developmentteam.name}"
      else
        retval[:short_info] = "Application not found for #{org_text}"
      end
    end

    if org_text.match('ID_WSMethod = ')
      ws = Wsmethod.get_cached_instance(org_text.split(' ')[2].to_i)
      if ws
        retval[:short_info] = ws.name
        retval[:long_info]  = "#{ws.name}"
      else
        retval[:short_info] = "WSMethod not found for #{org_text}"
      end
    end

    if org_text.match('ID_OFMsgType = ')
      mt = Ofmessagetype.get_cached_instance(org_text.split(' ')[2].to_i, session[:database].hash)
      if mt
        retval[:short_info] = mt.name
        retval[:long_info]  = "#{mt.description} >> Domain: #{mt.domain.name}"
      else
        retval[:short_info] = "OFMessagetype not found for #{org_text}"
      end
    end



    retval
  end

  def get_sga_sql_statement(instance, sql_id)  # Ermittlung formatierter SQL-Text

    def get_sga_sql_statement_internal(instance, sql_id)
      statement = sql_select_one(["\
        SELECT /* Panorama-Tool Ramm */ SQL_FullText
        FROM   GV$SQLArea
        WHERE  SQL_ID  = ?
        AND    Inst_ID = ?
        ",
          sql_id, instance, sql_id, instance
        ])
      statement = statement.gsub("\n", '<br>') if statement # Linefeed in HTML anzeigen
      statement
    end

    raise 'Parameter instance should not be nil' unless instance
    raise 'Parameter sql_id should not be nil' unless sql_id

    sql_statement = get_sga_sql_statement_internal(instance, sql_id)
    if sql_statement == '' # Nichts gefunden
      instances = sql_select_all 'SELECT Inst_ID FROM GV$Instance'
      instances.each do |i|
        if sql_statement == '' # Auf anderer Instance suchen, solange nicht gefunden
          sql_statement = get_sga_sql_statement_internal(i.inst_id, sql_id)
          sql_statement = "[Instance=#{i.inst_id}] #{sql_statement}" unless sql_statement == '' # abweichende Instance mit in Text aufnehmen
        end
      end
    end
    sql_statement
  end


  public

  # Setzen einer neutralen Connection nach Abarbeitung des Requests, damit frühzeitiger Connect bei Beginn der Verarbeitung eines Requests nicht gegen die DB des letzten Requests geht
  def set_dummy_db_connection
    ActiveRecord::Base.establish_connection(:adapter  => 'nulldb')
  end

  # Rendern des Templates für Action, optionale mit Angabe des Partial-Namens wenn von Action abweicht
  def render_partial(partial_name = nil)
    partial_name = self.action_name if partial_name.nil?
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"#{controller_name}/#{partial_name}"}');"}
    end
  end

  # Eindeutigen Bezeichner fuer DIV-ID in html-Struktur
  def get_unique_area_id
    session[:request_counter] = 0 if session[:request_counter] > 10000    # Sicherstellen, das keine Kumulation ohne Ende
    "a#{session[:request_counter]}"
  end

end
