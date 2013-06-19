# encoding: utf-8
require 'test_helper'

class StorageControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end

  test "list_materialized_view_action" do
     get :list_registered_materialized_view_action, :format=>:js, :registered_mviews => "Hugo"
     assert_response :success;

     get :list_all_materialized_view_action, :format=>:js, :all_mviews => "Hugo"
     assert_response :success;

     get :list_materialized_view_action, :format=>:js, :mview_logs => "Hugo"
     assert_response :success;
  end

end
