# encoding: utf-8
require 'test_helper'

class IoControllerTest < ActionController::TestCase
  include IoHelper


  setup do
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

  ################### io_file ######################
  test "list_io_file_history" do
    def do_test(groupby)
      post :list_io_file_history, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby
      assert_response :success
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_io_file_history_grouping" do
    def do_test(groupby)
      post :list_io_file_history_grouping, :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby
      assert_response :success
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_io_file_history_samples" do
    def do_test(groupby)
      post :list_io_file_history_samples, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
      assert_response :success
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_io_file_history_timeline" do
    def do_test(groupby)
      post :list_io_file_history_timeline, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
      assert_response :success
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end

  test "refresh_time_selection" do
    def do_test(groupby)
      post :refresh_time_selection, :format=>:js, :groupfilter=>@groupfilter, :grooupby=>'Instance', :repeat_action => :list_io_file_history_grouping, :groupby=>groupby
      assert_response :success   # redirect_to schwierig im Test?
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end


  #################### iostat_detail #######################
  test "list_iostat_detail_history" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby
        assert_response :success
      end
    end

    iostat_detail_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_detail_history_grouping" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history_grouping, :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby
        assert_response :success
      end
    end

    iostat_detail_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_detail_history_samples" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_detail_history_samples, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
        assert_response :success
      end
    end

    iostat_detail_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_detail_history_timeline" do
    def do_test(groupby)
      post :list_iostat_detail_history_timeline, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
      assert_response :success
    end

    iostat_detail_key_rules.each do |key, value|
      do_test key
    end

  end

  #################### iostat_filetype #######################
  test "list_iostat_filetype_history" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby
        assert_response :success
      end
    end

    iostat_filetype_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_filetype_history_grouping" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history_grouping, :format=>:js, :groupfilter=>@groupfilter, :groupby=>groupby
        assert_response :success
      end
    end

    iostat_filetype_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_filetype_history_samples" do
    def do_test(groupby)
      if ENV['DB_VERSION'] >= '11.2'
        post :list_iostat_filetype_history_samples, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
        assert_response :success
      end
    end

    iostat_filetype_key_rules.each do |key, value|
      do_test key
    end

  end

  test "list_iostat_filetype_history_timeline" do
    def do_test(groupby)
      post :list_iostat_filetype_history_timeline, :format=>:js, :groupfilter=>@groupfilter.merge(groupby=>'1'),  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
      assert_response :success
    end

    iostat_filetype_key_rules.each do |key, value|
      do_test key
    end

  end


end