require 'test_helper'

class TableTest < ActiveSupport::TestCase

  def drop_table_if_exists(owner, table_name)
    if PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM DBA_All_Tables WHERE Owner = ? AND Table_Name = ?", owner, table_name]) > 0
      PanoramaConnection.sql_execute("DROP TABLE #{owner}.#{table_name} CASCADE CONSTRAINTS")
    end
  end

  setup do
    set_session_test_db_context
  end

  test "references from and to" do
    drop_table_if_exists(PanoramaConnection.username, 'T1')
    drop_table_if_exists(PanoramaConnection.username, 'T2')
    PanoramaConnection.sql_execute("CREATE TABLE #{PanoramaConnection.username}.T1 (ID1 NUMBER, ID2 NUMBER, ID3 NUMBER)")
    PanoramaConnection.sql_execute("CREATE TABLE #{PanoramaConnection.username}.T2 (ID2 NUMBER PRIMARY KEY)")
    PanoramaConnection.sql_execute("ALTER TABLE T1 ADD CONSTRAINT T1_T2_FK FOREIGN KEY(ID2) REFERENCES #{PanoramaConnection.username}.T2(ID2)")
    # Create an index that is not protecting the foreign key
    PanoramaConnection.sql_execute("CREATE INDEX IX_T1_1 ON #{PanoramaConnection.username}.T1 (ID1, ID2, ID3)")
    Table.new(PanoramaConnection.username, 'T1').references_from.each do |ref|
      assert_nil ref.min_index_name, "There should not be a protecting index for foreign key #{ref.constraint_name} T1"
    end

    Table.new(PanoramaConnection.username, 'T2').references_to.each do |ref|
      assert_nil ref.min_index_name, "There should not be a protecting index for foreign key #{ref.constraint_name} T2"
    end

    # Create an index that is protecting the foreign key because the first column is the FK column
    PanoramaConnection.sql_execute("CREATE INDEX IX_T1_2 ON #{PanoramaConnection.username}.T1 (ID2, ID1, ID3)")
    Table.new(PanoramaConnection.username, 'T1').references_from.each do |ref|
      assert_not_nil ref.min_index_name, "There should be a protecting index for foreign key #{ref.constraint_name} T1"
    end

    Table.new(PanoramaConnection.username, 'T2').references_to.each do |ref|
      assert_not_nil ref.min_index_name, "There should be a protecting index for foreign key #{ref.constraint_name} T2"
    end

    drop_table_if_exists(PanoramaConnection.username, 'T1')
    drop_table_if_exists(PanoramaConnection.username, 'T2')
  end
end
