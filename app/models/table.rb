class Table
  attr_reader :owner, :table_name

  def initialize(owner, table_name)
    @owner = owner
    @table_name = table_name
  end

  # get the foreign key references from this table to other tables
  # @return [Array<Reference>]
  def references_from(constraint_name: nil, index_owner: nil, index_name: nil)

    where_string = String.new
    where_values = []

    if constraint_name
      where_string << "AND c.Constraint_Name = ?"
      where_values << constraint_name
    end

    if index_owner && index_name
      where_string << "AND c.Constraint_Name IN (SELECT cc.Constraint_Name
                                                 FROM   Cons_Columns cc /*+ Constraint_Type 'R' is filtered by outer SQL on c.Constraint_Name */
                                                 LEFT OUTER JOIN Ind_Columns ic ON ic.Column_Name = cc.Column_Name AND ic.Index_Owner = ? AND ic.Index_Name  = ?
                                                 GROUP BY cc.Constraint_Name
                                                 HAVING COUNT(*) = COUNT(DISTINCT ic.Column_Name) /* First columns of index match constraint columns */
                                                 AND MAX(cc.Position) = MAX(ic.Column_Position)  /* all matching columns of an index are starting from left without gaps */
                                                 AND MIN(cc.Position) = 1 /* Consider all constraint columns starting with the first */
                                                 AND MIN(cc.Column_Count) = COUNT(*) /* All columns of the constraint are contained in index */
                                                )"
      where_values << index_owner
      where_values << index_name
      where_values << owner
      where_values << table_name
    end

    PanoramaConnection.sql_select_all ["\
      WITH Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, Column_Name, Position,
                                   COUNT(*) OVER (PARTITION BY Constraint_Name) Column_Count
                            FROM   DBA_Cons_Columns WHERE Owner = ? AND Table_Name = ?),
           Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_Name, Column_Position FROM DBA_Ind_Columns WHERE Table_Owner = ? AND Table_Name = ?)
      SELECT c.*, r.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows, pi.Min_Index_Owner, pi.Min_Index_Name, pi.Index_Number, rt.Last_Analyzed, m.Inserts, m.Updates, m.Deletes,
             #{PanoramaConnection.db_version >= "11.2" ?
                                                     "(SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      " :
                                                     "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      "
    }
      FROM   DBA_Constraints c
      JOIN   DBA_Constraints r    ON r.Owner = c.R_Owner AND r.Constraint_Name = c.R_Constraint_Name
      JOIN   DBA_All_Tables rt        ON rt.Owner = r.Owner AND rt.Table_Name = r.Table_Name
      LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = rt.Owner AND m.Table_Name = rt.Table_Name AND m.Partition_Name IS NULL    -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
      LEFT OUTER JOIN  (SELECT Owner, Constraint_Name,
                               MIN(Index_Owner) KEEP (DENSE_RANK FIRST ORDER BY Index_Name) Min_Index_Owner, MIN(Index_Name) Min_Index_Name,
                               COUNT(*) Index_Number
                        FROM   (
                                SELECT /*+ NO_MERGE */ cc.Owner, cc.Constraint_Name, ic.Index_Owner, ic.Index_Name
                                FROM   Cons_Columns cc
                                LEFT OUTER JOIN Ind_Columns ic ON ic.Column_Name = cc.Column_Name
                                GROUP BY ic.Index_Owner, ic.Index_Name, cc.Owner, cc.Constraint_Name
                                HAVING COUNT(*) = COUNT(DISTINCT ic.Column_Name) /* First columns of index match constraint columns */
                                AND MAX(cc.Position) = MAX(ic.Column_Position)  /* all matching columns of an index are starting from left without gaps */
                                AND MIN(cc.Position) = 1 /* Consider all constraint columns starting with the first */
                                AND MIN(cc.Column_Count) = COUNT(*) /* All columns of the constraint are contained in index */
                               )
                        GROUP BY Owner, Constraint_Name
                       ) pi ON pi.Owner = c.Owner AND pi.Constraint_Name = c.Constraint_Name
      WHERE  c.Constraint_Type = 'R'
      AND    c.Owner      = ?
      AND    c.Table_Name = ?
      #{where_string}
                                  ", owner, table_name, owner, table_name, owner, table_name].concat(where_values)
  end

  # get the foreign key references to this table from other tables
  # @return [Array<Reference>]
  def references_to
    PanoramaConnection.sql_select_all ["\
      WITH Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, Column_Name, Position,
                                   COUNT(*) OVER (PARTITION BY Owner, Constraint_Name) Column_Count
                            FROM   DBA_Cons_Columns
                           )
      SELECT c.*, ct.Num_Rows,  pi.Min_Index_Owner, pi.Min_Index_Name, pi.Index_Number, rt.Num_rows r_Num_Rows,
             #{PanoramaConnection.db_version >= "11.2" ?
                                                      "(SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      " :
                                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      "
    }
      FROM   DBA_Constraints r
      JOIN   DBA_Constraints c ON c.R_Owner = r.Owner AND c.R_Constraint_Name = r.Constraint_Name
      JOIN   DBA_All_Tables ct ON ct.Owner = c.Owner AND ct.Table_Name = c.Table_Name
      JOIN   DBA_All_Tables rt ON rt.Owner = r.Owner AND rt.Table_Name = r.Table_Name
      LEFT OUTER JOIN  (SELECT Owner, Constraint_Name,
                               MIN(Index_Owner) KEEP (DENSE_RANK FIRST ORDER BY Index_Name) Min_Index_Owner, MIN(Index_Name) Min_Index_Name,
                               COUNT(*) Index_Number
                        FROM   (
                                SELECT /*+ NO_MERGE */ cc.Owner, cc.Constraint_Name, ic.Index_Owner, ic.Index_Name
                                FROM   Cons_Columns cc
                                LEFT OUTER JOIN DBA_Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name AND ic.Column_Name = cc.Column_Name
                                GROUP BY ic.Index_Owner, ic.Index_Name, cc.Owner, cc.Constraint_Name
                                HAVING COUNT(*) = COUNT(DISTINCT ic.Column_Name) /* First columns of index match constraint columns */
                                AND MAX(cc.Position) = MAX(ic.Column_Position)  /* all matching columns of an index are starting from left without gaps */
                                AND MIN(cc.Position) = 1 /* Consider all constraint columns starting with the first */
                                AND MIN(cc.Column_Count) = COUNT(*) /* All columns of the constraint are contained in index */
                               )
                        GROUP BY Owner, Constraint_Name
                       ) pi ON pi.Owner = c.Owner AND pi.Constraint_Name = c.Constraint_Name
      WHERE  c.Constraint_Type = 'R'
      AND    r.Owner      = ?
      AND    r.Table_Name = ?
      ", owner, table_name]
  end
end