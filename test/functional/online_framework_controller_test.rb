# encoding: utf-8
require 'test_helper'

class OnlineFrameworkControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
  end

  # Menu-Einträge separat testen, da diese nicht von env_controller_test erfasst werden
  test "show_overview"             do; xhr :get, :show_overview,             :format=>:js; assert_response :success; end
  test "show_history"              do; xhr :get, :show_history,              :format=>:js; assert_response :success; end

  test "show_history_list" do
    xhr :get, :show_history_list, :format=>:js,
                            :time_selection_start =>"01.01.2011 00:00",
                            :time_selection_end =>"01.01.2011 00:00",
                            :ShowGroup =>"ID_OFMessageType",
                            :domain    => {:id=>"1"},
                            :timeSlice => "10" if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "list_quick_overview" do
    xhr :get, :list_quick_overview, :format=>:js   if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "list_overview" do
    xhr :get, :list_overview, :format=>:js     if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end


  test "show_working_ofbulkgroup" do
    xhr :get, :show_working_ofbulkgroup, :format=>:js   if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

end
