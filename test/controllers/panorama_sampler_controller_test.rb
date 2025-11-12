# encoding: utf-8
require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context
    Panorama::Application.config.panorama_master_password = 'hugo'

    PanoramaSamplerConfig.delete_all_config_entries                             # Ensure that no config entries are present before test

    @config_entry_without_id            = get_current_database
    @config_entry_without_id[:name]     = 'Hugo'
    # Decrypted password used for test because this config is used as http request data for storing connection data
    @config_entry_without_id[:password] = Encryption.decrypt_value(@config_entry_without_id[:password], cookies[:client_salt])
    @config_entry_without_id[:owner]    = @config_entry_without_id[:user] # Default

    set_panorama_sampler_config_defaults!(@config_entry_without_id)

    if PanoramaSamplerConfig.get_max_id < 100
      id = PanoramaSamplerConfig.get_max_id + 1
      PanoramaSamplerConfig.add_config_entry(@config_entry_without_id.merge( {id: id, name: "Test-Config #{id} #{rand(1000)}" }))
    end
  end

  def admin_login
    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html,
                                            origin_controller: :admin,
                                            origin_action: :master_login,
                                            encrypted_master_password: Encryption.encrypt_browser_password(Panorama::Application.config.panorama_master_password)
    }
    assert_response :redirect, log_on_failure('Should be redirecte to a dummy page after successful logon')
  end

  def admin_logout
    get '/admin/admin_logout',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Remove a possibly existing cookie before test')
  end

  test "list_config with xhr: true" do
    admin_logout
    get '/panorama_sampler/list_config',  :params => {:format=>:html}
    assert_response :redirect, log_on_failure('should request admin logon')

    admin_login
    get '/panorama_sampler/list_config',  :params => {:format=>:html}
    assert_response :success, log_on_failure('should show config')
  end

  test "show_new_config_form with xhr: true" do
    admin_logout
    get '/panorama_sampler/show_new_config_form',  :params => {:format=>:html}
    assert_response :redirect, log_on_failure('show_new_config_form should request admin logon')

    admin_login
    get '/panorama_sampler/show_new_config_form',  :params => {:format=>:html}
    assert_response :success, log_on_failure('show_new_config_form should succeed')
  end

  test "show_edit_config_form with xhr: true" do
    admin_logout
    get '/panorama_sampler/show_edit_config_form',  :params => {:format=>:html, :id=>1}
    assert_response :redirect, log_on_failure('show_edit_config_form should request admin logon')

    admin_login
    get '/panorama_sampler/show_edit_config_form',  :params => {:format=>:html, :id=>1}
    assert_response :success, log_on_failure('show_edit_config_form should succeed')
  end

  test "clear_config_error with xhr: true" do
    admin_logout
    post '/panorama_sampler/clear_config_error',  :params => {:format=>:html, :id=>1}
    assert_response :redirect, log_on_failure('clear_config_error should request admin logon')

    admin_login
    post '/panorama_sampler/clear_config_error',  :params => {:format=>:html, :id=>1}
    assert_response :success, log_on_failure('clear_config_error should succeed')
  end

  test "save_config with xhr: true" do
    Thread.report_on_exception = false                                          # Suppress exception messages and stacktrace in sysout

    ['Save', 'Test connection'].each do |button|                          # Simulate pressed button "Save" or "Test connection"
      ['Existing', 'New'].each do |mode|                                  # Simulate change of existing or new record
        ['Right', 'Wrong'].each do |right|                                # Valid or invalid connection info
          id = mode=='New' ? PanoramaSamplerConfig.get_max_id + 1 : PanoramaSamplerConfig.get_max_id
          config = @config_entry_without_id.clone
          response_format = :html                                               # Default
          config[:name] = "Test save_config #{Time.now}"
          config[:user] = 'blabla' if right == 'Wrong'                          # Force connect error or not
          response_format = :js if (right == 'Wrong' || right == 'System') && button == 'Test connection'  # Popup-Dialog per JS expected

          admin_logout
          get '/panorama_sampler/save_config',
              :params => {
                :format => response_format,
                :commit => button,
                :id     => id,
                :config => config
              }
          assert_response :redirect, log_on_failure('save_config should request admin logon')

          admin_login
          get '/panorama_sampler/save_config',
              :params => {
                  :format => response_format,
                  :commit => button,
                  :id     => id,
                  :config => config
              }
          if right == 'Wrong' && button == 'Test connection'
            assert_response :error, log_on_failure("save_config should raise error for button='#{button}', mode='#{mode}', right='#{right}'")
          else
            assert_response :success, log_on_failure("save_config should be successful for button='#{button}', mode='#{mode}', right='#{right}'")
          end

          # delete config to ensure unique names for next test
          PanoramaSamplerConfig.get_config_array.each do |c|
            PanoramaSamplerConfig.delete_config_entry(c.get_config_value(:id)) if c.get_config_value(:name) == config[:name]
          end
        end
      end
    end
  end

  test "delete_config with xhr: true" do
    admin_logout
    get '/panorama_sampler/delete_config',  :params => {:format=>:html, :id=>PanoramaSamplerConfig.get_max_id }
    assert_response :redirect, log_on_failure('delete_config should request admin logon')

    admin_login
    get '/panorama_sampler/delete_config',  :params => {:format=>:html, :id=>PanoramaSamplerConfig.get_max_id }
    assert_response :success, log_on_failure('delete_config should succeed')
  end

end
