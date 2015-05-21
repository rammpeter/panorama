# encoding: utf-8
require 'test_helper'

class DragnetControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
  end

  test "show_selection"  do
    xhr :get,  :show_selection, :format=>:js
    assert_response :success
  end

  test "get_selection_list"  do
    xhr :get, :get_selection_list, :format=>:json
    assert_response :success
  end

  test "refresh_selected_data"  do
    xhr :get, :refresh_selected_data, :format=>:js, :entry_id=>"_0_0_3"
    assert_response :success
  end

  test "exec_dragnet_sql"  do
    post  :exec_dragnet_sql, :format=>:js, :dragnet=>{:selection=>0}, "Schwellwert für PctFree Index"=>10, "Schwellwert für PctFree Index-Partition"=>10, "Minimale Anzahl Rows" => 10
    assert_response :success

    post  :exec_dragnet_sql, :format=>:js, :dragnet=>{:selection=>0}, "Schwellwert für PctFree Index"=>10, "Schwellwert für PctFree Index-Partition"=>10, "Minimale Anzahl Rows" => 10 , :commit_show => 'hugo'
    assert_response :success
  end
end


