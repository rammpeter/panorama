# encoding: utf-8
require 'test_helper'

class TestHelperTest < ActiveSupport::TestCase
  test 'autonomous table cleanup continues after Oracle deadlocks' do
    truncated_tables = []
    execute_sql = proc do |sql|
      truncated_tables << sql
      raise Exception, 'ORA-00060: deadlock detected while waiting for resource'
    end

    PanoramaConnection.stub(:autonomous_database?, true) do
      PanoramaConnection.stub(:table_exists?, true) do
        PanoramaConnection.stub(:sql_execute, execute_sql) do
          assert_nothing_raised do
            shrink_table_size_for_always_free_autonomous_db(owner: 'PANORAMA_TEST')
          end
        end
      end
    end

    assert_equal 3, truncated_tables.length
  end

  test 'autonomous table cleanup propagates errors other than Oracle deadlocks' do
    PanoramaConnection.stub(:autonomous_database?, true) do
      PanoramaConnection.stub(:table_exists?, true) do
        PanoramaConnection.stub(:sql_execute, proc { raise Exception, 'unexpected Oracle error' }) do
          assert_raises(Exception) do
            shrink_table_size_for_always_free_autonomous_db(owner: 'PANORAMA_TEST')
          end
        end
      end
    end
  end
end
