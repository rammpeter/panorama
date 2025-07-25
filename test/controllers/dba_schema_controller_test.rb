# encoding: utf-8
require 'test_helper'

class DbaSchemaControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times
    @object_owner   = PanoramaConnection.username
    @lob_table_name = 'LOB_TEST_TABLE'
    @index_name     = "IX_#{@lob_table_name}"

    PanoramaConnection.sql_execute "DROP TABLE #{@lob_table_name}" if PanoramaConnection.user_table_exists? @lob_table_name
    PanoramaConnection.sql_execute "CREATE TABLE #{@lob_table_name} (ID NUMBER PRIMARY KEY, ID2 NUMBER, Lob_Column CLOB) LOB (Lob_Column) STORE AS (DISABLE STORAGE IN ROW)"
    PanoramaConnection.sql_execute "INSERT INTO #{@lob_table_name} VALUES (1, 1, 'My_Test_Lob')"
    PanoramaConnection.sql_execute "CREATE INDEX #{@index_name} ON #{@lob_table_name}(ID, ID2)"

    # Use LOB for test from Panorama itself (if already created)m suppress ORA-10614: Operation not allowed on this segment
    @lob_segment_name = sql_select_one ["SELECT Segment_Name FROM User_Lobs WHERE Segment_Created = 'YES' AND Table_Name = UPPER(?) AND RowNum < 2", @lob_table_name]

    @edition = PanoramaConnection.edition
    if @edition == :enterprise                                                  # Precondition for partitioning
      @part_table_table_name  = 'LOB_PART_TEST_TABLE'
      @part_index_index_name  = "IX_#{@part_table_table_name}"
      PanoramaConnection.sql_execute "DROP TABLE #{@part_table_table_name}" if PanoramaConnection.user_table_exists? @part_table_table_name
      PanoramaConnection.sql_execute "CREATE TABLE #{@part_table_table_name} (ID NUMBER, Lob_Column CLOB) LOB (Lob_Column) STORE AS (DISABLE STORAGE IN ROW)
                                      PARTITION BY HASH(ID) PARTITIONS 2"
      PanoramaConnection.sql_execute ["INSERT INTO #{@part_table_table_name} VALUES (1, ?)", '1'*10]
      PanoramaConnection.sql_execute "CREATE INDEX #{@part_index_index_name} ON #{@part_table_table_name}(ID) LOCAL"
      @part_table_partition_name = sql_select_one ["SELECT Partition_Name FROM User_Tab_Partitions WHERE Table_Name = ? AND RowNum < 2", @part_table_table_name]

      lob_part_table = sql_select_first_row ["SELECT Lob_Name, Partition_Name, LOB_Partition_Name FROM User_Lob_Partitions WHERE Segment_Created = 'YES' AND Table_Name = ? AND RowNum < 2", @part_table_table_name]
      @lob_part_lob_name            = lob_part_table.lob_name
      @lob_part_partition_name      = lob_part_table.partition_name
      @lob_part_lob_partition_name  = lob_part_table.lob_partition_name

      @subpart_table_table_name = 'LOB_SUBPART_TEST_TABLE'
      @subpart_index_index_name = "IX_#{@subpart_table_table_name}"
      PanoramaConnection.sql_execute "DROP TABLE #{@subpart_table_table_name}" if PanoramaConnection.user_table_exists? @subpart_table_table_name
      PanoramaConnection.sql_execute "CREATE TABLE #{@subpart_table_table_name} (ID1 NUMBER, ID2 NUMBER, Lob_Column CLOB) LOB (Lob_Column) STORE AS (DISABLE STORAGE IN ROW)
        PARTITION BY RANGE (ID1) SUBPARTITION BY HASH (ID2) SUBPARTITIONS 2
        ( PARTITION P1 VALUES LESS THAN (1), PARTITION P2 VALUES LESS THAN (2) )
      "
      PanoramaConnection.sql_execute "INSERT INTO #{@subpart_table_table_name} VALUES (1, 1, 'MyTestLOB')"
      PanoramaConnection.sql_execute "CREATE INDEX #{@subpart_index_index_name} ON #{@subpart_table_table_name}(ID1, ID2) LOCAL"

      subpart_table = sql_select_first_row ["SELECT Partition_Name, SubPartition_Name FROM User_Tab_SubPartitions
                                             WHERE Table_Name = ? AND Segment_Created = 'YES' AND RowNum < 2", @subpart_table_table_name]
      @subpart_table_partition_name     = subpart_table.partition_name
      @subpart_table_subpartition_name  = subpart_table.subpartition_name

      part_index = sql_select_first_row ["SELECT Partition_Name FROM User_Ind_Partitions WHERE Segment_Created = 'YES' AND Index_Name = ? AND RowNum < 2", @part_index_index_name]
      if part_index
        @part_index_partition_name     = part_index.partition_name
      else
        puts "DbaSchemaControllerTest.setup: There are no index subpartitions in database"
      end

      subpart_index = sql_select_first_row ["SELECT Partition_Name, SubPartition_Name FROM User_Ind_SubPartitions
                                           WHERE Segment_Created = 'YES' AND Index_Name = ? AND RowNum < 2", @subpart_index_index_name]
      if subpart_index
        @subpart_index_partition_name     = subpart_index.partition_name
        @subpart_index_subpartition_name  = subpart_index.subpartition_name
      else
        puts "DbaSchemaControllerTest.setup: There are no index subpartitions in database"
      end
    else
      puts "DbaSchemaControllerTest.setup: There are no table partitions or subpartitions in database because edition = #{PanoramaConnection.edition}"
    end
  end

  teardown do
    set_session_test_db_context
    PanoramaConnection.sql_execute "DROP TABLE #{@lob_table_name}"            if defined?(@lob_table_name)            && PanoramaConnection.user_table_exists?(@lob_table_name)
    PanoramaConnection.sql_execute "DROP TABLE #{@part_table_table_name}"     if defined?(@part_table_table_name)     && PanoramaConnection.user_table_exists?(@part_table_table_name)
    PanoramaConnection.sql_execute "DROP TABLE #{@subpart_table_table_name}"  if defined?(@subpart_table_table_name)  && PanoramaConnection.user_table_exists?(@subpart_table_table_name)
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    assert_nothing_raised do
      call_controllers_menu_entries_with_actions
    end
  end

  test "show_object_size with xhr: true"       do get '/dba_schema/show_object_size', :params => {:format=>:html, :update_area=>:hugo };   assert_response :success; end

  test "list_objects with xhr: true"  do
    post '/dba_schema/list_objects', :params => {format: :html, tablespace: {name: "USERS"}, schema: {name: @object_owner}, update_area: :hugo };
    assert_response :success;

    post '/dba_schema/list_objects', :params => {:format=>:html, sql_id: 'abcd', :update_area=>:hugo };
    assert_response :success;

    post '/dba_schema/list_objects', :params => {:format=>:html, sql_id: 'abcd', child_number: 1, :update_area=>:hugo };
    assert_response :success;

    post '/dba_schema/list_objects', :params => {:format=>:html, sql_id: 'abcd', child_address: 'ABCD16', :update_area=>:hugo };
    assert_response :success;
  end

  test "list_object_description with xhr: true" do
    [
        {owner: 'SYS',      object_name: 'AUD$'},                              # Table
        {owner: 'SYS',      object_name: 'AUD$%'},                             # Table (Wildcard with one hit)
        {owner: 'SYS',      object_name: 'A%'},                                # (Wildcard with multiple hit)
        {owner: 'SYS',      object_name: 'TAB$'},                              # Table
        {owner: 'SYS',      object_name: 'COL$'},                              # Table
        {owner: nil,        object_name: 'ALL_TABLES'},                        # View
        {owner: 'SYS',      object_name: 'WRH$_ACTIVE_SESSION_HISTORY'},       # partitioned Table
        {owner: 'PUBLIC',   object_name: 'V$ARCHIVE'},                         # Synonym
        {owner: 'SYS',      object_name: 'DBMS_SESSION'},                      # Package oder Body
        {owner: 'SYS',      object_name: 'INSTANCE_NUM'},                      # Function
        {owner: 'SYS',      object_name: 'LOAD_UNDO_STAT'},                    # Procedure
    ]
        .concat(get_db_version >= '12.1' ? [{owner: 'XDB',      object_name: 'XDB$XTAB'}] :  [])    # XML-Table instead of relational table
        .each do |object|
      get '/dba_schema/list_object_description', :params => {format: :html, owner: object[:owner], object_name: object[:object_name], :update_area=>:hugo }
      assert_response :success
    end

    [nil, 1].each do |show_line_numbers|
      get '/dba_schema/list_object_description', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE', show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_object_description', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE BODY', show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success
    end

    post '/dba_schema/list_indexes', :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_indexes', params: {format: :html, owner: @object_owner, table_name: @lob_table_name, index_name: @index_name, :update_area=>:hugo }
    assert_response :success

    if get_db_version >= '12.2'
      post '/dba_schema/list_index_usage', :params => {:format=>:html, owner: @object_owner, index_name: @index_name, :update_area=>:hugo }
      assert_response :success
    end

    post '/dba_schema/list_current_index_stats', :params => {:format=>:html, table_owner: @object_owner, table_name: @lob_table_name, index_owner: @object_owner, index_name: @index_name, :leaf_blocks=>1, :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_primary_key', params: {format: :html, owner: @object_owner, table_name: @lob_table_name, :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_check_constraints', :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_references_from', :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_references_from', :params => {:format=>:html, :owner=>@object_owner, :table_name=>@lob_table_name, index_owner: @object_owner, index_name: @index_name, :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_references_from', :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_references_to', :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_PARALLEL_SAMPLE_DATA", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_triggers', :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    [nil, 1].each do |show_line_numbers|
      post '/dba_schema/list_trigger_body', :params => {:format=>:html, :owner=>"SYS", :trigger_name=>"LOGMNRGGC_TRIGGER", show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success
    end

    post '/dba_schema/list_lobs', :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    if defined? @part_table_table_name                                                          # if lob partitions exists in this database
      get '/dba_schema/list_lob_partitions', :params => {:format=>:html, :owner=>@object_owner, :table_name=>@part_table_table_name, :lob_name=>@lob_part_lob_name, :update_area=>:hugo }
      assert_response :success
    end

    get '/dba_schema/list_table_partitions', :params => {:format=>:html, :owner=>"SYS", :table_name=>"WRH$_SQLSTAT", :update_area=>:hugo }
    assert_response :success

    if defined? @subpart_table_table_name
      get '/dba_schema/list_table_subpartitions', :params => {:format=>:html, :owner=>@object_owner, :table_name=>@subpart_table_table_name, :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_table_subpartitions', :params => {:format=>:html, :owner=>@object_owner, :table_name=>@subpart_table_table_name, :partition_name => @subpart_table_partition_name, :update_area=>:hugo }
      assert_response :success
    end

    get '/dba_schema/list_index_partitions', :params => {:format=>:html, :owner=>"SYS", :index_name=>"WRH$_SQLSTAT_PK", :update_area=>:hugo }
    assert_response :success

    if defined? @part_index_index_name
      get '/dba_schema/list_index_partitions', :params => {:format=>:html, :owner=>@object_owner, :index_name=>@part_index_index_name, :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_index_partitions', :params => {:format=>:html, :owner=>@object_owner, :index_name=>@part_index_index_name, :partition_name => @part_index_partition_name, :update_area=>:hugo }
      assert_response :success
    end


    if defined? @subpart_index_index_name
      get '/dba_schema/list_index_subpartitions', :params => {:format=>:html, :owner=>@object_owner, :index_name=>@subpart_index_index_name, :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_index_subpartitions', :params => {:format=>:html, :owner=>@object_owner, :index_name=>@subpart_index_index_name, :partition_name => @subpart_index_partition_name, :update_area=>:hugo }
      assert_response :success
    end

    post '/dba_schema/list_dbms_metadata_get_ddl', :params => {:format=>:html, :object_type=>'TABLE', :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_dependencies', :params => {:format=>:html, :owner=>"SYS", :object_name=>"AUD$", :object_type=>'TABLE', :update_area=>:hugo }
    assert_response :success
    post '/dba_schema/list_dependencies', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBA_AUDIT_TRAIL", :object_type=>'VIEW', :update_area=>:hugo }
    assert_response :success
    post '/dba_schema/list_dependencies', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE', :update_area=>:hugo }
    assert_response :success
    post '/dba_schema/list_dependencies', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_dependencies_from_me_tree', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_dependencies_im_from_tree', :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_SESSION", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_grants', :params => {:format=>:html, :owner=>"SYS", :object_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

  end

  test "list_plsql_methods with xhr: true" do
    post '/dba_schema/list_plsql_description_methods', params: {format: :html, owner: "SYS", object_name: "DBMS_SESSION", object_type: 'PACKAGE', :update_area=>:hugo }
    assert_response :success

    post '/dba_schema/list_plsql_arguments', params: {format: :html, owner: "SYS", object_name: "DBMS_SESSION", procedure_name: 'SET_ROLE', subprogram_id: 1, :update_area=>:hugo }
    assert_response :success
  end

  test "list_audit_rules with xhr: true" do
    get '/dba_schema/show_audit_rules', params: {format: :html,  update_area: :hugo }
    assert_response :success

    get '/dba_schema/show_audit_rules', params: {format: :html,  object_type: 'TABLE', update_area: :hugo }
    assert_response :success

    get '/dba_schema/show_audit_rules', params: {format: :html,  object_type: 'TABLE', owner: 'SYS', object_name: 'AUD$', update_area: :hugo }
    assert_response :success
  end

  test "list_audit_unified_policy_names with xhr: true" do
    if get_db_version >= '12.2'
      get '/dba_schema/list_audit_unified_policy_names', params: {format: :html, update_area: :hugo }
      assert_response :success

      get '/dba_schema/list_audit_unified_policy_names', params: {format: :html, policy_name: 'HUGO_POLICY', update_area: :hugo }
      assert_response :success

      get '/dba_schema/list_audit_unified_policy_names', params: {format: :html, policy_name: 'HUGO_POLICY', object_type: 'TABLE', update_area: :hugo }
      assert_response :success

      get '/dba_schema/list_audit_unified_policy_names', params: {format: :html, object_type: 'TABLE', update_area: :hugo }
      assert_response :success
    end
  end

  test "list_audit_trail with xhr: true" do
    get '/dba_schema/list_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get '/dba_schema/list_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :statement_type=>"Hugo", :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get '/dba_schema/list_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :session_id=>12345, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get '/dba_schema/list_audit_trail', :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get '/dba_schema/list_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :statement_type=>"Hugo", :grouping=>"MI", :top_x=>"5", :update_area=>:hugo }
    assert_response :success

    get '/dba_schema/list_audit_trail', :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"MI", :update_area=>:hugo }
    assert_response :success
  end

  test "list_unified_audit_trail with xhr: true" do
    if get_db_version >= '12.1'
      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
                                                 :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"none", :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :sessionid=>12345, :grouping=>"none", :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
                                                 :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"MI", :top_x=>"5", :update_area=>:hugo }
      assert_response :success

      get '/dba_schema/list_unified_audit_trail', :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"MI", :update_area=>:hugo }
      assert_response :success
    end
  end

  test "list_object_nach_file_und_block with xhr: true" do
    get '/dba_schema/list_object_nach_file_und_block', :params => {:format=>:html, :fileno=>1, :blockno=>1, :update_area=>:hugo }
    assert_response :success
  end

  test "list_space_usage with xhr: true" do
    get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @lob_segment_name , update_area: :hugo }
    assert_response :success

    if defined?(@lob_part_lob_name)
      # all partitions
      get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @lob_part_lob_name , update_area: :hugo }
      assert_response :success

      if defined?(@lob_part_lob_partition_name)
        # one partition
        get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @lob_part_lob_name, partition_name: @lob_part_lob_partition_name , update_area: :hugo }
        assert_response :success
      end
    end


    if defined?(@part_table_table_name)
      # all partitions
      get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @part_table_table_name , update_area: :hugo }
      assert_response :success

      if defined?(@lob_part_partition_name)
        # one partition
        get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @part_table_table_name, partition_name: @lob_part_partition_name , update_area: :hugo }
        assert_response :success
      end
    end

    if defined?(@part_index_index_name)
      # all partitions
      get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @part_index_index_name , update_area: :hugo }
      assert_response :success

      if defined?(@part_index_partition_name)
        # one partition
        get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @part_index_index_name, partition_name: @part_index_partition_name , update_area: :hugo }
        assert_response :success
      end
    end

    if defined?(@subpart_table_table_name)
      # all partitions
      get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @subpart_table_table_name , update_area: :hugo }
      assert_response :success

      if defined?(@subpart_table_subpartition_name)
        # one partition
        get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @subpart_table_table_name, partition_name: @subpart_table_subpartition_name , update_area: :hugo }
        assert_response :success
      end
    end

    if defined?(@subpart_index_index_name)
      # all partitions
      get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @subpart_index_index_name , update_area: :hugo }
      assert_response :success

      if defined?(@subpart_index_subpartition_name)
        # one partition
        get '/dba_schema/list_space_usage', params: {format: :html, owner: @object_owner, segment_name: @subpart_index_index_name, partition_name: @subpart_index_subpartition_name , update_area: :hugo }
        assert_response :success
      end
    end
  end

  test 'list stored settings' do
    get '/dba_schema/list_stored_settings', params: {format: :html, owner: 'SYS', object_name: 'DBMS_STATS', object_type: 'PACKAGE BODY' }
    assert_response :success
  end

  test 'list role grants' do
    post '/dba_schema/list_role_grants', params: {format: :html, role: 'CONNECT' }
    assert_response :success

    post '/dba_schema/list_role_grants', params: {format: :html, grantee: 'SYS' }
    assert_response :success
  end

  test 'list granted sys privileges' do
    post '/dba_schema/list_granted_sys_privileges', params: {format: :html, privilege: 'SELECT ANY TABLE' }
    assert_response :success

    post '/dba_schema/list_granted_sys_privileges', params: {format: :html, grantee: 'SYS' }
    assert_response :success
  end

  test 'list granted obj privileges' do
    post '/dba_schema/list_obj_grants', params: {format: :html, privilege: 'SELECT' }
    assert_response :success

    post '/dba_schema/list_obj_grants', params: {format: :html, grantee: 'SYS' }
    assert_response :success

    post '/dba_schema/list_obj_grants', params: {format: :html, grantor: 'SYS' }
    assert_response :success
  end

  test 'list db users' do
    # call without parameters is tested as first level menu entry
    post '/dba_schema/list_db_users', params: {format: :html, username: 'SYS' }
    assert_response :success
  end

  test 'list ts quotas' do
    post '/dba_schema/list_ts_quotas', params: {format: :html, username: 'SYS' }
    assert_response :success
  end

  test 'list roles' do
    # call without parameters is tested as first level menu entry
    post '/dba_schema/list_roles', params: {format: :html, role: 'CONNECT' }
    assert_response :success
  end

  test "compression_check with xhr: true" do
    post '/dba_schema/list_compression_check', :params => {format: :html, owner: @object_owner, table_name: @lob_table_name, avg_row_len: 32, gap_number: 1, :update_area=>:hugo }
    assert_response :success
    if @edition == :enterprise
      post '/dba_schema/list_compression_check', :params => {format: :html, owner: @object_owner, table_name: @part_table_table_name, partition_name: @part_table_partition_name, avg_row_len: 32, gap_number: 1, :update_area=>:hugo }
      assert_response :success
      post '/dba_schema/list_compression_check', :params => {format: :html, owner: @object_owner, table_name: @subpart_table_table_name, partition_name: @subpart_table_subpartition_name,  is_subpartition: 'true', avg_row_len: 32, gap_number: 1, :update_area=>:hugo }
      assert_response :success
    end
  end

  test 'list_db_objects with xhr: true' do
    post '/dba_schema/list_db_objects', params: {format: :html, owner: 'SYS', update_area: :hugo }
    assert_response :success
    post '/dba_schema/list_db_objects', params: {format: :html, object_name: 'DBMS_SESSION', update_area: :hugo }
    assert_response :success
    post '/dba_schema/list_db_objects', params: {format: :html, object_type: 'PACKAGE BODY', update_area: :hugo }
    assert_response :success
    post '/dba_schema/list_db_objects', params: {format: :html, owner: 'SYS', object_name: 'DBMS_SESSION', object_type: 'PACKAGE BODY', update_area: :hugo }
    assert_response :success
  end

  test 'list_gradual_password_rollover with xhr: true' do
    if get_db_version >= '19.12'
      post '/dba_schema/list_gradual_password_rollover', params: {format: :html, days_back: 3, update_area: :hugo }
      assert_response :success
    end
  end
end
