# encoding: utf-8
require 'test_helper'

class DbaSchemaControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end

  test "show_object_size"       do get  :show_object_size, :format=>:js;   assert_response :success; end
  test "list_objects"           do post :list_objects, :format=>:js, :tablespace=>{:name=>"USERS"}, :schema=>{:name=>"SCOTT"};       assert_response :success; end

  test "list_table_description" do
    get :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"AUD$"
    assert_response :success;

    get :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"TAB$"
    assert_response :success;

    get :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"COL$"
    assert_response :success;
  end

  test "list_table_partitions" do
    get :list_table_partitions, :format=>:js, :owner=>"SYS", :table_name=>"WRH$_SQLSTAT"
    assert_response :success;
  end

  test "list_index_partitions" do
    get :list_index_partitions, :format=>:js, :owner=>"SYS", :index_name=>"WRH$_SQLSTAT_PK"
    assert_response :success;
  end

  test "list_audit_trail" do
    get :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
    assert_response :success;
    get :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo"
    assert_response :success;
    get :list_audit_trail, :format=>:js, :sessionid=>12345
    assert_response :success;
  end

end
