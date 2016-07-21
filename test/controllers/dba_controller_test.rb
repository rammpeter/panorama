# encoding: utf-8
require 'test_helper'
include ActionView::Helpers::TranslationHelper
#include ActionDispatch::Http::URL

class DbaControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  test "dba"       do
    xhr :get,  :show_redologs, :format=>:js
    assert_response :success

    post :list_redologs_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end
    assert_response :success
    post :list_redologs_historic, :format=>:js,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1
    assert_response :success

    post :list_dml_locks, :format=>:js;  assert_response :success


    if sql_select_one("select COUNT(*) from dba_views where view_name='DBA_KGLLOCK' ") > 0      # Nur Testen wenn View auch existiert
      post :list_ddl_locks, :format=>:js;  assert_response :success
    end

    post :list_blocking_dml_locks, :format=>:js
    assert_response :success

    post :list_sessions, :format=>:js;
    assert_response :success

    post :list_sessions, :format=>:js, :onlyActive=>1, :showOnlyUser=>1, :instance=>1, :filter=>'hugo', :object_owner=>'SYS', :object_name=>'HUGO';
    assert_response :success

    xhr :get, :list_waits_per_event, :format=>:js, :event=>"db file sequential read", :instance=>"1", :update_area=>"hugo";
    assert_response :success

    xhr :get,  :show_session_detail, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_waits, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_locks, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :show_session_details_temp, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :saddr=>@saddr
    assert_response :success

    post :list_open_cursor_per_session, :format=>:js, :instance=>@instance, :sid=>@sid, :serialno=>@serialno
    assert_response :success

    post :list_accessed_objects, :format=>:js, :instance=>@instance, :sid=>@sid
    assert_response :success

    post :list_session_statistic, :format=>:js, :instance=>@instance, :sid=>@sid
    assert_response :success

    post :list_session_optimizer_environment, :format=>:js, :instance=>@instance, :sid=>@sid
    assert_response :success

    post :show_session_details_waits_object, :format=>:js, :event=>"db file sequential read"
    assert_response :success

    post  :show_explain_plan, :format=>:js, :statement => "SELECT SYSDATE FROM DUAL"
    assert_response :success

    xhr :get,  :show_session_waits, :format=>:js
    assert_response :success
    #test "show_application" do get  :show_application, :applexec_id => "0";  assert_response :success; end
    #test "show_segment_statistics" do get  :show_segment_statistics;  assert_response :success; end

    xhr :get,  :segment_stat, :format=>:js
    assert_response :success

#    xhr :get, :oracle_parameter, :format=>:js
#    assert_response :success
  end




end
