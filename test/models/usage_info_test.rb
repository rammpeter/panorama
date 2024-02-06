require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping_usage_info" do
    ClientInfoStore.reset_instance
    ClientInfoStore.write(:dummy, :value)                                       # Ensure existence of client_info_store file before test
    # Ensure that usage_info file exists before test
    UsageInfo.write_record(ActionDispatch::Request.new({}), 'hugo', 'hugo', 'TNS')
    UsageInfo.housekeeping
  end
end