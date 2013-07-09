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
     post :list_materialized_view_action, :format=>:js, :registered_mviews => "Hugo"
     assert_response :success;

     post :list_materialized_view_action, :format=>:js, :all_mviews => "Hugo"
     assert_response :success;

     post :list_materialized_view_action, :format=>:js, :mview_logs => "Hugo"
     assert_response :success;
  end

  test "list_registered_materialized_views" do
    get :list_registered_materialized_views, :format=>:js
    assert_response :success;

    get :list_registered_materialized_views, :format=>:js, :snapshot_id=>1
    assert_response :success;
  end


  test "list_all_materialized_views" do
    get :list_all_materialized_views, :format=>:js
    assert_response :success;

    get :list_all_materialized_views, :format=>:js, :owner=>"Hugo", :name=>"Hugo"
    assert_response :success;
  end

  test "list_materialized_view_logs" do
    get :list_materialized_view_logs, :format=>:js
    assert_response :success;

    get :list_materialized_view_logs, :format=>:js, :log_owner=>"Hugo", :log_name=>"Hugo"
    assert_response :success;
  end

  test "list_snapshot_logs" do
    get :list_snapshot_logs,  :format=>:js, :snapshot_id=>1
    assert_response :success;

    get :list_snapshot_logs,  :format=>:js,  :log_owner=>"Hugo", :log_name=>"Hugo"
    assert_response :success;
  end

  test "list_registered_mview_query_text" do
    get :list_registered_mview_query_text, :format=>:js, :mview_id=>1
    assert_response :success;
  end

  test "list_mview_query_text" do
    get :list_mview_query_text, :format=>:js, :owner=>"Hugo", :name=>"Hugo"
    assert_response :success;
  end

  test "list_real_num_rows" do
    get :list_real_num_rows, :format=>:js, :owner=>"sys", :name=>"user$"
    assert_response :success;
  end

end
