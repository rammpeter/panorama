# encoding: utf-8
module Dragnet::ViewIssuesHelper

  private

  def view_issues
    [
        {
            :name  => t(:dragnet_helper_138_name, :default => 'Views with outer ORDER BY in View-SQL'),
            :desc  => t(:dragnet_helper_138_desc, :default =>'Sorting of SQL result at the end of a view-SQL often is unnecessary because it is not known in view how the calling SQL processes the result.
Sorting should be placed in calling SQL instead of view if necessary.
Selection is usable with Rel. 12.1 or greater
'),
            min_db_version: '12.1',
            :sql=> "\
WITH
  FUNCTION fCheck(owner IN VARCHAR2, view_name IN VARCHAR2) RETURN VARCHAR2 IS
    Pos NUMBER;
    Res CLOB;
  BEGIN
    Res := DBMS_METADATA.GET_DDL(object_type => 'VIEW', name => view_name, schema => owner);
    Pos := DBMS_LOB.Instr(UPPER(Res), 'ORDER BY');
    IF Pos > 0 AND NOT DBMS_LOB.Instr(DBMS_LOB.SubStr(lob_loc => Res, offset => Pos), ')') > 0 THEN
      RETURN 'YES';
    ELSE
      RETURN 'NO';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN RETURN SQLERRM;
  END;
  Views AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, View_Name
            FROM   DBA_Views
            WHERE  Owner NOT IN (#{system_schema_subselect})
           )
SELECT Owner, View_Name, Check_Result
FROM   (SELECT Owner, View_Name, fCheck(Owner, View_Name) Check_Result
        FROM   Views
       )
WHERE  Check_Result != 'NO'
",
            :parameter=>[]
        },

    ]
  end # view_issues

end