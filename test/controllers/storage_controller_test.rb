# encoding: utf-8
require 'test_helper'

class StorageControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context
    initialize_min_max_snap_id_and_times
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    assert_nothing_raised do
      call_controllers_menu_entries_with_actions
    end
  end

  test "storage_controller with xhr: true" do

    get '/storage/datafile_usage', :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success

    post '/storage/list_materialized_view_action', :params => { :format=>:html, :registered_mviews => "Hugo", :update_area=>:hugo  }
    assert_response :success

    post '/storage/list_materialized_view_action', :params => { :format=>:html, :all_mviews => "Hugo", :update_area=>:hugo  }
    assert_response :success

    [nil, 'SYS'].each do |log_owner|
      [nil, 'LOG'].each do |log_name|
        [nil, 'MASTER'].each do |master|
          post '/storage/list_materialized_view_action', :params => { :format=>:html, :mview_logs => "Hugo", log_owner: log_owner, log_name: log_name, master: master, :update_area=>:hugo  }
          assert_response :success
        end
      end
    end

    get '/storage/list_registered_materialized_views', :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_registered_materialized_views', :params => { :format=>:html, :snapshot_id=>1, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_all_materialized_views', :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_all_materialized_views', :params => { :format=>:html, :owner=>"Hugo", :name=>"Hugo", :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_materialized_view_logs', :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_materialized_view_logs', :params => { :format=>:html, :log_owner=>"Hugo", :log_name=>"Hugo", :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_snapshot_logs',  :params => { :format=>:html, :snapshot_id=>1, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_snapshot_logs',  :params => { :format=>:html,  :log_owner=>"Hugo", :log_name=>"Hugo", :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_registered_mview_query_text', :params => { :format=>:html, :mview_id=>1, :update_area=>:hugo  }
    assert_response :success

    get '/storage/list_real_num_rows', :params => { :format=>:html, :owner=>"SYS", :name=>"All_Users", :update_area=>:hugo  } # sys.user$ requires extra rights compared to SELECT ANY DICTIONARY in 12c
    assert_response :success

    get '/storage/tablespace_usage', :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success
  end

  test "exadata with xhr: true" do
    post '/storage/list_exadata_cell_server', :params => { :format=>:html}
    assert_response :success

    post '/storage/list_exadata_cell_server', :params => { :format=>:html, :cellname=>'Hugo'}
    assert_response :success

    post '/storage/list_exadata_cell_physical_disk', :params => { :format=>:html}
    assert_response :success

    post '/storage/list_exadata_cell_physical_disk', :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk'}
    assert_response :success

    post '/storage/list_exadata_cell_cell_disk', :params => { :format=>:html}
    assert_response :success

    post '/storage/list_exadata_cell_cell_disk', :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk', :physical_disk_id=>'Hugo'}
    assert_response :success

    post '/storage/list_exadata_cell_grid_disk', :params => { :format=>:html}
    assert_response :success

    post '/storage/list_exadata_cell_grid_disk', :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk', :physical_disk_id=>'Hugo', :cell_disk_name=>'Hugo'}
    assert_response :success

    if get_db_version >= '19'
      post '/storage/list_exadata_io_load_by_cell_db', params: { format: :html, time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, dbid: get_dbid }
      [:none, :panorama_sampler].include?(management_pack_license) ? :error : :success
      post '/storage/list_exadata_io_load_by_cell_db', params: { format: :html, time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, dbid: get_dbid, cell_hash: 123 }
      [:none, :panorama_sampler].include?(management_pack_license) ? :error : :success
      post '/storage/list_exadata_io_load_by_cell_db', params: { format: :html, time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, dbid: get_dbid, src_dbid: 123 }
      [:none, :panorama_sampler].include?(management_pack_license) ? :error : :success
      post '/storage/list_exadata_io_load_by_cell_db', params: { format: :html, time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, dbid: get_dbid, cell_hash: 123, src_dbid: 123 }
      [:none, :panorama_sampler].include?(management_pack_license) ? :error : :success

      post '/storage/list_exadata_io_load_distribution', params: { format: :html, grouping: 'cell_hash', column: 'disk_small_io_reqs',time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, dbid: get_dbid }
      [:none, :panorama_sampler].include?(management_pack_license) ? :error : :success
    end
  end

  test "temp with xhr: true" do
    post '/storage/list_temp_usage_sysmetric_historic', :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end}
    assert_response management_pack_license == :none ? :error : :success
  end

  test "extents with xhr: true" do
    tablespace_name = sql_select_one "SELECT MIN(Tablespace_Name) FROM DBA_Tablespaces"
    post '/storage/list_free_extents', :params => { :format=>:html, :tablespace => tablespace_name}
    assert_response :success

    post '/storage/list_object_extents', :params => { :format=>:html, :owner => 'SYS', :segment_name => 'OBJ$'}  # Test-name must be upper case
    assert_response :success
  end

  test "list_sysaux_occupants with xhr: true" do
    post '/storage/list_sysaux_occupants', :params => { :format=>:html, con_id: (get_db_version >= '12.1' ? 1 : nil)}
    assert_response :success
  end

  test "list_undo_transactions with xhr: true" do
    instance = PanoramaConnection.instance_number
    post '/storage/list_undo_transactions', params: {format: :html, segment_id: 1}
    assert_response :success

    post '/storage/list_undo_transactions', params: {format: :html, instance: instance, sid: 1, serial_no: 1}
    assert_response :success

  end
end
