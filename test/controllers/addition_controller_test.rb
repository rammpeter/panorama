# encoding: utf-8
require 'test_helper'

class AdditionControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}
    #connect_oracle_db     # Nutzem Oracle-DB für Selektion
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

  end

  test "blocking_locks_history" do
    post :list_blocking_locks_history, :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>"10",
         :commit_table => "1"  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post :list_blocking_locks_history, :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>"10",
         :commit_hierarchy => "1"  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post :list_blocking_locks_history_hierarchy_detail, :format=>:js,
         :blocking_instance => 1,
         :blocking_sid => 1,
         :blocking_serialno => 1,
         :snapshotts =>"01.01.2011 00:00:00"  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end


  test "db_cache_historic" do
    post :list_db_cache_historic, :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :instance  => "1",
         :maxResultCount => 100  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    xhr :get, :list_db_cache_historic_detail, :format=>:js,
        :time_selection_start =>"01.01.2011 00:00",
        :time_selection_end =>"01.01.2011 01:00",
        :instance  => 1,
        :owner     => "sysp",
        :name      => "Employee"  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    xhr :get, :list_db_cache_historic_snap, :format=>:js,
        :snapshotts =>"01.01.2011 00:00",
        :instance  => "1"  if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "object_increase" do
    xhr :get, :show_object_increase, :format=>:js    if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    def do_test_list_object_increase(submit_tag, gruppierung_tag)
      post :list_object_increase,  {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                    :tablespace=>{"name"=>"[Alle]"}, "schema"=>{"name"=>"[Alle]"}, :gruppierung=>{"tag"=>gruppierung_tag} }.merge(submit_tag)
      assert_response :success
    end

    def do_test_list_object_increase_outer(gruppierung_tag)
      do_test_list_object_increase({:detail=>1},   gruppierung_tag)
      do_test_list_object_increase({:timeline=>1}, gruppierung_tag)
    end

    do_test_list_object_increase_outer("Segment_Type")
    do_test_list_object_increase_outer("Tablespace_Name")
    do_test_list_object_increase_outer("Owner")

    xhr :get, :list_object_increase_object_timeline, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :owner=>'Hugo', :name=>'Hugo'
    assert_response :success
  end


end
