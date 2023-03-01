require "test_helper"

class SpecAdditionsTest < PlaywrightSystemTestCase
  test "Dragnet investigation" do
    # Call menu entry
    menu_call(['Spec. additions', 'menu_dragnet_show_selection'])
    assert_ajax_success

    assert_text 'Dragnet investigation for performance bottlenecks and usage of anti-pattern'
    assert_text 'Select dragnet-SQL for execution'

    assert_ajax_success                                                         # Wait for content

    # dragnet/get_selection_list does not become visible with headless chrome on linux
=begin
    # Wait until content/list becomes visible
    loop_count = 0
    while loop_count < 100 && !page.has_text?(:visible, '1. Potential in DB-structures')
      Rails.logger.info "Waiting #{loop_count} seconds for '1. Potential in DB-structures'"
      sleep 1
      loop_count += 1
    end
    assert_text '1. Potential in DB-structures'

    # click first node
    page.first(:xpath, "//i[contains(@class, 'jstree-icon') and contains(@class, 'jstree-ocl') and contains(@role, 'presentation')]").click
    assert_ajax_success
    assert_text '1. Ensure optimal storage parameter for indexes'

    # click point 1.6
    page.first(:xpath, "//a[contains(@id, '_0_5_anchor')]").click
    assert_ajax_success
    assert_text 'Protection of colums with foreign key references by index can be necessary for'

    # Click "Show SQL"                                       ^
    page.first(:xpath, "//input[contains(@type, 'submit') and contains(@name, 'commit_show')]").click
    assert_ajax_success
    assert_text 'FROM   DBA_Constraints Ref'

    # Click "Do selection"
    page.first(:xpath, "//input[contains(@type, 'submit') and contains(@name, 'commit_exec')]").click
    assert_ajax_success
=end
  end

end