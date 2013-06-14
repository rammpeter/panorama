# encoding: utf-8
require 'test_helper'

class DbaSgaControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}

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
  end

  test "show_application_info" do
    get :show_application_info, :format=>:js, :moduletext=>"Application = 128"
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
    get  :list_sql_detail_sql_id_childno, :format=>:js, :instance => "1", :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_sql_detail_sql_id" do
    get  :list_sql_detail_sql_id , :format=>:js, :instance => "1", :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_open_cursor_per_sql" do
    get :list_open_cursor_per_sql, :format=>:js, :instance=>1, :sql_id => @sga_sql_id
    assert_response :success
  end

  test "list_sga_components" do
    post :list_sga_components, :format=>:js, :instance=>1
    post :list_sga_components, :format=>:js
    assert_response :success
  end

  test "list_db_cache_content" do
    post :list_db_cache_content, :format=>:js, :instance=>1
    assert_response :success
  end

  test "show_using_sqls" do
    get :show_using_sqls, :format=>:js, :ObjectName=>"gv$sql"
    assert_response :success
  end

  test "list_object_nach_file_und_block" do
    get :list_object_nach_file_und_block, :format=>:js, :fileno=>1, :blockno=>1
    assert_response :success
  end

  test "list_cursor_memory" do
    get :list_cursor_memory, :format=>:js, :instance=>1, :sql_id=>@sga_sql_id
    assert_response :success
  end

  test "compare_execution_plans" do
    post :list_compare_execution_plans, :format=>:js, :instance_1=>1, :sql_id_1=>@sga_sql_id, :child_number_1 =>@sga_child_number,  :instance_2=>1, :sql_id_2=>@sga_sql_id, :child_number_2 =>@sga_child_number
    assert_response :success
  end

  test "list_result_cache" do
    post :list_result_cache, :format=>:js, :instance=>1
    post :list_result_cache, :format=>:js
    assert_response :success
  end

end
