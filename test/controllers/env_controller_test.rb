# encoding: utf-8
require 'test_helper'
include MenuHelper
include ActionView::Helpers::TranslationHelper

class EnvControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    test_controllers_menu_entries_with_actions
  end

  test "should connect to test-db" do
    database = get_current_database
    database[:password] = database_helper_decrypt_value(database[:password])
    post :set_database_by_params, :format=>:js, :database => database
    assert_response :success
  end

  test "should throw oracle-error from test-db" do
=begin
  # Test führt aktuell zu account locked
    set_dummy_db_connection
    real_passwd = session[:database][:password]
    params = session[:database]
    params[:password] = "hugo"
    post :set_database_by_params, :format=>:js, :database => params
    assert_response :success
    expected_fehler_text = "Fehler bei Anmeldung an DB"
    assert @response.body.include?(expected_fehler_text),
      "erwarteter Fehlertext '#{expected_fehler_text}' nicht in Response '#{@response.body}'"

    # Rücksetzen Connection, damit nächster Zugriff reconnect ausführt
    session[:database][:password] = real_passwd
    open_oracle_connection
=end
  end

  # Test aller generischer Menü-Einträge ohne korrespondierende Action im Controller
  test "render_menu_action" do
    def test_menu_entry(menu_entry)
      menu_entry[:content].each do |m|
        test_menu_entry(m) if m[:class] == "menu"       # Rekursives Abtauchen in Menüstruktur
        if m[:class] == "item" && !controller_action_defined?(m[:controller], m[:action])
          xhr :get, :render_menu_action, :format=>:js, :redirect_controller => m[:controller], :redirect_action => m[:action]
          assert_response :success
        end
      end
    end


    menu_content.each do |mo|
      test_menu_entry(mo)
    end
  end


  test "Diverses" do
    get :index, :format=>:js
    assert_response :success

    post :set_locale, :format=>:js, :locale=>'de'
    assert_response :success

    post :set_locale, :format=>:js, :locale=>'en'
    assert_response :success

    post :set_dbid, :format=>:js, :dbid =>get_dbid   # Alten Wert erneut setzen um andere Tests nicht zu gefährden
    assert_response :success
  end

end
