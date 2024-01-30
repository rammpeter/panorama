require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping_usage_info" do
    UsageInfo.housekeeping
  end
end