# encoding: utf-8
require 'test_helper'
require 'json'

class DragnetControllerTest < ActionController::TestCase
  include DragnetHelper

  setup do
    #@routes = Engine.routes                                                    # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context                                                 # Ensure existence of AWR snapshots
    initialize_min_max_snap_id_and_times
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "get_selection_list with xhr: true"  do
    get :get_selection_list, :params => {:format=>:json }
    assert_response :success
  end

  test "refresh_selected_data with xhr: true"  do
    get :refresh_selected_data, :params => {:format=>:js, :entry_id=>"_0_0_3" }
    assert_response :success
  end

  # Test all subitems of node
  # Error: Java::JavaLang::ClassCastException: org.jruby.RubyObject cannot be cast to org.jruby.RubyModule
  # if method is declared inside test
  def execute_tree(node)
    node.each do |entry|
      if entry['children']
        execute_tree(entry['children'])        # Test subnode's entries
      else
        prepare_panorama_sampler_thread_db_config                               # Ensure that PanoramaConnection has valid config even outside controller action
        full_entry = extract_entry_by_entry_id(entry['id'])                     # Get SQL from id
        unless full_entry[:exclude_from_test]                                   # Exclude selections from test which are not executable
          params = {:format=>:html, :dragnet_hidden_entry_id=>entry['id'], :update_area=>:hugo}

          if full_entry[:parameter]
            full_entry[:parameter].each do |p|                                  # Iterate over optional parameter of selection
              if p[:name] == t(:dragnet_helper_param_history_backward_name, default: 'Consideration of history backward in days')
                params[p[:name]] = 1                                            # Show only 1 day back in history to speedup tests
              else
                params[p[:name]] = p[:default]
              end
            end
          end

          expected_result = :success                                            # May switch to error if license violation on DBA_Hist_xxx
          # Check if result should by error or success, Without management pack license execution should result in error if SQL contains DBA_HIST etc.
          begin
            prepare_panorama_sampler_thread_db_config                         # Ensure that PanoramaConnection has valid config even outside controller action
            PackLicense.filter_sql_for_pack_license(full_entry[:sql], management_pack_license: management_pack_license)
          rescue Exception => e
            Rails.logger.error "Expected result = error due to exception #{e.class} #{e.message}"
            expected_result = :error
          end

          if !full_entry[:not_executable] &&
            (full_entry[:min_db_version].nil? || full_entry[:min_db_version] <= get_db_version) &&
            !full_entry[:not_for_autonomous]
            start_time = Time.now
            post  :exec_dragnet_sql, :params => params                          # call execution of SQL
            Rails.logger.debug('DragnetControllerTest.execute_tree') {"#{Time.now-start_time} secs. in execute dragnet sql for #{entry['id']}"}
            errmsg = "Error testing dragnet SQL #{entry['id']} #{full_entry[:name]}, result should be '#{expected_result}'"
            if @response.response_code.to_s[0] != ActionDispatch::AssertionResponse.new(expected_result).code[0]
              Rails.logger.debug errmsg
            end
            # Without management pack license execution should result in error if SQL contains DBA_HIST
            assert_response(expected_result, errmsg)
          end

          params[:commit_show] = 'hugo'
          post  :exec_dragnet_sql, :params => params                          # Call show SQL text
          assert_response(expected_result, "Error showing dragnet SQL #{entry['id']} #{full_entry[:name]}, result should be '#{expected_result}'")
        end
      end
    end
  end

  test "exec_dragnet_sql with xhr: true"  do
    # get available selections
    get :get_selection_list, :params => {:format=>:json }
    dragnet_sqls = JSON.parse(@response.body)
    execute_tree(dragnet_sqls)                                                     # Test each dragnet SQL with default parameters
  end

  def create_personal_selection
    post :add_personal_selection, :params => {:format=>:html, :update_area=>:hugo, :selection => "
{
  \"name\": \"Name of selection in list#{Random.rand(1000000)}\",
  \"desc\": \"Explanation of selection in right dialog\",
  \"sql\":  \"SELECT * FROM DBA_Tables WHERE Owner = ? AND Table_Name = ?\",
  \"parameter\": [
    {
      \"name\":     \"Name of parameter for \\\"owner\\\" in dialog\",
      \"title\":    \"Description of parameter \\\"owner\\\" for mouseover hint\",
      \"size\":     \"Size of input field for parameter \\\"owner\\\" in characters\",
      \"default\":  \"SYS\"
    },
    {
      \"name\":     \"Name of parameter for \\\"table_name\\\" in dialog\",
      \"title\":    \"Description of parameter \\\"table_name\\\" for mouseover hint\",
      \"size\":     \"Size of input field for parameter \\\"table_name\\\" in characters\",
      \"default\":  \"AUD$\"
    }
  ]
}
    " }
    assert_response :success, "add_personal_selection"

  end

  # Find unique name by random to ensure selection does not already exists in client_info.store
  test "personal_selection with xhr: true" do

    # create 3 entries
    create_personal_selection
    create_personal_selection
    create_personal_selection

    # :dragnet_hidden_entry_id=>"_8_0" depends on number of submenus in list

    # drop 2nd entry
    post :drop_personal_selection, :params => {:format=>:html, :dragnet_hidden_entry_id=>"_9_1", :update_area=>:content_for_layout }
    assert_response :success, "Error drop_personal_selection _9_1"

    # drop 1st entry
    post :drop_personal_selection, :params => {:format=>:html, :dragnet_hidden_entry_id=>"_9_0", :update_area=>:content_for_layout }
    assert_response :success, "Error drop_personal_selection _9_0 1"

    # drop 3rd entry
    post :drop_personal_selection, :params => {:format=>:html, :dragnet_hidden_entry_id=>"_9_0", :update_area=>:content_for_layout }
    assert_response :success, "Error drop_personal_selection _9_0 2"
  end

end

