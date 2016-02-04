# encoding: utf-8
require 'test_helper'

class DbaSgaControllerTest < ActionController::TestCase
  setup do
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

  test "show_application_info" do
    xhr :get, :show_application_info, :format=>:js, :moduletext=>"Application = 128"
    assert_response :success
  end

  test "list_sql_area_sql_id" do
    @topSort.each do |ts|
      post :list_sql_area_sql_id, :format=>:js, :maxResultCount=>"100", :instance=>"", :sql_id=>"", :topSort=>ts
      assert_response :success
    end
  end

  test "list_sql_area_sql_id_childno" do
    @topSort.each do |ts|
      post :list_sql_area_sql_id_childno, :format=>:js, :maxResultCount=>"100", :instance=>"", :sql_id=>"", :topSort=>ts
      assert_response :success
    end
  end

  test "list_sql_detail_sql_id_childno" do
    xhr :get, :list_sql_detail_sql_id_childno, :format=>:js, :instance => "1", :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_sql_detail_sql_id" do
    xhr :get,  :list_sql_detail_sql_id , :format=>:js, :instance => "1", :sql_id => @sga_sql_id
    assert_response :success

    xhr :get,  :list_sql_detail_sql_id , :format=>:js, :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_open_cursor_per_sql" do
    xhr :get, :list_open_cursor_per_sql, :format=>:js, :instance=>1, :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_sga_components" do
    post :list_sga_components, :format=>:js, :instance=>1
    assert_response :success

    post :list_sga_components, :format=>:js
    assert_response :success

    post :list_sql_area_memory, :format=>:js, :instance=>1
    assert_response :success

    post :list_object_cache_detail, :format=>:js, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"sharable_mem"
    assert_response :success

    post :list_object_cache_detail, :format=>:js, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"record_count"
    assert_response :success

  end

  test "list_db_cache_content" do
    post :list_db_cache_content, :format=>:js, :instance=>1
    assert_response :success
  end

  test "show_using_sqls" do
    xhr :get, :show_using_sqls, :format=>:js, :ObjectName=>"gv$sql"
    assert_response :success
  end

  test "list_object_nach_file_und_block" do
    xhr :get, :list_object_nach_file_und_block, :format=>:js, :fileno=>1, :blockno=>1
    assert_response :success
  end

  test "list_cursor_memory" do
    xhr :get, :list_cursor_memory, :format=>:js, :instance=>1, :sql_id=>@sga_sql_id
    assert_response :success
  end

  test "compare_execution_plans" do
    post :list_compare_execution_plans, :format=>:js, :instance_1=>1, :sql_id_1=>@sga_sql_id, :child_number_1 =>@sga_child_number,  :instance_2=>1, :sql_id_2=>@sga_sql_id, :child_number_2 =>@sga_child_number
    assert_response :success
  end

  test "list_result_cache" do
    post :list_result_cache, :format=>:js, :instance=>1
    assert_response :success
    post :list_result_cache, :format=>:js
    assert_response :success


    if get_db_version >= '11.2'
      xhr :get, :list_result_cache_single_results, :format=>:js, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL'
      assert_response :success
    end

    xhr :get, :list_result_cache_dependencies_by_id, :format=>:js, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL'
    assert_response :success

    xhr :get, :list_result_cache_dependencies_by_name, :format=>:js, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL'
    assert_response :success

    xhr :get, :list_result_cache_dependents, :format=>:js, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL'
    assert_response :success

  end

  test "list_db_cache_advice_historic" do
    post :list_db_cache_advice_historic, :format=>:js, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
    assert_response :success
  end

  test "list_db_cache_by_object_id" do
    post :list_db_cache_by_object_id, :format=>:js, :object_id=>@object_id
    assert_response :success
  end

end
