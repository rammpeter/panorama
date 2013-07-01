# encoding: utf-8
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "application_helper"   # Erweiterung der Controller um Helper-Methoden
include ActionView::Helpers::JavaScriptHelper      # u.a. zur Nutzung von escape_javascript(j) im Controllern

class ApplicationController < ActionController::Base
  protect_from_forgery  # cross site scripting verhindern

  include ApplicationHelper # Erweiterung der Controller um Helper-Methoden des GUI's 

  # open_connection immer ausfuehren, ausser bei auswahl der Connection selbst
  before_filter :open_connection # , :except -Liste wird direkt in open_connection gehandelt
  after_filter  :close_connection
  rescue_from Exception, :with => :global_exception_handler

  # Abfangen aller Exceptions während Verarbeitung von Controller-Actions
  def global_exception_handler(exception)
    close_connection  # Umsetzen der Connection auf NullDB bei Auftreten von Exception während Verarbeitung (after_Filter wird nicht mehr durchlaufen)
    raise exception   # Standard-Behandlung der Exceptions
  end

  # Ausführung vor jeden Request
  def open_connection
    # Präziser before_filter mit Test auf controller
    return if (controller_name == "env"   && action_name == "index") ||
              (controller_name == "env"   && action_name == "set_database") ||
              (controller_name == "env"   && action_name == "set_database_by_index") ||
              (controller_name == "usage" && action_name == "info") ||
              (controller_name == "usage" && action_name == "detail_sum")

    # Letzten Menü-aufruf festhalten z.B. für Hilfe

    session[:last_used_menu_controller] = params[:last_used_menu_controller] if params[:last_used_menu_controller]
    session[:last_used_menu_action]     = params[:last_used_menu_action]     if params[:last_used_menu_action]
    session[:last_used_menu_caption]    = params[:last_used_menu_caption]    if params[:last_used_menu_caption]
    session[:last_used_menu_hint]       = params[:last_used_menu_hint]       if params[:last_used_menu_hint]

    # Bis hierher aktive Connection ist Dummy mit NullDB

    # Neue Connection auf Basis Oracle aufbauen mit durch Anwender gegebener DB
    if session[:database]
      # Initialisierungen
       I18n.locale = session[:database].locale      # fuer laufende Action Sprache aktiviert

      # Protokollieren der Aufrufe in lokalem File
      real_controller_name = params[:last_used_menu_controller] ? params[:last_used_menu_controller] : controller_name
      real_action_name     = params[:last_used_menu_action]     ? params[:last_used_menu_action]     : action_name
      begin
        # Ausgabe Logging-Info in File für Usage-Auswertung
        filename = Panorama::Application.config.usage_info_filename
        File.open(filename, "a"){|file| file.write("#{request.remote_ip} #{session[:database].raw_tns} #{Time.now.year}/#{Time.now.month} #{real_controller_name} #{real_action_name} #{Time.now.strftime("%Y/%m/%d-%H:%M:%S")}\n")}
      rescue Exception => e
        logger.warn("#### ApplicationController.open_connection: Exception beim Schreiben in #{filename}: #{e.message}")
      end

      session[:database].open_oracle_connection   # Oracle-Connection aufbauen

      # Registrieren mit Name an Oracle-DB
      #ActiveRecord::Base.connection().execute("call dbms_application_info.set_Module('Panorama', '#{controller_name}/#{action_name}')")
      ActiveRecord::Base.connection().exec_update("call dbms_application_info.set_Module('Panorama', :action)", nil,
                                                  [[ActiveRecord::ConnectionAdapters::Column.new(":action", nil), "#{controller_name}/#{action_name}"]]
      )
    else  # Keine DB bekannt
       raise "Keine DB ausgewählt! Bitte rechts oben DB auswählen"
    end

    # Request-Counter je HTML-Session als Hilsmittel für eindeutige html-IDs
    session[:request_counter] = 0 unless session[:request_counter]
    session[:request_counter] += 1
  end

  def set_dummy_db_connection
    ActiveRecord::Base.establish_connection(:adapter  => "nulldb")
  end

  # Ausfüherung nach jedem Request ohne Ausnahme
  def close_connection
    set_dummy_db_connection
  end


protected  
  # Ausgabe der Meldungen einer Exception
  def alert exception, header=""
    logger.error exception.message
    exception.backtrace.each do |bt|
      logger.error bt
    end
    message = exception.message 
    message << "\n\n"
    #message << caller.to_s
    exception.backtrace.each do |bt|
      message << bt
    end

    respond_to do |format|
      format.js {render :js => "alert('#{j header+message}');"}   # Optional zu erweitern um caller.to_s
    end

  end
  
end
