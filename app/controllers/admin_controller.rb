# encoding: utf-8

require 'ipaddr'
require 'logger'

class AdminController < ApplicationController
  include AdminHelper
  include MenuHelper

  # Called from menu entry "Spec. additions"/"Admin login"
  def master_login
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    render html: "<script type='text/javascript'>
      #{build_main_menu_js_code}
      show_status_bar_message('New submenu \"Admin\" added for administrative functions.');
      </script>".html_safe
  end

  # Called from restricted pages if not authorized before
  def show_admin_logon
    @origin_controller = prepare_param :origin_controller
    @origin_action     = prepare_param :origin_action
    render_partial
  end

  # Logon with valid master password and get JWT
  $master_password_wrong_count=0
  def admin_logon
    origin_controller = prepare_param :origin_controller
    origin_action     = prepare_param :origin_action
    master_password =  Encryption.decrypt_browser_password(params[:encrypted_master_password])

    if master_password == Panorama::Application.config.panorama_master_password
      $master_password_wrong_count=0                                            # reset delay for wrong password
      expire_time = 8.hours.from_now
      token = JWT.encode({exp: expire_time.to_i}, jwt_secret, 'HS256')
      cookies[:master] = {value: token, expires: expire_time, httponly: true}
      redirect_to url_for(controller: origin_controller,
                          action:     origin_action,
                          :params     => {browser_tab_id: @browser_tab_id },
                          :method     => :post
                  )
    else
      cookies.delete :master                                                   # remove the invalid cookie
      sleep $master_password_wrong_count
      $master_password_wrong_count += 1
      show_popup_message('Wrong value entered for master password')
    end
  end

  def admin_logout
    cookies.delete :master
    render html: "<script type='text/javascript'>#{build_main_menu_js_code}</script>".html_safe
  end

  def show_log_level
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @log_level = @@log_level_aliases[Rails.logger.level]
    render_partial
  end

  def set_log_level
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    log_level = prepare_param :log_level                                        # DEBUG, ERROR etc.
    # Rails.logger.level = "Logger::#{log_level}".constantize
    Rails.logger.level = log_level.downcase.to_sym
    msg = "Log level of Panorama server process set to #{log_level}"
    Rails.logger.warn('AdminController.set_log_level') { msg }
    render js: "show_status_bar_message('#{my_html_escape(msg)}')"
  end

  def show_usage_history
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    file = UsageInfo.file_for_read

    months = {}
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]

        if months[month]
          months[month][:Requests] = (months[month][:Requests]) +1
          months[month][:Databases][db]           = months[month][:Databases][db]           ? (months[month][:Databases][db]) +1           : 1
          months[month][:Clients][ip]             = months[month][:Clients][ip]             ? (months[month][:Clients][ip]) +1             : 1
          months[month][:Controllers][controller] = months[month][:Controllers][controller] ? (months[month][:Controllers][controller]) +1 : 1
          months[month][:Actions][action]         = months[month][:Actions][action]         ? (months[month][:Actions][action]) +1         : 1
        else
          months[month] = {:Requests     => 1,
                           :Databases    => { db         => 1},
                           :Clients      => { ip         => 1},
                           :Controllers  => { controller => 1},
                           :Actions      => { action     => 1},
          }
        end
      end
    rescue EOFError
      file.close
    end

    @usage = []
    months.each do |key,value|
      value[:Month]       = key
      value[:Databases]   = value[:Databases].count
      value[:Clients]     = value[:Clients].count
      value[:Controllers] = value[:Controllers].count
      value[:Actions]     = value[:Actions].count
      value.extend SelectHashHelper
      @usage << value
    end

    render_partial
  end

  def usage_detail_sum
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @groupkey = params[:groupkey]
    @filter   = params[:filter]

    @filter = @filter.to_unsafe_h.to_h.symbolize_keys  if @filter.class == ActionController::Parameters
    raise "Parameter filter should be of class Hash or ActionController::Parameters" if @filter.class != Hash

    file = UsageInfo.file_for_read
    groups = {}
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]
        rec = {:Database   => db,
               :IP_Address => ip,
               :Month      => month,
               :Controller => controller,
               :Action     => action
        }

        groupvalue = rec[@groupkey.to_sym]                     # Konkreter Wert des Gruppierungs-Feldes für diesen Record
        filtered = true
        @filter.each do |key, value|                    # Iteration ueber alle zu filternden Felder
          filtered = false if rec[key.to_sym] != value     # Ausfiltern wenn Filterattribut != Wert in aktueller Zeile
        end

        if filtered
          if groups[groupvalue]
            groups[groupvalue][:Requests] = (groups[groupvalue][:Requests]) +1
            groups[groupvalue][:Databases][db]           = groups[groupvalue][:Databases][db]           ? (groups[groupvalue][:Databases][db]) +1           : 1
            groups[groupvalue][:Clients][ip]             = groups[groupvalue][:Clients][ip]             ? (groups[groupvalue][:Clients][ip]) +1             : 1
            groups[groupvalue][:Controllers][controller] = groups[groupvalue][:Controllers][controller] ? (groups[groupvalue][:Controllers][controller]) +1 : 1
            groups[groupvalue][:Actions][action]         = groups[groupvalue][:Actions][action]         ? (groups[groupvalue][:Actions][action]) +1         : 1
          else
            groups[groupvalue] = {:Requests     => 1,
                                  :Databases    => { db         => 1},
                                  :Clients      => { ip         => 1},
                                  :Controllers  => { controller => 1},
                                  :Actions      => { action     => 1},
            }
          end
        end
      end
    rescue EOFError
      file.close
    end

    @usage = []
    groups.each do |key,value|
      value[:Groupkey]    = key
      value[:Databases]   = value[:Databases].count
      value[:Clients]     = value[:Clients].count
      value[:Controllers] = value[:Controllers].count
      value[:Actions]     = value[:Actions].count
      value.extend SelectHashHelper
      @usage << value
    end

    render_partial
  end

  def usage_single_record
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @filter   = params[:filter]
    file = UsageInfo.file_for_read
    @recs = []
    begin
      while true do
        recs = file.readline.split    # Einzelne Felder in Array
        ip         = recs[0]
        db         = recs[1]
        month      = recs[2]
        controller = recs[3]
        action     = recs[4]
        ts         = recs[5]
        url        = recs[6]
        rec = {:Database   => db,
               :IP_Address => ip,
               :Month      => month,
               :Controller => controller,
               :Action     => action,
               :Timestamp  => ts,
               :URL        => url
        }

        filtered = true
        @filter.each do |key, value|                    # Iteration ueber alle zu filternden Felder
          filtered = false if rec[key.to_sym] != value     # Ausfiltern wenn Filterattribut != Wert in aktueller Zeile
        end

        if filtered
          rec.extend SelectHashHelper
          @recs << rec
        end
      end
    rescue EOFError
      file.close
    end

    render_partial
  end

  def ip_info
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    ip_address = params[:ip_address]

    # Check if valid IP address to avoid execution of arbitrary commands
    IPAddr.new(ip_address) rescue raise "Invalid IP address given"

    output = "<h3>Info zu IP-Adresse #{ip_address}</h3>
<h4>nslookup:</h4>
#{my_html_escape `nslookup #{ip_address} `}
<h4>nmblookup -A:</h4>
#{my_html_escape `nmblookup -A #{ip_address} `}
    ".html_safe

    respond_to do |format|
      format.html {render :html => output}
    end
  end

  def connection_pool
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    render_partial
  end

  def client_info_store_sizes
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @locate_array = []
    @global_result = ClientInfoStore.instance.get_elements_count
    @result = ClientInfoStore.instance.get_client_info_store_elements(get_decrypted_client_key)
    render_partial :client_info_detail
  end

  def client_info_detail
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    @locate_array = params[:locate_array].values
    @cache_key = params[:cache_key]

    @result = ClientInfoStore.instance.get_client_info_store_elements(get_decrypted_client_key, @locate_array)
    render_partial :client_info_detail
  end

  def browser_tab_ids
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    render html: JSON.pretty_generate(ClientInfoStore.read_for_client_key(get_decrypted_client_key,:browser_tab_ids)).gsub(/\n/, "<br/>").gsub(/ /, '&nbsp;').html_safe
  end
end
