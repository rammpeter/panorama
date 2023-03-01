require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  setup do
    set_session_test_db_context{}
  end

#  teardown do
#    connect_sqlite_db
#  end

  test "sql_select_all" do
    res = sql_select_all "SELECT 1 Zahl FROM DUAL"
    assert_equal "Array", res.class.name
    assert_equal "Hash", res[0].class.name
    assert_equal 1, res[0].zahl
  end

  test "sql_select_first_row" do
    res = sql_select_first_row "SELECT 1 Zahl FROM DUAL"
    assert_equal "Hash", res.class.name
    assert_equal 1, res.zahl
  end

  test "sql_select_one" do
    res = sql_select_one "SELECT 1 Zahl FROM DUAL"
    assert_equal 1, res
  end

  test "save_session_alter_ts" do
    set_I18n_locale('de')
    assert_nothing_raised {
      params[:time_selection_start] = "01.01.2011 00:20"
      params[:time_selection_end] = "31.01.2012 23:20"
      save_session_time_selection
      assert_equal params[:time_selection_start], get_cached_time_selection_start
      assert_equal params[:time_selection_end], get_cached_time_selection_end

      params[:time_selection_start] = "01.01.2011 00:00";   save_session_time_selection
      params[:time_selection_start] = "31.01.2011 00:00";   save_session_time_selection
      params[:time_selection_start] = "01.12.2011 00:00";   save_session_time_selection
      params[:time_selection_start] = "01.01.2011 23:59";   save_session_time_selection
    }

    # Fehlerfälle
    params[:time_selection_start]  = "32.02.2011 00:20"
    params[:time_selection_end] = "31.01.2011 23:20"
    assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "01.13.2011 00:20"; assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "01.12.2011 24:20"; assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "01.12.2011 00:60"; assert_raise(RuntimeError){ save_session_time_selection }


    set_I18n_locale('en')
    assert_nothing_raised {
      params[:time_selection_start] = "2011/01/01 00:20"
      params[:time_selection_end] = "2012/12/31 23:20"
      assert_nothing_raised {  save_session_time_selection }
      assert_equal params[:time_selection_start], get_cached_time_selection_start
      assert_equal params[:time_selection_end], get_cached_time_selection_end
      params[:time_selection_start] = "2011/01/01 00:00";   save_session_time_selection
      params[:time_selection_start] = "2011/01/31 00:00";   save_session_time_selection
      params[:time_selection_start] = "2011/12/01 00:00";   save_session_time_selection
      params[:time_selection_start] = "2011/01/01 23:59";   save_session_time_selection
    }
    # Fehlerfälle
    params[:time_selection_start]  = "2011/02/32 00:20"
    params[:time_selection_end]  = "2011/01/31 23:20"
    assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "2011/13/01 00:20"; assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "2011/12/01 24:20"; assert_raise(RuntimeError){ save_session_time_selection }
    params[:time_selection_start]  = "2011/12/01 00:60"; assert_raise(RuntimeError){ save_session_time_selection }

    set_I18n_locale('de')                                                       # Rücksetzen auf de, da dies der Dafeault ist für weitere Tests
  end


end
