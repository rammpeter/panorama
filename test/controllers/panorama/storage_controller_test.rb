# encoding: utf-8
require 'test_helper'

module Panorama
class StorageControllerTest < ActionController::TestCase
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end

  test "storage_controller" do

    get  :datafile_usage, :params => { :format=>:js }
    assert_response :success

    post :list_materialized_view_action, :params => { :format=>:js, :registered_mviews => "Hugo" }
    assert_response :success;

    post :list_materialized_view_action, :params => { :format=>:js, :all_mviews => "Hugo" }
    assert_response :success;

    post :list_materialized_view_action, :params => { :format=>:js, :mview_logs => "Hugo" }
    assert_response :success;

    get :list_registered_materialized_views, :params => { :format=>:js }
    assert_response :success;

    get :list_registered_materialized_views, :params => { :format=>:js, :snapshot_id=>1 }
    assert_response :success;

    get :list_all_materialized_views, :params => { :format=>:js }
    assert_response :success;

    get :list_all_materialized_views, :params => { :format=>:js, :owner=>"Hugo", :name=>"Hugo" }
    assert_response :success;

    get :list_materialized_view_logs, :params => { :format=>:js }
    assert_response :success;

    get :list_materialized_view_logs, :params => { :format=>:js, :log_owner=>"Hugo", :log_name=>"Hugo" }
    assert_response :success;

    get :list_snapshot_logs,  :params => { :format=>:js, :snapshot_id=>1 }
    assert_response :success;

    get :list_snapshot_logs,  :params => { :format=>:js,  :log_owner=>"Hugo", :log_name=>"Hugo" }
    assert_response :success;

    get :list_registered_mview_query_text, :params => { :format=>:js, :mview_id=>1 }
    assert_response :success;

    get :list_mview_query_text, :params => { :format=>:js, :owner=>"Hugo", :name=>"Hugo" }
    assert_response :success;

    get :list_real_num_rows, :params => { :format=>:js, :owner=>"sys", :name=>"obj$" } # sys.user$ requires extra rights compared to SELECT ANY DICTIONARY in 12c
    assert_response :success;

    get  :tablespace_usage, :params => { :format=>:js }
    assert_response :success
  end

end
end