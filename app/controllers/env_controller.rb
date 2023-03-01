# encoding: utf-8

require 'application_controller'
require 'menu_helper'
require 'licensing_helper'
require 'java'

# version.rb not include wile using gem from http://github.com
require "panorama/version"

class EnvController < ApplicationController
   layout 'default'                                                             # layout name "application" had some drawbacks with automatic usage

#  include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include EnvHelper
  include MenuHelper
  include LicensingHelper

  # Verhindern "ActionController::InvalidAuthenticityToken" bei erstem Aufruf der Seite und im Test
  protect_from_forgery :except => :index unless Rails.env.test?

  def connect_check

  end

  public
  # Einstieg in die Applikation, rendert nur das layout (default.rhtml), sonst nichts
  def index
    # Ensure client browser has unique client_key stored as cookie (create new one if not already exists)
    initialize_client_key_cookie
    initialize_browser_tab_id(suppress_non_existing_error: true)                                                   # Helper to distiguish browser tabs
    write_to_browser_tab_client_info_store(:current_database, nil)              # Overwrite previous setting from last session

    set_I18n_locale('en') if get_locale.nil?                                    # Locale not yet specified, set default

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
    session.delete(:request_counter)                if session[:request_counter]
    session.delete(:instance)                       if session[:instance]
    session.delete(:time_selection_start)           if session[:time_selection_start]
    session.delete(:time_selection_end)             if session[:time_selection_end]


    #set_I18n_locale(get_locale)                                                 # ruft u.a. I18n.locale = get_locale auf

    write_to_browser_tab_client_info_store(:last_used_menu_controller,  'env')
    write_to_browser_tab_client_info_store(:last_used_menu_action,      'index')
    write_to_browser_tab_client_info_store(:last_used_menu_caption,     'Start')
    write_to_browser_tab_client_info_store(:last_used_menu_hint,        t(:menu_env_index_hint, :default=>"Start of application without connect to database"))


  rescue Exception=>e
    Rails.logger.error('EnvController.index'){ "#{e.message}" }
    set_current_database(nil) unless cookies['client_key'].nil? # Sicherstellen, dass bei naechstem Aufruf neuer Einstieg (nur wenn client_info_store bereits initialisiert ist)
    raise e                                                                     # Werfen der Exception
  end

  # Auffüllen SELECT mit OPTION aus tns-Records
  def get_tnsnames_content
    tnsnames      = read_tnsnames
    target_object = params[:target_object]
    raise "Unsupported target '#{target_object}' for env/get_tnsnames_content" unless ['config', 'database'].include?(target_object) # prevent from XSS
    selected      = params[:selected]

    result = "jQuery('##{target_object}_tns').replaceWith(\"<select id='#{target_object}_tns' name='#{target_object}[tns]' style='width: 85%;'>"

    tnsnames.keys.sort.each do |key|
      result << "<option #{"selected='selected' " if key==selected}value='#{key}'>#{key}&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;#{tnsnames[key][:hostName]} : #{tnsnames[key][:port]} : #{tnsnames[key][:sidName]}</option>"
    end
    result << "</select>"

    result << "<input type='search' placeholder='Filter' id='#{target_object}_filter' title='#{t(:combobox_filter_title, default: 'Filter for selection list')}' style='margin-left:4px; width: 12%;'>"

    result << "<script type='application/javascript'>$(function(){ initialize_combobox_filter('#{target_object}_tns', '#{target_object}_filter'); })</script>"

    result << "\");"

        respond_to do |format|
      format.js {render :js => result }
    end
  end

  # Wechsel der Sprache in Anmeldedialog
  def set_locale
    set_I18n_locale(params[:locale])                                            # Merken in Client_Info_Cache

    respond_to do |format|
      format.js {render :js => "window.location.reload();" }                    # Reload der ganzen Seite
    end
  end

  # start page called after login and management pack choice
  def start_page

    @dictionary_access_msg = ""       # wird additiv belegt in Folge
    @dictionary_access_problem = false    # Default, keine Fehler bei Zugriff auf Dictionary
    begin
      @banners       = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @instance_data = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @version_info  = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      # Einlesen der DBID der Database, gleichzeitig Test auf Zugriffsrecht auf DataDictionary
      # Data for DB versions
      @version_info = sql_select_all "SELECT /* Panorama Tool Ramm */ Banner FROM V$Version"
      @database_info = sql_select_first_row "SELECT /* Panorama Tool Ramm */ Name, Platform_name, Created, dbtimezone, sessiontimezone,
                                                    SYSDATE,       TO_CHAR(SYSTIMESTAMP,       'TZH:TZM') Sys_Offset,
                                                    CURRENT_DATE,  TO_CHAR(CURRENT_TIMESTAMP,  'TZH:TZM') Current_Offset
                                             FROM v$Database"  # Zugriff ueber Hash, da die Spalte nur in Oracle-Version > 9 existiert


      client_info = sql_select_first_row "SELECT sys_context('USERENV', 'NLS_DATE_LANGUAGE') || '_' || sys_context('USERENV', 'NLS_TERRITORY') NLS_Lang FROM DUAL"

      client_nls_info = ''
      sql_select_all("SELECT Parameter, Value FROM NLS_Session_Parameters").each do |nls_param|
        if nls_param.parameter == 'NLS_NUMERIC_CHARACTERS'
          client_nls_info << "Decimal separator = '#{nls_param.value[0]}'\n"
          client_nls_info << "Thousands separator = '#{nls_param.value[1]}'\n"
        else
          client_nls_info << "#{nls_param.parameter} = '#{nls_param.value}'\n"
        end
      end

      @version_info << ({:banner => "Platform: #{@database_info.platform_name}" }.extend SelectHashHelper)

      if get_db_version >= '11.2'
        exadata_info = sql_select_first_row "SELECT COUNT(*) Cell_Count,
                                                    MAX(CAST(extract(xmltype(confval), '/cli-output/cell/makeModel/text()') AS VARCHAR2(200))) MakeModel
                                             FROM   v$Cell_Config
                                             WHERE  ConfType = 'CELL'
                                            "
        @version_info << ({:banner => "Machine: EXADATA #{exadata_info.makemodel.remove('Oracle Corporation ORACLE SERVER ')} with #{exadata_info.cell_count} storage cell server" }.extend SelectHashHelper) if exadata_info.cell_count > 0
      end

      if get_db_version >= '12.1'
        oracle_home = sql_select_one "SELECT SYS_CONTEXT ('USERENV','ORACLE_HOME') FROM DUAL"
        @version_info << ({:banner => "ORACLE_HOME: '#{oracle_home}'" }.extend SelectHashHelper)
      end


      @version_info.each {|vi| vi[:client_info] = nil if vi[:client_info].nil? }                         # each row should have this column defined

      while @version_info.count < 5 do                                          # Ensure that at least 5 records exist
        @version_info << ({banner: nil, client_info: nil}.extend SelectHashHelper)
      end

      @version_info[0][:client_info]        = "JDBC connect string = \"#{PanoramaConnection.jdbc_thin_url}\""
      @version_info[1][:client_info]        = "JDBC driver version = \"#{PanoramaConnection.get_jdbc_driver_version}\""
      @version_info[2][:client_info]        = "Java client time zone = \"#{java.util.TimeZone.get_default.get_id}\", #{java.util.TimeZone.get_default.get_display_name}"
      @version_info[3][:client_info]        = "DB client time zone = \"#{@database_info.sessiontimezone}\""
      @version_info[3][:client_info_title]  = "\n#{client_nls_info}"
      @version_info[4][:client_info]        = "DB client NLS setting = \"#{client_info.nls_lang}\""
      @version_info[4][:client_info_title]  = "\n#{client_nls_info}"

      @version_info << ({:banner => "SYSDATE = '#{localeDateTime(@database_info.sysdate)}'&nbsp;&nbsp;#{@database_info.sys_offset}",
                         banner_title: "System time and time zone according to OS settings of DB server = '#{localeDateTime(@database_info.sysdate)} #{@database_info.sys_offset}'.\nDB timezone offset for TIMESTAMP WITH LOCAL TIME ZONE given at CREATE DATABASE =  '#{@database_info.dbtimezone}'",
                         :client_info=>"CURRENT_DATE = '#{localeDateTime(@database_info.current_date)}'&nbsp;&nbsp;#{@database_info.current_offset}"
      }.extend SelectHashHelper)


      @instance_data = sql_select_all "SELECT /* NO_CDB_TRANSFORMATION */ gi.*, i.Instance_Number Instance_Connected,
                                              (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_CHARACTERSET')         NLS_CharacterSet,
                                              (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_NCHAR_CHARACTERSET')   NLS_NChar_CharacterSet,
                                              (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'cpu_count')                 CPU_Count,
                                              (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'resource_manager_plan')     Resource_Manager_Plan,
                                              (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'compatible')                Compatible,
                                              s.Num_CPUs, s.Num_CPU_Cores, s.Num_CPU_Sockets, s.Phys_Mem_GB, s.Free_Mem_GB, s.Inactive_Mem_GB,
                                              d.DBID, d.Open_Mode, d.Protection_Mode, d.Protection_Level, d.Switchover_Status, d.Dataguard_Broker, d.Force_Logging, d.Database_Role,
                                              d.Supplemental_Log_Data_Min, d.Supplemental_Log_Data_PK, d.Supplemental_Log_Data_UI, d.Supplemental_Log_Data_FK, d.Supplemental_Log_Data_All, d.Supplemental_Log_Data_PL,
                                              #{PackLicense.diagnostics_pack_licensed? ? "(SELECT EXTRACT(DAY FROM 24*60*w.Snap_Interval) FROM DBA_Hist_WR_Control w WHERE w.DBID = d.DBID)" : "NULL" } Snap_Interval_Minutes,
                                              #{PackLicense.diagnostics_pack_licensed? ? "(SELECT EXTRACT(DAY FROM w.Retention)           FROM DBA_Hist_WR_Control w WHERE w.DBID = d.DBID)" : "NULL" } Snap_Retention_Days,
                                              srv.Service_Count
                                              #{", CDB" if get_db_version >= '12.1'}
                                       FROM  GV$Instance gi
                                       CROSS JOIN  v$Database d
                                       LEFT OUTER JOIN v$Instance i ON i.Instance_Number = gi.Instance_Number
                                       LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Inst_ID,
                                                               MAX(DECODE(Stat_Name, 'NUM_CPUS',              Comments||': '||Value))     Num_CPUs,
                                                               MAX(DECODE(Stat_Name, 'NUM_CPU_CORES',         Comments||': '||Value))     Num_CPU_Cores,
                                                               MAX(DECODE(Stat_Name, 'NUM_CPU_SOCKETS',       Comments||': '||Value))     Num_CPU_Sockets,
                                                               MAX(DECODE(Stat_Name, 'PHYSICAL_MEMORY_BYTES', Value)) / (1024*1024*1024)  Phys_Mem_GB,
                                                               MAX(DECODE(Stat_Name, 'FREE_MEMORY_BYTES', Value))     / (1024*1024*1024)  Free_Mem_GB,
                                                               MAX(DECODE(Stat_Name, 'INACTIVE_MEMORY_BYTES', Value)) / (1024*1024*1024)  Inactive_Mem_GB
                                                        FROM   gv$OSStat
                                                        GROUP BY Inst_ID
                                                       ) s ON s.Inst_ID = gi.Inst_ID
                                       LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Inst_ID, COUNT(*) Service_Count FROM gv$Services GROUP BY Inst_ID) srv ON srv.Inst_ID = gi.Inst_ID
                                       "
      @instance_data.each do |i|
        if i.instance_connected
          @instance_name = i.instance_name
          @host_name     = i.host_name
          set_current_database(get_current_database.merge({:cdb => true})) if get_db_version >= '12.1' && i.cdb == 'YES'  # Merken ob DB eine CDP/PDB ist
        end
      end
      if get_current_database[:cdb]
        @containers = sql_select_all "SELECT c.*, s.Con_ID Connected_Con_ID, srv.Service_Count
                                      FROM   gv$Containers c
                                      JOIN   v$session s ON SID = SYS_CONTEXT('userenv', 'sid')
                                      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ PDB, COUNT(*) Service_Count FROM gv$Services GROUP BY PDB) srv ON srv.PDB = c.name
                                     "
      end
      @traces = sql_select_all "SELECT * from DBA_ENABLED_TRACES"

      check_awr_for_time_drift
    rescue Exception => e
      Rails.logger.error('EnvController.start_page') { "#{e.class} #{e.message}" }
      log_exception_backtrace(e, 20)
      PanoramaConnection.destroy_connection                                     # Remove connection from pool. Ensure using new connection with next retry
      raise PopupMessageException.new("Your user is missing SELECT-right on gv$Instance, gv$Database.<br/>Please ensure that your user has granted SELECT ANY DICTIONARY or SELECT_CATALOG_ROLE.<br/>Panorama is not usable with this user account!\n\n".html_safe, e)
    end

    @dictionary_access_problem = true unless select_any_dictionary?(@dictionary_access_msg)

    render_partial :start_page, {additional_javascript_string: build_main_menu_js_code }  # Wait until all loogon jobs are processed before showing menu
  end

  # Aufgerufen aus dem Anmelde-Dialog für gemerkte DB-Connections
  def set_database_by_id
    check_for_valid_cookie
    if params[:login]                                                           # Button Login gedrückt
      params[:database] = read_last_logins[params[:saved_logins_id].to_i]   # Position des aktuell ausgewählten in Array

      raise "No saved login info found at position #{params[:saved_logins_id]}" if params[:database].nil?
      params[:database][:query_timeout] = 360 unless params[:database][:query_timeout]  # Initialize if stored login dies not contain query_timeout
      params.delete(:cached_panorama_object_sizes_exists)                       # Reset cached info so first access reads new state from database
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
    check_for_valid_cookie
    # Passwort sofort verschlüsseln als erstes und nur in verschlüsselter Form in session-Hash speichern
    params[:database][:password]  =  Encryption.encrypt_value(params[:database][:password], cookies['client_salt'])

    #set_I18n_locale(params[:database][:locale])  # locale is set directly before, use this
    set_database(true)
  end

  def list_services
    @instance = prepare_param_instance
    @pdb_name = prepare_param :pdb_name

    where_string = ''
    where_values = []
    session_where_string = ''
    session_where_values = []

    if @instance
      where_string << (where_string == '' ? "WHERE " : " AND ")
      where_string << "v.Service_ID IN (SELECT Service_ID FROM gv$Services WHERE Inst_ID = ?)"
      where_values << @instance
      session_where_string << (session_where_string == '' ? "WHERE " : " AND ")
      session_where_string << "s.Inst_ID = ?"
      session_where_values << @instance
    end

    if @pdb_name
      where_string << (where_string == '' ? "WHERE " : " AND ")
      where_string << "PDB = ?"
      where_values << @pdb_name
      session_where_string << (session_where_string == '' ? "WHERE " : " AND ")
      session_where_string << "s.Con_ID = (SELECT MIN(Con_ID) FROM gv$Containers WHERE Name = ?)"
      session_where_values << @pdb_name
    end

    @services = sql_select_all ["SELECT v.*, s.Sessions
                                 FROM   DBA_Services v
                                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Service_Name, COUNT(*) Sessions
                                                  FROM gv$Session s
                                                  #{session_where_string}
                                                  GROUP BY Service_Name
                                                 ) s ON s.Service_Name = v.Name
                                 #{where_string}
                                "].concat(session_where_values).concat(where_values)
    render_partial
  end

  private

  def check_for_valid_cookie
    hint = "Please ensure that the cookie stored in browser is transferred to server."
    raise "Empty HTTP cookie recognized!\n#{hint}" if cookies.count == 0
    raise "Missing value for 'client_salt' in browser cookie!\n#{hint}" if cookies[:client_salt].nil? || cookies[:client_salt] == ''
    raise "Missing value for 'client_key' in browser cookie!\n#{hint}"  if cookies[:client_key].nil?  || cookies[:client_key]  == ''
  end

  def select_any_dictionary?(msg)
    if sql_select_one("SELECT COUNT(*) FROM Session_Privs WHERE Privilege = 'SELECT ANY DICTIONARY'") == 0
      msg << t(:env_set_database_select_any_dictionary_msg, :user=>get_current_database[:user], :default=>"DB-User %{user} doesn't have the grant 'SELECT ANY DICTIONARY'! Many functions of Panorama may be not usable!<br>")
      false
    else
      true
    end
  end

  public

  # Erstes Anmelden an DB
  # Wurde direkt aus Browser aufgerufen oder per set_database_by_params_called?
  def set_database(called_from_set_database_by_params = false)

    write_to_browser_tab_client_info_store(:last_used_menu_controller, "env")
    write_to_browser_tab_client_info_store(:last_used_menu_action,     "set_database")
    write_to_browser_tab_client_info_store(:last_used_menu_caption,    "Login")
    write_to_browser_tab_client_info_store(:last_used_menu_hint,       t(:menu_env_set_database_hint, :default=>"Start of application after connect to database"))



    #current_database = params[:database].to_h.symbolize_keys                   # Puffern in lokaler Variable, bevor in client_info-Cache geschrieben wird
    current_database = params[:database]                                        # Puffern in lokaler Variable, bevor in client_info-Cache geschrieben wird
    if called_from_set_database_by_params
      current_database[:save_login] = current_database[:save_login] == '1' # Store as bool instead of number fist time after login
      current_database[:management_pack_license] = :none                        # No license violation possible until the user decides the license to use
    end

    @show_management_pack_choice =  called_from_set_database_by_params          # show choice for management pack if first login to database or stored login does not contain the choice

    if current_database[:modus] == 'tns'                                        # TNS-Alias auswerten
      tns_records = read_tnsnames                                               # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      tns_record = tns_records[current_database[:tns]&.upcase]                  # TNS aliases from tnsnames.ora are stored in upcase now
      unless tns_record
        respond_to do |format|
          format.js {render :js => "show_status_bar_message('Entry for DB \"#{current_database[:tns]}\" not found in tnsnames.ora');
                                    jQuery('#login_dialog').effect('shake', { times:3 }, 100);
                                   "
          }
        end
        return
      end
      # Alternative settings for connection if connect with current_database[:modus] == 'tns' does not work
      current_database[:host]       = tns_record[:hostName]
      current_database[:port]       = tns_record[:port]
      current_database[:sid]        = tns_record[:sidName]
      current_database[:sid_usage]  = tns_record[:sidUsage]
    else # Host, Port, SID auswerten
      current_database[:tns]       = PanoramaConnection.get_host_tns(current_database)             # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
    end

    if !check_credentials(current_database)
      return                                                                    # check_credentials renders self if returns false
    end

    set_current_database(current_database)                                      # Persist current database setting in cache
    current_database = nil                                                      # Diese Variable nicht mehr verwenden ab jetzt, statt dessen get_current_database verwenden


    # First SQL execution opens Oracle-Connection

    # Test der Connection und ruecksetzen auf vorherige wenn fehlschlaegt
    begin
      PanoramaConnection.check_for_open_connection
    rescue Exception => e
      respond_to do |format|
        format.js {render :js => "show_status_bar_message('#{
                                          my_html_escape("#{
t(:env_connect_error, :default=>'Error connecting to database')}:
#{e.class.name}: #{e.message}

JDBC URL:  '#{PanoramaConnection.jdbc_thin_url}'
Client Timezone: \"#{java.util.TimeZone.get_default.get_id}\", #{java.util.TimeZone.get_default.get_display_name}

                                                         ")
                                        }');
                                  jQuery('#login_dialog').effect('shake', { times:3 }, 300);
                                 "
        }
      end
      return        # Fehler-Ausgang
    end

    # Ensure that a sampler schema is set if management_pack_license is :panorama_sampler, else reset to :none
    if get_current_database[:management_pack_license] == :panorama_sampler && get_current_database[:panorama_sampler_schema].nil?
      Rails.logger.debug('EnvController.set_database') { "management_pack_license set to none because panorama_sampler_schema is missing"}
      set_current_database(get_current_database.merge( { management_pack_license: :none}))
    end


    # Detect existence of Panorama_Sampler
    panorama_sampler_data = {}
    PanoramaSamplerStructureCheck.panorama_sampler_schemas.each do |s|
      panorama_sampler_data[s.owner] = s
    end

    if panorama_sampler_data.count > 0
      ps_snapshot_schema_count = 0                                              # Number of schemas with AWR data
      panorama_sampler_owner = nil                                              # not yet known
      panorama_sampler_awr_owner = nil                                          # can exist but doesn't must

      if panorama_sampler_data.count == 1
        panorama_sampler_owner = panorama_sampler_data.first[0]
        if panorama_sampler_data.first[1].snapshot_count > 0
          panorama_sampler_awr_owner = panorama_sampler_owner
          ps_snapshot_schema_count = 1
        end
      end

      if panorama_sampler_data.count > 1
        config_owner = PanoramaSamplerConfig.sampler_schema_for_dbid(get_dbid) # Look at sampler config for the right owner
        if config_owner && panorama_sampler_data[config_owner.upcase]   # config owner by DBID has a local schema
          panorama_sampler_owner = config_owner.upcase
          panorama_sampler_awr_owner = panorama_sampler_owner if  panorama_sampler_data[panorama_sampler_owner].snapshot_count > 0
        end

        panorama_sampler_data.each do |key, value|
          panorama_sampler_owner = value.owner if panorama_sampler_owner.nil?
          if value.snapshot_count > 0
            panorama_sampler_awr_owner = value.owner if panorama_sampler_awr_owner.nil? # Take the first of multiple if not known who is the right one
            ps_snapshot_schema_count += 1
          end
        end
      end

      if panorama_sampler_owner
        set_current_database(get_current_database.merge( { :panorama_sampler_schema => panorama_sampler_owner}))
        if panorama_sampler_awr_owner
          add_statusbar_message "AWR/ASH by Panorama-Sampler exists in schema '#{panorama_sampler_owner}'#{" and #{ps_snapshot_schema_count-1} additional schemas" if ps_snapshot_schema_count>1}.\nPanorama may access Panorama-Sampler's data instead of AWR if you don't have Enterprise Edition with Diagnostics Pack licensed"
        end
      end
    end

    # Set management pack according to 'control_management_pack_access' only after DB selects,
    # Until now get_current_database[:management_pack_license] is :none for first time login, so no management pack license is violated until now
    # User has to acknowlede management pack licensing at next screen
    set_current_database(get_current_database.merge( {management_pack_license: init_management_pack_license } )) if called_from_set_database_by_params

    write_connection_to_last_logins

    set_cached_dbid(PanoramaConnection.select_initial_dbid)


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
      format.html {
        render_partial :choose_management_pack, :additional_javascript_string=>
                               "$('#current_tns').html('#{j "<span title='TNS=#{get_current_database[:tns]},\n#{"Host=#{get_current_database[:host]},\nPort=#{get_current_database[:port]},\n#{get_current_database[:sid_usage]}=#{get_current_database[:sid]},\n" if get_current_database[:modus].to_sym == :host}User=#{get_current_database[:user]}'>#{get_current_database[:user]}@#{get_current_database[:tns]}</span>"}');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                $.datepicker.setDefaults({ firstDay: 1, dateFormat: '#{timepicker_dateformat }'});
                                numeric_decimal_separator = '#{numeric_decimal_separator}';
                                var session_locale = '#{get_locale}';
                                $('#login_dialog').dialog('close');
                                "
      }
    end
  end

  # Rendern des zugehörigen Templates, wenn zugehörige Action nicht selbst existiert
  def render_menu_action
    # Template der eigentlichen Action rendern
    render_internal('content_for_layout', params[:redirect_controller], params[:redirect_action])
  end


private
  # Schreiben der aktuellen Connection in last logins, wenn neue dabei
  def write_connection_to_last_logins

    database = get_current_database

    last_logins = read_last_logins
    min_id = nil

    last_logins.each do |value|
      last_logins.delete(value) if value && value[:tns] == database[:tns] && value[:user] == database[:user]    # Aktuellen eintrag entfernen
    end
    if database[:save_login]
      last_logins = [database] + last_logins                                    # Neuen Eintrag an erster Stelle
      write_last_logins(last_logins)                                            # Zurückschreiben in client-info-store
    end

  end

  def init_management_pack_license
    cmpa = read_control_management_pack_access
    case cmpa.upcase
    when 'NONE'               then :none
    when 'DIAGNOSTIC'         then :diagnostics_pack
    when 'DIAGNOSTIC+TUNING'  then :diagnostics_and_tuning_pack
    else
      raise "EnvController.init_management_pack_license: Unknown value for control_management_pack_access: '#{cmpa}'"
    end
  end

  # @return [String] NONE | DIAGNOSTIC | DIAGNOSTIC+TUNING
  def read_control_management_pack_access
    sql = "SELECT Value FROM V$Parameter WHERE name='control_management_pack_access'"
    sql_select_one sql
  rescue Exception => e
    msg = "Cannot read managament pack licensing state from database!\nAssuming no management pack license exists.\n#{e.class}:#{e.message}\nUsed SQL:\n#{sql}"
    Rails.logger.error('EnvController.read_control_management_pack_access') { msg }
    log_exception_backtrace(e)
    # reraise_extended_exception(e, msg)
    'NONE'
  end


  def persist_management_pack_license(management_pack_license)
    current_database = get_current_database
    current_database[:management_pack_license] = management_pack_license.to_sym
    # Ensure that a panorama_sampler_schema is set for PackLicense.translate_sql_names
    if management_pack_license.to_sym == :panorama_sampler && current_database[:panorama_sampler_schema].nil?
      schemas = PanoramaSamplerStructureCheck.panorama_sampler_schemas
      raise "EnvController.persist_management_pack_license: A valid schema for Panorama-Sampler is required in DB to choose Panorama-Sampler" if schemas.count == 0
      current_database[:panorama_sampler_schema] = schemas[0].owner             # Choose the first schema to ensure PackLicense.translate_sql_names can work
    end
    set_current_database(current_database)
    write_connection_to_last_logins
    # choosen management pack license may influence the choosen DBID, therefore calculate it again
    set_cached_dbid(PanoramaConnection.select_initial_dbid)
  end

public

  # Process choosen management pack
  def choose_managent_pack_license
    persist_management_pack_license(params[:management_pack_license])
    start_page
  end

  def list_dbids
    @dbids = sql_select_all "SELECT /* NO_CDB_TRANSFORMATION */ s.DBID, MIN(Begin_Interval_Time) Min_TS, MAX(End_Interval_Time) Max_TS,
                                   (SELECT MIN(DB_Name) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) DB_Name,
                                   (SELECT COUNT(DISTINCT Instance_Number) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) Instances,
                                   #{"(SELECT MIN(i.Con_ID) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) Con_ID," if get_db_version >= '12.1'}
                                   #{PackLicense.diagnostics_pack_licensed? ? "(SELECT EXTRACT(DAY FROM 24*60*w.Snap_Interval) FROM DBA_Hist_WR_Control w WHERE w.DBID = s.DBID)" : "NULL" } Snap_Interval_Minutes,
                                   #{PackLicense.diagnostics_pack_licensed? ? "(SELECT EXTRACT(DAY FROM w.Retention)           FROM DBA_Hist_WR_Control w WHERE w.DBID = s.DBID)" : "NULL" } Snap_Retention_Days
                            FROM   DBA_Hist_Snapshot s
                            GROUP BY s.DBID
                            ORDER BY MIN(Begin_Interval_Time)"
    render_partial :list_dbids
  end

  # DBID explizit setzen wenn mehrere verschiedene in Historie vorhande
  def set_dbid
    set_cached_dbid(params[:dbid])
    list_dbids
  end

  def list_management_pack_license
    @control_management_pack_access = read_control_management_pack_access
    render_partial :list_management_pack_license
  end

  def set_management_pack_license
    persist_management_pack_license(params[:management_pack_license])
    list_management_pack_license
  end

  def panorama_sampler_data
    @update_area = params[:update_area]                                         # render next actions in same original DIV
    @panorama_sampler_data = PanoramaSamplerStructureCheck.panorama_sampler_schemas(:full)
    render_partial :panorama_sampler_data
  end

  def set_panorama_sampler_schema
    set_current_database(get_current_database.merge( { :panorama_sampler_schema => params[:schema]}))
    panorama_sampler_data
  end

  # repeat last called menu action
  def repeat_last_menu_action
    controller_name = read_from_browser_tab_client_info_store(:last_used_menu_controller)
    action_name     = read_from_browser_tab_client_info_store(:last_used_menu_action)

    # Suchen des div im Menü-ul und simulieren eines clicks auf den Menü-Eintrag
    respond_to do |format|
      format.js {render :js => "$('#menu_#{controller_name}_#{action_name}').click();"}
    end
  end

  def list_machine_ip_info
    @machine_name = params[:machine_name]

    resolver = Resolv::DNS.new

    @dns_info = []
    resolver.each_address(@machine_name) do |address|
      resolver.each_name(address.to_s) do |name|
        @dns_info << { ip_address: address, name: name }
      end
    end
    @sessions = sql_select_all ["SELECT OSUser, Program, COUNT(*) Sessions
                                 FROM   gv$Session
                                 WHERE  Machine = ?
                                 GROUP BY OSUser, Program
                                ", @machine_name]

    render_partial
  end

  # Get arry with all engine's controller actions for routing
  def self.routing_actions(controller_dir)
    routing_list = []

    # Rails.logger.info "###### set routes for all controller methods in #{controller_dir}"
    Dir.glob("#{controller_dir}/*.rb") do |fname|
      controller_short_name = nil
      public_actions = true                                                       # following actions are public
      File.open(fname) do |f|
        f.each do |line|

          # find classname in file
          if line.match(/^ *class /)
            controller_name = line.split[1]
            controller_short_name = controller_name.underscore.gsub(/_controller/, '')
            # Rails.logger.info "set routes for all following methods in file #{fname} for #{controller_name}"
          end

          public_actions = true  if line.match(/^ *public */)
          public_actions = false if line.match(/^ *private */)

          # Find methods in file
          if line.match(/^ *def /)
            unless controller_short_name.nil?
              action_name = line.gsub(/\(/, ' ').split[1]
              if !action_name.match(/\?/) && public_actions && !action_name.match(/self\./)
                # set route for controllers action
                # Rails.logger.info "set route for #{controller_short_name}/#{action_name}"
                routing_list << {:controller => controller_short_name, :action => action_name}
                #get  "#{controller_short_name}/#{action_name}"
                #post "#{controller_short_name}/#{action_name}"

                # if controller is ApplicationController than set route for ApplicationController's methods for all controllers
              end
            end
          end
        end
      end
    end

    routing_list
  end

  def self.require_all_controller_and_helpers_and_models
    puts "########## Directory #{__dir__}"
    Dir.glob("#{__dir__}/*.rb")             {|fname| puts "require #{fname}"; require(fname) }
    Dir.glob("#{__dir__}/../helpers/*.rb")  {|fname| puts "require #{fname}"; require(fname) }
    Dir.glob("#{__dir__}/../models/*.rb")   {|fname| puts "require #{fname}"; require(fname) }
  end

end
