class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include ActionView::Helpers::TranslationHelper
  include MenuHelper

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  def call_controllers_menu_entries_with_actions

    def call_menu_entry_test_helper(menu_entry)
      menu_entry[:content].each do |m|
        call_menu_entry_test_helper(m) if m[:class] == "menu"       # Rekursives Abtauchen in Menüstruktur
        if m[:class] == "item" &&
            controller_action_defined?(m[:controller], m[:action]) &&           # Controller hat eine Action-Methode für diesen Menü-Eintrag
            "#{m[:controller]}_controller".camelize == @controller.class.name   # Nur Menues des aktuellen Controllers testen

          @request.accept = "text/html, */*; q=0.01"

          get m[:action], :params => {:update_area=>:hugo }
          assert_response(:success, "Error calling #{m[:controller]}/#{m[:action]}, response_code=#{@response.response_code}")
        end
      end
    end

    # Iteration über Menues
    menu_content.each do |mo|
      call_menu_entry_test_helper(mo)
    end

  end
end
