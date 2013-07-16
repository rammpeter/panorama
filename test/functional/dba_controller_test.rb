# encoding: utf-8
require 'test_helper'

class DbaControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end


  test "dba"       do
    get  :show_redologs, :format=>:js
    assert_response :success

    post :list_redologs_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end
    assert_response :success
    post :list_redologs_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1
    assert_response :success

    post :list_dml_locks, :format=>:js;  assert_response :success
    post :list_ddl_locks, :format=>:js;  assert_response :success

    post :list_blocking_dml_locks, :format=>:js
    assert_response :success

    post :list_sessions, :format=>:js;   assert_response :success

    get :list_waits_per_event, :format=>:js, :event=>"db file sequential read", :instance=>"1", :update_area=>"hugo";
    assert_response :success

    get  :show_session_detail, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_waits, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_locks, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_temp, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :saddr=>@saddr
    assert_response :success

    post :list_open_cursor_per_session, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :list_session_statistic, :format=>:js, :instance=>@instance, :sid=>@sid
    assert_response :success

    post :show_session_details_waits_object, :format=>:js, :event=>"db file sequential read"
    assert_response :success

    get  :datafile_usage, :format=>:js
    assert_response :success

    get  :used_objects, :format=>:js
    assert_response :success

    post  :show_explain_plan, :format=>:js, :statement => "SELECT SYSDATE FROM DUAL"
    assert_response :success

    get  :show_session_waits, :format=>:js
    assert_response :success
    #test "show_application" do get  :show_application, :applexec_id => "0";  assert_response :success; end
    #test "show_segment_statistics" do get  :show_segment_statistics;  assert_response :success; end

    get  :segment_stat, :format=>:js
    assert_response :success
  end


end
