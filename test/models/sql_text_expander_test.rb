require 'test_helper'

class SqlTextExpanderTest < ActiveSupport::TestCase

  setup do
    set_session_test_db_context
  end

  test "expand" do
    assert_nil SqlTextExpander.expand(nil)
    if get_db_version >= '12.1'                                                 # WITH FUNCTION requires 12.1
      expanded_sql = SqlTextExpander.expand("SELECT * FROM SYS.DBA_Users")
      assert expanded_sql['"SYS"."USER$"'], "View DBA_Users should be replaced by its SQL text, but is #{expanded_sql}"
    end
  end
end
