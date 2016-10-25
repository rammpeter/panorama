# encoding: utf-8
require 'test_helper'

module Panorama
class IoControllerTest < ActionController::TestCase
  include Panorama::IoHelper
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    min_alter_org = Time.new
    max_alter_org = min_alter_org-10000
    @time_selection_end = min_alter_org.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = (max_alter_org).strftime("%d.%m.%Y %H:%M")
    @groupfilter = {
              :DBID            => get_dbid,
              :time_selection_start => @time_selection_start,
              :time_selection_end   => @time_selection_end,
      }


  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  ################### io_file ######################
  test "list_io_file_history" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history, :params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby }
      assert_response :success
    end
  end

  test "list_io_file_history_grouping" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_grouping, :params => { :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby  }
      assert_response :success
    end
  end

  test "list_io_file_history_samples" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_samples, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
      assert_response :success
    end
  end

  test "list_io_file_history_timeline" do
    io_file_key_rules.each do |groupby, value|
      post :list_io_file_history_timeline, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
      assert_response :success
    end
  end

  test "refresh_time_selection" do
    io_file_key_rules.each do |groupby, value|
      post :refresh_time_selection, :params => { :format=>:js, :groupfilter=>@groupfilter, :grooupby=>'Instance', :repeat_action => :list_io_file_history_grouping, :groupby=>groupby }
      assert_response :success   # redirect_to schwierig im Test?
    end
  end


  #################### iostat_detail #######################
  test "list_iostat_detail_history" do
    iostat_detail_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history, :params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby }
        assert_response :success
      end
    end
  end

  test "list_iostat_detail_history_grouping" do
    iostat_detail_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history_grouping, :params => { :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby }
        assert_response :success
      end
    end
  end

  test "list_iostat_detail_history_samples" do
    iostat_detail_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history_samples, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
        assert_response :success
      end
    end
  end

  test "list_iostat_detail_history_timeline" do
    iostat_detail_key_rules.each do |groupby, value|
      post :list_iostat_detail_history_timeline, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
      assert_response :success
    end
  end

  #################### iostat_filetype #######################
  test "list_iostat_filetype_history" do
    iostat_filetype_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history, :params => { :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby }
        assert_response :success
      end
    end
  end

  test "list_iostat_filetype_history_grouping" do
    iostat_filetype_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history_grouping, :params => { :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby }
        assert_response :success
      end
    end
  end

  test "list_iostat_filetype_history_samples" do
    iostat_filetype_key_rules.each do |groupby, value|
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history_samples, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
        assert_response :success
      end
    end
  end

  test "list_iostat_filetype_history_timeline" do
    iostat_filetype_key_rules.each do |groupby, value|
      post :list_iostat_filetype_history_timeline, :params => { :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
      assert_response :success
    end

  end


end
end