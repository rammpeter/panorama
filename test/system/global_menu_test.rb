require "test_helper"

class GlobalMenuTest < PlaywrightSystemTestCase
  include MenuHelper

  def exec_menu_array(menu_array, sub_menu_list)
    menu_array.each do |entry|
      curr_sub_menu_list = sub_menu_list.clone

      if entry[:class] == 'menu'
        curr_sub_menu_list << entry[:caption]
        exec_menu_array(entry[:content], curr_sub_menu_list)
      end
      if entry[:class] == 'item'
        curr_sub_menu_list << "menu_#{entry[:controller]}_#{entry[:action]}"
        begin
          menu_call(curr_sub_menu_list, entry_with_condition: !entry[:condition].nil?)
          close_possible_popup_message                                            # close potential popup message from call
        rescue Exception => e
          log_exception_backtrace(e)
          msg = "Exception #{e.class}: #{e.message}\nProcessing menu entry #{curr_sub_menu_list}"
          Rails.logger.error("#{self.class}.exec_menu_array"){ msg }
          raise msg
        end
      end
    end
  end

  test "Exec all menu entries" do
    exec_menu_array(menu_content_for_db, []);
  end
end