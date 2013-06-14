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
              :DBID            => {:sql => "s.DBID = ?"            , :bind_value => session[:database].dbid, :hide_filter => true},
              :time_selection_start => {:sql => "s.Begin_Interval_Time >= TO_TIMESTAMP(?, 'DD.MM.YYYY HH24:MI')"    , :bind_value => @time_selection_start},
              :time_selection_end   => {:sql => "s.End_Interval_Time <  TO_TIMESTAMP(?, 'DD.MM.YYYY HH24:MI')"    , :bind_value => @time_selection_end},
      }


  end

  test "list_io_ash_history" do
    post :list_io_ash_history, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :instance =>1
    assert_response :success
  end

  test "list_io_file_history" do
    def do_test(groupby)
      post :list_io_file_history, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :instance =>1, :groupby=>groupby
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
      post :list_io_file_history_samples, :format=>:js, :groupfilter=>@groupfilter,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end
      assert_response :success
    end

    io_file_key_rules.each do |key, value|
      do_test key
    end

  end


end