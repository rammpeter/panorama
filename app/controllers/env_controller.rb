# encoding: utf-8
class EnvController < ApplicationController
  layout "default"
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
        msg << "</div>"
        return false
      end
    end

    I18n.locale = params[:database][:locale]      # fuer laufende Action Sprache aktiviert
    cookies.permanent[:locale] = Marshal.dump params[:database][:locale]  # Default für erste Seite

    session[:last_used_menu_controller] = "env"
    session[:last_used_menu_action]     = "set_database"
    session[:last_used_menu_caption]    = "Login"
    session[:last_used_menu_hint]       = t :menu_env_set_database_hint, :default=>"Start of application after connect to database"

    old_database = session[:database]   # Bisherige Connection, = nil bei erster Anmeldung

    @database = Database.new( params[ :database ] ? params[ :database ] : params )

    if !@database.host || @database.host == ""  # Hostname nicht belegt, dann TNS-Alias auswerten
      tns_record = read_tnsnames[@database.tns]   # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      unless tns_record
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Eintrag für DB '#{@database.tns}' nicht gefunden in tnsnames.ora"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        # wiederherstellen alte Verbindung für fehlerfreien automatischen Connect je Request
        old_database.open_oracle_connection if old_database
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
        # wiederherstellen alte Verbindung für fehlerfreien automatischen Connect je Request
        old_database.open_oracle_connection if old_database
        return
      end
      if params[:database][:authorization]== nil || params[:database][:authorization]!="meyer"
        respond_to do |format|
          format.js {render :js => "$('#content_for_layout').html('#{j "Autorisierung '#{params[:database][:authorization]}' ungueltig fuer NOA-Produktionssystem"}'); $('#login_dialog').effect('shake', { times:3 }, 100);"}
        end
        # wiederherstellen alte Verbindung für fehlerfreien automatischen Connect je Request
        old_database.open_oracle_connection if old_database  # Oracle-Connection aufbauen
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
      # wiederherstellen alte Verbindung für fehlerfreien automatischen Connect je Request
      old_database.open_oracle_connection if old_database
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
      @dbids = sql_select_all  "SELECT DBID, MIN(Begin_Interval_Time) Min_TS, MAX(End_Interval_Time) Max_TS
                                FROM   DBA_Hist_Snapshot
                                GROUP BY DBID
                                ORDER BY MIN(Begin_Interval_Time)"
      @platform_name = sql_select_one "SELECT /* Panorama Tool Ramm */ Platform_name FROM v$Database"  # Zugriff ueber Hash, da die Spalte nur in Oracle-Version > 9 existiert
    rescue Exception => e
      @dictionary_access_problem = true    # Fehler bei Zugriff auf Dictionary
      @dictionary_access_msg << "<div> User '#{@database.user}' hat kein Leserecht auf Data Dictionary!<br/>#{e.message}<br/>Funktionen von Panorama werden nicht oder nur eingeschränkt nutzbar sein<br/>
      </div>"
    end

    @dictionary_access_problem = true if !x_memory_table_accessible?("BH", @dictionary_access_msg )

    session[:database] = @database
    write_connection_to_cookie @database
    @license_ok = check_license(@database.sid, @database.host, @database.port)

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
      format.js {render :js => "$('#current_tns').html('#{j "<span title='TNS=#{@database.tns},Host=#{@database.host},Port=#{@database.port},#{@database.sid_usage}=#{@database.sid}'>#{@database.tns}</span>"}');
                                $('#content_for_layout').html('#{j render_to_string :partial=> "env/set_database"}');
                                $('#main_menu').html('#{j render_to_string :partial =>"build_main_menu" }');
                                $('#login_dialog').dialog('close');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{session[:database].timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                numeric_decimal_separator = '#{session[:database].numeric_decimal_separator}';
                                var session_locale = '#{session[:database].locale}';
                                "
                }
    end
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
    begin
      if cookies[:last_logins]
        cookies_last_logins = Marshal.load cookies[:last_logins]
      else
        cookies_last_logins = []
      end
    rescue Exception
        cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
    end
    cookies_last_logins = [] unless cookies_last_logins.instance_of?(Array)  # Falscher Typ des Cookies?

    cookies_last_logins.each do |value|
      cookies_last_logins.delete(value) if value && value[:sid] == database.sid && value[:host] == database.host    # Aktuellen eintrag entfernen
    end
    if params[:saveLogin] == "1"
      cookies_last_logins.delete_at 0 if cookies_last_logins.length > 4    # ersten Eintrag des Arrays löschen bei Überlauf
      cookies_last_logins << database.to_params  # Aktuellen Eintrag hinzufügen
      cookies.permanent[:last_logins] = Marshal.dump cookies_last_logins  # Zurückschreiben des Cookies
    end

  end

  def check_license(sid, host, port)
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
