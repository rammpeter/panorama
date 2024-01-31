require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping_usage_info" do
    ClientInfoStore.reset_instance
    ClientInfoStore.write(:dummy, :value)                                       # Ensure existence of client_info_store file before test
    UsageInfo.housekeeping
  end
end