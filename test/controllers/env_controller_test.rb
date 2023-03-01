# encoding: utf-8
require 'test_helper'
include MenuHelper
include ActionView::Helpers::TranslationHelper

class EnvControllerTest <  ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context
    @instance = PanoramaConnection.instance_number
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "should connect to test-db with xhr: true" do
    database = get_current_database
    database[:password] = Encryption.decrypt_value(database[:password], cookies['client_salt'])

    # Test with new login parameters
    database[:save_login] = '1'                                                 # String insted of bool like for connect with saved credentials
    post '/env/set_database_by_params', :params => {:format=>:html, :database => database }
    assert_response :success

    # test with stored login from previous connect (0 = first position in list of stored connections)
    post '/env/set_database_by_id', :params => {:saved_logins_id=>'0' }
    assert_response :success

  end

  test "list_services with xhr: true" do
    post '/env/list_services', :params => {:format=>:html }
    assert_response :success

    post '/env/list_services', :params => {:format=>:html, instance: @instance }
    assert_response :success

    if get_db_version >= '12.1'
      post '/env/list_services', :params => {:format=>:html, pdb_name: 'ORCLPDB1' }
      assert_response :success

      post '/env/list_services', :params => {:format=>:html, instance: @instance, pdb_name: 'ORCLPDB1' }
      assert_response :success
    end
  end


  test "should throw oracle-error from test-db" do
=begin
  # Test führt aktuell zu account locked
    set_dummy_db_connection
    real_passwd = session[:database][:password]
    params = session[:database]
    params[:password] = "hugo"
    post :set_database_by_params, :format=>:html, :database => params
    assert_response :success
    expected_fehler_text = "Fehler bei Anmeldung an DB"
    assert @response.body.include?(expected_fehler_text),
      "erwarteter Fehlertext '#{expected_fehler_text}' nicht in Response '#{@response.body}'"

    # Rücksetzen Connection, damit nächster Zugriff reconnect ausführt
    session[:database][:password] = real_passwd
    open_oracle_connection
=end
  end


  def exec_menu_entry_action(menu_entry)
    menu_entry[:content].each do |m|
      exec_menu_entry_action(m) if m[:class] == "menu"       # Rekursives Abtauchen in Menüstruktur
      if m[:class] == "item" && !controller_action_defined?(m[:controller], m[:action])
        Rails.logger.info "calling #{m[:controller]}/#{m[:action]}"
        get '/env/render_menu_action', :params => {:format=>:html, :redirect_controller => m[:controller], :redirect_action => m[:action], :update_area=>:hugo}
        assert_response :success, "Error executing #{m[:controller]}/#{m[:action]}, response_code=#{@response.response_code}"
      end
    end
  end

  # Test aller generischer Menü-Einträge ohne korrespondierende Action im konkreten Controller
  test "render_menu_action with xhr: true" do
    menu_content.each do |mo|
      exec_menu_entry_action(mo)
    end
  end

  test "get_tnsnames_content with xhr: true" do
    get '/env/get_tnsnames_content',  :params => {:format=>:js, :target_object=>:database}
    assert_response :success
  end

  test "choose_managent_pack_license with xhr: true" do
    # :panorama_sampler excluded because it is tested with panorama_sampler_schema by set_management_pack_license
    [:diagnostics_pack, :diagnostics_and_tuning_pack, :none].each do |license|
      post '/env/choose_managent_pack_license',  :params => {:format=>:html, :management_pack_license => license }
      assert_response :success
    end
  end

  test 'set_management_pack_license with xhr: true' do
    [:diagnostics_pack, :diagnostics_and_tuning_pack, :panorama_sampler, :none].each do |license|
      post '/env/set_management_pack_license', :params => {:format=>:html, :management_pack_license => license }
      assert_response :success
    end
  end

  test "dbids with xhr: true" do
    post '/env/list_dbids', :params => {:format=>:html, :update_area=>:hugo}
    assert_response :success

    post '/env/set_dbid', :params => {:format=>:html, :dbid =>get_dbid, :update_area=>:hugo }  # Alten Wert erneut setzen um andere Tests nicht zu gefährden
    assert_response :success
  end

  test "Startup_Without_Ajax" do
    # Index destroys your cuurent session, therefore ist should be the last action of test
    get '/env/index', :params => {:format=>:js}
    assert_response :success

    post '/env/set_locale', :params => {:format=>:js, :locale=>'de'}
    assert_response :success

    post '/env/set_locale', :params => {:format=>:js, :locale=>'en'}
    assert_response :success
  end

end
