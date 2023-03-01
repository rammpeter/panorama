# encoding: utf-8

module AdditionHelper

  # Suppress partition types from beeing named
  def compact_object_type_sql_case(object_type_name)
    "CASE
       WHEN #{object_type_name} = 'INDEX PARTITION'    THEN 'INDEX'
       WHEN #{object_type_name} = 'INDEX SUBPARTITION' THEN 'INDEX'
       WHEN #{object_type_name} = 'LOB PARTITION'      THEN 'LOBSEGMENT'
       WHEN #{object_type_name} = 'LOB SUBPARTITION'   THEN 'LOBSEGMENT'
       WHEN #{object_type_name} = 'NESTED TABLE'       THEN 'TABLE'
       WHEN #{object_type_name} = 'TABLE PARTITION'    THEN 'TABLE'
       WHEN #{object_type_name} = 'TABLE SUBPARTITION' THEN 'TABLE'
     ELSE #{object_type_name} END
    "
  end

  def blocking_locks_groupfilter_values(key)

    retval = {
      "Blocking_Event"      => {:sql => 'l.blocking_Event'},
      "Event"               => {:sql => 'l.Event'},
      "Blocking_Status"     => {:sql => 'l.Blocking_Status'},
      "Snapshot_Timestamp" => {:sql => "l.Snapshot_Timestamp =TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true },
      "Min_Timestamp"     => {:sql => "l.Snapshot_Timestamp>=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
      "Max_Timestamp"     => {:sql => "l.Snapshot_Timestamp<=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
      "Instance"          => {:sql => "l.Instance_Number",          alias: 'instance_number' },
      "SID"               => {:sql => "l.SID"},
      "Serial_No"          => {:sql => "l.Serial_No"},
      "Hide_Non_Blocking" => {:sql => "NVL(l.Blocking_SID, '0') != ?", :already_bound => true },
      "Blocking Object"   => {:sql => "LOWER(l.Blocking_Object_Owner)||'.'||l.Blocking_Object_Name", alias: 'blocking_object' },
      "SQL-ID"            => {:sql => "l.SQL_ID",                   alias: 'sql_id'},
      "Module"            => {:sql => "l.Module"},
      "Objectname"        => {:sql => "l.Object_Name",              alias: 'object_name'},
      "Locktype"          => {:sql => "l.Lock_Type",                alias: 'lock_type'},
      "Request"           => {:sql => "l.Request"},
      "LockMode"          => {:sql => "l.Lock_Mode",                alias: 'lock_mode'},
      "RowID"             => {:sql => "CAST(l.blocking_rowid AS VARCHAR2(18))", alias: 'blocking_rowid'},
      "B.Instance"        => {:sql => 'l.blocking_Instance_Number', alias: 'blocking_instance_number'},
      "B.SID"             => {:sql => 'l.blocking_SID',             alias: 'blocking_sid'},
      "B.SQL-ID"          => {:sql => 'l.blocking_SQL_ID',          alias: 'blocking_sql_id'},
    }[key.to_s]
    raise "blocking_locks_groupfilter_values: unknown key '#{key}' of class #{key.class}" unless retval
    retval
  end

  def worksheet_bind_types
    {
      'Content dependent' => { type_class: ActiveRecord::Type::Value,   test_sql_value: 5,              test_bind_value: 5 } ,
      'String'            => { type_class: ActiveRecord::Type::String,  test_sql_value: "'Hugo'",       test_bind_value: 'Hugo' },
      'Integer'           => { type_class: ActiveRecord::Type::Integer, test_sql_value: 3,              test_bind_value: 3 },
      'Float'             => { type_class:  ActiveRecord::Type::Float,  test_sql_value: 5.3,            test_bind_value: 5.3 },
      'Date/Time'         => { type_class:  ActiveRecord::Type::Time,   test_sql_value: "TO_DATE('01.11.2023 13:45', 'DD.MM.YYYY HH24:MI')", test_bind_value: '01.11.2023 13:45' }
    }
  end
end

