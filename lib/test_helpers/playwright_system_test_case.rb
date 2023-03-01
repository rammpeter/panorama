# encoding: UTF-8
require 'puma'
require 'playwright'
require 'rack/handler/puma'

=begin
Precondition for using playwright
npx playwright install

=end

class PlaywrightSystemTestCase < ActiveSupport::TestCase

  def setup
    set_session_test_db_context
    set_I18n_locale('en')
    initialize_min_max_snap_id_and_times(:minutes)
    ensure_playwright_is_up
    super
  end

  def teardown
    unless self.passed?
      unless @@pw_page.nil?
        screenshot_dir = "#{Rails.root}/tmp/screenshots"
        Dir.mkdir(screenshot_dir) unless File.exists?(screenshot_dir)
        filename = method_name.clone
        filename.gsub!(/\//, '_') if filename['/']
        filepath = "#{screenshot_dir}/#{filename}.png"
        @@pw_page.screenshot(path: filepath)
        Rails.logger.debug(PlaywrightSystemTestCase.teardown){"Screenshot created at '#{filepath}'"}
      else
        Rails.logger.error(PlaywrightSystemTestCase.teardown){"Screenshot not possible because @@pw_page not initialized"}
      end
    end
    super
  end

  @@pw_browser     = nil
  @@pw_page        = nil
  @@host           = nil
  @@port           = nil
  def ensure_playwright_is_up
    if @@pw_browser.nil?
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "@@pw_browser == nil, starting puma" }
      #      pw_puma_server = Puma::Server.new(Rails.application, Puma::Events.stdio, max_threads:100)
      pw_puma_server = Puma::Server.new(Rails.application, nil, max_threads:100)
      @@host = '127.0.0.1'
      @@port = pw_puma_server.add_tcp_listener(@@host, 0).addr[1]
      pw_puma_server.run
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "Playwright.create" }
      playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "playwright.playwright.chromium.launch" }
      @@pw_browser  = playwright.playwright.chromium.launch(
        headless: RbConfig::CONFIG['host_os'] != 'darwin',
        args: ['--no-sandbox']                                                  # allow running chrome as root
      )
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "@@pw_browser.new_page" }
      @@pw_page = @@pw_browser.new_page(viewport: { width: 800, height: 600 })
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "@@pw_browser.set_timeout" }
      @@pw_page.set_default_timeout(30000)
      do_login

      MiniTest.after_run do                                                       # called at exit of program
        pw_puma_server&.stop
        @@pw_browser&.close
        playwright&.stop
      end
    else
      Rails.logger.debug('PlaywrightSystemTestCase.ensure_playwright_is_up') { "@@pw_browser != nil, no action needed" }
    end
  end

  def page
    @@pw_page
  end

  def do_login
    Rails.logger.debug('PlaywrightSystemTestCase.do_login') { "goto http" }
    page.goto("http://#{@@host}:#{@@port}")

    test_config = PanoramaTestConfig.test_config
    # page.screenshot(path: '/tmp/playwright.png')
    #
    if test_config[:tns_or_host_port_sn] == :TNS
      page.check("#database_modus_tns")
      page.select_option('#database_tns', value: test_config[:tns])
    else
      page.check("#database_modus_host")
      page.fill('#database_host', test_config[:host])

      page.fill('#database_port', test_config[:port])

      page.check('#database_sid_usage_SERVICE_NAME')
      page.fill('#database_sid', test_config[:sid])
    end

    page.fill('#database_user', test_config[:user])
    page.fill('#database_password', test_config[:password_decrypted])
    page.click('#submit_login_dialog')
    page.wait_for_selector('#management_pack_license_diagnostics_pack')   # dialog shown
    page.check("#management_pack_license_#{management_pack_license}")
    page.click('text="Acknowledge and proceed"')
    page.wait_for_selector('#main_menu')
  end

  # Call menu, last argument is DOM-ID of menu entry to click on
  # previous arguments are captions of submenus for hover to open submenu
  # @param entries
  # @param retries: Number of already executed recursive retries
  # @param entry_with_condition: does the menu entry have a condition that may have changed since creating the menu in Puma. Tolerate non-existence in this case
  def menu_call(entries, retries: 0, entry_with_condition: false)
    raise "Parameter entries should be of type Array, not #{entries.class}" unless entries.instance_of?(Array)
    if page.visible?('#main_menu >> #menu_node_0')                              # menu 'Menu' if exists (small window width)
      log_exception('menu_call: hover for #menu_node_0') do
        page.hover('#main_menu >> #menu_node_0')                                # Open first level menu under "Menu"
      end
    end

    entries.each_index do |i|
      sleep(retries)                                                            # Add a sleep in retry
      if i < entries.length-1                                                   # SubMenu
        log_exception("menu_call: hover at submenu #{entries[i]}") do
          page.hover("#main_menu >> .sf-with-ul >> text =\"#{entries[i]}\"", timeout: 30000) # Expand menu node
        end
      else                                                                      # last argument is DOM-ID of menu entry to click on
        log_exception("menu_call: click at menu'#{entries[i]}'") do
          begin
            # possibly comment out because it catched non visible tooltips
            # check_for_tooltip
            page.click("##{entries[i]}")                                          # click menu
          rescue
            if entry_with_condition
              msg = "No menu entry found to click for '#{entries[i]}'! Tolerate non-existence because menu entry has a condition that may have changed."
              puts msg
              Rails.logger.debug('PlaywrightSystemTestCase.menu_call') { msg }
            else
              raise
            end
          end
        end
      end
    end
    assert_ajax_success_and_test_for_access_denied                              # Accept error dur to missing rights on Diagnostics or Tuning pack
  rescue Exception=>e
    screenshot_path = "/tmp/screenshot_#{e.class}.png"
    puts "#{e.class}:#{e.message}: Screenshot created at #{screenshot_path}"
    page.screenshot(path: screenshot_path)
    if retries < 3
      msg = "#{e.class}:#{e.message}: Starting #{retries+1}. retry with new login"
      puts msg
      Rails.logger.warn("#{self.class}.menu_call"){ msg }
      do_login                                                                  # Login again to clear the page with possibly overlapping tooltip
      menu_call(entries, retries: retries+1)
    else
      raise
    end

  end

  # remove possible tooltips the prevent playwright from clicking an action
  # Don't use for hover, only before click
  def check_for_tooltip
    tooltip = page.query_selector('.ui-tooltip:visible')
    if tooltip
      page.screenshot(path: '/tmp/check_for_tooltip.png')
      msg = "Trying to close tooltip with content '#{tooltip.inner_html}'"
      puts "PlaywrightSystemTestCase.check_for_tooltip': #{msg}"
      Rails.logger.debug('PlaywrightSystemTestCase.check_for_tooltip') { msg }
      tooltip.click                                                             # Try to close tooltip by clicking on it to allow next retry to proceed
      page.screenshot(path: '/tmp/check_for_tooltip_after_click.png')
    end
  end

  def wait_for_ajax(timeout_secs = 5)
    # page.expect_request_finished
    loop_count = 0
    while page.evaluate('indicator_call_stack_depth') > 0 && loop_count < timeout_secs
      sleep(0.1)
      loop_count += 0.1
      # puts "After #{loop_count} seconds: indicator_call_stack_depth = #{page.evaluate_script('indicator_call_stack_depth')}"
    end
    if loop_count >= timeout_secs
      message = "Timeout raised in wait_for_ajax after #{loop_count} seconds, indicator_call_stack_depth=#{page.evaluate('indicator_call_stack_depth') }"
      Rails.logger.error "############ #{message}"
      raise message
    end

    # Wait until indicator dialog becomes really unvisible
    loop_count = 0
    while page.query_selector('#ajax_indicator:visible') && loop_count < timeout_secs   # only visible elements evaluate to true in has_css?
      Rails.logger.info "wait_for_ajax: ajax_indicator is still visible, retrying..."
      sleep(0.1)                                                                # Allow browser to update DOM after setting ajax_indicator invisible
      loop_count += 0.1
    end
    if loop_count >= timeout_secs
      message = "Timeout raised in wait_for_ajax after #{loop_count} seconds, indicator-dialog did not disappear') }"
      Rails.logger.error "############ #{message}"
      raise message
    end
  end

  def assert_ajax_success(timeout_secs = 60)
    wait_for_ajax(timeout_secs)
    assert_not error_dialog_open?
  end

  # Does the page contain the text
  def assert_text(expected_text)
    assert(page.content[expected_text], "Page should contain: #{expected_text}")
  end

  def error_dialog_open?
    # Visibility of role="dialog" cannot be checked by playwright
    page.evaluate("jQuery('#error_dialog').is(':visible')")
  end

  # accept error due to missing management pack license
  # Error message "Access denied" called for _management_pack_license = :none ?
  def assert_ajax_success_and_test_for_access_denied(timeout_secs = 120)
    wait_for_ajax(timeout_secs)

    if  error_dialog_open?
      allowed_msg_content = []
      if management_pack_license != :diagnostics_and_tuning_pack
        allowed_msg_content << 'Sorry, accessing DBA_HIST_Reports requires licensing of Diagnostics and Tuning Pack'
      end

      if management_pack_license == :none
        allowed_msg_content <<  'because of missing license for '               # Access denied on table
      end

      raise_error = true
      error_dialog = page.query_selector('#error_dialog')                       # ErrorDialog already checked to be open
      err_dialog_text_content = error_dialog.text_content
      allowed_msg_content.each do |amc|
        if err_dialog_text_content[amc]                                         # No error if dialog contains any of the strings
          raise_error = false
          begin
            page.click('#error_dialog_close_button')                            # Close the error dialog to ensure next actions may see the target, use ID for identification
          rescue Exception
            sleep(5)                                                            # retry after x seconds if exception raised
            page.click('#error_dialog_close_button')                            # Close the error dialog to ensure next actions may see the target, use ID for identification
          end
        end
      end

      assert(!raise_error, "ApplicationSystemTestCase.assert_ajax_success_or_access_denied: Error dialog raised but not because missing management pack license.\nmanagement_pack_license = #{management_pack_license} (#{management_pack_license.class})\nError dialog:\n#{err_dialog_text_content}")
      return true
    else
      return false                                                              # Error dialog not shown
    end
  end

  def close_possible_popup_message
    # Visibility of role="dialog" cannot be checked by playwright
    log_exception('close_possible_popup_message') do
      page.evaluate("
        if (jQuery('.ui-dialog-titlebar-close').length){
          jQuery('.ui-dialog-titlebar-close').click();
        }"
      )
    end
  end


  def log_exception(context)
    yield
  rescue Exception => e
    Rails.logger.error("#{self.class}.log_exception"){ "#{e.class}:#{e.message}: at #{context}" }
    raise
  end

  private

end
