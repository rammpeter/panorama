# encoding: utf-8
module EnvHelper
  require "zlib"

  # Einlesen diverser Parameter der DB, die spaeter noch laufend gebraucht werden
  def read_initial_db_values
    set_cached_dbid(sql_select_one("SELECT /* Panorama Tool Ramm */ DBID FROM v$Database"))
    write_to_client_info_store(:db_block_size,  sql_select_one("SELECT /* Panorama Tool Ramm */ TO_NUMBER(Value) FROM v$parameter WHERE UPPER(Name) = 'DB_BLOCK_SIZE'"))
    write_to_client_info_store(:db_version,     sql_select_one("SELECT /* Panorama Tool Ramm */ Version FROM V$Instance"))
    write_to_client_info_store(:wordsize,       sql_select_one("SELECT /* Panorama Tool Ramm */ DECODE (INSTR (banner, '64bit'), 0, 4, 8) FROM v$version WHERE Banner LIKE '%Oracle Database%'"))
  end



  # Einlesen last_logins aus client_info-store
  def read_last_logins
=begin
    begin
      if cookies[:last_logins]
        #last_logins = Marshal.load(Zlib::Inflate.inflate(cookies[:last_logins]))
        cookies_last_logins = Marshal.load(cookies[:last_logins])
      else
        cookies_last_logins = []
      end
    rescue Exception => e
      Rails.logger.warn "read_last_login_cookies: #{e.message}"
      cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
      write_last_logins(cookies_last_logins)   # Zurückschreiben in cookie-store
    end

    unless cookies_last_logins.instance_of?(Array)  # Falscher Typ des Cookies?
      cookies_last_logins = []
      write_last_logins(cookies_last_logins)   # Zurückschreiben in cookie-store
    end

    # Transformation der cookie-Kürzel in lesbare Bezeichner
    cookies_last_logins.map{|c| {:host=>c[:h], :port=>c[:p], :sid=>c[:s], :user=>c[:u], :password=>c[:w], :authorization=>c[:a], :sid_usage=>(c[:g]==1 ? :SID : :SERVICE_NAME)} }
=end
    last_logins = read_from_client_info_store(:last_logins)
    if last_logins.nil? || !last_logins.instance_of?(Array)
      last_logins = []
      write_last_logins(last_logins)   # Zurückschreiben in client_info-store
    end
    last_logins
  end

  # Zurückschreiben des logins in client_info_store
  def write_last_logins(last_logins)
=begin
    #compressed_cookie = Zlib::Deflate.deflate(Marshal.dump(last_logins))

    # Transformation der lesbaren Bezeichner in cookie-Kürzel
    write_cookie = last_logins.map {|o| {:h=>o[:host], :p=>o[:port], :s=>o[:sid], :u=>o[:user], :w=>o[:password], :a=>o[:authorization], :g=>(o[:sid_usage] == :SID ? 1 : 0) } }

    while Marshal.dump(write_cookie).length > 1500 do                           # Größe des Cookies überschreitet x kByte
      write_cookie.delete(write_cookie.last)                                    # Letzten Eintrag loeschen
    end

    compressed_cookie = Marshal.dump(write_cookie)
    cookies[:last_logins] = { :value => compressed_cookie, :expires => 1.year.from_now }
=end
    write_to_client_info_store(:last_logins, last_logins)
  end


end