# encoding: utf-8
require 'test_helper'

module Panorama
class DbaSgaControllerTest < ActionController::TestCase
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    @topSort = ["ElapsedTimePerExecute",
               "ElapsedTimeTotal",
               "ExecutionCount",
               "RowsProcessed",
               "ExecsPerDisk",
               "BufferGetsPerRow",
               "CPUTime",
               "BufferGets",
               "ClusterWaits"
    ]

    @object_id = sql_select_one "SELECT objd FROM v$BH WHERE RowNum < 2"
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  test "show_application_info" do
    get :show_application_info, :params => {:format=>:js, :moduletext=>"Application = 128" }
    assert_response :success
  end

  test "list_sql_area_sql_id" do
    @topSort.each do |ts|
      post :list_sql_area_sql_id, :params => {:format=>:js, :maxResultCount=>"100", :instance=>"", :sql_id=>"", :topSort=>ts }
      assert_response :success
    end
  end

  test "list_sql_area_sql_id_childno" do
    @topSort.each do |ts|
      post :list_sql_area_sql_id_childno, :params => {:format=>:js, :maxResultCount=>"100", :instance=>"", :sql_id=>"", :topSort=>ts }
      assert_response :success
    end
  end

  test "list_sql_detail_sql_id_childno" do
    get :list_sql_detail_sql_id_childno, :params => {:format=>:js, :instance => "1", :sql_id => @sga_sql_id  }
    assert_response :success
  end

  test "list_sql_detail_sql_id" do
    get  :list_sql_detail_sql_id , :params => {:format=>:js, :instance => "1", :sql_id => @sga_sql_id }
    assert_response :success

    get  :list_sql_detail_sql_id , :params => {:format=>:js, :sql_id => @sga_sql_id }
    assert_response :success

    post :list_sql_profile_detail, :params => {:format=>:js, :profile_name=>'Hugo' }
    assert_response :success

  end

  test "list_open_cursor_per_sql" do
    get :list_open_cursor_per_sql, :params => {:format=>:js, :instance=>1, :sql_id => @sga_sql_id }
    assert_response :success
  end

  test "list_sga_components" do
    post :list_sga_components, :params => {:format=>:js, :instance=>1 }
    assert_response :success

    post :list_sga_components, :format=>:js
    assert_response :success

    post :list_sql_area_memory, :params => {:format=>:js, :instance=>1 }
    assert_response :success

    post :list_object_cache_detail, :params => {:format=>:js, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"sharable_mem" }
    assert_response :success

    post :list_object_cache_detail, :params => {:format=>:js, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"record_count" }
    assert_response :success

  end

  test "list_db_cache_content" do
    post :list_db_cache_content, :params => {:format=>:js, :instance=>1 }
    assert_response :success
  end

  test "show_using_sqls" do
    get :show_using_sqls, :params => {:format=>:js, :ObjectName=>"gv$sql" }
    assert_response :success
  end

  test "list_cursor_memory" do
    get :list_cursor_memory, :params => {:format=>:js, :instance=>1, :sql_id=>@sga_sql_id }
    assert_response :success
  end

  test "compare_execution_plans" do
    post :list_compare_execution_plans, :params => {:format=>:js, :instance_1=>1, :sql_id_1=>@sga_sql_id, :child_number_1 =>@sga_child_number,  :instance_2=>1, :sql_id_2=>@sga_sql_id, :child_number_2 =>@sga_child_number }
    assert_response :success
  end

  test "list_result_cache" do
    post :list_result_cache, :params => {:format=>:js, :instance=>1 }
    assert_response :success
    post :list_result_cache, :params => {:format=>:js }
    assert_response :success


    if get_db_version >= '11.2'
      get :list_result_cache_single_results, :params => {:format=>:js, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL' }
      assert_response :success
    end

    get :list_result_cache_dependencies_by_id, :params => {:format=>:js, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL' }
    assert_response :success

    get :list_result_cache_dependencies_by_name, :params => {:format=>:js, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL' }
    assert_response :success

    get :list_result_cache_dependents, :params => {:format=>:js, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL' }
    assert_response :success

  end

  test "list_db_cache_advice_historic" do
    post :list_db_cache_advice_historic, :params => {:format=>:js, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
    assert_response :success
  end

  test "list_db_cache_by_object_id" do
    post :list_db_cache_by_object_id, :params => {:format=>:js, :object_id=>@object_id }
    assert_response :success
  end

  test "plan_management" do
    post :list_sql_profile_sqltext, :params => {:format=>:js, :profile_name=>'Hugo' }
    assert_response :success

    post :list_sql_plan_baseline_sqltext, :params => {:format=>:js, :plan_name=>'Hugo' }
    assert_response :success
  end

end
end
