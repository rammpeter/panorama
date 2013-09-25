# encoding: utf-8
class EnvController < ApplicationController
  layout "default"
  include EnvHelper
  include LicensingHelper

  # Einstieg in die Applikation, rendert nur das layout (default.rhtml), sonst nichts
  def index
    I18n.locale = :de                   # Default
    I18n.locale =  Marshal.load cookies[:locale]  if cookies[:locale]
    I18n.locale = session[:locale]                if session[:locale]

    session[:last_used_menu_controller] = "env"
    session[:last_used_menu_action]     = "index"
    session[:last_used_menu_caption]    = "Start"
    session[:last_used_menu_hint]       = t :menu_env_index_hint, :default=>"Start of application without connect to database"
  end

public
  # Aufgerufen aus dem Anmelde-Dialog für DB
  def set_database_by_id
    if params[:login]                                                           # Button Login gedrückt
      read_last_login_cookies.each do |db_cookie|
puts "#{db_cookie[:id]} , #{params[:saved_logins_id]}"
        if db_cookie[:id].to_i == params[:saved_logins_id].to_i                           # Diese DB wurde in leect-Liste ausgewählt
puts "Treffer"
          params[:database] = db_cookie                                         # Vorbelegen der Formular-Inhalte mit dieser DB
        end
      end
      params[:saveLogin] = "1"                                                  # Damit bei nächstem Refresh auf diesem Eintrag positioniert wird
      raise "env_controller.set_database_by_id: No database found to login! Please use direct login!" unless params[:database]
      set_database
    end

    if params[:delete]                                                          # Button DELETE gedrückt, Entfernen des aktuell selektierten Eintrages aus Liste der Cookies
      cookies_last_logins = read_last_login_cookies
      cookies_last_logins.each do |c|
        cookies_last_logins.delete c if c[:id].to_i == params[:saved_logins_id].to_i
      end

      write_last_login_cookies(cookies_last_logins)
      respond_to do |format|
        format.js {render :js => "window.location.reload();" }                  # Neuladen der gesamten HTML-Seite, damit Entfernung des Eintrages auch sichtbar wird
      end
    end

  end

  # Aufgerufen aus dem Anmelde-Dialog für DB
  def set_database
    # Test auf Lesbarkeit von X$-Tabellen
    def x_memory_table_accessible?(table_name_suffix, msg)
      begin
        sql_select_all "SELECT /* Panorama Tool Ramm */ * FROM X$#{table_name_suffix} WHERE RowNum < 1"
        return true
      rescue Exception => e
        msg << "<div> User '#{@database.user}' hat kein Leserecht auf X$#{table_name_suffix} ! Damit sind einige Funktionen von Panorama nicht nutzbar!<br/>"
        msg << "#{e.message}<br/><br/>"
        msg << "Workaround:<br/>"
        msg << "Variante 1: Anmelden mit Rolle SYSDBA<br/>"
        msg << "Variante 2: Ausführen als User SYS<br/>"
        msg << "> create view X_$#{table_name_suffix} as select * from X$#{table_name_suffix};<br/>"
        msg << "> create public synonym X$#{table_name_suffix} for sys.X_$#{table_name_suffix};<br/>"
        msg << "Damit wird X$#{table_name_suffix} verfügbar unter Rolle SELECT ANY DICTIONARY"
        msg << "<br></div>"
        return false
      end
    end


    I18n.locale = params[:database][:locale]      # fuer laufende Action Sprache aktiviert
    cookies.permanent[:locale] = Marshal.dump params[:database][:locale]  # Default für erste Seite

    session[:last_used_menu_controller] = "env"
    session[:last_used_menu_action]     = "set_database"
    session[:last_used_menu_caption]    = "Login"
    session[:last_used_menu_hint]       = t :menu_env_set_database_hint, :default=>"Start of application after connect to database"

    @database = Database.new( params[ :database ] ? params[ :database ] : params )

    if !@database.host || @database.host == ""  # Hostname nicht belegt, dann TNS-Alias auswerten
      tns_record = read_tnsnames[@database.tns]   # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      unless tns_record
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Eintrag für DB '#{@database.tns}' nicht gefunden in tnsnames.ora"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        set_dummy_db_connection
        return
      end
      @database.host      = tns_record[:hostName]   # Erweitern um Attribute aus tnsnames.ora
      @database.port      = tns_record[:port]       # Erweitern um Attribute aus tnsnames.ora
      @database.sid       = tns_record[:sidName]    # Erweitern um Attribute aus tnsnames.ora
      @database.sid_usage = tns_record[:sidUsage]   # :SID oder :SERVICE_NAME
    else # Host, Port, SID auswerten
      @database.sid_usage = :SID   # Erst mit SID versuchen, zweiter Versuch dann als ServiceName
      @database.tns       = "#{@database.host}:#{@database.port}:#{@database.sid}"   # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
    end

    # Temporaerer Schutz des Produktionszuganges bis zur Implementierung LDAP-Autorisierung    
    if @database.host.rindex("noaa") || @database.host.rindex("noab")
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
    @database.open_oracle_connection   # Oracle-Connection aufbauen

    # Test der Connection und ruecksetzen auf vorherige wenn fehlschlaegt
    begin
      # Test auf Funktionieren der Connection
      begin
        sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
      rescue Exception => e    # 2. Versuch mit alternativer SID-Deutung
        @database.switch_sid_usage
        @database.open_oracle_connection   # Oracle-Connection aufbauen
        sql_select_all "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"
      end
    rescue Exception => e
      set_dummy_db_connection
      respond_to do |format|
        format.js {render :js => "$('#content_for_layout').html('#{j "Fehler bei Anmeldung an DB: <br>
                                                                      #{e.message}<br>
                                                                      Host: #{@database.host}<br>
                                                                      Port: #{@database.port}<br>
                                                                      SID: #{@database.sid}"
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
      @database.read_initial_db_values
      @banners = sql_select_all "SELECT /* Panorama Tool Ramm */ Banner FROM V$Version"
      @instance_data = sql_select_all "SELECT /* Panorama Tool Ramm */ gi.*, i.Instance_Number Instance_Connected,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_CHARACTERSET') NLS_CharacterSet,
                                                      (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'cpu_count') CPU_Count
                                               FROM  GV$Instance gi
                                               LEFT OUTER JOIN v$Instance i ON i.Instance_Number = gi.Instance_Number"
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
      @dictionary_access_msg << "<div><br>User '#{@database.user}' hat kein Leserecht auf Data Dictionary!<br/>#{e.message}<br/>Funktionen von Panorama werden nicht oder nur eingeschränkt nutzbar sein</div>"
    end

    @dictionary_access_problem = true if !x_memory_table_accessible?("BH", @dictionary_access_msg )

    if !sql_select_one("SELECT * FROM User_SYS_Privs WHERE Privilege = 'SELECT ANY DICTIONARY'") &&
       !sql_select_one("SELECT * FROM user_Role_Privs WHERE Granted_Role = 'DBA'")
      @dictionary_access_problem = true    # Fehler bei Zugriff auf Dictionary
      @dictionary_access_msg << "<div><br>User '#{@database.user}' does not have grant SELECT ANY DICTIONARY or DBA! Only less functions of Panorama are usable for this user account!</div>"
    end


    session[:database] = @database
    write_connection_to_cookie @database
    @license_ok = check_license(@instance_name, @host_name, @database.port)

    timepicker_regional = ""
    if session[:database].locale == "de"  # Deutsche Texte für DateTimePicker
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
      format.js {render :js => "$('#current_tns').html('#{j "<span title='TNS=#{@database.tns},Host=#{@database.host},Port=#{@database.port},#{@database.sid_usage}=#{@database.sid}, User=#{@database.user}'>#{@database.user}@#{@database.tns}</span>"}');
                                $('#main_menu').html('#{j render_to_string :partial =>"build_main_menu" }');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{session[:database].timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                numeric_decimal_separator = '#{session[:database].numeric_decimal_separator}';
                                var session_locale = '#{session[:database].locale}';
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

  def show_licensed_databases
    output = ""
    license_list.each do |l|
      output << "SID=#{l[:sid]}"
      output << ", Host=#{l[:host]}" if l[:host]
      output << ", Port=#{l[:port]}" if l[:port]
      output << "<br>"
    end

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output}');" }
    end
  end

private
  # Schreiben der aktuellen Connection in Cookie, wenn neue dabei
  def write_connection_to_cookie database
    cookies_last_logins = read_last_login_cookies

    max_id = 0
    cookies_last_logins.each do |value|
      max_id = value[:id] if max_id < value[:id]    # Ermitteln der max. ID einer Database
    end
    new_database_id = max_id + 1

    cookies_last_logins.each do |value|
      if value && value[:sid] == database.sid && value[:host] == database.host && value[:user] == database.user
        new_database_id = value[:id]                          # Beim erneuten Speichern der DB die selbe ID verwenden statt hochzaehlen
        cookies_last_logins.delete(value)                     # Aktuellen eintrag entfernen
      end
    end
    if params[:saveLogin] == "1"
      database.id = new_database_id                           # Eindeutiges Kriterium für Wiederverwendung
      cookies_last_logins << database.to_params  # Aktuellen Eintrag hinzufügen
      cookies_last_logins.sort_by!{|obj| "#{obj[:sid]}.#{obj[:host]}.#{obj[:user]}"}
      cookies.permanent[:last_login_id]  = Marshal.dump database.id             # Merken der ID der aktuellen DB
      write_last_login_cookies(cookies_last_logins)                             # Zurückschreiben des Cookies in cookie-store
    end

  end

  def check_license(sid, host, port)
    return false unless sid
    license_list.each do |l|
      return true if sid.upcase==l[:sid].upcase && ( l[:host].nil? || host.upcase.match(l[:host].upcase) ) && ( l[:port].nil? || port==l[:port] )
    end
    false
  end

public
  # DBID explizit setzen wenn mehrere verschiedene in Historie vorhande
  def set_dbid
    session[:database].dbid = params[:dbid]
    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j "DBID for access on AWR history set to #{session[:database].dbid }"}');"}
    end
  end


end
