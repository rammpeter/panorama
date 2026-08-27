require 'test_helper'

class PanoramaSamplerConfigTest < ActiveSupport::TestCase

  # test "get_cloned_config_array" do
  #   assert PanoramaSamplerConfig.get_cloned_config_array.class == Array
  # end

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
    PanoramaSamplerConfig.delete_all_config_entries                             # Ensure that no config entries are present before test
    # Test data needed, must not have valid DB user (until now)
    PanoramaSamplerConfig.add_config_entry(PanoramaSamplerConfig.new.get_cloned_config_hash.merge({name: 'test1', user: 'test1', owner: 'test1', password: 'test1'}))
    PanoramaSamplerConfig.add_config_entry(PanoramaSamplerConfig.new.get_cloned_config_hash.merge({name: 'test2', user: 'test2', owner: 'test2', password: 'test2'}))
    PanoramaSamplerConfig.add_config_entry(PanoramaSamplerConfig.new.get_cloned_config_hash.merge({name: 'test3', user: 'test3', owner: 'test3', password: 'test3'}))
  end

  test "validate" do
    original_master_password = Panorama::Application.config.panorama_master_password
    Panorama::Application.config.panorama_master_password = 'not_hugo' # awr_ash_snapshot_cycle requires this
    begin
    [
        { name: :user,                                value: nil},
        { name: :user,                                value: ''},
        { name: :password,                            value: nil},
        { name: :password,                            value: ''},
        { name: :awr_ash_snapshot_cycle,              value: nil},
        { name: :awr_ash_snapshot_cycle,              value: 0},
        { name: :awr_ash_snapshot_cycle,              value: 7},
        { name: :awr_ash_snapshot_cycle,              value: 52},
        { name: :awr_ash_snapshot_cycle,              value: 130},
        { name: :awr_ash_snapshot_retention,          value: nil},
        { name: :awr_ash_snapshot_retention,          value: 0},
        { name: :object_size_snapshot_cycle,          value: nil},
        { name: :object_size_snapshot_cycle,          value: 1.2},
        { name: :object_size_snapshot_cycle,          value: 25},
        { name: :object_size_snapshot_cycle,          value: nil},
        { name: :object_size_snapshot_cycle,          value: 0},
        { name: :object_size_snapshot_retention,      value: nil},
        { name: :object_size_snapshot_retention,      value: 0},
        { name: :blocking_locks_snapshot_cycle,       value: nil},
        { name: :blocking_locks_snapshot_cycle,       value: 0},
        { name: :blocking_locks_snapshot_retention,   value: nil},
        { name: :blocking_locks_snapshot_retention,   value: 0},
        { name: :longterm_trend_snapshot_cycle,       value: nil},
        { name: :longterm_trend_snapshot_cycle,       value: 0},
        { name: :longterm_trend_snapshot_cycle,       value: 25},
        { name: :longterm_trend_snapshot_cycle,       value: 1.2},
        { name: :longterm_trend_snapshot_retention,   value: nil},
        { name: :longterm_trend_snapshot_retention,   value: 0},
        { name: :longterm_trend_subsume_limit,        value: nil},
        { name: :longterm_trend_subsume_limit,        value: -1},
        { name: :longterm_trend_subsume_limit,        value: 1000},
    ].each do |rec|
      config_hash = @sampler_config.get_cloned_config_hash
      config_hash[rec[:name]] = rec[:value]
      assert_raise(PopupMessageException, "#{rec[:name]} = #{rec[:value]}") do
        PanoramaSamplerConfig.validate_entry(config_hash)
      end
    end
    ensure
      Panorama::Application.config.panorama_master_password = original_master_password # reset to previous value for next tests
    end
  end

  test "export JSON" do
    json = PanoramaSamplerConfig.export_config
    assert json.class == String
    assert json.length > 0
  end

  test "get_config_entry_by_id" do
    existing_id = PanoramaSamplerConfig.get_config_array.first.get_id
    missing_id  = PanoramaSamplerConfig.get_max_id + 1000                       # ID that surely does not exist

    # Existing entry is found, regardless of the option
    assert_equal existing_id, PanoramaSamplerConfig.get_config_entry_by_id(existing_id).get_id,
                 'Existing config entry should be returned'
    assert_equal existing_id, PanoramaSamplerConfig.get_config_entry_by_id(existing_id, option: :return_nil_if_not_found).get_id,
                 'Existing config entry should be returned also with option :return_nil_if_not_found'

    # Missing entry without option must raise a meaningful RuntimeError (not NoMethodError on nil)
    exception = assert_raise(RuntimeError, 'Missing config entry should raise without option') do
      PanoramaSamplerConfig.get_config_entry_by_id(missing_id)
    end
    assert_match(/No Panorama-Sampler config found/, exception.message,
                 "Should raise the explicit error message, but got: #{exception.message}")

    # Missing entry with option must return nil instead of raising
    assert_nil PanoramaSamplerConfig.get_config_entry_by_id(missing_id, option: :return_nil_if_not_found),
               'Missing config entry should return nil with option :return_nil_if_not_found'
  end

  test "import JSON" do
    json = PanoramaSamplerConfig.export_config
    assert json.class == String
    assert json.length > 0
    assert_raise do
      PanoramaSamplerConfig.import_config(json) # Import the sme config again should be raise an exception on double name
    end

    PanoramaSamplerConfig.delete_all_config_entries # Delete all entries        # remove the existing config
    PanoramaSamplerConfig.import_config(json)
    assert PanoramaSamplerConfig.get_config_array.count == JSON.parse(json).count, 'Should have same number of entries after import'
    new_json = PanoramaSamplerConfig.export_config
    assert_equal json, new_json, 'JSON should be the same after import'
  end
end