require 'test_helper'

class SqlTextExpanderTest < ActiveSupport::TestCase

  setup do
    set_session_test_db_context
  end

  def drop_object_if_exists(object_type, name)
    if PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM User_Objects WHERE Object_Type = ? AND Object_Name = ?", object_type, name]) > 0
      PanoramaConnection.sql_execute("DROP #{object_type} #{name}")
    end
  end

  def expander_test_objects
    [['SYNONYM', 'S_EXP'], ['SYNONYM', 'S_CYC1'], ['SYNONYM', 'S_CYC2'], ['VIEW', 'V_EXP2'], ['VIEW', 'V_EXP1'], ['VIEW', 'V_CYC1'], ['VIEW', 'V_CYC2'], ['TABLE', 'T_EXP']]
  end

  test "expand" do
    assert_nil SqlTextExpander.expand(nil)
    if get_db_version >= '12.1'                                                 # WITH FUNCTION requires 12.1
      expanded_sql = SqlTextExpander.expand("SELECT * FROM SYS.DBA_Users")
      assert expanded_sql['"SYS"."USER$"'], "View DBA_Users should be replaced by its SQL text, but is #{expanded_sql}"
    end
  end

  test "expand by parser if DBMS_UTILITY fails" do
    return if get_db_version < '12.1'                                           # WITH FUNCTION requires 12.1
    expander_test_objects.each { |type, name| drop_object_if_exists(type, name) }
    begin
      PanoramaConnection.sql_execute "CREATE TABLE T_EXP (ID NUMBER, Name VARCHAR2(20))"
      PanoramaConnection.sql_execute "CREATE VIEW V_EXP1 AS SELECT ID, Name FROM T_EXP WHERE ID > 0"
      PanoramaConnection.sql_execute "CREATE VIEW V_EXP2 AS SELECT v.ID FROM V_EXP1 v"
      PanoramaConnection.sql_execute "CREATE SYNONYM S_EXP FOR V_EXP2"

      # DBMS_UTILITY.expand_sql_text fails with ORA-24256 because of the not existing table
      expanded_sql = SqlTextExpander.expand("SELECT s.ID FROM S_EXP s JOIN Not_Existing_XY n ON n.ID = s.ID")
      assert_match(/FROM \(SELECT v.ID FROM \(SELECT ID, Name FROM T_EXP WHERE ID > 0\) v\) s JOIN Not_Existing_XY n/i, expanded_sql)

      expander = SqlTextExpander.new
      username = PanoramaConnection.username.upcase

      # Original name is kept as alias, CTE names are not resolved
      expanded_sql = expander.expand_by_parser("WITH V_EXP2 AS (SELECT 1 ID FROM DUAL) SELECT V_EXP1.ID FROM #{username}.V_EXP1, V_EXP2", username)
      assert_match(/FROM \(SELECT ID, Name FROM T_EXP WHERE ID > 0\) V_EXP1, V_EXP2\z/i, expanded_sql)

      # Circular references must not lead to infinite loops
      PanoramaConnection.sql_execute "CREATE SYNONYM S_CYC1 FOR S_CYC2"
      PanoramaConnection.sql_execute "CREATE SYNONYM S_CYC2 FOR S_CYC1"
      PanoramaConnection.sql_execute "CREATE FORCE VIEW V_CYC1 AS SELECT * FROM V_CYC2"
      PanoramaConnection.sql_execute "CREATE OR REPLACE FORCE VIEW V_CYC2 AS SELECT * FROM V_CYC1"
      expanded_sql = expander.expand_by_parser("SELECT * FROM S_CYC1, V_CYC1", username)
      assert_match(/S_CYC1/i, expanded_sql)
      assert_match(/V_CYC1/i, expanded_sql)
    ensure
      expander_test_objects.each { |type, name| drop_object_if_exists(type, name) }
    end
  end
end
