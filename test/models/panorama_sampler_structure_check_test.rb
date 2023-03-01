require 'test_helper'

class PanoramaSamplerStructureCheckTest < ActiveSupport::TestCase

  setup do
    # Ensures valid connection info for all tests by PanoramaConnection.get_threadlocal_config
    prepare_panorama_sampler_thread_db_config
  end

  test "has_column?" do
    assert_equal(true, PanoramaSamplerStructureCheck.has_column?('Panorama_Snapshot', 'Snap_ID'))
  end

  test 'tables' do
    assert_equal(PanoramaSamplerStructureCheck.tables.class, Array)
    assert(PanoramaSamplerStructureCheck.tables.length > 0)
  end

  test 'panorama_sampler_schemas' do
    assert_equal(PanoramaSamplerStructureCheck.panorama_sampler_schemas.class, Array)
  end

  test 'transform_sql_for_sampler' do
    config = PanoramaConnection.get_threadlocal_config
    assert_equal(PanoramaSamplerStructureCheck.transform_sql_for_sampler("SELECT * FROM DBA_Hist_SQLStat").upcase,          "SELECT * FROM #{config[:panorama_sampler_schema].upcase}.PANORAMA_SQLSTAT")
    assert_equal(PanoramaSamplerStructureCheck.transform_sql_for_sampler("SELECT * FROM gv$Active_Session_History").upcase, "SELECT * FROM #{config[:panorama_sampler_schema].upcase}.PANORAMA_V$ACTIVE_SESS_HISTORY")
    assert_equal(PanoramaSamplerStructureCheck.transform_sql_for_sampler("SELECT * FROM DBA_Hist_Hugo").upcase,             "SELECT * FROM DBA_HIST_HUGO")
  end

  test 'adjust_table_name' do
    config = PanoramaConnection.get_threadlocal_config

    config[:management_pack_license] = :none
    PanoramaConnection.set_connection_info_for_request(config)
    # TODO: CDB_OR_DBA
    #    assert_equal(PanoramaConnection.adjust_table_name('DBA_Hist_SQLStat'), PanoramaConnection.autonomous_database? ? 'CDB_Hist_SQLStat' : 'DBA_Hist_SQLStat')
    assert_equal(PanoramaConnection.adjust_table_name('DBA_Hist_SQLStat'), PanoramaConnection.autonomous_database? ? 'DBA_Hist_SQLStat' : 'DBA_Hist_SQLStat')

    config[:management_pack_license] = :panorama_sampler
    PanoramaConnection.set_connection_info_for_request(config)
    assert_equal(PanoramaConnection.adjust_table_name('DBA_Hist_SQLStat'), "#{config[:panorama_sampler_schema]}.Panorama_SQLStat")

  end

  test 'do_check' do
    sampler_config = prepare_panorama_sampler_thread_db_config
    PanoramaSamplerStructureCheck.remove_tables(sampler_config)                # Ensure that first run starts with empty schema
    2.downto(1) do
      sampler_config = prepare_panorama_sampler_thread_db_config                # Use fresh config to ensure structure_check is not :finished
      PanoramaSamplerStructureCheck.do_check(sampler_config, :ASH)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :AWR)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :OBJECT_SIZE)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :CACHE_OBJECTS)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :BLOCKING_LOCKS)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :LONGTERM_TREND)
    end
    PanoramaConnection.sql_execute "ALTER TABLE Panorama_Blocking_Locks MODIFY Action VARCHAR2(20)"
    sampler_config = prepare_panorama_sampler_thread_db_config                # Use fresh config to ensure structure_check is not :finished
    PanoramaSamplerStructureCheck.do_check(sampler_config, :BLOCKING_LOCKS)
    assert_equal 128,
                 PanoramaConnection.sql_select_one("SELECT Char_Length FROM User_Tab_Columns WHERE Table_Name = 'PANORAMA_BLOCKING_LOCKS' AND Column_Name = 'ACTION'"),
                 log_on_failure('Ensure original length is restored after check')
  end
end