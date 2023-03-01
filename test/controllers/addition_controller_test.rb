# encoding: utf-8
require 'test_helper'

# Execution of WorkerThreadTest is precondition for successful run (initial table creation must be executed before this test)

class AdditionControllerTest < ActionDispatch::IntegrationTest
  include MenuHelper
  include AdditionHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    #connect_oracle_db     # Nutzem Oracle-DB für Selektion
    @ttime_selection_end    = Time.new
    @ttime_selection_start  = @ttime_selection_end-10000          # x Sekunden Abstand
    @time_selection_end     = @ttime_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start   = @ttime_selection_start.strftime("%d.%m.%Y %H:%M")
    @gather_date            = @ttime_selection_end.strftime("%d.%m.%Y %H:%M:%S")

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    @instance = PanoramaConnection.instance_number
    set_current_database(get_current_database.merge( {panorama_sampler_schema: get_current_database[:user]} ))    # Ensure Panorama's tables are searched here
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "blocking_locks_history with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :BLOCKING_LOCKS)         # Ensure that structures are existing

    post '/addition/list_blocking_locks_history', :params => { :format=>:html,
                                                               :time_selection_start =>"01.01.2011 00:00",
                                                               :time_selection_end =>"01.01.2011 01:00",
                                                               :timeslice =>"10",
                                                               min_wait_ms: 0,
                                                               :commit_table => "1",
                                                               :update_area=>:hugo } if get_db_version >= '11.2'
    assert_response :success

    post '/addition/list_blocking_locks_history', :params => { :format=>:html,
                                                               :time_selection_start =>"01.01.2011 00:00",
                                                               :time_selection_end =>"01.01.2011 01:00",
                                                               :timeslice =>'10',
                                                               min_wait_ms: 0,
                                                               :commit_hierarchy => "1",
                                                               :update_area=>:hugo } if get_db_version >= '11.2'
    assert_response :success

    post '/addition/list_blocking_locks_history_hierarchy_detail', :params => { :format=>:html,
         :blocking_instance => @instance,
         :blocking_sid => 1,
         :blocking_serial_no => 1,
         :snapshot_timestamp =>"01.01.2011 00:00:00",
         :update_area=>:hugo } if get_db_version >= '11.2'
    assert_response :success
  end


  test "db_cache_historic with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :CACHE_OBJECTS)         # Ensure that structures are existing

    [nil, 1].each do |instance|
      [nil, 1].each do |show_partitions|
        post '/addition/list_db_cache_historic', :params => { :format               => :html,
                                                              :time_selection_start => "01.01.2011 00:00",
                                                              :time_selection_end   => "01.01.2011 01:00",
                                                              :instance             => instance,
                                                              :maxResultCount       => 100,
                                                              :show_partitions      => show_partitions,
                                                              :update_area          => :hugo } if get_db_version >= '11.2'
        assert_response :success
      end

    end

    [nil, 1].each do |show_partitions|
      get '/addition/list_db_cache_historic_detail', :params => { :format               =>:html,
                                                                  :time_selection_start =>"01.01.2011 00:00",
                                                                  :time_selection_end   =>"01.01.2011 01:00",
                                                                  :instance             => @instance,
                                                                  :owner                => "sysp",
                                                                  :name                 => "Employee",
                                                                  show_partitions:      show_partitions,
                                                                  partitionname:        show_partitions ? 'PART1' : nil,
                                                                  :update_area          => :hugo  } if get_db_version >= '11.2'
      assert_response :success

    end

    [nil, 1].each do |instance|
      [nil, 1].each do |show_partitions|
        post '/addition/list_db_cache_historic_timeline', :params => {  format:               :html,
                                                                        time_selection_start: "01.01.2011 00:00",
                                                                        time_selection_end:   "01.01.2011 01:00",
                                                                        :instance             => instance,
                                                                        :show_partitions      => show_partitions,
                                                                        :update_area          => :hugo } if get_db_version >= '11.2'
        assert_response :success

      end
    end

    [nil,1].each do |show_partitions|
      get '/addition/list_db_cache_historic_snap', :params => { :format=>:html,
                                                                :snapshot_timestamp =>"01.01.2011 00:00",
                                                                :instance  => @instance,
                                                                show_partitions: show_partitions,
                                                                :update_area=>:hugo } if get_db_version >= '11.2'
      assert_response :success
    end

  end

  test "object_increase with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :OBJECT_SIZE)         # Ensure that structures are existing

    @sampler_config_entry                                  = get_current_database
    @sampler_config_entry[:owner]                          = @sampler_config_entry[:user] # Default

    # Create test data
    PanoramaSamplerSampling.do_sampling(PanoramaSamplerConfig.new(@sampler_config_entry), @ttime_selection_start, :OBJECT_SIZE)
    PanoramaSamplerSampling.do_sampling(PanoramaSamplerConfig.new(@sampler_config_entry), @ttime_selection_end,   :OBJECT_SIZE)

    [all_dropdown_selector_name, 'SYSTEM'].each do |tablespace|
      [all_dropdown_selector_name, 'SYS'].each do |schema|

        [nil, 1].each do |row_count_changes|
          post '/addition/list_object_increase', params: { format: :html,
                                                           time_selection_start: @time_selection_start,
                                                           time_selection_end: @time_selection_end,
                                                           row_count_changes: row_count_changes,
                                                           tablespace: {name: tablespace},
                                                           schema: {name: schema},
                                                           detail: 1,
                                                           update_area: :hugo
          }
          assert_response :success
        end

        ['Segment_Type', 'Tablespace_Name', 'Owner'].each do |gruppierung_tag|
          post '/addition/list_object_increase',  :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                                                :tablespace=>{"name"=>tablespace}, "schema"=>{"name"=>schema}, :gruppierung=>{"tag"=>gruppierung_tag}, timeline: 1, :update_area=>:hugo }
          assert_response :success

          post '/addition/list_object_increase_objects_per_time',  :params => { :format=>:html, gather_date: @gather_date, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                                                Tablespace_Name: tablespace, Owner: schema, gruppierung_tag => 'Hugo', timeline: 1, :update_area=>:hugo }
          assert_response :success
        end
      end
    end

    get '/addition/show_object_increase',  :params => {:format=>:html}    if get_db_version >= '11.2'
    assert_response :success

    get '/addition/list_object_increase_object_timeline', :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :owner=>'Hugo', :name=>'Hugo', :update_area=>:hugo  }
    assert_response :success
  end

  test "exec_worksheet_sql with xhr: true" do
    post '/addition/exec_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL', update_area: :hugo }
    assert_response :success

    # Should render dialog for binds
    post '/addition/exec_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL WHERE 1=:A1', update_area: :hugo }
    assert_response :success

    # Should execute with values for binds
    worksheet_bind_types.each do |key, value|
      post '/addition/exec_worksheet_sql', params: {format: :html, sql_statement: "SELECT /* #{key} */ 'VALUE_MATCHED '||SYSDATE result FROM DUAL WHERE #{value[:test_sql_value]} = :A1", alias_A1: value[:test_bind_value], type_A1: key, update_area: :hugo }
      assert_response :success
      assert @response.body['VALUE_MATCHED'] != nil, "Response should contain one result line from SQL with matching filter condition"
    end
  end

  test "explain_worksheet_sql with xhr: true" do
    post '/addition/explain_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL', update_area: :hugo }
    assert_response :success

    # Should render dialog for binds
    post '/addition/explain_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL WHERE 1=:A1', update_area: :hugo }
    assert_response :success

    # Should explain with values for binds
    worksheet_bind_types.each do |key, value|
      post '/addition/explain_worksheet_sql', params: {format: :html, sql_statement: "SELECT /* #{key} */ SYSDATE FROM DUAL WHERE #{value[:test_sql_value]} = :A1", alias_A1: value[:test_bind_value], type_A1: key, update_area: :hugo }
      assert_response :success
    end
  end

  test "exec_recall_params with xhr: true" do
    post '/addition/exec_recall_params', params: {format: :html, parameter_info: "{\"action\":\"list_session_statistic_historic\",\"controller\":\"active_session_history\",\"filter\":\"\",\"groupby\":\"Event\",\"instance\":\"\",\"method\":\"post\",\"time_selection_end\":\"#{@time_selection_end}\",\"time_selection_start\":\"#{@time_selection_start}\"}"}
    assert_response :redirect
  end



end
