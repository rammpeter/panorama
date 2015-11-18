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
          ioutput << "<li><a href='"
          ioutput << url_for(
              :controller =>:help,
              :action => :content,
              :last_used_menu_action      => m[:action],
              :last_used_menu_controller  => m[:controller],
              :last_used_menu_caption     => m[:caption],
              :last_used_menu_hint        => m[:hint]
          )
          ioutput << "'>#{m[:caption]}</a>&nbsp;&nbsp;&nbsp; #{m[:hint]}</li>"
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

    render :template=>"help/index"
  end

  # Themenspezifische Seite zu zuletzt ausgeführtem Menü-Eintrag
  def content
    @last_used_menu_caption = read_from_client_info_store(:last_used_menu_caption)                  # Default
    @last_used_menu_hint    = read_from_client_info_store(:last_used_menu_hint)                     # Default

    @last_used_menu_caption = params[:last_used_menu_caption] if params[:last_used_menu_caption]
    @last_used_menu_hint    = params[:last_used_menu_hint]    if params[:last_used_menu_hint]

    begin
    render :template=>"help/help_#{read_from_client_info_store(:last_used_menu_controller)}_#{read_from_client_info_store(:last_used_menu_action)}"
    rescue Exception=>e
      render :text=>t(:help_no_help_available, :default=>"Sorry no help yet available")+" '#{@last_used_menu_caption}' (#{@last_used_menu_hint})"
    end
  end

  def version_history

  end

end
