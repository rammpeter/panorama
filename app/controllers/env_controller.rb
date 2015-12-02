# encoding: utf-8


class EnvController < ApplicationController
  layout 'application'
  #include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include EnvHelper
  include MenuHelper
  include LicensingHelper

  # Verhindern "ActionController::InvalidAuthenticityToken" bei erstem Aufruf der Seite
  protect_from_forgery except: :index

  public
  MAX_NEW_KEY_TRIES  = 1000
  # Einstieg in die Applikation, rendert nur das layout (default.rhtml), sonst nichts
  def index
    # Test ob sich client_key-Cookie entschlüsseln lässt
    begin
      database_helper_decrypt_value(cookies[:client_key])
    rescue Exception
      cookies.delete(:client_key)                                               # Verwerfen des nicht entschlüsselbaren Cookies
      cookies.delete(:client_salt)
    end


    unless cookies[:client_key]                                                 # Erster Zugriff in neu gestartetem Browser oder Cookie nicht mehr verfügbar
      loop_count = 0
      while loop_count < MAX_NEW_KEY_TRIES
        loop_count++
        new_client_key = rand(10000000)
        if !get_client_info_store.exist?(new_client_key)                        # Dieser Key wurde noch nie genutzt
          # Salt immer mit belegen bei Vergabe des client_key, da es genutzt wird zur Verschlüsselung des Client_Key im cookie
          cookies[:client_salt] = { :value => rand(10000000000),                              :expires => 1.year.from_now }  # Lokaler Schlüsselbestandteil im Browser-Cookie des Clients, der mit genutzt wird zur Verschlüsselung der auf Server gespeicherten Login-Daten
          cookies[:client_key]  = { :value => database_helper_encrypt_value(new_client_key),  :expires => 1.year.from_now }
          get_client_info_store.write(new_client_key, 1)                        # Marker fuer Verwendung des Client-Keys
          break
        end
      end
      raise "Cannot create client key after #{MAX_NEW_KEY_TRIES} tries" if loop_count >= MAX_NEW_KEY_TRIES
    else
      cookies[:client_salt] = { :value => cookies[:client_salt], :expires => 1.year.from_now }    # Timeout neu setzen bei Benutzung
      cookies[:client_key]  = { :value => cookies[:client_key],  :expires => 1.year.from_now }    # Timeout neu setzen bei Benutzung
    end

    # Entfernen evtl. bisheriger Bestandteile des Session-Cookies
    cookies.delete(:locale)                         if cookies[:locale]
    cookies.delete(:last_logins)                    if cookies[:last_logins]
    session.delete(:locale)                         if session[:locale]
    session.delete(:last_used_menu_controller)      if session[:last_used_menu_controller]
    session.delete(:last_used_menu_action)          if session[:last_used_menu_action]
    session.delete(:last_used_menu_caption)         if session[:last_used_menu_caption]
    session.delete(:last_used_menu_hint)            if session[:last_used_menu_hint]
    session.delete(:database)                       if session[:database]
    session.delete(:dbid)                           if session[:dbid]
    session.delete(:version)                        if session[:version]
    session.delete(:db_block_size)                  if session[:db_block_size]
    session.delete(:wordsize)                       if session[:wordsize]
    session.delete(:dba_hist_cache_objects_owner)   if session[:dba_hist_cache_objects_owner]
    session.delete(:dba_hist_blocking_locks_owner)  if session[:dba_hist_blocking_locks_owner]
    session.delete(:request_counter)                if session[:request_counter]
    session.delete(:instance)                       if session[:instance]
    session.delete(:time_selection_start)           if session[:time_selection_start]
    session.delete(:time_selection_end)             if session[:time_selection_end]


    set_I18n_locale(get_locale)                                                 # ruft u.a. I18n.locale = get_locale auf

    write_to_client_info_store(:last_used_menu_controller,  'env')
    write_to_client_info_store(:last_used_menu_action,      'index')
    write_to_client_info_store(:last_used_menu_caption,     'Start')
    write_to_client_info_store(:last_used_menu_hint,        t(:menu_env_index_hint, :default=>"Start of application without connect to database"))
  rescue Exception=>e
    set_current_database(nil)                                                   # Sicherstellen, dass bei naechstem Aufruf neuer Einstieg
    raise e                                                                     # Werfen der Exception
  end

  # Auffüllen SELECT mit OPTION aus tns-Records
  def get_tnsnames_records
    tnsnames = read_tnsnames

    result = ''
    tnsnames.keys.sort.each do |key|
      result << "jQuery('#database_tns').append('<option value=\"#{key}\">'+rpad('#{key}', 180, 'database_tns')+'&nbsp;&nbsp;#{tnsnames[key][:hostName]} : #{tnsnames[key][:port]} : #{tnsnames[key][:sidName]}</value>');\n"
    end

    respond_to do |format|
      format.js {render :js => result }
    end
  end

  # Wechsel der Sprache in Anmeldedialog
  def set_locale
    set_I18n_locale(params[:locale])                                            # Merken in Client_Info_Cache

    respond_to do |format|
      format.js {render :js => "window.location.reload();" }                    # Reload der Sganzen Seite
    end
  end

  # Aufgerufen aus dem Anmelde-Dialog für gemerkte DB-Connections
  def set_database_by_id
    if params[:login]                                                           # Button Login gedrückt
      params[:database] = read_last_logins[params[:saved_logins_id].to_i]   # Position des aktuell ausgewählten in Array

      params[:saveLogin] = "1"                                                  # Damit bei nächstem Refresh auf diesem Eintrag positioniert wird
      raise "env_controller.set_database_by_id: No database found to login! Please use direct login!" unless params[:database]
      set_database
    end

    if params[:delete]                                                          # Button DELETE gedrückt, Entfernen des aktuell selektierten Eintrages aus Liste der gespeicherten Logins
      last_logins = read_last_logins
      last_logins.delete_at(params[:saved_logins_id].to_i)

      write_last_logins(last_logins)
      respond_to do |format|
        format.js {render :js => "window.location.reload();" }                  # Neuladen der gesamten HTML-Seite, damit Entfernung des Eintrages auch sichtbar wird
      end
    end

  end

  # Aufgerufen aus dem Anmelde-Dialog für DB mit Angabe der Login-Info
  def set_database_by_params
    # Passwort sofort verschlüsseln als erstes und nur in verschlüsselter Form in session-Hash speichern
    params[:database][:password]  = database_helper_encrypt_value(params[:database][:password])

    set_I18n_locale(params[:database][:locale])
    set_database
  end

  # Erstes Anmelden an DB
  def set_database
    # Test auf Lesbarkeit von X$-Tabellen
    def x_memory_table_accessible?(table_name_suffix, msg)
      begin
        sql_select_all "SELECT /* Panorama Tool Ramm */ * FROM X$#{table_name_suffix} WHERE RowNum < 1"
        return true
      rescue Exception => e
        msg << "<div>#{t(:env_set_database_xmem_line1, :user=>get_current_database[:user], :table_name_suffix=>table_name_suffix, :default=>'User %{user} has no right to read on X$%{table_name_suffix} ! This way less number of functions of Panorama is not usable!')}<br/>"
        msg << "#{e.message}<br/><br/>"
        msg << "Workaround:<br/>"
        msg << "#{t(:env_set_database_xmem_line2, :default=>'Alternative 1: Connect with role SYSDABA')}<br/>"
        msg << "#{t(:env_set_database_xmem_line3, :default=>'Alternative 2: Execute as user SYS')}<br/>"
        msg << "> create view X_$#{table_name_suffix} as select * from X$#{table_name_suffix};<br/>"
        msg << "> create public synonym X$#{table_name_suffix} for sys.X_$#{table_name_suffix};<br/>"
        msg << t(:env_set_database_xmem_line4, :table_name_suffix=>table_name_suffix, :default=>'This way X$%{table_name_suffix} becomes available with role SELECT ANY DICTIONARY')
        msg << "</div>"
        return false
      end
    end

    write_to_client_info_store(:last_used_menu_controller, "env")
    write_to_client_info_store(:last_used_menu_action,     "set_database")
    write_to_client_info_store(:last_used_menu_caption,    "Login")
    write_to_client_info_store(:last_used_menu_hint,       t(:menu_env_set_database_hint, :default=>"Start of application after connect to database"))

    current_database = params[:database].symbolize_keys                         # Puffern in lokaler Variable, bevor in client_info-Cache geschrieben wird

    if params[:database][:modus] == 'tns'                    # TNS-Alias auswerten
      tns_records = read_tnsnames                            # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      tns_record = tns_records[current_database[:tns]]
      unless tns_record
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Eintrag für DB '#{current_database[:tns]}' nicht gefunden in tnsnames.ora"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        set_dummy_db_connection
        return
      end
      current_database[:host]      = tns_record[:hostName]   # Erweitern um Attribute aus tnsnames.ora
      current_database[:port]      = tns_record[:port]       # Erweitern um Attribute aus tnsnames.ora
      current_database[:sid]       = tns_record[:sidName]    # Erweitern um Attribute aus tnsnames.ora
      current_database[:sid_usage] = tns_record[:sidUsage]   # :SID oder :SERVICE_NAME
    else # Host, Port, SID auswerten
      current_database[:sid_usage] = :SID unless current_database[:sid_usage]  # Erst mit SID versuchen, zweiter Versuch dann als ServiceName
      current_database[:tns]       = "#{current_database[:host]}:#{current_database[:port]}:#{current_database[:sid]}"   # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
    end

    # Temporaerer Schutz des Produktionszuganges bis zur Implementierung LDAP-Autorisierung    
    if current_database[:host].upcase.rindex("DM03-SCAN") && current_database[:sid].upcase.rindex("NOADB")
      if params[:database][:authorization]== nil  || params[:database][:authorization]==""
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "zusätzliche Autorisierung erforderlich fuer NOA-Produktionssystem"}'); $('#login_dialog_authorization').show(); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        set_dummy_db_connection
        return
      end
      if params[:database][:authorization]== nil || params[:database][:authorization]!="meyer"
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Autorisierung '#{params[:database][:authorization]}' ungueltig fuer NOA-Produktionssystem"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        set_dummy_db_connection
        return
      end
    end

    set_current_database(current_database)                                      # Persistieren im Cache

    open_oracle_connection   # Oracle-Connection aufbauen

    # Test der Connection und ruecksetzen auf vorherige wenn fehlschlaegt
    begin
      # Test auf Funktionieren der Connection
      begin
        sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
      rescue Exception => e    # 2. Versuch mit alternativer SID-Deutung
        Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{get_current_database[:tns]}' User='#{get_current_database[:user]}'"
        Rails.logger.error e.message
        Rails.logger.error 'Switching between SID and SERVICE_NAME'

        database_helper_switch_sid_usage
        open_oracle_connection   # Oracle-Connection aufbauen mit Wechsel zwischen SID und ServiceName
        begin
          sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
        rescue Exception => e    # 3. Versuch mit alternativer SID-Deutung
          Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{get_current_database[:tns]}' User='#{get_current_database[:user]}'"
          Rails.logger.error e.message
          Rails.logger.error 'Error persists, switching back between SID and SERVICE_NAME'
          database_helper_switch_sid_usage
          open_oracle_connection   # Oracle-Connection aufbauen mit Wechsel zurück zwischen SID und ServiceName
          sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"    # Provozieren der ursprünglichen Fehlermeldung wenn auch zweiter Versuch fehlschlägt
        end
      end
    rescue Exception => e
      set_dummy_db_connection
      respond_to do |format|
        format.js {render :js => "$('#content_for_layout').html('#{j "Fehler bei Anmeldung an DB: <br>
                                                                      #{e.message}<br>
                                                                      URL:  '#{jdbc_thin_url}'<br>
                                                                      Host: #{get_current_database[:host]}<br>
                                                                      Port: #{get_current_database[:port]}<br>
                                                                      SID: #{get_current_database[:sid]}"
                                                                  }');
                                    $('#login_dialog').effect('shake', { times:3 }, 100);
                                 "
                  }
      end
      return        # Fehler-Ausgang
    end

    @dictionary_access_msg = ""       # wird additiv belegt in Folge
    @dictionary_access_problem = false    # Default, keine Fehler bei Zugriff auf Dictionary
    begin
      @banners       = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @instance_data = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @dbids         = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @platform_name = ""   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      # Einlesen der DBID der Database, gleichzeitig Test auf Zugriffsrecht auf DataDictionary
      read_initial_db_values
      @banners = sql_select_all "SELECT /* Panorama Tool Ramm */ Banner FROM V$Version"
      @instance_data = sql_select_all ["SELECT /* Panorama Tool Ramm */ gi.*, i.Instance_Number Instance_Connected,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_CHARACTERSET') NLS_CharacterSet,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_NCHAR_CHARACTERSET') NLS_NChar_CharacterSet,
                                                      (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'cpu_count') CPU_Count,
                                                      d.Open_Mode, d.Protection_Mode, d.Protection_Level, d.Switchover_Status, d.Dataguard_Broker, d.Force_Logging,
                                                      ws.Snap_Interval_Minutes, ws.Snap_Retention_Days
                                               FROM  GV$Instance gi
                                               JOIN  v$Database d ON 1=1
                                               LEFT OUTER JOIN v$Instance i ON i.Instance_Number = gi.Instance_Number
                                               LEFT OUTER JOIN (SELECT DBID, MIN(EXTRACT(MINUTE FROM Snap_Interval)) Snap_Interval_Minutes, MIN(EXTRACT(DAY FROM Retention)) Snap_Retention_Days FROM DBA_Hist_WR_Control GROUP BY DBID) ws ON ws.DBID = ?
                                      ", get_dbid ]

      @instance_data.each do |i|
        if i.instance_connected
          @instance_name = i.instance_name
          @host_name     = i.host_name
        end
      end
      @dbids = sql_select_all ["SELECT s.DBID, MIN(Begin_Interval_Time) Min_TS, MAX(End_Interval_Time) Max_TS,
                                       (SELECT MIN(DB_Name) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) DB_Name,
                                       (SELECT COUNT(DISTINCT Instance_Number) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) Instances,
                                       MIN(EXTRACT(MINUTE FROM w.Snap_Interval)) Snap_Interval_Minutes,
                                       MIN(EXTRACT(DAY FROM w.Retention))        Snap_Retention_Days
                                FROM   DBA_Hist_Snapshot s
                                LEFT OUTER JOIN DBA_Hist_WR_Control w ON w.DBID = s.DBID
                                GROUP BY s.DBID
                                ORDER BY MIN(Begin_Interval_Time)"]
      @platform_name = sql_select_one "SELECT /* Panorama Tool Ramm */ Platform_name FROM v$Database"  # Zugriff ueber Hash, da die Spalte nur in Oracle-Version > 9 existiert
    rescue Exception => e
      @dictionary_access_problem = true    # Fehler bei Zugriff auf Dictionary
      @dictionary_access_msg << "<div> User '#{get_current_database[:user]}' hat kein Leserecht auf Data Dictionary!<br/>#{e.message}<br/>Funktionen von Panorama werden nicht oder nur eingeschränkt nutzbar sein<br/>
      </div>"
    end

    @dictionary_access_problem = true if !x_memory_table_accessible?("BH", @dictionary_access_msg )

    write_connection_to_last_logins

    initialize_unique_area_id                                                   # Zaehler für eindeutige IDs ruecksetzen

    timepicker_regional = ""
    if get_locale == "de"  # Deutsche Texte für DateTimePicker
      timepicker_regional = "prevText: '<zurück',
                                    nextText: 'Vor>',
                                    monthNames: ['Januar','Februar','März','April','Mai','Juni', 'Juli','August','September','Oktober','November','Dezember'],
                                    dayNamesMin: ['So','Mo','Di','Mi','Do','Fr','Sa'],
                                    timeText: 'Zeit',
                                    hourText: 'Stunde',
                                    minuteText: 'Minute',
                                    currentText: 'Jetzt',
                                    closeText: 'Auswählen',"
    end
    respond_to do |format|
      format.js {render :js => "$('#current_tns').html('#{j "<span title='TNS=#{get_current_database[:tns]},Host=#{get_current_database[:host]},Port=#{get_current_database[:port]},#{get_current_database[:sid_usage]}=#{get_current_database[:sid]}, User=#{get_current_database[:user]}'>#{get_current_database[:user]}@#{get_current_database[:tns]}</span>"}');
                                $('#main_menu').html('#{j render_to_string :partial =>"build_main_menu" }');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                numeric_decimal_separator = '#{numeric_decimal_separator}';
                                var session_locale = '#{get_locale}';
                                $('#content_for_layout').html('#{j render_to_string :partial=> "env/set_database"}');
                                $('#login_dialog').dialog('close');
                                "
                }
    end
  rescue Exception=>e
    set_dummy_db_connection                                                     # Rückstellen auf neutrale DB
    raise e
  end

  # Rendern des zugehörigen Templates, wenn zugehörige Action nicht selbst existiert
  def render_menu_action
    # Template der eigentlichen Action rendern
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"#{params[:redirect_controller]}/#{params[:redirect_action]}"}');" }
    end
  end


private
  # Schreiben der aktuellen Connection in last logins, wenn neue dabei
  def write_connection_to_last_logins

    database = read_from_client_info_store(:current_database)

    last_logins = read_last_logins
    min_id = nil

    last_logins.each do |value|
      last_logins.delete(value) if value && value[:sid] == database[:sid] && value[:host] == database[:host] && value[:user] == database[:user]    # Aktuellen eintrag entfernen
    end
    if params[:saveLogin] == "1"
      last_logins = [database] + last_logins                                    # Neuen Eintrag an erster Stelle
      write_last_logins(last_logins)                                            # Zurückschreiben in client-info-store
    end

  end


public
  # DBID explizit setzen wenn mehrere verschiedene in Historie vorhande
  def set_dbid
    set_cached_dbid(params[:dbid])
    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j "DBID for access on AWR history set to #{get_dbid}"}');"}
    end
  end

  # repeat last called menu action
  def repeat_last_menu_action
    controller_name = read_from_client_info_store(:last_used_menu_controller)
    action_name     = read_from_client_info_store(:last_used_menu_action)

    # Suchen des div im Menü-ul und simulieren eines clicks auf den Menü-Eintrag
    respond_to do |format|
      format.js {render :js => "$('#menu_#{controller_name}_#{action_name}').click();"}
    end
  end

end

