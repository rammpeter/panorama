# encoding: utf-8
class TableDependenciesController < ApplicationController

public
  def show_frame
    @all_users = sql_select_all "SELECT DISTINCT Owner UserName FROM DBA_Tables ORDER BY Owner"

    render_partial
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

    render_partial :show_tables
  end
  
  def find_dependencies
    @username = params[:username]
    @tablename = params[:all_table][:table_name]
    @filter_user = params[:filter_user][:username]

    @dependencies = sql_select_all "\
      SELECT Level, DECODE(CONNECT_BY_ISCYCLE, 1, 'YES') CONNECT_BY_ISCYCLE, x.*, RowNum RN FROM
      (
        SELECT  DISTINCT
          child.Owner       ChildOwner,
          child.Table_Name  ChildTable,
          child.Owner||'.'||child.Table_Name ChildOwnerTable,
          parent.Owner      ParentOwner,
          parent.Table_Name ParentTable,
          parent.Owner||'.'||parent.Table_Name ParentOwnerTable,
          parent.Constraint_Name Parent_Constraint_Name,
          child.Constraint_Name Child_Constraint_Name
        FROM  DBA_constraints child,
              DBA_constraints parent
        WHERE   child.Constraint_Type='R'
        AND     parent.Constraint_Name = child.R_Constraint_Name
        AND     parent.Owner           = child.R_Owner
        AND     parent.Table_Name != child.Table_Name       /* keine Selbstreferenzen */
      ) x
      CONNECT BY NOCYCLE PRIOR ChildOwnerTable = ParentOwnerTable
      START WITH ParentOwnerTable='"+@username+"."+@tablename+"'"

    render_partial :show_dependencies
  end
end
