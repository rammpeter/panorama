require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping" do
    ClientInfoStore.cleanup
  end
end