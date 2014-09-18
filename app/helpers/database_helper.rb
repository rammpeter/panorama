# encoding: utf-8

# Hilfsmethoden mit Bezug auf die aktuell verbundene Datenbank sowie verbundene Einstellunen wie Sprache
module DatabaseHelper


  def database_helper_switch_sid_usage
    if session[:database][:sid_usage] == :SID
      session[:database][:sid_usage] = :SERVICE_NAME
    else
      session[:database][:sid_usage] = :SID
    end
  end


    # Notation für Anzeige und Connect per Ruby
  def database_helper_tns
    if session[:database][:tns]
      session[:database][:tns]
    else
      database_helper_raw_tns
    end
  end

  # Verschlüsseln eines Wertes
  def database_helper_encrypt_value(raw_value)
    crypt = ActiveSupport::MessageEncryptor.new(Panorama::Application.config.secret_key_base)
    crypt.encrypt_and_sign(raw_value)
  end

  # Entschlüsseln des Wertes
  def database_helper_decrypt_value(encrypted_value)
    crypt = ActiveSupport::MessageEncryptor.new(Panorama::Application.config.secret_key_base)
    crypt.decrypt_and_verify(encrypted_value)
  end

  def database_helper_raw_tns
    if session[:database]
      "#{session[:database][:host]}:#{session[:database][:port]}:#{session[:database][:sid]}"
    else
      "session[:database] not set!"
    end
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

      config = ActiveRecord::Base.connection.instance_variable_get(:@config)  # Aktuelle config, kann reduziert sein auf :adapter bei NullDB

      # Connect nur ausführen wenn bisherige DB-Connection nicht der gewünschten entspricht
      if ActiveRecord::Base.connection.class.name != 'ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter' ||
          config[:adapter]  != 'oracle_enhanced' ||
          config[:driver]   != 'oracle.jdbc.driver.OracleDriver' ||
          config[:url]      != jdbc_thin_url ||
          config[:username] != session[:database][:user]

        # Entschlüsseln des Passwortes
        local_password = database_helper_decrypt_value(session[:database][:password])

        ActiveRecord::Base.establish_connection(
            :adapter  => "oracle_enhanced",
            :driver   => "oracle.jdbc.driver.OracleDriver",
            :url      => jdbc_thin_url,
            :username => session[:database][:user],
            :password => local_password,
            :privilege => session[:database][:privilege],
            :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
        )
        Rails.logger.info "Connecting database: URL='#{jdbc_thin_url}' User='#{session[:database][:user]}'"
      else
        Rails.logger.info "Using connected database: URL='#{jdbc_thin_url}' User='#{session[:database][:user]}'"
      end

    else
      raise "Native ruby (RUBY_ENGINE=#{RUBY_ENGINE}) is no longer supported! Please use JRuby runtime environment! Call contact for support request if needed."
=begin
      ActiveRecord::Base.establish_connection(
          :adapter  => "oracle_enhanced",
          :database => session[:database][:tns],
          :username => session[:database][:user],
          :password => local_password,
          :privilege => session[:database][:privilege],
          :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
      )
      Rails.logger.info "Database: TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
=end
    end

  rescue Exception => e                   # Exception kommt i.d.R. erst bei erstem DB-Zugriff
    Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
    Rails.logger.error e.message
    raise e
  end

  # Format für JQuery-UI Plugin DateTimePicker
  def timepicker_dateformat
    case session[:locale]
      when "de" then "dd.mm.yy"
      when "en" then "yy-mm-dd"
      else "dd.mm.yy"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Tag
  def strftime_format_with_days
    case session[:locale]
      when "de" then "%d.%m.%Y"
      when "en" then "%Y-%m-%d"
      else "%d.%m.%Y"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden
  def strftime_format_with_seconds
    case session[:locale]
      when "de" then "%d.%m.%Y %H:%M:%S"
      when "en" then "%Y-%m-%d %H:%M:%S"
      else "%d.%m.%Y %H:%M:%S"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Minuten
  def strftime_format_with_minutes
    case session[:locale]
      when "de" then "%d.%m.%Y %H:%M"
      when "en" then "%Y-%m-%d %H:%M"
      else "%d.%m.%Y %H:%M"     # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_second_mask
    case session[:locale]
      when "de" then "DD.MM.YYYY HH24:MI:SS"
      when "en" then "YYYY-MM-DD HH24:MI:SS"
      else "DD.MM.YYYY HH24:MI:SS" # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_minute_mask
    case session[:locale]
      when "de" then "DD.MM.YYYY HH24:MI"
      when "en" then "YYYY-MM-DD HH24:MI"
      else "DD.MM.YYYY HH24:MI" # Deutsche Variante als default
    end
  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_minute_mask
    case session[:locale]
      when "de" then "TT.MM.JJJJ HH:MI"
      when "en" then "YYYY-MM-DD HH:MI"
      else "TT.MM.JJJJ HH24:MI" # Deutsche Variante als default
    end
  end


  def numeric_thousands_separator
    case session[:locale]
      when "de" then "."
      when "en" then ","
      else "." # Deutsche Variante als default
    end
  end


  def numeric_decimal_separator
    case session[:locale]
      when "de" then ","
      when "en" then "."
      else "," # Deutsche Variante als default
    end
  end

end