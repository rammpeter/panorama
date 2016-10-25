# encoding: utf-8
require 'test_helper'

module Panorama
class DragnetControllerTest < ActionController::TestCase
  include Engine.routes.url_helpers

  setup do
    @routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  test "get_selection_list"  do
    get :get_selection_list, :params => {:format=>:json }
    assert_response :success
  end

  test "refresh_selected_data"  do
    get :refresh_selected_data, :params => {:format=>:js, :entry_id=>"_0_0_3" }
    assert_response :success
  end

  test "exec_dragnet_sql"  do
    post  :exec_dragnet_sql, :params => {:format=>:js, :dragnet_hidden_entry_id=>"_0_0_0", "Threshold for pctfree of index"=>10, "Threshold for pctfree of index partition"=>10, "Minumum number of rows" => 10 }
    assert_response :success

    post  :exec_dragnet_sql, :params => {:format=>:js, :dragnet_hidden_entry_id=>"_0_0_0", "Threshold for pctfree of index"=>10, "Threshold for pctfree of index partition"=>10, "Minumum number of rows" => 10 , :commit_show => 'hugo' }
    assert_response :success
  end

  # Find unique name by random to ensure selection does not already exists in client_info.store
  test "personal_selection" do
    post :add_personal_selection, :params => {:format=>:js, :selection => "
{
  name: \"Name of selection in list#{Random.rand(1000000)}\",
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
    " }
    assert_response :success

    # :dragnet_hidden_entry_id=>"_8_0" depends from number of submenus in list
    post :exec_dragnet_sql, :params => {:format=>:js, :commit_drop=>"Drop personal SQL", :dragnet_hidden_entry_id=>"_8_0" }
    assert_response :success

  end

end
end

