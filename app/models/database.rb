# encoding: utf-8
# Pseudo-Model zur Speicherung der Anmeldeinformation

class Database < Hash
  include ApplicationHelper # Erweiterung der Controller um Helper-Methoden des GUI's

#  attr_accessor :id, :user, :password, :privilege, :host, :port, :sid, :sid_usage, :dbid, :authorization, :locale,
#                :db_block_size, :version, :wordsize

  def initialize( params = {} )
    self[:tns]      = params[:tns]
    self[:user]     = params[:user]
    self[:password] = params[:password]
    self[:privilege]= params[:privilege]
    self[:host]     = params[:host]
    self[:port]     = params[:port]
    self[:sid]      = params[:sid]
    self[:sid_usage]= :SID
    self[:dbid]     = params[:dbid]         # Database ID aus V$Database
    self[:authorization] = params[:authorization]  # Autorisierung für spezielle DB's
    self[:locale]   = params[:locale]
    self[:version]  = params[:version]         # DB-Version Oracle
    self[:wordsize] = params[:wordsize]         # Wortbreite in Byte (4/8 für 32/64 bit)
  end

  def tns=(param)
    @tns = param
  end
  
  # Rueck-Konvertierung in params-Hash
  def to_params
    {
      :id       => self[:id],
      :user     => self[:user],
      :password => self[:password],
      :privilege=> self[:privilege],
      :host     => self[:host],
      :port     => self[:port],
      :sid      => self[:sid],
      :authorization => self[:authorization],
      :locale   => self[:locale],
      :version  => self[:version],
      :wordsize => self[:wordsize],
    }
  end



  def switch_sid_usage
    if self[:sid_usage] == :SID
      self[:sid_usage] = :SERVICE_NAME
    else
      self[:sid_usage] == :SID if self[:sid_usage] == :SERVICE_NAME
    end
  end

=begin
  # Notation für Anzeige und Connect per Ruby
  def tns
    if self[:tns]
      self[:tns]
    else
      raw_tns
    end
  end

  def raw_tns
    "#{self[:host]}:#{self[:port]}:#{self[:sid]}"
  end

  # Notation für Connect per JRuby
  def jdbc_thin_url
    sid_separator = ":" # Default, if self.sid_usage == :SID
    sid_separator = "/" if self.sid_usage == :SERVICE_NAME
    raise "Keine Deutung (#{self.sid_usage}) für #{self.sid} bekannt ob SID oder SERVICE_NAME" unless sid_separator
    "jdbc:oracle:thin:@#{self.host}:#{self.port}#{sid_separator}#{self.sid}"
  end

  # Einlesen diverser Parameter der DB, die spaeter noch laufend gebraucht werden
  def read_initial_db_values
    self.dbid          = sql_select_one "SELECT /* Panorama Tool Ramm */ DBID FROM v$Database"
    self.db_block_size = sql_select_one "SELECT /* Panorama Tool Ramm */ TO_NUMBER(Value) FROM v$parameter WHERE UPPER(Name) = 'DB_BLOCK_SIZE'"
    self.version       = sql_select_one "SELECT /* Panorama Tool Ramm */ Version FROM V$Instance"
    self.wordsize      = sql_select_one "SELECT DECODE (INSTR (banner, '64bit'), 0, 4, 8) FROM v$version WHERE Banner LIKE '%Oracle Database%'"
  end


  def open_oracle_connection
    # Unterscheiden der DB-Adapter zwischen Ruby und JRuby
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      ActiveRecord::Base.establish_connection(
        :adapter  => "oracle_enhanced",
        :driver   => "oracle.jdbc.driver.OracleDriver",
        :url      => self.jdbc_thin_url,
        :username => self.user,
        :password => self.password,
        :privilege => self.privilege,
        :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
      )
      Rails.logger.info "Database: URL='#{self.jdbc_thin_url}' User='#{self.user}'"
    else
      ActiveRecord::Base.establish_connection(
        :adapter  => "oracle_enhanced",
        :database => self.tns,
        :username => self.user,
        :password => self.password,
        :privilege => self.privilege,
        :cursor_sharing => :exact             # oracle_enhanced_adapter setzt cursor_sharing per Default auf similar bzw. force
      )
      Rails.logger.info "Database: TNSName='#{self.tns}' User='#{self.user}'"
    end

  rescue Exception => e
    Rails.logger.error "Error connecting to database: URL='#{self.jdbc_thin_url}' TNSName='#{self.tns}' User='#{self.user}'"
    Rails.logger.error e.message
    raise e
  end



  # Format für JQuery-UI Plugin DateTimePicker
  def timepicker_dateformat
    case self.locale
      when "de" then "dd.mm.yy"
      when "en" then "yy-mm-dd"
      else "dd.mm.yy"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Tag
  def strftime_format_with_days
    case self.locale
      when "de" then "%d.%m.%Y"
      when "en" then "%Y-%m-%d"
      else "%d.%m.%Y"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden
  def strftime_format_with_seconds
    case self.locale
      when "de" then "%d.%m.%Y %H:%M:%S"
      when "en" then "%Y-%m-%d %H:%M:%S"
      else "%d.%m.%Y %H:%M:%S"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Minuten
  def strftime_format_with_minutes
    case self.locale
      when "de" then "%d.%m.%Y %H:%M"
      when "en" then "%Y-%m-%d %H:%M"
      else "%d.%m.%Y %H:%M"     # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def translate_sql_datetime_second_mask
    case self.locale
      when "de" then "DD.MM.YYYY HH24:MI:SS"
      when "en" then "YYYY-MM-DD HH24:MI:SS"
      else "DD.MM.YYYY HH24:MI:SS" # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def translate_sql_datetime_minute_mask
    case self.locale
      when "de" then "DD.MM.YYYY HH24:MI"
      when "en" then "YYYY-MM-DD HH24:MI"
      else "DD.MM.YYYY HH24:MI" # Deutsche Variante als default
    end
  end

  # Menschenlesbare Ausgabe in Hints etc
  def translate_human_datetime_minute_mask
    case self.locale
      when "de" then "TT.MM.JJJJ HH:MI"
      when "en" then "YYYY-MM-DD HH:MI"
      else "TT.MM.JJJJ HH24:MI" # Deutsche Variante als default
    end
  end


  def numeric_thousands_separator
    case self.locale
      when "de" then "."
      when "en" then ","
      else "." # Deutsche Variante als default
    end
  end

  def numeric_decimal_separator
    case self.locale
      when "de" then ","
      when "en" then "."
      else "," # Deutsche Variante als default
    end
  end
=end


end
