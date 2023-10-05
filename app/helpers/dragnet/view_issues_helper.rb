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
           ),
  Dependencies AS (SELECT /*+ NO_MERGE MATERIALIZE */ Referenced_Owner, Referenced_Name, COUNT(*) References
                   FROM   DBA_Dependencies
                   WHERE  Referenced_Type = 'VIEW'
                   GROUP BY Referenced_Owner, Referenced_Name
                  )
SELECT v.Owner, v.View_Name, d.References, v.Check_Result
FROM   (SELECT Owner, View_Name, fCheck(Owner, View_Name) Check_Result
        FROM   Views
       ) v
LEFT OUTER JOIN Dependencies d ON d.Referenced_Owner = v.Owner AND d.Referenced_Name = v.View_Name
WHERE  v.Check_Result != 'NO'
ORDER BY v.Check_Result DESC, d.References DESC NULLS LAST
",
            :parameter=>[]
        },

    ]
  end # view_issues

end