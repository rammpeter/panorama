# encoding: utf-8
require 'test_helper'

class DragnetControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
  end

  test "show_selection"  do
    get  :show_selection, :format=>:js
    assert_response :success
  end

  test "refresh_selection_hint"  do
    get :refresh_selection_hint, :format=>:js, :array_index=>0
    assert_response :success
  end

  test "exec_dragnet_sql"  do
    post  :exec_dragnet_sql, :format=>:js, :dragnet=>{:selection=>0}, "Schwellwert für PctFree Index"=>10, "Schwellwert für PctFree Index-Partition"=>10, "Minimale Anzahl Rows" => 10
    assert_response :success
  end
end


