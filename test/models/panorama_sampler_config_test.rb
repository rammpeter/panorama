require 'test_helper'

class PanoramaSamplerConfigTest < ActiveSupport::TestCase

  # test "get_cloned_config_array" do
  #   assert PanoramaSamplerConfig.get_cloned_config_array.class == Array
  # end

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  test "validate" do
    Panorama::Application.config.panorama_master_password = 'not_hugo' # awr_ash_snapshot_cycle requires this
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
    Panorama::Application.config.panorama_master_password = 'hugo' # reset to previous value for next tests
  end

  test "export JSON" do
    json = PanoramaSamplerConfig.export_config
    assert json.class == String
    assert json.length > 0
  end

  test "import JSON" do
    if PanoramaSamplerConfig.get_config_array.count == 0                        # Test data needed
      PanoramaSamplerConfig.add_config_entry(PanoramaSamplerConfig.new.get_cloned_config_hash)
    end
    json = PanoramaSamplerConfig.export_config
    assert json.class == String
    assert json.length > 0
    assert_raise do
      PanoramaSamplerConfig.import_config(json) # Import the sme config again should be raise an exception on double name
    end
    # remove the existing config
    existing_ids = PanoramaSamplerConfig.get_config_array.map{|x| x.get_id}
    existing_ids.each do |id|
      PanoramaSamplerConfig.delete_config_entry(id)
    end
    PanoramaSamplerConfig.import_config(json)
    assert PanoramaSamplerConfig.get_config_array.count == JSON.parse(json).count, 'Should have same number of entries after import'
    new_json = PanoramaSamplerConfig.export_config
    assert_equal json, new_json, 'JSON should be the same after import'
  end

end