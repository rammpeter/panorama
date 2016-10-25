# encoding: utf-8
require 'test_helper'

module Panorama
class DbaSchemaControllerTest < ActionController::TestCase
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
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

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end

  test "show_object_size"       do get  :show_object_size, :format=>:js;   assert_response :success; end
  test "list_objects"           do post :list_objects, :params => {:format=>:js, :tablespace=>{:name=>"USERS"}, :schema=>{:name=>"SCOTT"} };       assert_response :success; end

  test "list_table_description" do
    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"AUD$" }
    assert_response :success;

    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"TAB$" }
    assert_response :success;

    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"COL$" }
    assert_response :success;

    post :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"COL$" }
    assert_response :success;

    get :list_object_description, :params => {:format=>:js, :owner=>"PUBLIC", :segment_name=>"V$ARCHIVE" } # Synonym
    assert_response :success;
    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"DBMS_LOCK" }     # Package oder Body
    assert_response :success;
    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"DBMS_LOCK", :object_type=>'PACKAGE' }
    assert_response :success;
    get :list_object_description, :params => {:format=>:js, :owner=>"SYS", :segment_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY' }
    assert_response :success;
    get :list_object_description, :params => {:format=>:js, :segment_name=>"ALL_TABLES" }                  # View
    assert_response :success;

    post :list_indexes, :params => {:format=>:js, :owner=>"SYS", :table_name=>"AUD$" }
    assert_response :success;

    post :list_primary_key, :params => {:format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD" }
    assert_response :success;

    post :list_check_constraints, :params => {:format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD" }
    assert_response :success;

    post :list_references_from, :params => {:format=>:js, :owner=>"SYS", :table_name=>"HS$_INST_DD" }
    assert_response :success;

    post :list_references_to, :params => {:format=>:js, :owner=>"SYS", :table_name=>"HS$_PARALLEL_SAMPLE_DATA" }
    assert_response :success;

    post :list_triggers, :params => {:format=>:js, :owner=>"SYS", :table_name=>"AUD$" }
    assert_response :success;

    post :list_lobs, :params => {:format=>:js, :owner=>"SYS", :table_name=>"AUD$" }
    assert_response :success;

    if @lob_part_owner                                                          # if lob partitions exists in this database
      get :list_lob_partitions, :params => {:format=>:js, :owner=>@lob_part_owner, :table_name=>@lob_part_table_name, :lob_name=>@lob_part_lob_name }
      assert_response :success;
    end

    get :list_table_partitions, :params => {:format=>:js, :owner=>"SYS", :table_name=>"WRH$_SQLSTAT" }
    assert_response :success;

    if @subpart_table_owner
      get :list_table_subpartitions, :params => {:format=>:js, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name }
      assert_response :success;

      get :list_table_subpartitions, :params => {:format=>:js, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name, :partition_name => @subpart_table_partition_name }
      assert_response :success;
    end

    get :list_index_partitions, :params => {:format=>:js, :owner=>"SYS", :index_name=>"WRH$_SQLSTAT_PK" }
    assert_response :success;

    if @subpart_index_owner
      get :list_index_subpartitions, :params => {:format=>:js, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name }
      assert_response :success;

      get :list_index_subpartitions, :params => {:format=>:js, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name, :partition_name => @subpart_table_partition_name }
      assert_response :success;
    end

    post :list_dbms_metadata_get_ddl, :params => {:format=>:js, :owner=>"SYS", :table_name=>"AUD$" }
    assert_response :success;

    post :list_dependencies, :params => {:format=>:js, :owner=>"SYS", :object_name=>"AUD$", :object_type=>'TABLE' }
    assert_response :success;
    post :list_dependencies, :params => {:format=>:js, :owner=>"SYS", :object_name=>"DBA_AUDIT_TRAIL", :object_type=>'VIEW' }
    assert_response :success;
    post :list_dependencies, :params => {:format=>:js, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE' }
    assert_response :success;
    post :list_dependencies, :params => {:format=>:js, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY' }
    assert_response :success;

    post :list_grants, :params => {:format=>:js, :owner=>"SYS", :object_name=>"AUD$" }
    assert_response :success;

  end

  test "list_audit_trail" do
    get :list_audit_trail, :params => {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none" }
    assert_response :success;

    get :list_audit_trail, :params => {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"none" }
    assert_response :success;

    get :list_audit_trail, :params => {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :sessionid=>12345, :grouping=>"none" }
    assert_response :success;

    get :list_audit_trail, :params => {:format=>:js,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none" }
    assert_response :success;

    get :list_audit_trail, :params => {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"MI", :top_x=>"5" }
    assert_response :success;

    get :list_audit_trail, :params => {:format=>:js,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"MI" }
    assert_response :success;

  end

  test "list_object_nach_file_und_block" do
    get :list_object_nach_file_und_block, :params => {:format=>:js, :fileno=>1, :blockno=>1 }
    assert_response :success
  end

end
end
