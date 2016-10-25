# encoding: utf-8
require 'test_helper'

module Panorama
class DbaWaitsControllerTest < ActionController::TestCase
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  test "show_system_events" do
    post :show_system_events, :params => {:format=>:js, :sample_length=>"1", :filter=>"", :suppress_idle_waits=>"1" }
    assert_response :success
  end

  test "show_session_waits" do
    post :show_session_waits, :params => {:format=>:js, :instance=>1, :event=>"Hugo" }
    assert_response :success
  end


  test "gc_request_latency" do
    get :gc_request_latency, :params => {:format=>:js }
    assert_response :success
  end

  test "list_gc_request_latency_history" do
    get :list_gc_request_latency_history, :params => {:format=>:js, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
    assert_response :success
  end

  test "show_ges_blocking_enqueue" do
    get  :show_ges_blocking_enqueue, :params => {:format=>:js }
    assert_response :success
  end

end
end