# encoding: utf-8
require 'test_helper'

class IoControllerTest < ActionController::TestCase
  include IoHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times

    @groupfilter = {
              :DBID            => get_dbid,
              :time_selection_start => @time_selection_start,
              :time_selection_end   => @time_selection_end,
      }


  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  ################### io_file ######################
  test "list_io_file_history with xhr: true" do
    instance = PanoramaConnection.instance_number
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history, :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
      assert_response management_pack_license == :none ? :error : :success

      post :list_io_file_history, :params => { :format=>:html, :instance=>instance, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "list_io_file_history_grouping with xhr: true" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_grouping, :params => { :format=>:html, :groupfilter=>@groupfilter, :groupby=>groupby, :update_area=>:hugo   }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "list_io_file_history_samples with xhr: true" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_samples, :params => { :format=>:html, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo  }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "list_io_file_history_timeline with xhr: true" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_timeline, :params => { :format=>:html, :groupby=>groupby, :groupfilter=>@groupfilter,  :data_column_name=>io_file_values_column_options[0][:caption],  :update_area=>:hugo  }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  test "refresh_time_selection with xhr: true" do
    io_file_key_rules.each do |groupby, value|
      post :refresh_time_selection, :params => { :format=>:html, :groupfilter=>@groupfilter, repeat_controller: :io, :repeat_action => :list_io_file_history_grouping, :groupby=>groupby, :update_area=>:hugo }
      assert_response :redirect # redirect_to schwierig im Test?
    end
  end


  #################### iostat_detail #######################
  test "list_iostat_detail_history with xhr: true" do
    instance = PanoramaConnection.instance_number
    iostat_detail_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_detail_history, :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success

        post :list_iostat_detail_history, :params => { :format=>:html, :instance=>instance, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_detail_history_grouping with xhr: true" do
    iostat_detail_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_detail_history_grouping, :params => { :format=>:html, :groupfilter=>@groupfilter, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_detail_history_samples with xhr: true" do
    iostat_detail_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_detail_history_samples, :params => { :format=>:html, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo  }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_detail_history_timeline with xhr: true" do
    iostat_detail_key_rules.each do |groupby, value|
      post :list_iostat_detail_history_timeline, :params => { :format=>:html, :groupby=>groupby, :groupfilter=>@groupfilter, :data_column_name=>iostat_detail_values_column_options[0][:caption],  :update_area=>:hugo  }
      assert_response management_pack_license == :none ? :error : :success
    end
  end

  #################### iostat_filetype #######################
  test "list_iostat_filetype_history with xhr: true" do
    instance = PanoramaConnection.instance_number
    iostat_filetype_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_filetype_history, :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success

        post :list_iostat_filetype_history, :params => { :format=>:html, :instance=>instance, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_filetype_history_grouping with xhr: true" do
    iostat_filetype_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_filetype_history_grouping, :params => { :format=>:html, :groupfilter=>@groupfilter, :groupby=>groupby, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_filetype_history_samples with xhr: true" do
    iostat_filetype_key_rules.each do |groupby, value|
      if get_db_version >= '11.2'
        post :list_iostat_filetype_history_samples, :params => { :format=>:html, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo }
        assert_response management_pack_license == :none ? :error : :success
      end
    end
  end

  test "list_iostat_filetype_history_timeline with xhr: true" do
    iostat_filetype_key_rules.each do |groupby, value|
      post :list_iostat_filetype_history_timeline, :params => { :format=>:html, :groupby=>groupby, :groupfilter=>@groupfilter,  :data_column_name=>iostat_filetype_values_column_options[0][:caption],  :update_area=>:hugo }
      assert_response management_pack_license == :none ? :error : :success
    end

  end


end
