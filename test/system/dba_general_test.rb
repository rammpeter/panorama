require "test_helper"

class DbaGeneralTest < PlaywrightSystemTestCase

  test "Start page" do
    menu_call(['DBA general', 'menu_env_start_page'])
    content = page.content
    assert content['Current database'],                             log_on_failure("Current database")
    assert content['Server versions'],                              log_on_failure("Server versions")
    assert content['Client versions'],                              log_on_failure("Client versions")
    assert content['Instance data'],                                log_on_failure("Instance data")
    assert content['Usage of Oracle management packs by Panorama'], log_on_failure("Usage of Oracle management packs by Panorama")
  end

  test "DB-Locks / current" do
    menu_call(['DBA general', 'DB-Locks', 'menu_dba_show_locks'])
    assert_ajax_success
    assert_text 'List current locks of different types'

    page.click '#button_dml_locks:visible'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'DML Database locks (from GV$Lock)'                           # Check only if not error "Access denied" raised before
      session_link_selector = '.slick-cell.l0.r0 a:visible'
      unless page.query_selector(session_link_selector)                         # Session may not exists anymore
        page.click(session_link_selector)
        assert_ajax_success
        assert_text 'Details for session SID='
      else
        Rails.logger.debug('DbaGeneralTest.DB-Locks / current'){"No session found with DML locks for test"}
      end
    end

    page.click '#button_blocking_dml_locks'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Blocking DML-Locks from gv$Lock'                             # Check only if not error "Access denied" raised before
    end

    page.click '#button_blocking_ddl_locks'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Blocking DDL-Locks in Library Cache (from DBA_KGLLock)'      # Check only if not error "Access denied" raised before
    end

    page.click '#button_2pc'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Pending two-phase commits '                                  # Check only if not error "Access denied" raised before
    end
  end

  test "DB-Locks / Blocking locks historic" do
    menu_call(['DBA general', 'DB-Locks', 'menu_active_session_history_show_blocking_locks_historic'])
    assert_ajax_success

    assert_text 'Blocking Locks from '

    page.query_selector('#time_selection_start_default').fill(@time_selection_start)
    page.query_selector('#time_selection_end_default').fill(@time_selection_end)

    page.click 'text=Blocking locks session dependency tree'
    unless assert_ajax_success_and_test_for_access_denied(300)                  # May last a bit longer
      assert_text 'Blocking locks between'
    end

    page.click 'text=Blocking locks event dependency'
    unless assert_ajax_success_and_test_for_access_denied(300)                  # May last a bit longer
      assert_text 'Event combinations for waiting and blocking sessions'
    end
  end

end

