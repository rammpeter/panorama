# encoding: utf-8

require 'cgi'                                           # for unescapeHTML
require 'exception_helper'


class ApplicationController < ActionController::Base

  include ActionView::Helpers::JavaScriptHelper                                 # u.a. zur Nutzung von escape_javascript(j) im Controllern
  include ApplicationHelper # Erweiterung der Controller um Helper-Methoden des GUI's


  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception

  # cross site scripting verhindern, ausser fuer Tests
  protect_from_forgery with: :null_session unless Rails.env.test?

  # content security policy is defined in config/initializers/content_security_policy.rb
  # get request-specific nonce to allow inline script in templates
  def csp_nonce
    request.content_security_policy_nonce
  end

  before_action :begin_request # , :except -Liste wird direkt in begin_request gehandelt
  after_action  :after_request

  rescue_from Exception, with: :global_exception_handler

  # Abfangen aller Exceptions während Verarbeitung von Controller-Actions
  def global_exception_handler(exception)
    PanoramaConnection.destroy_connection                                       # Ensure next requests gets new database connection after exception
    PanoramaConnection.reset_thread_local_attributes

    @exception = exception                                                      # Sichtbarkeit im template
    @request   = request

    location = @request.parameters['controller'] ? "#{@request.parameters['controller'].camelize}Controller#{"##{@request.parameters['action']}" if @request.parameters['action']} " : ''
    Rails.logger.error('ApplicationController.global_exception_handler') { "#{location}#{@exception.class.name} : #{@exception.message}" }
    ExceptionHelper.log_exception_backtrace(@exception, Rails.env.test? ? nil : 40)

    if performed?                                                               # Render already called in action?, Suppress DoubleRenderError
      Rails.logger.error('ApplicationController.global_exception_handler') { "#{@exception.class} #{@exception.message} raised!\nAction has already rendered, so error cannot be shown as HTML-result with status 500" }
    else
      if @exception.instance_of? PopupMessageException
        render partial: 'application/popup_exception_message', status: 500 # Show message only without status etc.
      else
        render partial: 'application/error_message', status: 500
      end
    end
  end

  # Ausführung vor jeden Request
  def begin_request
    check_params_4_vulnerability(params)

    begin
      I18n.locale = get_locale(default: 'en')                                   # fuer laufende Action Sprache aktivieren
    rescue
      I18n.locale = 'en'                                                        # wenn Problem bei Lesen des Cookies auftreten, dann Default verwenden
    end

    if Rails.env.test?
      @browser_tab_id = 1                                                       # Use browser_tab_id 1 for test instead of param
    else
      @browser_tab_id = params[:browser_tab_id]
    end
    @browser_tab_id = nil if @browser_tab_id == ''
    @browser_tab_id = @browser_tab_id.to_i unless @browser_tab_id.nil?

    # Ausschluss von Methoden, die keine DB-Connection bebötigen
    # Präziser before_filter mit Test auf controller
    if (controller_name == 'env' && ['index', 'get_tnsnames_content', 'set_locale', 'set_database_by_params', 'set_database_by_id'].include?(action_name)) ||
      (controller_name == 'usage' && ['info', 'detail_sum', 'single_record', 'ip_info', 'connection_pool', 'client_info_store_sizes', 'client_info_detail', 'browser_tab_ids'].include?(action_name)) ||
      (controller_name == 'panorama_sampler' && ['monitor_sampler_status'].include?(action_name))
      return
    end

    raise "URL-parameter 'browser_tab_id' missing for request with controller = #{controller_name}, action = #{action_name}.\nPlease report error to administrator." if @browser_tab_id.nil?
    raise PopupMessageException.new("Your browser session has expired!\nPlease reload the page in browser and start again!") if session.empty? && !Rails.env.test?

    begin
      current_database = get_current_database
      unless current_database
        Rails.logger.error('ApplicationController.begin_request') { "current_database is nil for controller = '#{controller_name}', action = '#{action_name}'" }
        raise PopupMessageException.new('No current DB connect info set! Please reconnect to DB!')
      end
      set_connection_info_for_request(current_database)
    rescue StandardError => e                                                   # Problem bei Zugriff auf verschlüsselte Cookies
      Rails.logger.error('ApplicationController.begin_request') { "Error '#{e.message}' occured" }
      ExceptionHelper.log_exception_backtrace(e)
      raise "Error '#{e.message}' occured. Please close browser session and start again!"
    end

    raise PopupMessageException.new(t(:application_connection_no_db_choosen, default: 'No DB choosen! Please connect to DB by link in right upper corner. (Browser-cookies are required)')) if current_database.nil?

    current_database.symbolize_keys! if current_database.class.name == 'Hash'   # Sicherstellen, dass Keys wirklich symbole sind. Bei Nutzung Engine in App erscheinen Keys als Strings

    # Letzten Menü-aufruf festhalten z.B. für Hilfe
    client_info_data = {}
    client_info_data[:last_used_menu_controller]  = params[:last_used_menu_controller]  if params[:last_used_menu_controller]
    client_info_data[:last_used_menu_action]      = params[:last_used_menu_action]      if params[:last_used_menu_action]
    client_info_data[:last_used_menu_caption]     = params[:last_used_menu_caption]     if params[:last_used_menu_caption]
    client_info_data[:last_used_menu_hint]        = params[:last_used_menu_hint]        if params[:last_used_menu_hint]
    client_info_data[:last_request]               = Time.now                    # Time of last request, used for housekeeping
    ClientInfoStore.write_to_browser_tab_client_info_store(get_decrypted_client_key,  @browser_tab_id, client_info_data)

    # Protokollieren der Aufrufe in lokalem File
    real_controller_name = params[:last_used_menu_controller] ? params[:last_used_menu_controller] : controller_name
    real_action_name     = params[:last_used_menu_action]     ? params[:last_used_menu_action]     : action_name

    UsageInfo.write_record(request, real_controller_name, real_action_name, get_current_database[:tns])
    add_statusbar_message(params[:statusbar_message]) if params[:statusbar_message]
  end

  # Aktivitäten nach Requestbearbeitung
  def after_request
    PanoramaConnection.release_connection # Free DB connection
  end

  ####################################### only protected and private methods from here #####################################
  protected

  # Ausgabe der Meldungen einer Exception
  def alert_exception(exception, header = '')
    if exception
      logger.error exception.message
      ExceptionHelper.log_exception_backtrace(exception)
      message = exception.message
      message << "\n\n"
      exception.backtrace.each do |bt|
        message << bt << "\n"
      end
    else
      message = 'ApplicationController.alert: Exception = nil'
    end

    show_popup_message("#{header}\n\n#{message}")
  end

  # Ausgabe einer Popup-Message,
  # Nach Aufruf von show_popup_message muss mittels return die Verarbeitung der Controller-Methode abgebrochen werden (Vermeiden doppeltes rendern)
  def show_popup_message(message)
    Rails.logger.info('ApplicationController.show_popup_message') { "called with format #{request.format}: #{message}" }
    Rails.logger.debug('ApplicationController.show_popup_message') { "called from #{caller.select{|c| c['app/']}[1]}" }

    case request.format.to_s
    when 'test/javascript'
      respond_to do |format|
        format.js { render js: "show_popup_message('#{my_html_escape(message)}');" }
      end
    when 'text/html'
      respond_to do |format|
        format.html { render html: "<script type='text/javascript'>show_popup_message('#{my_html_escape(message)}');</script>".html_safe }
      end
    else
      raise "show_popup_message: unsupported format #{request.format}"
    end
  end

  def render_button(caption, url, html_options)
    @caption = caption
    @url = url
    @html_options = html_options
    render_partial :render_button, controller: :application
  end

  # Check request parameters for possibly vulnerable content / XSS
  EVIL_PARAM_CONTENT = ['<SCRIPT', '&LT;SCRIPT']
  def check_params_4_vulnerability(parameters)
    raise "ApplicationController.check_params_4_vulnerability: Wrong class '#{parameters.class}' for parameters" unless parameters.is_a?(Hash) || parameters.is_a?(ActionController::Parameters)

    check_string = proc do |param_key, param_value|
      norm_param = CGI.unescapeHTML(param_value)                                # Unescape HTML entities, replace unicode entities like &#x70; or &#112; with characters
      norm_param = norm_param.gsub(/<!--.*?-->/m, '').gsub(/<!--.*/m, '')       # Remove HTML comments even if they are split over multiple lines or are not closed

      norm_param = norm_param
                     .upcase
                     .delete(" \t\r\n")
      # Own check for evil content
      EVIL_PARAM_CONTENT.each do |evil|
        if norm_param[evil]
          Rails.logger.error('ApplicationController.check_params_4_vulnerability'){ "Evil content detected for parameter '#{param_key}' with content '#{param_value}'"}
          raise "Not supported parameter content detected for parameter '#{param_key}'"
        end
      end
      # (?i) makes case insenitive
      if norm_param.match(/(?i)\bon\w*\s*=\s*['"]/)  # Check for event handler like onclick, onmouseover, etc.
        Rails.logger.error('ApplicationController.check_params_4_vulnerability'){ "Event handler detected for parameter '#{param_key}' with content '#{param_value}'"}
        raise "Not supported parameter content detected for parameter '#{param_key}'"
      end
    end

    parameters.keys.each do |k|
      case parameters[k].class.name
      when 'ActionController::Parameters' then check_params_4_vulnerability(parameters[k]) # nested parameters
      when 'String'                       then
        check_string.call('Parameter name', k)                                  # check parameter name for evil content
        check_string.call(k, parameters[k])                                             # check parameter value for evil content
      when 'NilClass'                     then # nothing
      when 'Array'                        then
        parameters[k].each do |p|
          case p.class.name
          when 'String'                       then check_string.call(k, p)
          when 'ActionController::Parameters' then check_params_4_vulnerability(p) # recursive check
          else
            raise "ApplicationController.check_params_4_vulnerability: Unsupported class '#{p.class}' for parameter array element '#{p}'"
          end
        end
      else
        raise "ApplicationController.check_params_4_vulnerability: Unsupported class '#{parameters[k].class}' for parameter '#{parameters[k]}'"
      end
    end
  end
end
