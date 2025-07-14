# encoding: utf-8
require 'test_helper'

class AdminControllerTest < ActionDispatch::IntegrationTest
  include AdminHelper

  setup do
    set_session_test_db_context
    Panorama::Application.config.panorama_master_password = 'hugo'
  end

  def admin_login
    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: Panorama::Application.config.panorama_master_password}
    assert_response :redirect, log_on_failure('Should be redirecte to a dummy page after successful logon')
  end

  def admin_logout
    get '/admin/admin_logout',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Remove a possibly existing cookie before test')
  end

  def usage_file_exists?
    File.open(Panorama::Application.config.usage_info_filename, "r")
    Rails.logger.info "UsageControllerTest.usage_file_exists?: Test excuted because usage #{Panorama::Application.config.usage_info_filename} file exists. PWD = #{Dir.pwd}"
    true
  rescue Exception
    Rails.logger.info "UsageControllerTest.usage_file_exists?: Test skipped because usage #{Panorama::Application.config.usage_info_filename} file does not exist. PWD = #{Dir.pwd}"
    false
  end

  # Called from menu entry "Spec. additions"/"Admin login"
  test "master_login with xhr: true" do
    admin_logout
    get '/admin/master_login',  :params => {:format=>:html}
    assert_response :redirect, log_on_failure('Should be redirecte to login page')

    admin_login
    get '/admin/master_login',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Should refresh menu with admin menu with valid JWT in cookie')
  end

  test "show_admin_logon with xhr: true" do
    get '/admin/show_admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login}
    assert_response :success, log_on_failure('Should show the logon dialog')
  end

  test "admin_logon with xhr: true" do
    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: Panorama::Application.config.panorama_master_password}
    assert_response :redirect, log_on_failure('Should be redirecte to a dummy page after successful logon')

    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: 'false'}
    assert response.body['show_popup_message'], log_on_failure('Should raise popup dialog due to wrong passworf')
  end

  test "admin_logout with xhr: true" do
    get '/admin/admin_logout',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Logout from admin')
  end

  test "set_log_level with xhr: true" do
    admin_logout
    post '/admin/set_log_level',  :params => {:format=>:html, log_level: :DEBUG}
    assert_response :redirect, log_on_failure("Should be redirected to logon request but is #{@response.response_code}" )

    admin_login
    post '/admin/set_log_level',  :params => {:format=>:html, log_level: :INFO}
    assert_response :success, log_on_failure('Should set log level')
    assert @@log_level_aliases[Rails.logger.level] == 'INFO', log_on_failure('Log level should be INFO now')
    post '/admin/set_log_level',  :params => {:format=>:html, log_level: :DEBUG}
    assert_response :success, log_on_failure('Should set log level')
    assert @@log_level_aliases[Rails.logger.level] == 'DEBUG', log_on_failure('Log level should be DEBUG now')
  end

  test "show_usage_history with xhr: true" do
    if usage_file_exists?
      admin_logout
      get '/admin/show_usage_history', :params => {:format=>:html }
      assert_response :redirect, log_on_failure('Should be redirected to logon request')

      admin_login
      get '/admin/show_usage_history', :params => {:format=>:html }
      assert_response :success, log_on_failure('Should succeed')
    end
  end

  test "usage_detail_sum with xhr: true" do
    if usage_file_exists?
      admin_logout
      post '/admin/usage_detail_sum', :params => {format: :html }
      assert_response :redirect, log_on_failure('Should be redirected to logon request')

      admin_login
      ['Database', 'IP_Address', 'Controller', 'Action'].each do |groupkey|
        [{'Month' => '2017/05'}, {'Database' => 'Hugo'}, {'IP_Address' => '0.0.0.0'}, {'Controller' => 'Hugo'}, {'Action' => 'Hugo'}].each do |filter|
          post '/admin/usage_detail_sum', :params => {format: :html, groupkey: groupkey, filter: filter }
          assert_response :success, log_on_failure('Should succeed')
        end
      end
    end
  end

  test "single_record with xhr: true" do
    if usage_file_exists?
      admin_logout
      post '/admin/usage_single_record', :params => {format: :html }
      assert_response :redirect, log_on_failure('Should be redirected to logon request')

      admin_login
      [{'Month' => '2017/05'}, {'Database' => 'Hugo'}, {'IP_Address' => '0.0.0.0'}, {'Controller' => 'Hugo'}, {'Action' => 'Hugo'}].each do |filter|
        post '/admin/usage_single_record', :params => {format: :html, filter: filter }
        assert_response :success, log_on_failure('Should succeed')
      end
    end
  end

  test "connection_pool with xhr: true" do
    admin_logout
    get '/admin/connection_pool', :params => {:format=>:html }
    assert_response :redirect, log_on_failure('Should be redirected to logon request')
    admin_login
    get '/admin/connection_pool', :params => {:format=>:html }
    assert_response :success, log_on_failure('Should succeed')
  end


end
