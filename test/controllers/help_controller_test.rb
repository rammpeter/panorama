# encoding: utf-8
require 'test_helper'

class HelpControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context
  end

  test "overview with xhr: true" do
    get '/help/overview', :params => {:format=>:html }
    assert_response :success
  end

  test "version_history with xhr: true" do
    get '/help/version_history', :params => {:format=>:html }
    assert_response :success
  end

end
