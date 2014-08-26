# encoding: utf-8

# Hilfsmethoden mit Bezug auf die aktuell verbundene Datenbank sowie verbundene Einstellunen wie Sprache
module DatabaseHelper


  def database_helper_switch_sid_usage
    if session[:database][:sid_usage] == :SID
      session[:database][:sid_usage] = :SERVICE_NAME
    else
      session[:database][:sid_usage] == :SID if session[:database][:sid_usage] == :SERVICE_NAME
    end
  end


    # Notation für Anzeige und Connect per Ruby
  def database_helper_tns
    if session[:database][:tns]
      session[:database][:tns]
    else
      raw_tns
    end
  end


  def raw_tns
    "#{session[:database][:host]}:#{session[:database][:port]}:#{session[:database][:sid]}"
  end

private
  # Notation für Connect per JRuby
  def jdbc_thin_url
    sid_separator = ":" # Default, if session[:database][:sid_usage].to_sym == :SID
    sid_separator = "/" if session[:database][:sid_usage].to_sym == :SERVICE_NAME
    raise "Keine Deutung (#{session[:database][:sid_usage]}) für #{session[:database][:sid]} bekannt ob SID oder SERVICE_NAME" unless sid_separator
    "jdbc:oracle:thin:@#{session[:database][:host]}:#{session[:database][:port]}#{sid_separator}#{session[:database][:sid]}"
  end

public

  # Einlesen diverser Parameter der DB, die spaeter noch laufend gebraucht werden
  def read_initial_db_values
    session[:database][:dbid]          = sql_select_one "SELECT /* Panorama Tool Ramm */ DBID FROM v$Database"
    session[:database][:db_block_size] = sql_select_one "SELECT /* Panorama Tool Ramm */ TO_NUMBER(Value) FROM v$parameter WHERE UPPER(Name) = 'DB_BLOCK_SIZE'"
    session[:database][:version]       = sql_select_one "SELECT /* Panorama Tool Ramm */ Version FROM V$Instance"
    session[:database][:wordsize]      = sql_select_one "SELECT DECODE (INSTR (banner, '64bit'), 0, 4, 8) FROM v$version WHERE Banner LIKE '%Oracle Database%'"
  end



  def open_oracle_connection
    # Unterscheiden der DB-Adapter zwischen Ruby und JRuby
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      ActiveRecord::Base.establish_connection(
          :adapter  => "oracle_enhanced",
          :driver   => "oracle.jdbc.driver.OracleDriver",
          :url      => jdbc_thin_url,
          :username => session[:database][:user],
          :password => session[:database][:password],
          :privilege => session[:database][:privilege],
          :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
      )
      Rails.logger.info "Database: URL='#{jdbc_thin_url}' User='#{session[:database][:user]}'"
    else
      ActiveRecord::Base.establish_connection(
          :adapter  => "oracle_enhanced",
          :database => session[:database][:tns],
          :username => session[:database][:user],
          :password => session[:database][:password],
          :privilege => session[:database][:privilege],
          :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
      )
      Rails.logger.info "Database: TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
    end

  rescue Exception => e
    Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
    Rails.logger.error e.message
    raise e
  end

  # Format für JQuery-UI Plugin DateTimePicker
  def timepicker_dateformat
    case session[:database][:locale]
      when "de" then "dd.mm.yy"
      when "en" then "yy-mm-dd"
      else "dd.mm.yy"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Tag
  def strftime_format_with_days
    case session[:database][:locale]
      when "de" then "%d.%m.%Y"
      when "en" then "%Y-%m-%d"
      else "%d.%m.%Y"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden
  def strftime_format_with_seconds
    case session[:database][:locale]
      when "de" then "%d.%m.%Y %H:%M:%S"
      when "en" then "%Y-%m-%d %H:%M:%S"
      else "%d.%m.%Y %H:%M:%S"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Minuten
  def strftime_format_with_minutes
    case session[:database][:locale]
      when "de" then "%d.%m.%Y %H:%M"
      when "en" then "%Y-%m-%d %H:%M"
      else "%d.%m.%Y %H:%M"     # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_second_mask
    case session[:database][:locale]
      when "de" then "DD.MM.YYYY HH24:MI:SS"
      when "en" then "YYYY-MM-DD HH24:MI:SS"
      else "DD.MM.YYYY HH24:MI:SS" # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_minute_mask
    case session[:database][:locale]
      when "de" then "DD.MM.YYYY HH24:MI"
      when "en" then "YYYY-MM-DD HH24:MI"
      else "DD.MM.YYYY HH24:MI" # Deutsche Variante als default
    end
  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_minute_mask
    case session[:database][:locale]
      when "de" then "TT.MM.JJJJ HH:MI"
      when "en" then "YYYY-MM-DD HH:MI"
      else "TT.MM.JJJJ HH24:MI" # Deutsche Variante als default
    end
  end


  def numeric_thousands_separator
    case session[:database][:locale]
      when "de" then "."
      when "en" then ","
      else "." # Deutsche Variante als default
    end
  end


  def numeric_decimal_separator
    case session[:database][:locale]
      when "de" then ","
      when "en" then "."
      else "," # Deutsche Variante als default
    end
  end

end