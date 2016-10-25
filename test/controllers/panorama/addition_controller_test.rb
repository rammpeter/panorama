# encoding: utf-8
require 'test_helper'


module Panorama
class AdditionControllerTest < ActionController::TestCase
  include Panorama::MenuHelper
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
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

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end

  test "blocking_locks_history" do
    post :list_blocking_locks_history, :params => { :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>"10",
         :commit_table => "1" } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post :list_blocking_locks_history, :params => { :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>'10',
         :commit_hierarchy => "1" } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post :list_blocking_locks_history_hierarchy_detail, :params => { :format=>:js,
         :blocking_instance => 1,
         :blocking_sid => 1,
         :blocking_serialno => 1,
         :snapshotts =>"01.01.2011 00:00:00" } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end


  test "db_cache_historic" do
    post :list_db_cache_historic, :params => { :format=>:js,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :instance  => "1",
         :maxResultCount => 100 } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    get :list_db_cache_historic_detail, :params => { :format=>:js,
        :time_selection_start =>"01.01.2011 00:00",
        :time_selection_end =>"01.01.2011 01:00",
        :instance  => 1,
        :owner     => "sysp",
        :name      => "Employee" } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    get :list_db_cache_historic_snap, :params => { :format=>:js,
        :snapshotts =>"01.01.2011 00:00",
        :instance  => "1" } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "object_increase" do
    get :show_object_increase, :format=>:js    if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    ['Segment_Type', 'Tablespace_Name', 'Owner'].each do |gruppierung_tag|
      [{:detail=>1}, {:timeline=>1}].each do |submit_tag|
        if showObjectIncrease                                                     # Nur Testen wenn Tabelle(n) auch existieren
          post :list_object_increase,  {:params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>"[Alle]"}, "schema"=>{"name"=>"[Alle]"}, :gruppierung=>{"tag"=>gruppierung_tag} }.merge(submit_tag)
          }
          assert_response :success

          post :list_object_increase,  {:params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>'USERS'}, "schema"=>{"name"=>"[Alle]"}, :gruppierung=>{"tag"=>gruppierung_tag} }.merge(submit_tag)
          }
          assert_response :success

          post :list_object_increase,  {:params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>"[Alle]"}, "schema"=>{"name"=>'SYS'}, :gruppierung=>{"tag"=>gruppierung_tag} }.merge(submit_tag)
          }
          assert_response :success
        end
      end
    end

    get :list_object_increase_object_timeline, :params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :owner=>'Hugo', :name=>'Hugo' }
    assert_response :success
  end


end
end
