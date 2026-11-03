require 'test_helper'

class UsageInfoTest < ActiveSupport::TestCase
  test "housekeeping" do
    assert_nothing_raised do
      ClientInfoStore.cleanup
    end
  end

  test "update_for_client_key is atomic for concurrent threads" do
    client_key = "test_update_for_client_key_#{SecureRandom.hex(8)}"
    threads = 10.times.map do |t|
      Thread.new do
        20.times do |i|
          ClientInfoStore.update_for_client_key(client_key, :browser_tab_ids, default: {}) do |tab_ids|
            tab_ids["#{t}_#{i}"] = { last_request: Time.now }
            tab_ids
          end
        end
      end
    end
    threads.each(&:join)
    assert_equal 200, ClientInfoStore.read_for_client_key(client_key, :browser_tab_ids).count, 'No update should be lost by concurrent writes'
  ensure
    ClientInfoStore.instance.delete(client_key)
  end

  test "cleanup keeps browser tab id reserved until reuse delay" do
    client_key = "test_cleanup_browser_tab_ids_#{SecureRandom.hex(8)}"
    ClientInfoStore.write_for_client_key(client_key, :browser_tab_ids, {
      1 => { last_request: Time.now,                                                       current_database: { user: 'a' } },
      2 => { last_request: Panorama::MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST.ago - 1.hour, current_database: { user: 'b' } },
      3 => { last_request: Panorama::BROWSER_TAB_ID_REUSE_DELAY.ago - 1.hour,              current_database: { user: 'c' } },
    })
    ClientInfoStore.cleanup
    tab_ids = ClientInfoStore.read_for_client_key(client_key, :browser_tab_ids)
    assert_equal({ user: 'a' }, tab_ids[1][:current_database], 'Active browser tab should keep its session state')
    assert tab_ids.key?(2), 'Expired browser tab id should still be reserved'
    assert_nil tab_ids[2][:current_database], 'Session state of expired browser tab should be removed'
    assert !tab_ids.key?(3), 'Browser tab id should be removed after reuse delay'
  ensure
    ClientInfoStore.instance.delete(client_key)
  end
end
