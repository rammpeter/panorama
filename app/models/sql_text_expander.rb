# Expand SQL statements by replacing the accessed views with their SQL text
class SqlTextExpander

  # Expand a SQL statement by DBMS_UTILITY.expand_sql_text
  # Unqualified object names are resolved in the schema of the current Panorama user
  # @param [String] sql_text The SQL statement to expand
  # @return [String] The expanded SQL statement, nil if sql_text is nil
  def self.expand(sql_text)
    return nil if sql_text.nil?
    PanoramaConnection.sql_select_one ["\
      WITH
        FUNCTION Expand(p_Org_SQL CLOB) RETURN CLOB
        IS
        v_Expanded_SQL CLOB;
        BEGIN
          DBMS_UTILITY.expand_sql_text(input_sql_text => p_Org_SQL, output_sql_text => v_Expanded_SQL);
          RETURN v_Expanded_SQL;
        END;
      SELECT Expand(?) FROM DUAL", sql_text]
  end
end
