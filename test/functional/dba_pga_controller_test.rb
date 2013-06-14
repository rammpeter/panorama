# encoding: utf-8
require 'test_helper'

class DbaPgaControllerTest < ActionController::TestCase
  setup do
    set_session_test_db_context{}

    min_alter_org = Time.new
    max_alter_org = min_alter_org-10000
    @time_selection_end = min_alter_org.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = (max_alter_org).strftime("%d.%m.%Y %H:%M")

  end

  test "list_pga_stat_historic" do
    post :list_pga_stat_historic, :format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :instance =>1
    assert_response :success
  end

end