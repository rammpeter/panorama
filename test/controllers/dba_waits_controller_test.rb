# encoding: utf-8
require 'test_helper'

class DbaWaitsControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context
    initialize_min_max_snap_id_and_times
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "show_system_events with xhr: true" do
    post '/dba_waits/show_system_events', :params => {:format=>:html, :sample_length=>"1", :filter=>"", :suppress_idle_waits=>"1", :update_area=>:hugo }
    assert_response :success
  end

  test "show_session_waits with xhr: true" do
    post '/dba_waits/show_session_waits', :params => {:format=>:html, :instance=>PanoramaConnection.instance_number, :event=>"Hugo", :update_area=>:hugo }
    assert_response :success
  end


  test "gc_request_latency with xhr: true" do
    get '/dba_waits/gc_request_latency', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "list_gc_request_latency_history with xhr: true" do
    get '/dba_waits/list_gc_request_latency_history', :params => {:format=>:html, :instance=>PanoramaConnection.instance_number, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "show_ges_blocking_enqueue with xhr: true" do
    get  '/dba_waits/show_ges_blocking_enqueue', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "drm_history with xhr: true" do
    instance = PanoramaConnection.instance_number
    [:second, :minute, :hour, :day, :week].each do |time_groupby|
      post  '/dba_waits/list_drm_historic', params: {format: :html, commit: 'Show event history', time_groupby: time_groupby, time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, policy_event: 'initiate_affinity', update_area: :hugo }
      assert_response :success
    end

    post  '/dba_waits/list_drm_historic', params: {format: :html, commit: 'Show objects with events', time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, policy_event: 'initiate_affinity', update_area: :hugo }
    assert_response :success

    [[nil,nil], [@time_selection_start, @time_selection_end]].each do |times|
      [nil, instance].each do |target_instance|
        [[nil, nil, nil], ['sys', 'obj$', nil], ['sys', 'dummy', 'dummy']].each do |objects|
          post  '/dba_waits/list_drm_historic_single_records', params: {format: :html, target_instance: target_instance, time_selection_start: times[0], time_selection_end: times[1], owner: objects[0], object_name: objects[1], subobject_name: objects[2], policy_event: 'initiate_affinity', update_area: :hugo }
          assert_response :success
        end
      end
    end
  end


end
