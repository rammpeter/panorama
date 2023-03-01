require 'test_helper'

class PackLicenseTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
    @autonomous = PanoramaConnection.autonomous_database?
  end

  test "translate_sql_table_names" do
    #    expected = @autonomous ? 'CDB_Hist_Snapshot' :  'DBA_Hist_Snapshot'
    # TODO: CDB_OR_DBA
    expected = @autonomous ? 'DBA_Hist_Snapshot' :  'DBA_Hist_Snapshot'
    assert_equal("#{@sampler_config.get_owner}.Panorama_Snapshot", PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :panorama_sampler))
    assert_equal(expected, PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :diagnostics_pack))
    assert_equal(expected, PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :diagnostics_and_tuning_pack))
    assert_equal(expected, PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :none))
  end
end

