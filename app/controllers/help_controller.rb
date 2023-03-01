# encoding: utf-8
class HelpController < ApplicationController
  include ApplicationHelper
  include MenuHelper
  layout "help_layout"

  def overview
    def print_menu_entry(menu_entry)
      ioutput = ""
      ioutput << "<h3>#{menu_entry[:caption]}</h3>"
      ioutput << "<ul>
      "
      menu_entry[:content].each do |m|
        ioutput << "<li>#{print_menu_entry(m) }</li>" if m[:class] == "menu"

        if m[:class] == "item"
          # Link selbst gebastelt da im Controller kein Aufruf von link_to möglich
          ioutput << "<li><b>#{m[:caption]}</b>&nbsp;&nbsp;&nbsp; #{m[:hint]}</li>"
        end
       end
       ioutput << "</ul>
       "
       ioutput
    end

    @menu_entry_help = ""
   menu_content.each do |m|
      @menu_entry_help << print_menu_entry(m)
    end

    @help_title = t(:help_function_overview, default: 'Function overview')
    render :template=>"help/index"
  end

  def version_history

  end

end
