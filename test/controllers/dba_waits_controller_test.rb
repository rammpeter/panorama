# encoding: utf-8
require 'test_helper'

class DbaWaitsControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

  end

  test "show_system_events" do
    post :show_system_events, :format=>:js, :sample_length=>"1", :filter=>"", :suppress_idle_waits=>"1"
    assert_response :success
  end

  test "show_session_waits" do
    post :show_session_waits, :format=>:js, :instance=>1, :event=>"Hugo"
    assert_response :success
  end


  test "gc_request_latency" do
    xhr :get, :gc_request_latency, :format=>:js
    assert_response :success
  end

  test "list_gc_request_latency_history" do
    xhr :get, :list_gc_request_latency_history, :format=>:js, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
    assert_response :success
  end

  test "show_ges_blocking_enqueue" do
    xhr :get,  :show_ges_blocking_enqueue, :format=>:js
    assert_response :success
  end

  test "show_session_wait_object" do
    xhr :get, :show_session_wait_object,  :format=>:js, :instance=>1, :event=>"Hugo"
    assert_response :success
  end

end
