# encoding: utf-8
require 'test_helper'

class DbaHistoryControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
    connect_oracle_db     # Nutzem Oracle-DB für Selektion
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
    @min_snap_id = sql_select_one ["SELECT  /* Panorama-Tool Ramm */ MIN(Snap_ID)
                                   FROM    DBA_Hist_Snapshot
                                   WHERE   Begin_Interval_Time >= ?", time_selection_start ]
    @max_snap_id = sql_select_one ["SELECT  /* Panorama-Tool Ramm */ MAX(Snap_ID)
                                   FROM    DBA_Hist_Snapshot
                                   WHERE   Begin_Interval_Time <= ?", time_selection_end ]
  end


  test "segment_stat_historic" do
    post :list_segment_stat_historic_sum, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end
    assert_response :success
    post :list_segment_stat_historic_sum, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1
    assert_response :success

    post :list_segment_stat_hist_detail, :format=>:js, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :owner=>'sys', :object_name=>'SEG$'
    assert_response :success

    post :list_segment_stat_hist_sql, :format=>:js, :instance=>1,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :owner =>"sys", :object_name=> "all_tables"
    assert_response :success
  end



  test "sql_area_historic" do
    def do_test_list_sql_area_historic(topSort)
      def do_inner_test(topSort, instance, filter, sql_id)
        post :list_sql_area_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
             :maxResultCount=>100, :topSort=>topSort, :instance=>instance, :filter=>filter, :sql_id=>sql_id
        assert_response :success
      end

      do_inner_test(topSort, nil, nil,  nil)
      do_inner_test(topSort, nil, nil,  '14147ß1471')
      do_inner_test(topSort, nil, 'hugo<>%&', nil)
      do_inner_test(topSort, 1,   nil,  nil)
    end

    do_test_list_sql_area_historic "ElapsedTimePerExecute"
    do_test_list_sql_area_historic "ElapsedTimeTotal"
    do_test_list_sql_area_historic "ExecutionCount"
    do_test_list_sql_area_historic "RowsProcessed"
    do_test_list_sql_area_historic "ExecsPerDisk"
    do_test_list_sql_area_historic "BufferGetsPerRow"
    do_test_list_sql_area_historic "CPUTime"
    do_test_list_sql_area_historic "BufferGets"
    do_test_list_sql_area_historic "ClusterWaits"

    post :list_sql_detail_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id
     assert_response :success

    post :list_sql_detail_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id, :instance=>1
    assert_response :success

    post :list_sql_detail_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id, :parsing_schema_name=>@sga_parsing_schema_Name
    assert_response :success

    post :list_sql_history_snapshots, :format=>:js, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_Name, :groupby=>:day
    assert_response :success
    post :list_sql_history_snapshots, :format=>:js, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_Name,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end
    assert_response :success

    post :list_sql_history_execution_plan, :format=>:js, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_Name,
         :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end
    assert_response :success
  end


  test "show_using_sqls_historic" do
    post :show_using_sqls_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
                                    :ObjectName => "WRH$_sysmetric_history"
    assert_response :success
  end

  test "list_system_events_historic" do
    post :list_system_events_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>1
     assert_response :success
  end

  test "list_system_events_historic_detail" do
    post :list_system_events_historic_detail, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :event_id=>1, :event_name=>"Hugo"
     assert_response :success
     assert_response :success
  end

  test "list_system_statistics_historic" do
    post :list_system_statistics_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :sum=>1
    assert_response :success
    post :list_system_statistics_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"MI"}
    assert_response :success
    post :list_system_statistics_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"HH24"}
    assert_response :success
    post :list_system_statistics_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"DD"}
    assert_response :success
  end

  test "list_system_statistics_historic_detail" do
    post :list_system_statistics_historic_detail, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1,
         :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :stat_id=>1, :stat_name=>"Hugo"
    assert_response :success
  end

  test "list_sysmetric_historic" do
    # Evtl. als sysdba auf Test-DB Table loeschen wenn noetig: truncate table sys.WRH$_SYSMETRIC_HISTORY;

    def do_test(grouping)
      # Zeitabstand deutlich kuerzer fuer diesen Test
      time_selection_end  = Time.new
      time_selection_start  = time_selection_end-80          # x Sekunden Abstand
      time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
      time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

      post :list_sysmetric_historic, :format=>:js,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :detail=>1, :grouping=>{:tag =>grouping}
      assert_response :success
      post :list_sysmetric_historic, :format=>:js,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>1, :detail=>1, :grouping=>{:tag =>grouping}
      assert_response :success
      post :list_sysmetric_historic, :format=>:js,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :summary=>1, :grouping=>{:tag =>grouping}
      assert_response :success
      post :list_sysmetric_historic, :format=>:js,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>1, :summary=>1, :grouping=>{:tag =>grouping}
      assert_response :success
    end

    if get_current_database[:host] == "ramm.osp-dd.de"                              # Nur auf DB ausführen wo Test-User ein ALTER-Grant auf sys.WRH$_SYSMETRIC_HISTORY hat
      puts "Prepare for Test: Executing ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space"
      ActiveRecord::Base.connection.execute("ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space");
    end

    do_test("SS")
    do_test("MI")
    do_test("HH24")
    do_test("DD")
  end

  test "mutex_statistics_historic" do
    def do_test_list_mutex_statistics_historic(submit_name)
      post :list_mutex_statistics_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, submit_name=>"Hugo"
      assert_response :success
      post :list_mutex_statistics_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, submit_name=>"Hugo"
      assert_response :success
    end

    do_test_list_mutex_statistics_historic(:Blocker)
    do_test_list_mutex_statistics_historic(:Waiter)
    do_test_list_mutex_statistics_historic(:Timeline)

    xhr :get, :list_mutex_statistics_historic_samples, :format=>:js, :instance=>1, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
        :filter=>:Blocking_Session, :filter_session=>@sid
    assert_response :success

    xhr :get, :list_mutex_statistics_historic_samples, :format=>:js, :instance=>1, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
        :filter=>:Requesting_Session, :filter_session=>@sid
    assert_response :success
  end

  test "latch_statistics_historic" do
    post :list_latch_statistics_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1
    assert_response :success

    post :list_latch_statistics_historic_details, :format=>:js, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :latch_hash => 12313123, :latch_name=>"Hugo"
    assert_response :success
  end

  test "enqueue_statistics_historic" do
    post :list_enqueue_statistics_historic, :format=>:js, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_start, :instance=>1
    assert_response :success

    post :list_enqueue_statistics_historic_details, :format=>:js, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :eventno => 12313123, :reason=>"Hugo", :description=>"Hugo"
    assert_response :success
  end

  test "list_compare_sql_area_historic" do
    tag1 = Time.new
    post :list_compare_sql_area_historic, :format=>:js, :instance=>1, :filter=>"Hugo", :sql_id=>@sga_sql_id, :minProzDiff=>50,
         :tag1=> tag1.strftime("%d.%m.%Y"), :tag2=>(tag1-86400).strftime("%d.%m.%Y")
    assert_response :success
  end

end
