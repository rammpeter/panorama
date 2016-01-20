# encoding: utf-8

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include KeyExplanationHelper
  include AjaxHelper
  include DiagramHelper
  include HtmlHelper
  include ActionView::Helpers::SanitizeHelper
  include DatabaseHelper
  include SlickgridHelper
  include ExplainApplicationInfoHelper

  def get_client_info_store
    if $login_client_store.nil?
      $login_client_store = ActiveSupport::Cache::FileStore.new(Panorama::Application.config.client_info_filename)
      Rails.logger.info("Local directory for client-info store is #{Panorama::Application.config.client_info_filename}")
    end

    $login_client_store
  rescue Exception =>e
    raise "Exception '#{e.message}' while creating file store at '#{Panorama::Application.config.client_info_filename}'"
  end

  private
  @@cached_encrypted_client_key = nil
  @@cached_decrypted_client_key = nil

  # Ausliefern des client-Keys
  def get_cached_client_key
    if @@cached_encrypted_client_key.nil? || @@cached_decrypted_client_key.nil? || @@cached_encrypted_client_key != cookies[:client_key]        # gecachten Wert neu belegen bei anderem Cookie-Inhalt
      @@cached_decrypted_client_key = database_helper_decrypt_value(cookies[:client_key])                                                       # Merken des entschlüsselten Cookies in Memory
      @@cached_encrypted_client_key = cookies[:client_key]                                                                                      # Merken des verschlüsselten Cookies für Vergleich bei nächstem Zugriff
    end
    @@cached_decrypted_client_key
  end

  public
  # Schreiben eines client-bezogenen Wertes in serverseitigen Cache
  def write_to_client_info_store(key, value)
#    get_client_info_store.write("#{get_cached_client_key}_#{key}", value)

    full_hash = get_client_info_store.read(get_cached_client_key)               # Kompletten Hash aus Cache auslesen
    full_hash = {} if full_hash.nil? || full_hash.class != Hash                 # Neustart wenn Struktur nicht passt
    full_hash[key] = value                                                      # Wert in Hash verankern
    get_client_info_store.write(get_cached_client_key, full_hash)               # Überschreiben des kompletten Hashes im Cache
  rescue Exception =>e
    raise "Exception '#{e.message}' while writing file store at '#{Panorama::Application.config.client_info_filename}'"
  end

  # Lesen eines client-bezogenen Wertes aus serverseitigem Cache
  def read_from_client_info_store(key)
    full_hash = get_client_info_store.read(get_cached_client_key)               # Auslesen des kompletten Hashes aus Cache
    return nil if full_hash.nil? || full_hash.class != Hash                     # Abbruch wenn Struktur nicht passt
    full_hash[key]
  end

  # Setzen locale in Client_Info-Cache und aktueller Session
  def set_I18n_locale(locale)
    if !locale.nil? && ['de', 'en'].include?(locale)
      write_to_client_info_store(:locale, locale)
    else
      write_to_client_info_store(:locale, 'en')
      Rails.logger.warn(">>> I18n.locale set to 'en' because '#{locale}' is not yet supported")
    end
    @buffered_locale = nil                                                      # Sicherstellen, dass lokaler Cache neu aus FileStore gelesen wird
    I18n.locale = get_locale
  end

  # Cachen diverser Client-Einstellungen in lokalen Variablen
  def get_locale
    @buffered_locale = read_from_client_info_store(:locale) unless @buffered_locale
    @buffered_locale
  end

  def set_current_database(current_database)
    @buffered_current_database = nil                                            # lokalen Cache verwerfen
    write_to_client_info_store(:current_database, current_database)
  end


  def get_current_database
    @buffered_current_database = read_from_client_info_store(:current_database) unless @buffered_current_database
    @buffered_current_database
  end

  def set_cached_dbid(dbid)
    @buffered_dbid = nil
    write_to_client_info_store(:dbid, dbid)
  end

  def get_dbid    # die originale oder nach Login ausgewählte DBID
    @buffered_dbid = read_from_client_info_store(:dbid) unless @buffered_dbid
    @buffered_dbid
  end

  def get_db_version    # Oracle-Version
    @buffered_db_version = read_from_client_info_store(:db_version) unless @buffered_db_version
    @buffered_db_version
  end

  def get_db_block_size    # Oracle block size
    @buffered_db_block_size = read_from_client_info_store(:db_block_size) unless @buffered_db_block_size
    @buffered_db_block_size
  end

  def get_db_wordsize    # word size des Oracle-Servers
    @buffered_wordsize = read_from_client_info_store(:db_wordsize) unless @buffered_wordsize
    @buffered_wordsize
  end

  def set_cached_time_selection_start(time_selection_start)
    @buffered_time_selection_start = nil
    write_to_client_info_store(:time_selection_start, time_selection_start)
  end

  def get_cached_time_selection_start
    @buffered_time_selection_start = read_from_client_info_store(:time_selection_start) unless @buffered_time_selection_start
    @buffered_time_selection_start
  end

  def set_cached_time_selection_end(time_selection_end)
    @buffered_time_selection_end = nil
    write_to_client_info_store(:time_selection_end, time_selection_end)
  end

  def get_cached_time_selection_end
    @buffered_time_selection_end = read_from_client_info_store(:time_selection_end) unless @buffered_time_selection_end
    @buffered_time_selection_end
  end

  private
  def sql_prepare_binds(sql)
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
        binds << [
            ActiveRecord::ConnectionAdapters::Column.new(bind_alias,
                                                         nil,
                                                         ActiveRecord::Type::Value.new    # Neu ab Rails 4.2.0, Abstrakter Typ muss angegeben werden
            ),
            sql[bind_index]
        ]
      end
    else
      if sql.class == String
        stmt = sql
      else
        raise "Unsupported Parameter-Class '#{sql.class.name}' for parameter sql of sql_select_all(sql)"
      end
    end
    [stmt, binds]
  end

  public
  # Helper fuer Ausführung SQL-Select-Query,
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  # return Array of Hash mit Columns des Records
  def sql_select_all(sql, modifier=nil)   # Parameter String mit SQL oder Array mit SQL und Bindevariablen
    stmt, binds = sql_prepare_binds(sql)
    result = ConnectionHolder.connection().select_all(stmt, 'sql_select_all', binds)
    result.each do |h|
      h.each do |key, value|
        h[key] = value.strip if value.class == String   # Entfernen eines eventuellen 0x00 am Ende des Strings, dies führt zu Fehlern im Internet Explorer
      end
      h.extend SelectHashHelper    # erlaubt, dass Element per Methode statt als Hash-Element zugegriffen werden können
      modifier.call(h) unless modifier.nil?             # Anpassen der Record-Werte
    end
    result.to_ary                                                               # Ab Rails 4 ist result nicht mehr vom Typ Array, sondern ActiveRecord::Result
  end

  # Analog sql_select all, jedoch return ResultIterator mit each-Method
  # liefert Objekt zur späteren Iteration per each, erst dann wird SQL-Select ausgeführt (jedesmal erneut)
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  def sql_select_iterator(sql, modifier=nil)
    stmt, binds = sql_prepare_binds(sql)
    SqlSelectIterator.new(stmt, binds, modifier)      # kann per Aufruf von each die einzelnen Records liefern
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
    if get_current_database
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
      when :days    then timestamp.strftime(strftime_format_with_days)
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

  # Aufbereiten des Parameters "instance" aus Request, return nil wenn kein plausibler Wert
  def prepare_param_instance
    retval = params[:instance].to_i
    retval = nil if retval == 0
    write_to_client_info_store(:instance, retval)      # Werte puffern fuer spaetere Wiederverwendung
    retval
  end

  # Aufbereiten des Parameters "dbid" aus Request, return session-default wenn kein plausibler Wert
  def prepare_param_dbid
    retval = params[:dbid]
    retval = get_dbid unless retval
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
          raise "#{t(:application_helper_delimiter_on_pos, :default=>'Delimiter at position')} #{index} #{t(:application_helper_is_not, :default=>'is not')} '#{m}'" if ts[index,1] != m
        end
        index = index+1
      end

      daypos = sql_datetime_minute_mask.index 'DD'
      raise "#{t(:application_helper_length_error, :default=>'Length of expression')} != 16" if ts.length != 16
      raise t(:application_helper_range_error_day, :default=>'Day not between 01 and 31')        if  ts[daypos,1] < '0' || ts[daypos,1] > '3' ||      # Tag
                                                      ts[daypos+1,1] < '0' || ts[daypos+1,1] > '9' ||
                                                      ts[daypos,2].to_i < 1  ||
                                                      ts[daypos,2].to_i > 31

      monthpos = sql_datetime_minute_mask.index 'MM'
      raise t(:application_helper_range_error_month, :default=>'Month not between 01 and 12')      if ts[monthpos,1] < '0' || ts[monthpos,1] > '1' ||      # Monat
                                                     ts[monthpos+1,1] < '0' || ts[monthpos+1,1] > '9' ||
                                                     ts[monthpos,2].to_i < 1  ||
                                                     ts[monthpos,2].to_i > 12

      yearpos = sql_datetime_minute_mask.index 'YYYY'
      raise t(:application_helper_range_error_year, :default=>'Year not between 1000 and 2999') if ts[yearpos,1] < '1' || ts[yearpos,1] > '2' ||      #Jahr
                                                       ts[yearpos+1,1] < '0' || ts[yearpos+1,1] > '9' ||
                                                       ts[yearpos+2,1] < '0' || ts[yearpos+2,1] > '9' ||
                                                       ts[yearpos+3,1] < '0' || ts[yearpos+3,1] > '9'

      hourpos = sql_datetime_minute_mask.index 'HH24'
      raise t(:application_helper_range_error_hour, :default=>'Hour not between 00 and 23') if ts[hourpos,1] < '0' || ts[hourpos,1] > '2' ||    # Stunde
                                                       ts[hourpos+1,1] < '0' || ts[hourpos+1,1] > '9' ||
                                                       ts[hourpos,2].to_i > 23

      minutepos = sql_datetime_minute_mask.index('MI') - 2    # HH24 verbraucht 2 stellen mehr als in Realität
      raise t(:application_helper_range_error_minute, :default=>'Minute not between 00 and 59') if ts[minutepos,1] < '0' || ts[minutepos,1] > '5' ||    # Minute
                                                       ts[minutepos+1,1] < '0' || ts[minutepos+1,1] > '9' ||
                                                       ts[minutepos,2].to_i > 59

      ts      # Return-wert
    rescue Exception => e
      raise "#{t(:ajax_helper_link_sql_id_title_prefix, :default=>'Invalid format of timestamp')} '#{ts}'. #{t(:ajax_helper_link_wait_params_hint, :default=>'Expected is')} '#{human_datetime_minute_mask}'! Problem: #{e.message}"
    end

    raise "Parameter 'time_selection_start' missung in hash 'params'" unless params[:time_selection_start]
    raise "Parameter 'time_selection_end' missung in hash 'params'"   unless params[:time_selection_end]
    @time_selection_start = params[:time_selection_start].rstrip
    @time_selection_end   = params[:time_selection_end].rstrip

    if @time_selection_start && @time_selection_start != ''
      set_cached_time_selection_start(check_timestamp_picture(@time_selection_start))
    end
    if @time_selection_end && @time_selection_end != ''
      set_cached_time_selection_end(check_timestamp_picture(@time_selection_end))
    end
  end

  # Vorbelegung fuer Eingabefeld
  def default_time_selection_start
    if get_cached_time_selection_start && get_cached_time_selection_start != ''
      get_cached_time_selection_start
    else
      "#{Date.today.strftime(strftime_format_with_days)} 00:00"
    end
  end

  # Vorbelegung fuer Eingabefeld
  def default_time_selection_end
    if get_cached_time_selection_end && get_cached_time_selection_end != ''
      get_cached_time_selection_end
    else
      "#{Date.today.strftime(strftime_format_with_days)} 13:00"
    end
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

    if (event && event.include?('gc ') || event == 'buffer busy waits'
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
                   get_dbid, sql_id]
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
    ConnectionHolder.establish_connection(:adapter  => 'nulldb')
  end

  # Rendern des Templates für Action, optionale mit Angabe des Partial-Namens wenn von Action abweicht
  def render_partial(partial_name = nil)
    partial_name = self.action_name if partial_name.nil?
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"#{controller_name}/#{partial_name}"}');"}
    end
  end

  # Rücksetzen des Zählers bei Neuanmeldung
  def initialize_unique_area_id
    write_to_client_info_store(:request_counter, 0)
  end

  # Eindeutigen Bezeichner fuer DIV-ID in html-Struktur
  def get_unique_area_id
    request_counter = read_from_client_info_store(:request_counter)
    request_counter = 0 if request_counter.nil? || request_counter > 100000           # Sicherstellen, das keine Kumulation ohne Ende
    request_counter += 1                                              # Eindeutigkeit sicherstellen durch Weiterzählen auch innerhalb eines Requests
    write_to_client_info_store(:request_counter, request_counter)
    "a#{request_counter}"
  end


  # Umwandeln des String so, dass er bei Darstellung in html auch an Kommas umgebrochen werden kann
  def convert_word_wrap_comma(origin)
puts origin
    # Erst alle html-Fehlinterpretationen in origin esacapen, dann MiniSpace einfuegen und html_safe setzen, damit nächster Escape durch <%= nicht mehr stattfindet
    my_html_escape(origin).gsub(/,/, ',<wbr>').html_safe    # Komma erweitert um Space mit breite 0, an dem bei word_wrap: brake_word trotzdem umgebrochen werden soll
    #my_html_escape(origin).gsub(/,/, ',&#8203;').html_safe    # Komma erweitert um Space mit breite 0, an dem bei word_wrap: brake_word trotzdem umgebrochen werden soll
  end


end
