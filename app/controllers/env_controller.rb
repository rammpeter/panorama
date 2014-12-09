# encoding: utf-8


class EnvController < ApplicationController
  layout 'application'
  #include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include EnvHelper
  include MenuHelper
  include LicensingHelper

  # Verhindern "ActionController::InvalidAuthenticityToken" bei erstem Aufruf der Seite
  protect_from_forgery except: :index

  private
  # Merken locale für weitere Verwendung
  def register_locale(locale)
    session[:locale] = locale
    cookies[:locale] = { :value => locale, :expires => 1.year.from_now }  # sichern als separater Cookie, da session nur Lebenszeit der Browser-Session hat
  end

  public
  # Einstieg in die Applikation, rendert nur das layout (default.rhtml), sonst nichts
  def index
    session[:database] = nil   if session[:database].class.name != 'Hash'       # Abwärtskompatibilität zu Vorversion

    session[:locale] = cookies[:locale]                         # locale aus Cookie restaurieren
    session[:locale] = "en" if session[:locale].nil?  || !['de', 'en'].include?(session[:locale])
    I18n.locale = session[:locale]

    session[:last_used_menu_controller] = "env"
    session[:last_used_menu_action]     = "index"
    session[:last_used_menu_caption]    = "Start"
    session[:last_used_menu_hint]       = t :menu_env_index_hint, :default=>"Start of application without connect to database"
  rescue Exception=>e
    session[:database] = nil                                                    # Sicherstellen, dass bei naechstem Aufruf neuer Einstieg
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
    register_locale(params[:locale])

    respond_to do |format|
      format.js {render :js => "window.location.reload();" }                    # Reload der Sganzen Seite
    end
  end

  # Aufgerufen aus dem Anmelde-Dialog für gemerkte DB-Connections
  def set_database_by_id
    if params[:login]                                                           # Button Login gedrückt
      params[:database] = read_last_login_cookies[params[:saved_logins_id].to_i]   # Position des aktuell ausgewählten in Array

      params[:saveLogin] = "1"                                                  # Damit bei nächstem Refresh auf diesem Eintrag positioniert wird
      raise "env_controller.set_database_by_id: No database found to login! Please use direct login!" unless params[:database]
      set_database
    end

    if params[:delete]                                                          # Button DELETE gedrückt, Entfernen des aktuell selektierten Eintrages aus Liste der Cookies
      cookies_last_logins = read_last_login_cookies
      cookies_last_logins.delete_at(params[:saved_logins_id].to_i)

      write_last_login_cookies(cookies_last_logins)
      respond_to do |format|
        format.js {render :js => "window.location.reload();" }                  # Neuladen der gesamten HTML-Seite, damit Entfernung des Eintrages auch sichtbar wird
      end
    end

  end

  # Aufgerufen aus dem Anmelde-Dialog für DB mit Angabe der Login-Info
  def set_database_by_params
    # Passwort sofort verschlüsseln als erstes und nur in verschlüsselter Form in session-Hash speichern
    params[:database][:password]  = database_helper_encrypt_value(params[:database][:password])

    register_locale(params[:database][:locale])                                          # Wert initial setzen auf Vorgabe
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
        msg << "<div> User '#{session[:database][:user]}' hat kein Leserecht auf X$#{table_name_suffix} ! Damit sind einige Funktionen von Panorama nicht nutzbar!<br/>"
        msg << "#{e.message}<br/><br/>"
        msg << "Workaround:<br/>"
        msg << "Variante 1: Anmelden mit Rolle SYSDBA<br/>"
        msg << "Variante 2: Ausführen als User SYS<br/>"
        msg << "> create view X_$#{table_name_suffix} as select * from X$#{table_name_suffix};<br/>"
        msg << "> create public synonym X$#{table_name_suffix} for sys.X_$#{table_name_suffix};<br/>"
        msg << "Damit wird X$#{table_name_suffix} verfügbar unter Rolle SELECT ANY DICTIONARY"
        msg << "</div>"
        return false
      end
    end

    session[:last_used_menu_controller] = "env"
    session[:last_used_menu_action]     = "set_database"
    session[:last_used_menu_caption]    = "Login"
    session[:last_used_menu_hint]       = t :menu_env_set_database_hint, :default=>"Start of application after connect to database"

    session[:database] = params[:database].to_h.symbolize_keys

    if params[:database][:modus] == 'tns'                    # TNS-Alias auswerten
      tns_record = read_tnsnames[session[:database][:tns]]   # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      unless tns_record
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Eintrag für DB '#{session[:database][:tns]}' nicht gefunden in tnsnames.ora"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        set_dummy_db_connection
        return
      end
      session[:database][:host]      = tns_record[:hostName]   # Erweitern um Attribute aus tnsnames.ora
      session[:database][:port]      = tns_record[:port]       # Erweitern um Attribute aus tnsnames.ora
      session[:database][:sid]       = tns_record[:sidName]    # Erweitern um Attribute aus tnsnames.ora
      session[:database][:sid_usage] = tns_record[:sidUsage]   # :SID oder :SERVICE_NAME
    else # Host, Port, SID auswerten
      session[:database][:sid_usage] = :SID unless session[:database][:sid_usage]  # Erst mit SID versuchen, zweiter Versuch dann als ServiceName
      session[:database][:tns]       = "#{session[:database][:host]}:#{session[:database][:port]}:#{session[:database][:sid]}"   # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
    end

    # Temporaerer Schutz des Produktionszuganges bis zur Implementierung LDAP-Autorisierung    
    if session[:database][:host].upcase.rindex("DM03-SCAN") && session[:database][:sid].upcase.rindex("NOADB")
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

    open_oracle_connection   # Oracle-Connection aufbauen

    # Test der Connection und ruecksetzen auf vorherige wenn fehlschlaegt
    begin
      # Test auf Funktionieren der Connection
      begin
        sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
      rescue Exception => e    # 2. Versuch mit alternativer SID-Deutung
        Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
        Rails.logger.error e.message
        Rails.logger.error 'Switching between SID and SERVICE_NAME'

        database_helper_switch_sid_usage
        open_oracle_connection   # Oracle-Connection aufbauen mit Wechsel zwischen SID und ServiceName
        begin
          sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
        rescue Exception => e    # 3. Versuch mit alternativer SID-Deutung
          Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{session[:database][:tns]}' User='#{session[:database][:user]}'"
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
                                                                      Host: #{session[:database][:host]}<br>
                                                                      Port: #{session[:database][:port]}<br>
                                                                      SID: #{session[:database][:sid]}"
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
      @instance_data = sql_select_all "SELECT /* Panorama Tool Ramm */ gi.*, i.Instance_Number Instance_Connected,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_CHARACTERSET') NLS_CharacterSet,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_NCHAR_CHARACTERSET') NLS_NChar_CharacterSet,
                                                      (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'cpu_count') CPU_Count,
                                                      d.Open_Mode, d.Protection_Mode, d.Protection_Level, d.Switchover_Status, d.Dataguard_Broker, d.Force_Logging
                                               FROM  GV$Instance gi
                                               JOIN  v$Database d ON 1=1
                                               LEFT OUTER JOIN v$Instance i ON i.Instance_Number = gi.Instance_Number
                                      "
      @instance_data.each do |i|
        if i.instance_connected
          @instance_name = i.instance_name
          @host_name     = i.host_name
        end
      end
      @dbids = sql_select_all  "SELECT DBID, MIN(Begin_Interval_Time) Min_TS, MAX(End_Interval_Time) Max_TS
                                FROM   DBA_Hist_Snapshot
                                GROUP BY DBID
                                ORDER BY MIN(Begin_Interval_Time)"
      @platform_name = sql_select_one "SELECT /* Panorama Tool Ramm */ Platform_name FROM v$Database"  # Zugriff ueber Hash, da die Spalte nur in Oracle-Version > 9 existiert
    rescue Exception => e
      @dictionary_access_problem = true    # Fehler bei Zugriff auf Dictionary
      @dictionary_access_msg << "<div> User '#{session[:database][:user]}' hat kein Leserecht auf Data Dictionary!<br/>#{e.message}<br/>Funktionen von Panorama werden nicht oder nur eingeschränkt nutzbar sein<br/>
      </div>"
    end

    @dictionary_access_problem = true if !x_memory_table_accessible?("BH", @dictionary_access_msg )

    write_connection_to_cookie

    timepicker_regional = ""
    if session[:locale] == "de"  # Deutsche Texte für DateTimePicker
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
      format.js {render :js => "$('#current_tns').html('#{j "<span title='TNS=#{session[:database][:tns]},Host=#{session[:database][:host]},Port=#{session[:database][:port]},#{session[:database][:sid_usage]}=#{session[:database][:sid]}, User=#{session[:database][:user]}'>#{session[:database][:user]}@#{session[:database][:tns]}</span>"}');
                                $('#main_menu').html('#{j render_to_string :partial =>"build_main_menu" }');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                numeric_decimal_separator = '#{numeric_decimal_separator}';
                                var session_locale = '#{session[:locale]}';
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
  # Schreiben der aktuellen Connection in Cookie, wenn neue dabei
  def write_connection_to_cookie

    database = session[:database]                                              # Hash für Speicherung in Cookie

    cookies_last_logins = read_last_login_cookies
    min_id = nil

    cookies_last_logins.each do |value|
      cookies_last_logins.delete(value) if value && value[:sid] == database[:sid] && value[:host] == database[:host] && value[:user] == database[:user]    # Aktuellen eintrag entfernen
    end
    if params[:saveLogin] == "1"
      cookies_last_logins = [database] + cookies_last_logins                    # Neuen Eintrag an erster Stelle
      write_last_login_cookies(cookies_last_logins)                             # Zurückschreiben des Cookies in cookie-store
    end

  end


public
  # DBID explizit setzen wenn mehrere verschiedene in Historie vorhande
  def set_dbid
    session[:dbid] = params[:dbid]
    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j "DBID for access on AWR history set to #{session[:dbid] }"}');"}
    end
  end


end

