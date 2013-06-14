# encoding: utf-8
class DragnetController < ApplicationController
  include DragnetHelper

  def show_selection
    @dragnet_sqls = dragnet_sqls  # Helper-method
    @select_options=[]
    groups = {}                   # Hash mit distinct group
    @dragnet_sqls.each do |s|
      groups[s[:group]] = 1
    end

    group_id = 0
    groups.each do |key, value|           # Iteration über Gruppen
      group_id += 1
      group = ["#{group_id}. #{key}"]     # Gruppe in Ausgabe mit fortlaufender Nummer versehen
      names = []                          # Neues Array mit Namen der Gruppe
      name_id = 0
      @dragnet_sqls.each_index do |i|
        if @dragnet_sqls[i][:group] == key   # Namen der Gruppe suchen
          name_id += 1
          names << [ "#{name_id}. #{@dragnet_sqls[i][:name]}", i]
        end
      end
      group << names
      @select_options << group
    end

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dragnet/show_selection" }');"}
    end
  end

  def refresh_selection_hint
    index = params[:array_index].to_i
    parameter = ""
    if dragnet_sqls[index][:parameter]        # Parameter erwähnt (erwartet als Array)
      dragnet_sqls[index][:parameter].each do |p|
        parameter << "<div>#{p[:name]} <input name='#{p[:name]}' size='#{p[:size]}' title='#{p[:title]}' value='#{p[:default]}' type='text'></div><br/>"
      end
    end
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j my_html_escape(dragnet_sqls[index][:desc]) }');
                                $('##{params[:param_area]}').html('#{j parameter }');"
      }
    end
  end

  # Ausführen Report
  def exec_dragnet_sql
    raise t(:dragnet_exec_dragnet_sql_selection_raise, :default=>"please select selection first") unless params[:dragnet]
    index = params[:dragnet][:selection].to_i
    dragnet_sql = dragnet_sqls[index]

    if params[:commit_show]    # Verzweigen auf weitere Funktion bei Anwahl zweiter Button
      show_used_sql(index)
      return
    end


    # Headerzeile des Report erstellen, Parameter ermitteln
    @caption = "#{dragnet_sql[:name]}"
    command_array = [dragnet_sql[:sql]]
    if dragnet_sql[:parameter]
      @caption << ": "
      dragnet_sql[:parameter].each do |p|   # Binden evtl. Parameter
        command_array << params[p[:name]]           # Parameter aus Form mit Name erwartet
        @caption << " '#{p[:name]}' = #{params[p[:name]]}"  # Ausgabe im Header
      end
    end



    # Ausführen des SQL
    @res = sql_select_all command_array

    # Optionales Filtern des Results
    if dragnet_sql[:filter_proc]
      raise "filter_proc muss Klasse proc besitzen für #{dragnet_sql[:name]}" if dragnet_sql[:filter_proc].class.name != "Proc"
      res = []
      @res.each do |r|
        res << r if dragnet_sql[:filter_proc].call(r)
      end
      @res = res
    end

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_dragnet_sql_result" }');"}
    end
  end

  def show_used_sql(index)


    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j "<div class='float_left' style='background-color:lightgray;'><pre>#{my_html_escape(dragnet_sqls[index][:sql])}</pre></div>" }');"}
    end
  end

end