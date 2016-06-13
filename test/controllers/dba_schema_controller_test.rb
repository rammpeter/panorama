# encoding: utf-8
require 'test_helper'

class DbaSchemaControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-100000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    lob_part_table = sql_select_first_row "SELECT Table_Owner, Table_Name, Lob_Name FROM DBA_Lob_Partitions WHERE RowNum < 2"
    if lob_part_table
      @lob_part_owner      = lob_part_table.table_owner
      @lob_part_table_name = lob_part_table.table_name
      @lob_part_lob_name   = lob_part_table.lob_name
    end

    subpart_table = sql_select_first_row "SELECT Table_Owner, Table_Name, Partition_Name FROM DBA_Tab_SubPartitions WHERE RowNum < 2"
    if subpart_table
      @subpart_table_owner            = subpart_table.table_owner
      @subpart_table_table_name       = subpart_table.table_name
      @subpart_table_partition_name   = subpart_table.partition_name
    end

    subpart_index = sql_select_first_row "SELECT Index_Owner, Index_Name, Partition_Name FROM DBA_Ind_SubPartitions WHERE RowNum < 2"
    if subpart_index
      @subpart_index_owner            = subpart_index.index_owner
      @subpart_index_index_name       = subpart_index.index_name
      @subpart_index_partition_name   = subpart_index.partition_name
    end

  end

  test "show_object_size"       do xhr :get,  :show_object_size, :format=>:js;   assert_response :success; end
  test "list_objects"           do post :list_objects, :format=>:js, :tablespace=>{:name=>"USERS"}, :schema=>{:name=>"SCOTT"};       assert_response :success; end

  test "list_table_description" do
    xhr :get, :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"AUD$"
    assert_response :success;

    xhr :get, :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"TAB$"
    assert_response :success;

    xhr :get, :list_table_description, :format=>:js, :owner=>"SYS", :segment_name=>"COL$"
    assert_response :success;

    post :list_indexes, :format=>:js, :owner=>"SYS", :table_name=>"AUD$"
    assert_response :success;

    post :list_primary_key, :format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD"
    assert_response :success;

    post :list_check_constraints, :format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD"
    assert_response :success;

    post :list_references_from, :format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD"
    assert_response :success;

    post :list_references_to, :format=>:js, :owner=>"SYS", :table_name=>"HS$_PARALLEL_SAMPLE_DATA"
    assert_response :success;

    post :list_triggers, :format=>:js, :owner=>"SYS", :table_name=>"AUD$"
    assert_response :success;

    post :list_lobs, :format=>:js, :owner=>"SYS", :table_name=>"AUD$"
    assert_response :success;

    if @lob_part_owner                                                          # if lob partitions exists in this database
      xhr :get, :list_lob_partitions, :format=>:js, :owner=>@lob_part_owner, :table_name=>@lob_part_table_name, :lob_name=>@lob_part_lob_name
      assert_response :success;
    end

    post :list_sessions, :format=>:js, :object_owner=>"SYS", :object_name=>"AUD$"
    assert_response :success;

         #   list_trigger_body hat leider keine Table in SYS

    xhr :get, :list_table_partitions, :format=>:js, :owner=>"SYS", :table_name=>"WRH$_SQLSTAT"
    assert_response :success;

    if @subpart_table_owner
      xhr :get, :list_table_subpartitions, :format=>:js, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name
      assert_response :success;

      xhr :get, :list_table_subpartitions, :format=>:js, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name, :partition_name => @subpart_table_partition_name
      assert_response :success;
    end

    xhr :get, :list_index_partitions, :format=>:js, :owner=>"SYS", :index_name=>"WRH$_SQLSTAT_PK"
    assert_response :success;

    if @subpart_index_owner
      xhr :get, :list_index_subpartitions, :format=>:js, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name
      assert_response :success;

      xhr :get, :list_index_subpartitions, :format=>:js, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name, :partition_name => @subpart_table_partition_name
      assert_response :success;
    end

  end

  test "list_audit_trail" do
    xhr :get, :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none"
    assert_response :success;

    xhr :get, :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"none"
    assert_response :success;

    xhr :get, :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :sessionid=>12345, :grouping=>"none"
    assert_response :success;

    xhr :get, :list_audit_trail, :format=>:js,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none"
    assert_response :success;

    xhr :get, :list_audit_trail, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"MI", :top_x=>"5"
    assert_response :success;

    xhr :get, :list_audit_trail, :format=>:js,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"MI"
    assert_response :success;

  end

  test "list_object_nach_file_und_block" do
    xhr :get, :list_object_nach_file_und_block, :format=>:js, :fileno=>1, :blockno=>1
    assert_response :success
  end

end
