# encoding: utf-8
class TableDependenciesController < ApplicationController

private
  def fillNOAUser     # liefert Liste der NOA-User
    AllUser.all :conditions => "EXISTS (SELECT '!' FROM all_tables at \
                          WHERE at.owner=all_users.UserName \
                          AND at.Table_Name='EMTABLE')",
      :order => "UserName"
  end
  
public
  def show_frame
    @all_users = fillNOAUser
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "table_dependencies/show_frame" }');"}
    end
  end
  
  def select_schema
    @username = params["username"] ? params["username"] : params[:all_user][:username]
#    @username = params[:all_user][:username]
    @all_tables = AllTable.all :conditions => ["owner=?", @username]
    # Schema-Filter für Ergebnisanzeige
    @filter_users = []
    @filter_users << AllUser.new(:username=>"[Alle]")
    fillNOAUser.each do |user|
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

    noa_users = fillNOAUser   
    statement = "\
    SELECT * FROM (                                                                           \
      SELECT Level, x.*, RowNum RN FROM                                                                  \
      (                                                                                       \
        SELECT  DISTINCT                                                                      \
          child.Owner       ChildOwner,                                                       \
          child.Owner||'.'||child.Table_Name  ChildTable,                                     \
          parent.Owner      ParentOwner,                                                      \
          parent.Owner||'.'||parent.Table_Name ParentTable                                    \
        FROM  all_constraints child,                                                          \
              all_constraints parent                                                          \
        WHERE   child.Constraint_Type='R'                                                     \
        AND     parent.Constraint_Name = child.R_Constraint_Name                              \
        AND     parent.Owner           = child.R_Owner                                        \
        AND     parent.Table_Name != child.Table_Name       /* keine Selbstreferenzen */      \
      ) x                                                                                     \
      CONNECT BY PRIOR ChildTable = ParentTable                                               \
      START WITH ParentTable='"+@username+"."+@tablename+"') x,                             \
      ("
    # Union SELECT aller EMTable der NOA-User zur Ermittlung TableTypeShort
    first=true  
    noa_users.each do |user|
      if first
        first = false
      else
        statement += "UNION ALL "
      end
      statement += "SELECT '" + user.username + "' Owner, Name, TableTypeShort, Documentation FROM " + user.username + ".EMTable "
    end
    statement += ") emtable WHERE x.ChildTable = emtable.Owner||'.'||UPPER(emtable.Name) 
                 #{@filter_user != '[Alle]' ? " AND ChildOwner='"+@filter_user+"' " : ""}
                 ORDER BY RN"
    @dependencies = AllTable.find_by_sql(statement)
    
    if params[:onlyMasterData] == "1"
      masterdependencies = []
      @dependencies.each do |dependency|
        masterdependencies << dependency if dependency.tabletypeshort == 'M'                        
      end
      @dependencies = masterdependencies 
    end
    
    respond_to do |format|
      format.js {render :js => "$('#dependencies').html('#{j render_to_string :partial=>"show_dependencies" }');"}
    end
  end
end
