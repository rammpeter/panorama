require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping" do
    assert_nothing_raised do
      ClientInfoStore.cleanup
    end
  end
end