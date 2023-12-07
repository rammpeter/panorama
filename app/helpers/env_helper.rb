# encoding: utf-8

require "zlib"
require 'encryption'
require 'java'
# require_relative '../../config/engine_config'
require 'database_helper'
require 'env_extension_helper'

module EnvHelper
  include DatabaseHelper
  include EnvExtensionHelper


  # get master_key from file or environment
  def self.secret_key_base
    # set default dir so that it is persistent if PANORAMA_VAR_HOME is set outside
    default_secret_key_base_file = File.join(Panorama::Application.config.panorama_var_home, 'secret_key_base')
    retval = nil

    if ENV['SECRET_KEY_BASE']                                                   # Env rules over file
      retval = ENV['SECRET_KEY_BASE']
      Rails.logger.info('EnvHelper.secret_key_base') { "Secret key base read from environment variable SECRET_KEY_BASE (#{retval.length} chars)"}
      Rails.logger.warn('EnvHelper.secret_key_base') { "Secret key base from SECRET_KEY_BASE environment variable is too short! Should have at least 128 chars!" } if retval.length < 128
    end

    if retval.nil? && ENV['SECRET_KEY_BASE_FILE']                                              # User-provided secrets file
      if File.exists?(ENV['SECRET_KEY_BASE_FILE'])
        retval = File.read(ENV['SECRET_KEY_BASE_FILE'])
        Rails.logger.info('EnvHelper.secret_key_base') { "Secret key base read from file '#{ENV['SECRET_KEY_BASE_FILE']}' pointed to by SECRET_KEY_BASE_FILE environment variable (#{retval.length} chars)" }
        Rails.logger.error('EnvHelper.secret_key_base') { "Secret key base file pointed to by SECRET_KEY_BASE_FILE environment variable is empty!" } if retval.nil? || retval == ''
        Rails.logger.warn('EnvHelper.secret_key_base') { "Secret key base from file pointed to by SECRET_KEY_BASE_FILE environment variable is too short! Should have at least 128 chars!" } if retval.length < 128
      else
        Rails.logger.error('EnvHelper.secret_key_base') { "Secret key base file pointed to by SECRET_KEY_BASE_FILE environment variable does not exist (#{ENV['SECRET_KEY_BASE_FILE']})!" }
      end
    end

    if retval.nil? && File.exists?(default_secret_key_base_file)                # look for generated file
      retval = File.read(default_secret_key_base_file)
      Rails.logger.info('EnvHelper.secret_key_base') { "Secret key base read from default file location '#{default_secret_key_base_file}' (#{retval.length} chars)" }
      Rails.logger.warn('EnvHelper.secret_key_base') { "Default location of secret key base file '#{default_secret_key_base_file}' points to a temporary folder because you did not provide a value for PANORAMA_VAR_HOME" } unless Panorama::Application.config.panorama_var_home_user_defined
      Rails.logger.warn('EnvHelper.secret_key_base') { "Your stored connections and sampler configuration may be lost at next Panorama restart !" } unless Panorama::Application.config.panorama_var_home_user_defined
      Rails.logger.error('EnvHelper.secret_key_base') { "Secret key base file at default location '#{default_secret_key_base_file}' is empty!" } if retval.nil? || retval == ''
      Rails.logger.warn('EnvHelper.secret_key_base') { "Secret key base from file at default location '#{default_secret_key_base_file}' is too short! Should have at least 128 chars!" } if retval.length < 128
    end

    if retval.nil? || retval == ''
      Rails.logger.warn('EnvHelper.secret_key_base') { "Neither SECRET_KEY_BASE nor SECRET_KEY_BASE_FILE provided nor file exists at default location #{default_secret_key_base_file}!" }
      Rails.logger.warn('EnvHelper.secret_key_base') { "Encryption key for SECRET_KEY_BASE is initially generated and stored at #{default_secret_key_base_file}!" }
      Rails.logger.warn('EnvHelper.secret_key_base') { "This key is may be valid only for the lifetime of this running Panorama instance because you did not provide a value for PANORAMA_VAR_HOME !" } unless Panorama::Application.config.panorama_var_home_user_defined
      retval = Random.rand 99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
      File.write(default_secret_key_base_file, retval)
    end
    retval.to_s.strip                                                           # remove witespaces incl. \n
  end

  #def init_management_pack_license(current_database)
  #  if current_database[:management_pack_license].nil?                          # not already set, calculate initial value
  #    PanoramaConnection.get_management_pack_license_from_db_as_symbol
  #  else
  #    current_database[:management_pack_license] # Use old value if already set
  #  end
  #end


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
    last_logins = read_from_client_info_store(:last_logins, default: [])
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

  # Ensure client browser has unique client_key stored as cookie
  MAX_NEW_KEY_TRIES  = 1000
  def initialize_client_key_cookie
    if cookies['client_key']
      begin
        Encryption.decrypt_value(cookies['client_key'], cookies['client_salt']) # Test client_key-Cookie for possible decryption
      rescue Exception => e
        Rails.logger.error('EnvHelper.initialize_client_key_cookie') { "Exception #{e.message} while database_helper_decrypt_value(cookies['client_key'])" }
        cookies.delete('client_key')                                            # Verwerfen des nicht entschlüsselbaren Cookies
        cookies.delete('client_salt')
      end
    end

    if cookies['client_key']
      if cookies.class.name != 'Rack::Test::CookieJar' # Don't set Hash for cookies in test because it becomes String like ' { :value => 100, :expires => ... }'
        cookies['client_salt'] = {:value => cookies['client_salt'], :expires => 1.year.from_now, httponly: true} # Timeout neu setzen bei Benutzung
        cookies['client_key'] = {:value => cookies['client_key'], :expires => 1.year.from_now, httponly: true} # Timeout neu setzen bei Benutzung
      end
    else # Erster Zugriff in neu gestartetem Browser oder Cookie nicht mehr verfügbar
      loop_count = 0
      while loop_count < MAX_NEW_KEY_TRIES
        loop_count = loop_count + 1
        new_client_key = rand(10000000)
        unless ApplicationHelper.get_client_info_store.exist?(new_client_key) # Dieser Key wurde noch nie genutzt
          # Salt immer mit belegen bei Vergabe des client_key, da es genutzt wird zur Verschlüsselung des Client_Key im cookie
          cookies['client_salt'] = {:value => rand(10000000000), :expires => 1.year.from_now, httponly: true} # Lokaler Schlüsselbestandteil im Browser-Cookie des Clients, der mit genutzt wird zur Verschlüsselung der auf Server gespeicherten Login-Daten
          cookies['client_key'] = {:value => Encryption.encrypt_value(new_client_key, cookies['client_salt']), :expires => 1.year.from_now, httponly: true}
          client_store = ApplicationHelper.get_client_info_store
          client_store.write(new_client_key, 1) # Marker fuer Verwendung des Client-Keys
          break
        end
      end
      raise "Cannot create client key after #{MAX_NEW_KEY_TRIES} tries" if loop_count >= MAX_NEW_KEY_TRIES
    end
  end

  # Helper to distiguish browser tabs, sets @browser_tab_id
  def initialize_browser_tab_id
    tab_ids = read_from_client_info_store(:browser_tab_ids, default: {})
    tab_ids = {} if tab_ids.class != Hash
    @browser_tab_id = 1                                                         # Default tab-id if no other exists
    while tab_ids.key?(@browser_tab_id) do
      if tab_ids[@browser_tab_id].key?(:last_used) && tab_ids[@browser_tab_id][:last_used] < Time.now-84600*10  # Reuse after 10 days
        break
      end
      @browser_tab_id += 1
    end
    tab_ids[@browser_tab_id] = {} if !tab_ids.key?(@browser_tab_id)             # create Hash for browser tab if not already exsists
    tab_ids[@browser_tab_id][:last_used] = Time.now
    write_to_client_info_store(:browser_tab_ids, tab_ids)
  end

  # Read tnsnames.ora
  def read_tnsnames
    if ENV['TNS_ADMIN'] && ENV['TNS_ADMIN'] != ''
      tnsadmin = ENV['TNS_ADMIN']
    else
      if ENV['ORACLE_HOME']
        tnsadmin = "#{ENV['ORACLE_HOME']}/network/admin"
      else
        logger.warn 'read_tnsnames: TNS_ADMIN or ORACLE_HOME not set in environment, no TNS names provided'
        return {} # Leerer Hash
      end
    end

    tnsnames_filename = "#{tnsadmin}/tnsnames.ora"
    Rails.logger.info "Using tnsnames-file at #{tnsnames_filename}"
    read_tnsnames_internal(tnsnames_filename)

  rescue Exception => e
    Rails.logger.error('EnvHelper.read_tnsnames') { "Error processing tnsnames.ora: #{e.message}" }
    {}
  end

  # extract host or port from file buffer
  def extract_attr(searchstring, fullstring)
    # ermitteln Hostname
    start_pos = fullstring.index(searchstring)
    # Naechster Block mit Description beginnen wenn kein Host enthalten oder in naechster Description gefunden
    return nil, nil if start_pos==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos)    # Alle weiteren Treffer muessen vor der naechsten Description liegen
    #fullstring = fullstring[start_pos_host + 5, 1000000]
    start_pos_value = start_pos + searchstring.length
    next_parenthesis = fullstring[start_pos_value, 1000000].index(')')                # Next closing parenthesis after searched object
    retval = fullstring[start_pos_value, next_parenthesis]
    retval = retval.delete(' ').delete('=') # Entfernen Blank u.s.w
    return retval, start_pos
  end

  def read_tnsnames_internal(file_name)
    tnsnames = {}

    fullstring = IO.read(file_name)
    fullstring.encode!(fullstring.encoding, :universal_newline => true)         # Ensure that Windows-Linefeeds 0D0A are replaced by 0A
    fullstring.upcase!

    # Test for IFILE insertions
    fullstring_ifile = fullstring.clone                                         # local copy
    while true
      start_pos_ifile = fullstring_ifile.index('IFILE')
      break unless start_pos_ifile
      fullstring_ifile = fullstring_ifile[start_pos_ifile+5, 1000000]           # remove all before and including IFILE

      while fullstring_ifile[0].match '[= ]'                                    # remove = and blanks before filename
        fullstring_ifile = fullstring_ifile[1, 1000000]                         # remove first char of string
      end

      start_pos_ifile = fullstring_ifile.index("\n")
      if start_pos_ifile.nil?
        ifile_name = fullstring_ifile[0, 1000000]
      else
        ifile_name = fullstring_ifile[0, start_pos_ifile]
      end

      tnsnames.merge!(read_tnsnames_internal(ifile_name))
    end

    while true
      # Ermitteln TNSName
      start_pos_description = fullstring.index('DESCRIPTION')
      break unless start_pos_description                                        # Abbruch, wenn kein weitere DESCRIPTION im String
      tns_name = fullstring[0..start_pos_description-1]
      while tns_name[tns_name.length-1,1].match '[=,\(, ,\n,\r]'                # Zeichen nach dem TNSName entfernen
        tns_name = tns_name[0, tns_name.length-1]                               # Letztes Zeichen des Strings entfernen
      end
      while tns_name.index("\n")                                                # Alle Zeilen vor der mit DESCRIPTION entfernen
        tns_name = tns_name[tns_name.index("\n")+1, 10000]                      # Wert akzeptieren nach Linefeed wenn enthalten
      end
      fullstring = fullstring[start_pos_description + 10, 1000000]              # Rest des Strings fuer weitere Verarbeitung

      next if tns_name[0,1] == "#"                                              # Auskommentierte Zeile

      hostName, start_pos_host = extract_attr('HOST', fullstring)
      port,     start_pos_port = extract_attr('PORT', fullstring)

      if hostName.nil? || port.nil?
        Rails.logger.error('EnvHelper.read_tnsnames_internal') { "tnsnames.ora: cannot determine host and port for '#{tns_name}'" }
        next
      end

      hostName.downcase!

      if start_pos_host < start_pos_port
        fullstring = fullstring[start_pos_port + 5 + port.length, 1000000]
      else
        fullstring = fullstring[start_pos_host + 5 + hostName.length, 1000000]
      end

      # ermitteln SID oder alternativ Instance_Name oder Service_Name
      sid_tag_length = 4
      sid_usage = :SID
      start_pos_sid = fullstring.index('SID=')                                  # i.d.R. folgt unmittelbar ein "="
      start_pos_sid = fullstring.index('SID ') if start_pos_sid.nil? || fullstring.index('DESCRIPTION')<start_pos_sid    # evtl. " " zwischen SID und "=" and "SID=" of next entry found
      if start_pos_sid.nil? || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
        sid_tag_length = 12
        sid_usage = :SERVICE_NAME
        start_pos_sid = fullstring.index('SERVICE_NAME')
      end
      # Naechster Block mit Description beginnen wenn kein SID enthalten oder in naechster Description gefunden
      if start_pos_sid==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
        Rails.logger.error('EnvHelper.read_tnsnames_internal') { "tnsnames.ora: cannot determine sid or service_name for '#{tns_name}'" }
        next
      end
      fullstring = fullstring[start_pos_sid + sid_tag_length, 1000000]               # Rest des Strings fuer weitere Verarbeitung

      sidName = fullstring[0..fullstring.index(')')-1]
      sidName = sidName.delete(' ').delete('=')   # Entfernen Blank u.s.w.

      # Kompletter Record gefunden
      tnsnames[tns_name] = {:hostName => hostName, :port => port, :sidName => sidName, :sidUsage =>sid_usage }
    end
    tnsnames
  rescue Exception => e
    Rails.logger.error('EnvHelper.read_tnsnames_internal') { "Error processing #{file_name}: #{e.message}" }
    tnsnames
  end

  def check_awr_for_time_drift
    # TODO: Check with foreign time settings if End_Interval_Time_TZ can replace End_Interval_Time in selections
    if get_db_version >= '18.1' && [:diagnostics_pack, :diagnostics_and_tuning_pack].include?(PanoramaConnection.get_threadlocal_config[:management_pack_license])
      msg = ''
      sql_select_all("SELECT Snap_ID, DBID, Con_ID, End_Interval_Time, End_Interval_Time_TZ,
                             TO_CHAR(EXTRACT (Hour FROM Snap_Timezone), '00')||':'||TRIM(TO_CHAR(EXTRACT (Minute FROM Snap_Timezone), '00')) Snap_Timezone,
                             (CAST(End_Interval_Time AS DATE) - CAST(End_Interval_Time_TZ AS DATE)) *24 Diff_Hours
                      FROM DBA_Hist_Snapshot s1
                      WHERE  Snap_ID = (SELECT MAX(Snap_ID) FROM DBA_Hist_Snapshot s2 WHERE s2.DBID = s1.DBID)
                      AND    CAST(End_Interval_Time AS DATE) != CAST(End_Interval_Time_TZ AS DATE)
                     ").each do |s|
        msg << "Caution: Time drift in AWR snapshot times for DBID = #{s.dbid}, Con-ID = #{s.con_id}\n"
        msg << "Values of last AWR snapshot in DBA_Hist_Snapshot are:\n"
        msg << "End_Interval_Time = #{localeDateTime(s.end_interval_time)}:\n"
        msg << "End_Interval_Time_TZ = #{localeDateTime(s.end_interval_time_tz)}:\n"
        msg << "Snap_Timezone diff. to GMT = #{s.snap_timezone}:\n"
        msg << "Time drift between End_Interval_Time and End_Interval_Time_TZ = #{fn(s.diff_hours, 1)} hours\n\n"
      end
      if msg.length > 0
        msg << "AWR data selected by Panorama may be falsified regarding time boundaries!!!\n"
        add_statusbar_message(msg)
      end
    end
  end
end