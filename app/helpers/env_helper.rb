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

  # Einlesen last_logins aus client_info-store
  def read_last_logins
    last_logins = ClientInfoStore.read_for_client_key(get_decrypted_client_key,:last_logins, default: [])
    if last_logins.nil? || !last_logins.instance_of?(Array)
      last_logins = []
      write_last_logins(last_logins)   # Zurückschreiben in client_info-store
    end
    last_logins
  end

  # Zurückschreiben des logins in client_info_store
  def write_last_logins(last_logins)
    ClientInfoStore.write_for_client_key(get_decrypted_client_key,:last_logins, last_logins)
  end

  # Ensure client browser has unique client_key stored as cookie
  MAX_NEW_KEY_TRIES  = 1000
  def initialize_client_key_cookie
    if cookies[:client_key]
      begin
        Encryption.decrypt_value(cookies[:client_key], cookies[:client_salt]) # Test client_key-Cookie for possible decryption
      rescue Exception => e
        Rails.logger.error('EnvHelper.initialize_client_key_cookie') { "Exception #{e.message} while database_helper_decrypt_value(cookies[:client_key])" }
        cookies.delete(:client_key)                                            # Verwerfen des nicht entschlüsselbaren Cookies
        cookies.delete(:client_salt)
      end
    end

    if cookies[:client_key]
      if cookies.class.name != 'Rack::Test::CookieJar' # Don't set Hash for cookies in test because it becomes String like ' { :value => 100, :expires => ... }'
        cookies[:client_salt] = {:value => cookies[:client_salt], :expires => 1.year.from_now, httponly: true} # Timeout neu setzen bei Benutzung
        cookies[:client_key] = {:value => cookies[:client_key], :expires => 1.year.from_now, httponly: true} # Timeout neu setzen bei Benutzung
      end
    else # Erster Zugriff in neu gestartetem Browser oder Cookie nicht mehr verfügbar
      loop_count = 0
      while loop_count < MAX_NEW_KEY_TRIES
        loop_count = loop_count + 1
        new_client_key = rand(10000000)
        unless ClientInfoStore.exist?(new_client_key) # Dieser Key wurde noch nie genutzt
          # Salt immer mit belegen bei Vergabe des client_key, da es genutzt wird zur Verschlüsselung des Client_Key im cookie
          cookies[:client_salt] = {:value => rand(10000000000), :expires => 1.year.from_now, httponly: true} # Lokaler Schlüsselbestandteil im Browser-Cookie des Clients, der mit genutzt wird zur Verschlüsselung der auf Server gespeicherten Login-Daten
          cookies[:client_key] = {:value => Encryption.encrypt_value(new_client_key, cookies[:client_salt]), :expires => 1.year.from_now, httponly: true}
          ClientInfoStore.write(new_client_key, 1) # Marker fuer Verwendung des Client-Keys
          break
        end
      end
      raise "Cannot create client key after #{MAX_NEW_KEY_TRIES} tries" if loop_count >= MAX_NEW_KEY_TRIES
    end
  end

  # Helper to distinguish browser tabs, sets @browser_tab_id
  # @return [void]
  def initialize_browser_tab_id
    tab_ids = ClientInfoStore.read_for_client_key(get_decrypted_client_key,:browser_tab_ids, default: {})
    tab_ids = {} if tab_ids.class != Hash
    @browser_tab_id = 1                                                         # Default tab-id if no other exists
    while tab_ids.key?(@browser_tab_id) do
      if tab_ids[@browser_tab_id].key?(:last_page_load) && tab_ids[@browser_tab_id][:last_page_load] < Time.now-84600*10  # Reuse after 10 days
        break
      end
      @browser_tab_id += 1
    end
    tab_ids[@browser_tab_id] = {} if !tab_ids.key?(@browser_tab_id)             # create Hash for browser tab if not already exists
    tab_ids[@browser_tab_id][:last_page_load] = Time.now
    tab_ids[@browser_tab_id][:last_request]   = Time.now                        # Ensure that this browser tab entry will not be cleaned up by ClientInfoStore.cleanup in ConnectionTerminationJob
    ClientInfoStore.write_for_client_key(get_decrypted_client_key,:browser_tab_ids, tab_ids)
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

    fullstring = File.read(file_name, encoding: 'UTF-8')
    unless fullstring.valid_encoding?
      Rails.logger.info('EnvHelper.read_tnsnames_internal') { "File #{file_name} is not valid UTF-8, trying to read with ISO-8859-1 encoding" }
      fullstring = File.read(file_name, encoding: 'ISO-8859-1')
      unless fullstring.valid_encoding?
        Rails.logger.error('EnvHelper.read_tnsnames_internal') { "File #{file_name} is not valid UTF-8 or ISO-8859-1, cannot read tnsnames.ora file" }
        return {}
      end
    end

    fullstring.encode!(fullstring.encoding, {
      universal_newline: true,                                                  # Ensure that Windows-Linefeeds 0D0A are replaced by 0A
      invalid: :replace,
      undef: :replace,
      replace: ''
    }
    )
    fullstring.upcase!
    fullstring.gsub!(/#.*$/, '')                                                # Remove comments starting with # until end of line

    fullstring.scan(/^\s*IFILE\s*=\s*(.+)$/i).each do |ifile_match|
      ifile_path = ifile_match[0].strip
      # Relativer Pfad: relativ zur aktuellen Datei auflösen
      ifile_path = File.expand_path(ifile_path, File.dirname(file_name))

      Rails.logger.error('EnvHelper.read_tnsnames_internal') { "IFILE specified in tnsnames.ora but file not found at #{ifile_path}" } unless File.exist?(ifile_path)
      tnsnames.merge!(read_tnsnames_internal(ifile_path)) if File.exist?(ifile_path)
    end


    # Alias finden: Wort am Zeilenanfang gefolgt von =
    fullstring.scan(/^\s*(\w[\w.\-]*)\s*=\s*(\(.*?\n(?=\s*\w[\w.\-]*\s*=|\z))/mi).each do |alias_name, body|
      # Klammern normalisieren – Zeilenumbrüche/Whitespace komprimieren
      body = body.gsub(/\s+/, ' ').strip

      # Ersten HOST, PORT, SERVICE_NAME extrahieren (bei Failover = erster Eintrag)
      host         = body[/HOST\s*=\s*([^\)]+)/i, 1]&.strip
      port         = body[/PORT\s*=\s*([^\)]+)/i, 1]&.strip
      service_name = body[/SERVICE_NAME\s*=\s*([^\)]+)/i, 1]&.strip

      # Typ bestimmen und Fallback auf SID
      if service_name
        sid_usage = :SERVICE_NAME
      else
        service_name = body[/\bSID\s*=\s*([^\)]+)/i, 1]&.strip
        Rails.logger.error('EnvHelper.read_tnsnames_internal') { "tnsnames.ora: cannot determine service_name or sid for '#{alias_name}'" } if service_name.nil?
        sid_usage = :SID
      end

      alias_name.strip!

      tnsnames[alias_name] = {
        hostName: host,
        port:     port,
        sidName:  service_name,
        sidUsage: sid_usage,
      }
    end

    tnsnames
  end

  def check_awr_for_time_drift
    # TODO: Check with foreign time settings if End_Interval_Time_TZ can replace End_Interval_Time in selections
    if get_db_version >= '18.1' && PackLicense.diagnostics_pack_licensed?
      msg = String.new
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