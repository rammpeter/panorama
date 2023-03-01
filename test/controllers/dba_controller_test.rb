# encoding: utf-8
require 'test_helper'
include ActionView::Helpers::TranslationHelper
#include ActionDispatch::Http::URL

class DbaControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times
    @autonomous = PanoramaConnection.autonomous_database?
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "redologs with xhr: true"       do
    instance  = PanoramaConnection.instance_number

    post  '/dba/show_redologs', :params => {:format=>:html, :update_area=>:hugo, instance: instance }
    assert_response :success

    post  '/dba/list_redolog_members', :params => {:format=>:html, :update_area=>:hugo, instance: instance, group: 1 }
    assert_response :success

    [:single, :second, :second_10, :minute, :minute_10, :hour, :day, :week].each do |time_groupby|
      post '/dba/list_redologs_log_history', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, time_groupby: time_groupby, :update_area=>:hugo }
      assert_response :success
    end
    post '/dba/list_redologs_log_history', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, time_groupby: :single, instance: instance, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_redologs_log_history', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, time_groupby: :single, instance: instance, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_redologs_historic', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
    post '/dba/list_redologs_historic', :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>instance, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "locks with xhr: true"       do
    DBA_KGLLOCK_exists = sql_select_one("select COUNT(*) from dba_views where view_name='DBA_KGLLOCK' ")

    post '/dba/list_dml_locks', :params => {:format=>:html }
    assert_response :success

    if DBA_KGLLOCK_exists > 0      # Nur Testen wenn View auch existiert
      post '/dba/list_ddl_locks', params: {format: :html}
      assert_response :success
    end

    post '/dba/list_blocking_dml_locks', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_pending_two_phase_commits', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_2pc_neighbors', :params => {:format=>:html, local_tran_id: '100', :update_area=>:hugo }
    assert_response :success

  end

  test "list_sessions with xhr: true" do
    instance  = PanoramaConnection.instance_number

    post '/dba/list_sessions', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_sessions', :params => {:format=>:html, :onlyActive=>1, :showOnlyUser=>1, :instance=>instance, :filter=>'hugo', :object_owner=>'SYS', :object_name=>'HUGO', :update_area=>:hugo }
    assert_response :success

    post '/dba/list_sessions', :params => {:format=>:html, :onlyActive=>1, :showOnlyUser=>1, :instance=>instance, :filter=>'hugo', :object_owner=>'SYS', :object_name=>'HUGO', object_type: 'TABLE', :update_area=>:hugo }
    assert_response :success
  end

  test "show_session_detail with xhr: true" do
    dbid      = PanoramaConnection.login_container_dbid
    instance  = PanoramaConnection.instance_number
    pid       = PanoramaConnection.pid
    saddr     = PanoramaConnection.saddr
    sid       = PanoramaConnection.sid
    serial_no = PanoramaConnection.serial_no

    get  '/dba/show_session_detail', :params => {:format=>:html, :instance=>instance, :sid=>sid, :serial_no=>serial_no, :update_area=>:hugo }
    assert_response :success

    # Access on gv$Diag_Trace_File in autonomous DB leads cancels the connection
    if get_db_version >= '12.2' && !@autonomous
      post  '/dba/render_session_detail_tracefile_button', :params => {:format=>:html, :instance=>instance, :pid=>pid, :update_area=>:hugo }
      assert_response :success
    end

    post  '/dba/render_session_detail_sql_monitor', params: {format: :html, dbid: dbid, instance: instance, sid: sid, serial_no: serial_no, time_selection_start: localeDateTime(Time.now-200, :minutes), time_selection_end: localeDateTime(Time.now, :minutes), :update_area=>:hugo }
    assert_response :success

    post '/dba/show_session_details_waits', :params => {:format=>:html, :instance=>instance, :sid=>sid, :serial_no=>serial_no, :update_area=>:hugo }
    assert_response :success

    post '/dba/show_session_details_locks', :params => {:format=>:html, :instance=>instance, :sid=>sid, :serial_no=>serial_no, :update_area=>:hugo }
    assert_response :success

    post '/dba/show_session_details_temp', :params => {:format=>:html, :instance=>instance, :sid=>sid, :serial_no=>serial_no, :saddr=>saddr, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_open_cursor_per_session', :params => {:format=>:html, :instance=>instance, :sid=>sid, :serial_no=>serial_no, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_accessed_objects', :params => {:format=>:html, :instance=>instance, :sid=>sid, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_session_statistic', :params => {:format=>:html, :instance=>instance, :sid=>sid, :update_area=>:hugo }
    assert_response :success

    post '/dba/list_session_optimizer_environment', :params => {:format=>:html, :instance=>instance, :sid=>sid, :update_area=>:hugo }
    assert_response :success

    post '/dba/show_session_details_waits_object', :params => {:format=>:html, :event=>"db file sequential read", :update_area=>:hugo }
    assert_response :success
  end

  test "show_session_waits with xhr: true" do
    get  '/dba/show_session_waits', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
    #test "show_application" do get  :show_application, :applexec_id => "0";  assert_response :success; end
    #test "show_segment_statistics" do get  :show_segment_statistics;  assert_response :success; end
  end

  test "list_waits_per_event with xhr: true" do
    instance  = PanoramaConnection.instance_number
    get '/dba/list_waits_per_event', :params => {:format=>:html, :event=>"db file sequential read", :instance=>instance, :update_area=>"hugo" }
    assert_response :success
  end

  test "segment_stat with xhr: true"       do
    get  '/dba/segment_stat', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "list_server_logs with xhr: true" do
    # Access cancels the DB session in autonomous DB
    unless PanoramaConnection.autonomous_database?
      [
        {tag: 'SS',   log_type: 'all',      button: :group,   filter: nil},
        {tag: 'MI',   log_type: 'tnslsnr',  button: :detail,  filter: 'hugo' },
        {tag: 'HH24', log_type: 'rdbms',    button: :group,   filter: 'erster|zweiter' },
        {tag: 'DD',   log_type: 'asm',      button: :detail,  filter: nil }
      ].each do |variant|
        post '/dba/list_server_logs', :params => {format:               :html,
                                                  time_selection_start: @time_selection_start,
                                                  time_selection_end:   @time_selection_end,
                                                  log_type:             variant[:log_type],
                                                  verdichtung:          {tag: variant[:tag]},
                                                  button:               variant[:button],
                                                  incl_filter:          variant[:filter],
                                                  excl_filter:          variant[:filter],
                                                  :update_area          => :hugo
        }
        assert_response(:success)
      end
    end
  end

  test 'show_rowid_details with xhr: true' do

    # Readable table with primary key and records
    data_object = sql_select_first_row "SELECT o.Data_Object_ID, t.Owner, t.Table_Name
                                        FROM   All_Tables t
                                        JOIN   All_Constraints c ON c.Owner = t.Owner AND c.Table_Name = t.Table_Name AND c.Constraint_Type = 'P'
                                        JOIN   DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name
                                        WHERE  t.Cluster_Name IS NULL
                                        AND    t.IOT_Name IS NULL
                                        AND    t.Table_Name NOT LIKE '%$%'
                                        AND    t.Num_Rows > 0
                                        AND    o.Data_Object_ID IS NOT NULL
                                        AND    RowNum < 2
                                        "

    raise "No readable table with num_rows > 0 found in database" if data_object.nil?

    waitingforrowid = sql_select_one "SELECT RowIDTOChar(RowID) FROM #{data_object.owner}.#{data_object.table_name} WHERE RowNum < 2"

    post '/dba/show_rowid_details', :params => {format: :html, data_object_id: data_object.data_object_id, waitingforrowid: waitingforrowid, update_area: :hugo }
    assert_response :success

  end

  test 'trace_files with xhr: true' do
    # Access on trace files leads to hours of runtime in autonomous DBK
    if get_db_version >= '12.2' && !PanoramaConnection.autonomous_database?
      instance  = PanoramaConnection.instance_number
      trace_file = nil
      trace_file = sql_select_first_row "SELECT Inst_ID, ADR_Home, Trace_Filename, Con_ID FROM gv$Diag_Trace_File"

      [nil, 'hugo', 'erster|zweiter'].each do |filter|
        post '/dba/list_trace_files', :params => {format:               :html,
                                                  time_selection_start: @time_selection_start,
                                                  time_selection_end:   @time_selection_end,
                                                  filename_incl_filter: filter,
                                                  filename_excl_filter: filter,
                                                  content_incl_filter:  filter,
                                                  content_excl_filter:  filter,
                                                  update_area:          :hugo
        }
        assert_response :success

        if !trace_file.nil?
          [0,1].each do |dont_show_sys|
            [0,1].each do |dont_show_stat|
              post '/dba/list_trace_file_content', params: {format: :html, instance: trace_file.inst_id, adr_home: trace_file.adr_home,
                                                            trace_filename: trace_file.trace_filename, con_id: trace_file.con_id,
                                                            dont_show_sys: dont_show_sys, dont_show_stat: dont_show_stat,
                                                            max_trace_file_lines_to_show: 100,
                                                            first_or_last_lines: dont_show_sys==0 ? 'first' : 'last',
                                                            update_area: :hugo }
              assert_response :success
            end
          end
        end

        post '/dba/list_trace_file_content', params: {format: :html, instance: instance, adr_home: 'hugo', trace_filename: 'hugo', con_id: 1, update_area: :hugo }
        assert_response :success
      end
    end
  end


end
