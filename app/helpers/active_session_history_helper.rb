# encoding: utf-8

module ActiveSessionHistoryHelper


  def session_statistics_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@session_statistics_key_rules_hash) || @session_statistics_key_rules_hash.nil?
      @session_statistics_key_rules_hash = {}
      @session_statistics_key_rules_hash["Instance"]    = {:sql => "s.Instance_Number",   :sql_alias => "instance_number",    :Name => 'Inst.',         :Title => 'RAC-Instance' }
      if get_db_version >= "11.2"
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "DECODE(s.QC_instance_ID, NULL, s.Session_ID||', '||s.Session_Serial_No, s.QC_Session_ID||', '||s.QC_Session_Serial#)",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, SerialNo. (if executed in parallel query this is SID/sn of PQ-coordinator session)',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session-Type" }
      else
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "s.Session_ID||', '||s.Session_Serial_No",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, SerialNo.',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session-Type" }
      end
      @session_statistics_key_rules_hash["Transaction"] = {:sql => "RawToHex(s.XID)",     :sql_alias => "transaction",        :Name => 'Tx.',           :Title => 'Transaction-ID' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["User"]        = {:sql => "u.UserName",          :sql_alias => "username",           :Name => "User",          :Title => "User" }
      @session_statistics_key_rules_hash["SQL-ID"]      = {:sql => "s.SQL_ID",            :sql_alias => "sql_id",             :Name => 'SQL-ID',        :Title => 'SQL-ID', :info_sql  => "(SELECT SUBSTR(t.SQL_Text,1,40) FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)", :info_caption => "SQL-Text (first chars)" }
      @session_statistics_key_rules_hash["SQL Exec-ID"] = {:sql => "s.SQL_Exec_ID",       :sql_alias => "sql_exec_id",        :Name => 'SQL Exec-ID',   :Title => 'SQL Execution ID', :info_sql  => "MIN(SQL_Exec_Start)", :info_caption => "Exec. start time"} if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Operation"]   = {:sql => "RTRIM(s.SQL_Plan_Operation||' '||s.SQL_Plan_Options)", :sql_alias => "operation", :Name => 'Operation', :Title => 'Operation of explain plan line' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Entry-PL/SQL"]= {:sql => "peo.Object_Type||CASE WHEN peo.Owner IS NOT NULL THEN ' ' END||peo.Owner||CASE WHEN peo.Object_Name IS NOT NULL THEN '.' END||peo.Object_Name||CASE WHEN peo.Procedure_Name IS NOT NULL THEN '.' END||peo.Procedure_Name",
                                                           :sql_alias => "entry_plsql_module", :Name => 'Entry-PL/SQL',      :Title => 'outermost PL/SQL module' }
      @session_statistics_key_rules_hash["PL/SQL"]      = {:sql => "po.Object_Type||CASE WHEN po.Owner IS NOT NULL THEN ' ' END||po.Owner||CASE WHEN po.Object_Name IS NOT NULL THEN '.' END||po.Object_Name||CASE WHEN po.Procedure_Name IS NOT NULL THEN '.' END||po.Procedure_Name",
                                                                                          :sql_alias => "plsql_module",       :Name => 'PL/SQL',        :Title => 'currently executed PL/SQL module' }
      @session_statistics_key_rules_hash["Module"]      = {:sql => "TRIM(s.Module)",      :sql_alias => "module",             :Name => 'Module',        :Title => 'Module set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["Action"]      = {:sql => "TRIM(s.Action)",      :sql_alias => "action",             :Name => 'Action',        :Title => 'Action set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["Event"]       = {:sql => "NVL(s.Event, s.Session_State)", :sql_alias => "event",    :Name => 'Wait-Event',    :Title => 'Event (Session-State, if Event = NULL)', :info_sql  => "MIN(s.Wait_Class)", :info_caption => "Wait-Class", :Data_Title => '#{explain_wait_event(rec.event)}' }
      @session_statistics_key_rules_hash["Wait-Class"]  = {:sql => "NVL(s.Wait_Class, 'CPU')", :sql_alias => "wait_class",    :Name => 'Wait-Class',    :Title => 'Wait-Class' }
      @session_statistics_key_rules_hash["DB-Object"]   = {:sql => "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END", :sql_alias  => "current_object", :Name => 'DB-Object',
                                                           :Title => "DB-Object #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}", :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["DB-Sub-Object"]= {:sql=> "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name|| CASE WHEN o.SubObject_Name IS NULL THEN '' ELSE ' ('||o.SubObject_Name||')' END ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END",
                                                            :sql_alias  => "current_subobject", :Name => 'DB-Sub-Object',
                                                            :Title      => "DB-Sub-Object / Partition #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}",
                                                            :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["Service"]     = {:sql => "sv.Service_Name",     :sql_alias => "service",            :Name => 'Service',       :Title =>'TNS-Service' }
      @session_statistics_key_rules_hash["Tablespace"]  = {:sql => "f.TableSpace_Name",   :sql_alias => "ts_name",            :Name => 'TS-name',       :Title => "Tablespace name" }
      @session_statistics_key_rules_hash["Data-File"]   = {:sql => "s.Current_File_No",   :sql_alias => "file_no",            :Name => 'Data-file#',    :Title => "Data-file number", :info_sql => "MIN(f.File_Name)||' TS='||MIN(f.Tablespace_Name)", :info_caption => "Tablespace-Name" }
      @session_statistics_key_rules_hash["Program"]     = {:sql => "TRIM(s.Program)",     :sql_alias => "program",            :Name => 'Program',       :Title      => "Client program" }
      @session_statistics_key_rules_hash["Machine"]     = {:sql => "TRIM(s.Machine)",     :sql_alias => "machine",            :Name => 'Machine',       :Title      => "Client machine" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Modus"]       = {:sql => "s.Modus",             :sql_alias => "modus",              :Name => 'Mode',          :Title      => "Mode in which session is executed" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["PQ"]          = {:sql => "DECODE(s.QC_Instance_ID, NULL, 'NO', s.Instance_Number||':'||s.Session_ID||', '||s.Session_Serial_No)",  :sql_alias => "pq",  :Name => 'Parallel query',  :Title => 'PQ instance and session if executed in parallel query (NO if not executed in parallel or session is PQ-coordinator)' }
      @session_statistics_key_rules_hash["Session-Type"]= {:sql => "SUBSTR(s.Session_Type,1,1)", :sql_alias => "session_type",              :Name => 'S-T',          :Title      => "Session-type: (F)OREGROUND or (B)ACKGROUND" }
    end
    @session_statistics_key_rules_hash
  end

  def session_statistics_key_rule(key)
    retval = session_statistics_key_rules[key]
    raise "session_statistics_key_rule: unknown key '#{key}'" unless retval
    retval
  end

  # Übersetzen des SQL_Opcode in Text
  def translate_opcode(opcode)
    case opcode
      when 1 then "CREATE TABLE"
      when 2 then "INSERT"
      when 3 then "SELECT"
      when 6 then "UPDATE"
      when 7 then "DELETE"
      when 9 then "CREATE INDEX"
      when 11 then "ALTER INDEX"
      when 15 then "ALTER TABLE"
      when 44 then "COMMIT"
      when 45 then "ROLLBACK"
      when 47 then "PL/SQL EXECUTE"
      else "Unbekannt, siehe http://download.oracle.com/docs/cd/B19306_01/server.102/b14237/dynviews_2088.htm#g1432037"
    end
  end


  # Ermitteln des SQL für NOT NULL oder NULL
  def groupfilter_value(key, value=nil)
    retval = case key
      when 'Blocking_Instance'          then {:sql => "s.Blocking_Inst_ID"}
      when "Blocking_Session"           then {:sql => "s.Blocking_Session"}
      when 'Blocking_Session_Serial_No' then {:sql => "s.Blocking_Session_Serial_No"}
      when "Blocking_Session_Status"    then {:sql => "s.Blocking_Session_Status"}
      when "DBID"                       then {:sql => "s.DBID",                          :hide_content => true}
      when "Min_Snap_ID"                then {:sql => "s.snap_id >= ?",                  :hide_content => true, :already_bound => true  }
      when "Max_Snap_ID"                then {:sql => "s.snap_id <= ?",                  :hide_content => true, :already_bound => true  }
      when "Plan-Line-ID"               then {:sql => "s.SQL_Plan_Line_ID" }
      when "Plan-Hash-Value"            then {:sql => "s.SQL_Plan_Hash_Value"}
      when "Session-ID"                 then {:sql => "s.Session_ID"}
      when "SerialNo"                   then {:sql => "s.Session_Serial_No"}
      when "time_selection_start"       then {:sql => "s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
      when "time_selection_end"         then {:sql => "s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
      when "Idle_Wait1"                 then {:sql => "NVL(s.Event, s.Session_State) != ?", :hide_content =>true, :already_bound => true}
      when "Owner"                      then {:sql => "UPPER(o.Owner)"}
      when "Object_Name"                then {:sql => "o.Object_Name"}
      when "SubObject_Name"             then {:sql => "o.SubObject_Name"}
      when "Current_Obj_No"             then {:sql => "s.Current_Obj_No"}
      when "User-ID"                    then {:sql => "s.User_ID"}
      when "Additional Filter"          then {:sql => "UPPER(u.UserName||s.Session_ID||s.Module||s.Action||o.Object_Name||s.Program#{get_db_version >= '11.2' ? '|| s.Machine' : ''}) LIKE UPPER('%'||?||'%')", :already_bound => true }  # Such-Filter
      else                              { :sql => session_statistics_key_rule(key)[:sql] }                              # 2. Versuch aus Liste der Gruppierungskriterien
    end
    
    raise "groupfilter_value: unknown key '#{key}'" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      if value && value != ''
        retval[:sql] = "#{retval[:sql]} = ?"
      else
        #if retval[:sql]["?"]
        #  puts retval.to_s
        #end
        retval[:sql] = "#{retval[:sql]} IS NULL"
      end
    end

    retval
  end


  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @global_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @global_where_values = []              # Filter-werte für nachfolgendes Statement für alle Union-Tabellen
    @dba_hist_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für DBA_Hist_Active_Sess_History
    @dba_hist_where_values = []              # Filter-werte für nachfolgendes Statement für DBA_Hist_Active_Sess_History

    @groupfilter.each do |key,value|
      @groupfilter.delete(key) if value.nil? || key == 'NULL'   # '' zulassen, da dies NULL signalisiert, Dummy-Werte ausblenden
      @groupfilter[key] = value.strip if key == 'time_selection_start' || key == 'time_selection_end'                   # Whitespaces entfernen vom Rand des Zeitstempels
    end

    @groupfilter.each {|key,value|
      sql = groupfilter_value(key, value)[:sql]
      if key == "DBID" || key == "Min_Snap_ID" || key == "Max_Snap_ID"    # Werte nur gegen HistTabelle binden
        @dba_hist_where_string << " AND #{sql}"  # Filter weglassen, wenn nicht belegt
        if value && value != ''
          @dba_hist_where_values << value   # Wert nur binden wenn nicht im :sql auf NULL getestet wird
        else
          @dba_hist_where_values << 0                    # Wenn kein valides Alter festgestellt über DBA_Hist_Snapshot, dann reicht gv$Active_Session_History aus für Zugriff,
          @dba_hist_where_string << "/* Zugriff auf DBA_Hist_Active_Sess_History ausblenden, da kein Wert für #{key} gefunden wurde (alle Daten kommen aus gv$Active_Session_History)*/"
        end
      else                                # Werte für Hist- und gv$-Tabelle binden
        @global_where_string << " AND #{sql}"
        @global_where_values << value if value && value != ''  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      end
    }
  end # where_from_groupfilter

  # Gruppierungskriterien für list_temp_usage_historic
  def temp_historic_grouping_options
    if !defined?(@temp_historic_grouping_options_hash) || @temp_historic_grouping_options_hash.nil?
      @temp_historic_grouping_options_hash = {}
      @temp_historic_grouping_options_hash[:second] = t(:second, :default=>'Second')
      @temp_historic_grouping_options_hash[:minute] = 'Minute'
      @temp_historic_grouping_options_hash[:hour]   = t(:hour,  :default => 'Hour')
      @temp_historic_grouping_options_hash[:day]    = t(:day,  :default => 'Day')
      @temp_historic_grouping_options_hash[:week]   = t(:week, :default => 'Week')
    end
    @temp_historic_grouping_options_hash
  end


end