# encoding: utf-8
require 'test_helper'

class DragnetControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context{}
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
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
    post  :exec_dragnet_sql, :format=>:js, :dragnet_hidden_entry_id=>"_0_0_0", "Schwellwert für PctFree Index"=>10, "Schwellwert für PctFree Index-Partition"=>10, "Minimale Anzahl Rows" => 10
    assert_response :success

    post  :exec_dragnet_sql, :format=>:js, :dragnet_hidden_entry_id=>"_0_0_0", "Schwellwert für PctFree Index"=>10, "Schwellwert für PctFree Index-Partition"=>10, "Minimale Anzahl Rows" => 10 , :commit_show => 'hugo'
    assert_response :success
  end

  test "personal_selection" do
    post :add_personal_selection, :format=>:js, :selection => "
{
  name: \"Name of selection in list\",
  desc: \"Explanation of selection in right dialog\",
  sql:  \"Your SQL-Statement without trailing ';'. Example: SELECT * FROM DBA_Tables WHERE Owner = ? AND Table_Name = ?\",
  parameter: [
    {
      name:     \"Name of parameter for \\\"owner\\\" in dialog\",
      title:    \"Description of parameter \\\"owner\\\" for mouseover hint\",
      size:     \"Size of input field for parameter \\\"owner\\\" in characters\",
      default:  \"Default value for parameter \\\"owner\\\" in input field\",
    },
    {
      name:     \"Name of parameter for \\\"table_name\\\" in dialog\",
      title:    \"Description of parameter \\\"table_name\\\" for mouseover hint\",
      size:     \"Size of input field for parameter \\\"table_name\\\" in characters\",
      default:  \"Default value for parameter \\\"table_name\\\" in input field\",
    },
  ]
}
    "
    assert_response :success

    # :dragnet_hidden_entry_id=>"_8_0" depends from number of submenus in list
    post :exec_dragnet_sql, :format=>:js, :commit_drop=>"Drop personal SQL", :dragnet_hidden_entry_id=>"_8_0"
    assert_response :success

  end

end


