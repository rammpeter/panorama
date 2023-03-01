# encoding: utf-8
require 'test_helper'

class DbaHistoryControllerTest < ActionDispatch::IntegrationTest
  include DbaHistoryHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times

    @autonomous_database =  PanoramaConnection.autonomous_database?             # No access to DB possible within test code ???

    if management_pack_license == :none                                         # Fake defaults if no management pack license
      @@sga_sql_id_without_history = '12345'
      @@hist_sql_id                = '12345'
      @@hist_parsing_schema_name   = 'HUGO'
    else
      if !defined? @@sql_initial_read
        @@sql_initial_read = true
        @@sga_sql_id_without_history = sql_select_one ["\
        SELECT /*+ USE_NL(s ht) INDEX_RS_ASC(ht) */ s.SQL_ID
        FROM   v$SQLArea s
        LEFT OUTER JOIN DBA_Hist_SQLText ht ON ht.SQL_ID = s.sql_ID and ht.DBID = ?
        WHERE ht.SQL_ID IS NULL
        AND    RowNum < 2
      ", get_dbid]
        raise "No SQL-ID found in SGA" if @@sga_sql_id_without_history.nil?

        # Find a SQL_ID that surely exists in History
        sql_row = sql_select_first_row "SELECT MAX(SQL_ID)              KEEP (DENSE_RANK LAST ORDER BY Occurs) SQL_ID,
                                             MAX(Parsing_Schema_Name) KEEP (DENSE_RANK LAST ORDER BY Occurs) Parsing_Schema_Name
                                      FROM   (
                                              SELECT SQL_ID, Parsing_Schema_Name, COUNT(*) Occurs
                                              FROM   DBA_Hist_SQLStat s
                                              WHERE  s.Snap_ID > (SELECT MAX(Snap_ID) FROM DBA_Hist_Snapshot) - 20
                                              GROUP BY SQL_ID, Parsing_Schema_Name
                                             )
                                     "

        @@hist_sql_id = sql_row.sql_id
        @@hist_parsing_schema_name = sql_row.parsing_schema_name
      end
    end
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "segment_stat_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    post '/dba_history/list_segment_stat_historic_sum', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response_success_or_management_pack_violation('list_segment_stat_historic_sum')
    post '/dba_history/list_segment_stat_historic_sum', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>instance, :update_area=>:hugo }
    assert_response_success_or_management_pack_violation('list_segment_stat_historic_sum with instance')

    post '/dba_history/list_segment_stat_hist_detail', :params => {:format=>:html, :instance=>instance, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :owner=>'sys', :object_name=>'SEG$', :update_area=>:hugo }
    assert_response :success  # DBA_Hist_Seg_Stat does not require diagnostics pack

    post '/dba_history/list_segment_stat_hist_detail', :params => {:format=>:html, :owner=>'sys', :object_name=>'SEG$', :update_area=>:hugo } # called from list_object_description
    assert_response :success  # DBA_Hist_Seg_Stat does not require diagnostics pack

    post '/dba_history/list_segment_stat_hist_sql', :params => {:format=>:html, :instance=>instance,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :owner =>"sys", :object_name=> "all_tables", :update_area=>:hugo }
    assert_response_success_or_management_pack_violation('list_segment_stat_hist_sql')
  end

  test "sql_area_historic with xhr: true" do
    instances = [nil, PanoramaConnection.instance_number]
    def do_test(topSort, filter, sql_id, instance)
      post '/dba_history/list_sql_area_historic', :params => {:format=>:html,
                                                              :time_selection_start => @time_selection_start,
                                                              :time_selection_end   => @time_selection_end,
                                                              :maxResultCount       => 100,
                                                              :topSort              => topSort,
                                                              :filter               => filter,
                                                              :sql_id               => sql_id,
                                                              :instance             => instance,
                                                              :update_area          => :hugo }
      assert_response management_pack_license == :none ? :error : :success
    end

    sql_area_sort_criteria_historic.each do |key, value|
      do_test(key, nil, nil, nil)
    end

    [nil, 'hugo<>%&'].each do |filter|
      do_test('ElapsedTimePerExecute', filter, nil, nil)
    end

    [nil, '14147ß1471'].each do |sql_id|
      do_test('ElapsedTimePerExecute', nil, sql_id, nil)
    end

    instances.each do |instance|
      do_test('ElapsedTimePerExecute', nil, nil, instance)
    end
  end

  test 'list_sql_historic_execution_plan with xhr: true' do
    if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
      Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
    else
      post '/dba_history/list_sql_historic_execution_plan', :params => {:format=>:html, :sql_id=>@@hist_sql_id, :instance=>PanoramaConnection.instance_number, :parsing_schema_name=>@@hist_parsing_schema_name,
                                                                        :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test 'list_sql_history_snapshots with xhr: true' do
    instances = [nil, PanoramaConnection.instance_number]

    def do_test(ts, instance, groupby, parsing_schema_name)
      post '/dba_history/list_sql_history_snapshots', :params => {:format=>:html,
                                                                  :sql_id               => @@hist_sql_id,
                                                                  :instance             => instance,
                                                                  :parsing_schema_name  => parsing_schema_name,
                                                                  :groupby              => groupby,
                                                                  :time_selection_start => ts[:time_selection_start],
                                                                  :time_selection_end   => ts[:time_selection_end],
                                                                  :update_area          => :hugo }
      assert_response management_pack_license == :none ? :error : :success
    end

    if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
      Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
    else
      default_ts = {:time_selection_start => @time_selection_start, :time_selection_end =>@time_selection_end}

      instances.each do |instance|
        do_test(default_ts, instance, 'snap', nil)
      end

      [default_ts, {:time_selection_start => nil, :time_selection_end => nil} ].each do |ts|
        do_test(ts, nil, 'snap', nil)
      end

      [nil, 'snap', 'hour', 'day', 'week', 'month'].each do |groupby|
        do_test(default_ts, nil, groupby, nil)
      end

      [nil, @@hist_parsing_schema_name].each do |parsing_schema_name|
        do_test(default_ts, nil, 'snap', parsing_schema_name)
      end
    end
  end

  test 'sql_detail_historic with xhr: true' do
    instances = [nil, PanoramaConnection.instance_number]
    def do_test(instance, sql_id, parsing_schema_name)
      if sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
        Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
      else
        Rails.logger.info "####################### SQL-ID=#{sql_id} #{@@hist_sql_id} #{@@sga_sql_id_without_history} parsing_schema_name=#{parsing_schema_name}"
        post '/dba_history/list_sql_detail_historic', :params => {:format               => :html,
                                                                  :time_selection_start => @time_selection_start,
                                                                  :time_selection_end   => @time_selection_end,
                                                                  :sql_id               => sql_id,
                                                                  :instance             => instance,
                                                                  :parsing_schema_name  => parsing_schema_name,
                                                                  :update_area          => :hugo }

        if management_pack_license == :none
          assert_response :error
        else
          if @response.response_code != 302                                   # Redirect is o.k., because fired if not foung SQL exists in SGA
            assert_response :success
          end
        end
      end
    end

    instances.each do |instance|
      do_test(instance, @@hist_sql_id, nil)
    end

    [@@hist_sql_id, @@sga_sql_id_without_history, '1234567890123'].each do |sql_id|
      do_test(nil, sql_id, nil)
    end

    [nil, @@hist_parsing_schema_name].each do |parsing_schema_name|
      do_test(nil, @@hist_sql_id, parsing_schema_name)
    end
  end



  test "show_using_sqls_historic with xhr: true" do
    post '/dba_history/show_using_sqls_historic', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
                                    :ObjectName => "WRH$_sysmetric_history", :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_system_events_historic with xhr: true" do
    post '/dba_history/list_system_events_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>PanoramaConnection.instance_number, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_system_events_historic_detail with xhr: true" do
    post '/dba_history/list_system_events_historic_detail', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>PanoramaConnection.instance_number, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :event_id=>1, :event_name=>"Hugo", :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_system_statistics_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    [nil, 'MI', 'HH24', 'DD'].each do |tag|
      post '/dba_history/list_system_statistics_historic', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>instance, :full=>1, :verdichtung=>{tag: tag}, :update_area=>:hugo }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "list_system_statistics_historic_detail with xhr: true" do
    post '/dba_history/list_system_statistics_historic_detail', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>PanoramaConnection.instance_number,
         :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :stat_id=>1, :stat_name=>"Hugo", :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_sysmetric_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    # Evtl. als sysdba auf Test-DB Table loeschen wenn noetig: truncate table sys.WRH$_SYSMETRIC_HISTORY;

    if get_current_database[:host] == "ramm.osp-dd.de"                              # Nur auf DB ausführen wo Test-User ein ALTER-Grant auf sys.WRH$_SYSMETRIC_HISTORY hat
      puts "Prepare for Test: Executing ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space"
      ActiveRecord::Base.connection.execute("ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space")
    end

   ['SS', 'MI', 'HH24', 'DD'].each do |grouping|
     # Zeitabstand deutlich kuerzer fuer diesen Test
     time_selection_end  = Time.new
     time_selection_start  = time_selection_end-80          # x Sekunden Abstand
     time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
     time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

     post '/dba_history/list_sysmetric_historic', :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :detail=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response management_pack_license == :none ? :error : :success
     post '/dba_history/list_sysmetric_historic', :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>instance, :detail=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response management_pack_license == :none ? :error : :success
     post '/dba_history/list_sysmetric_historic', :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :summary=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response management_pack_license == :none ? :error : :success
     post '/dba_history/list_sysmetric_historic', :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>instance, :summary=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response management_pack_license == :none ? :error : :success
   end
  end

  test "mutex_statistics_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    sid = PanoramaConnection.sid
    if management_pack_license != :none
      [:Blocker, :Waiter, :Timeline].each do |submit_name|
        post '/dba_history/list_mutex_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>instance, submit_name=>"Hugo", :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
        post '/dba_history/list_mutex_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, submit_name=>"Hugo", :update_area=>:hugo }
        assert_response :success
      end

      get '/dba_history/list_mutex_statistics_historic_samples', :params => {:format=>:html, :instance=>instance, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
                                                                             :filter=>:Blocking_Session, :filter_session=>sid, :update_area=>:hugo }
      assert_response :success

      get '/dba_history/list_mutex_statistics_historic_samples', :params => {:format=>:html, :instance=>instance, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
                                                                             :filter=>:Requesting_Session, :filter_session=>sid, :update_area=>:hugo }
      assert_response :success
    end
  end

  test "latch_statistics_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    post '/dba_history/list_latch_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>instance }
    assert_response management_pack_license == :none ? :error : :success

    post '/dba_history/list_latch_statistics_historic_details', :params => {:format=>:html, :instance=>instance, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :latch_hash => 12313123, :latch_name=>"Hugo" }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "enqueue_statistics_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    post '/dba_history/list_enqueue_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_start, :instance=>instance }
    assert_response management_pack_license == :none ? :error : :success

    post '/dba_history/list_enqueue_statistics_historic_details', :params => {:format=>:html, :instance=>instance, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :eventno => 12313123, :reason=>"Hugo", :description=>"Hugo" }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_os_statistics_historic with xhr: true" do
    instance = PanoramaConnection.instance_number
    post '/dba_history/list_os_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_start }
    assert_response management_pack_license == :none ? :error : :success

    post '/dba_history/list_os_statistics_historic', :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_start, :instance=>instance }
    assert_response management_pack_license == :none ? :error : :success
  end


  test "list_compare_sql_area_historic with xhr: true" do
    if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
      Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
    else
      tag1 = Time.new
      post '/dba_history/list_compare_sql_area_historic', :params => {:format=>:html, :instance=>PanoramaConnection.instance_number, :filter=>"Hugo", :sql_id=>@@hist_sql_id, :minProzDiff=>50,
                                                                      :tag1=> tag1.strftime("%d.%m.%Y"), :tag2=>(tag1-86400).strftime("%d.%m.%Y") }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "genuine_oracle_reports with xhr: true" do
    if get_db_version['18'] and PanoramaConnection.edition == :express
      Rails.logger.debug "don't test this for 18.4 XE because it will raise ORA-13716: Diagnostic Package-Lizenz ist zur Verwendung dieses Features erforderlich."
    else
      instance = PanoramaConnection.instance_number
      instances = [nil, PanoramaConnection.instance_number]
      def management_pack_license_ok?
        return false if @autonomous_database                  # Only admin is allowed to execute this functions in autonomous DB, therefore call of DBMS_WORKLOAD_REPOSITORY raises error for panorama_test
        [:diagnostics_pack, :diagnostics_and_tuning_pack].include? management_pack_license
      end

      if get_db_version >= '12.1'
        instances.each do |instance|
          # download_oracle_com_reachable: simulate test from previous dialog
          begin
            post '/dba_history/list_performance_hub_report', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance, download_oracle_com_reachable: true }
            assert_response management_pack_license_ok? ? :success : :error
          rescue Exception => e
            # TODO: rescue also catches Minitest::Assertion Expected response to be a <2XX: success>, but was a <500: Surely hasn't been expected
            msg = "DbaHistoryControllerTest.genuine_oracle_reports: #{e.class} catched  #{e.message} but not raised for breaking test"
            Rails.logger.info msg
            puts msg
          end
        end
      end

      post '/dba_history/list_awr_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance }
      assert_response management_pack_license_ok? ? :success : :error

      post '/dba_history/list_awr_global_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end }
      assert_response management_pack_license_ok? ? :success : :error

      post '/dba_history/list_awr_global_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance }
      assert_response management_pack_license_ok? ? :success : :error

      post '/dba_history/list_ash_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance }
      assert_response management_pack_license_ok? ? :success : :error

      post '/dba_history/list_ash_global_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end }
      assert_response management_pack_license_ok? ? :success : :error

      post '/dba_history/list_ash_global_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance }
      assert_response management_pack_license_ok? ? :success : :error

      if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
        Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
      else
        post '/dba_history/list_awr_sql_report_html', :params => {:format=>:html, :time_selection_start =>@time_selection_between, :time_selection_end =>@time_selection_end, :instance=>instance, :sql_id=>@@hist_sql_id }
        assert_response management_pack_license_ok? ? :success : :error
      end
    end
  end

  test "generate_baseline_creation with xhr: true" do
    if [:diagnostics_pack, :diagnostics_and_tuning_pack].include? management_pack_license
      if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
        Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
      else
        post '/dba_history/generate_baseline_creation', :params => {:format=>:html, :sql_id=>@@hist_sql_id, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :plan_hash_value=>1234567, :update_area=>:hugo }
        assert_response :success
      end
    end
  end

  test "select_plan_hash_value_for_baseline with xhr: true" do
    if @@hist_sql_id.nil?                                                        # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
      Rails.logger.info 'DBA_Hist_SQLStat is empty, function not testable. This is the case for 18.4.0-XE'
    else
      post '/dba_history/select_plan_hash_value_for_baseline', :params => {:format=>:html, :sql_id=>@@hist_sql_id, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :update_area=>:hugo }
      assert_response [:diagnostics_pack, :diagnostics_and_tuning_pack, :panorama_sampler].include?(management_pack_license) ? :success : :error
    end
  end

  test "list_resource_limits_historic with xhr: true" do
    instances = [nil, PanoramaConnection.instance_number]
    if management_pack_license != :none
      sql_select_all("SELECT DISTINCT Resource_Name FROM DBA_Hist_Resource_Limit").each do |resname_rec|
        instances.each do |instance|
          post '/dba_history/list_resource_limits_historic', params: {
              format:               :html,
              instance:             instance,
              resource_name:        resname_rec.resource_name,
              update_area:          :hugo
          }
          assert_response :success
        end
      end
    end
  end

  test "list_sql_monitor_reports with xhr: true" do
    if get_db_version >= '11.1' && management_pack_license == :diagnostics_and_tuning_pack && !@@hist_sql_id.nil?  # 18c XE does not sample DBA_HIST_SQLSTAT during AWR-snapshots
      [nil,PanoramaConnection.instance_number].each do |instance |
        [{sql_id: @@hist_sql_id}, {sid: 1, serial_no: 2}].each do |p|
          post '/dba_history/list_sql_monitor_reports', params: {format: :html, instance: instance, sql_id: p[:sql_id], sid: p[:sid], serial_no: p[:serial_no],
                                                                 time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, update_area: :hugo }
          assert_response management_pack_license == :none ? :error : :success
        end
      end
    end
  end

  test "list_awr_sql_monitor_report_html with xhr: true" do
    instance = PanoramaConnection.instance_number
    if get_db_version >= '11.1' && management_pack_license == :diagnostics_and_tuning_pack
      origins = ['GV$SQL_MONITOR']

      # DBA_Hist_Reports available beginning with 12.1
      if get_db_version >= '12.1'
        origins << 'DBA_Hist_Reports'
        report_id_hist = sql_select_one "SELECT MAX(report_ID) FROM DBA_HIST_REPORTS"
        report_id_hist = 1 if report_id_hist.nil?                               # Use fake ID if no real hit exists
      end

      origins.each do |origin|
        post '/dba_history/list_awr_sql_monitor_report_html', params: {format: :html,
                                                                       report_id:             origin == 'GV$SQL_MONITOR' ? 0 : report_id_hist,
                                                                       instance:              instance,
                                                                       sid:                   1,
                                                                       serial_no:              1,
                                                                       sql_id:                '1',
                                                                       sql_exec_id:           1,
                                                                       origin:                origin,
                                                                       update_area: :hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

end
