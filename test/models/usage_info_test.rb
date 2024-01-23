require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping" do
    UsageInfo.housekeeping
  end
end