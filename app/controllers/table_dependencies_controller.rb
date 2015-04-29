# encoding: utf-8
class TableDependenciesController < ApplicationController

public
  def show_frame
    @all_users = sql_select_all "SELECT DISTINCT Owner UserName FROM DBA_Tables ORDER BY Owner"
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "table_dependencies/show_frame" }');"}
    end
  end
  
  def select_schema
    @username = params["username"] ? params["username"] : params[:all_user][:username]
    @all_tables = sql_select_all ['SELECT * FROM DBA_Tables WHERE Owner = ? ORDER BY Table_Name', @username]
    # Schema-Filter für Ergebnisanzeige
    @filter_users = []
    @filter_users << ({ :username => "[Alle]"}.extend SelectHashHelper)
    all_users = sql_select_all "SELECT DISTINCT Owner UserName FROM DBA_Tables ORDER BY Owner"
    all_users.each do |user|
      @filter_users << user
    end
    respond_to do |format|
      format.js {render :js => "$('#table_selection').html('#{j render_to_string :partial=>"show_tables" }');"}
    end
  end
  
  def find_dependencies
    @username = params[:username]
    @tablename = params[:all_table][:table_name]
    @filter_user = params[:filter_user][:username]

    noa_users = sql_select_all "SELECT * FROM DBA_Users ORDER BY UserName"
    @dependencies = sql_select_all "\
      SELECT Level, x.*, RowNum RN FROM
      (
        SELECT  DISTINCT
          child.Owner       ChildOwner,
          child.Table_Name  ChildTable,
          child.Owner||'.'||child.Table_Name ChildOwnerTable,
          parent.Owner      ParentOwner,
          parent.Table_Name ParentTable,
          parent.Owner||'.'||parent.Table_Name ParentOwnerTable
        FROM  DBA_constraints child,
              DBA_constraints parent
        WHERE   child.Constraint_Type='R'
        AND     parent.Constraint_Name = child.R_Constraint_Name
        AND     parent.Owner           = child.R_Owner
        AND     parent.Table_Name != child.Table_Name       /* keine Selbstreferenzen */
      ) x
      CONNECT BY NOCYCLE PRIOR ChildOwnerTable = ParentOwnerTable
      START WITH ParentOwnerTable='"+@username+"."+@tablename+"'"

    respond_to do |format|
      format.js {render :js => "$('#dependencies').html('#{j render_to_string :partial=>"show_dependencies" }');"}
    end
  end
end
