# encoding: utf-8

module ActiveSessionHistoryHelper


  def session_statistics_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    unless @session_statistics_key_rules_hash
      @session_statistics_key_rules_hash = {}
      @session_statistics_key_rules_hash["Instance"]    = {:sql => "s.Instance_Number",   :sql_alias => "instance_number",    :Name => 'Inst.',         :Title => 'RAC-Instance' }
      @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "s.Session_ID||', '||s.Session_Serial_No",        :sql_alias => "session_sn",        :Name => 'Session/Sn.',    :Title => 'Session-ID, SerialNo.',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session-Type" }
      @session_statistics_key_rules_hash["Transaction"] = {:sql => "RawToHex(s.XID)",     :sql_alias => "transaction",        :Name => 'Tx.',           :Title => 'Transaction-ID' } if session[:version] >= "11.2"
      @session_statistics_key_rules_hash["User"]        = {:sql => "u.UserName",          :sql_alias => "username",           :Name => "User",          :Title => "User" }
      @session_statistics_key_rules_hash["SQL-ID"]      = {:sql => "s.SQL_ID",            :sql_alias => "sql_id",             :Name => 'SQL-ID',        :Title => 'SQL-ID', :info_sql  => "(SELECT SUBSTR(t.SQL_Text,1,40) FROM DBA_Hist_SQLText t WHERE t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID)", :info_caption => "SQL-Text (first chars)" }
      @session_statistics_key_rules_hash["SQL Exec-ID"] = {:sql => "s.SQL_Exec_ID",       :sql_alias => "sql_exec_id",        :Name => 'SQL Exec-ID',   :Title => 'SQL Execution ID', :info_sql  => "MIN(SQL_Exec_Start)", :info_caption => "Exec. start time"} if session[:version] >= "11.2"
      @session_statistics_key_rules_hash["Operation"]   = {:sql => "RTRIM(s.SQL_Plan_Operation||' '||s.SQL_Plan_Options)", :sql_alias => "operation", :Name => 'Operation', :Title => 'Operation of explain plan line' } if session[:version] >= "11.2"
      @session_statistics_key_rules_hash["Entry-PL/SQL"]= {:sql => "peo.Object_Type||CASE WHEN peo.Owner IS NOT NULL THEN ' ' END||peo.Owner||CASE WHEN peo.Object_Name IS NOT NULL THEN '. ' END||peo.Object_Name||CASE WHEN peo.Procedure_Name IS NOT NULL THEN '. ' END||peo.Procedure_Name",
                                                           :sql_alias => "entry_plsql_module", :Name => 'Entry-PL/SQL',      :Title => 'outermost PL/SQL module' }
      @session_statistics_key_rules_hash["PL/SQL"]      = {:sql => "po.Object_Type||CASE WHEN po.Owner IS NOT NULL THEN ' ' END||po.Owner||CASE WHEN po.Object_Name IS NOT NULL THEN '. ' END||po.Object_Name||CASE WHEN po.Procedure_Name IS NOT NULL THEN '. ' END||po.Procedure_Name",
                                                                                          :sql_alias => "plsql_module",       :Name => 'PL/SQL',        :Title => 'currently executed PL/SQL module' }
      @session_statistics_key_rules_hash["Module"]      = {:sql => "s.Module",            :sql_alias => "module",             :Name => 'Module',        :Title => 'Module' }
      @session_statistics_key_rules_hash["Action"]      = {:sql => "s.Action",            :sql_alias => "action",             :Name => 'Action',        :Title => 'Action' }
      @session_statistics_key_rules_hash["Event"]       = {:sql => "NVL(s.Event, s.Session_State)", :sql_alias => "event",    :Name => 'Event',         :Title => 'Event (Session-State, wenn Event = NULL)', :info_sql  => "MIN(s.Wait_Class)", :info_caption => "Wait-Class", :Data_Title => '#{explain_wait_event(rec.event)}' }
      @session_statistics_key_rules_hash["Wait-Class"]  = {:sql => "NVL(s.Wait_Class, 'CPU')", :sql_alias => "wait_class",    :Name => 'Wait-Class',    :Title => 'Wait-Class' }
      @session_statistics_key_rules_hash["DB-Object"]   = {:sql => "LOWER(o.Owner)||'.'||o.Object_Name", :sql_alias  => "current_object", :Name => 'DB-Object',
                                                           :Title => "DB-Object #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}", :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["DB-Sub-Object"]= {:sql=> "LOWER(o.Owner)||'.'||o.Object_Name|| CASE WHEN o.SubObject_Name IS NULL THEN '' ELSE ' ('||o.SubObject_Name||')' END",
                                                            :sql_alias  => "current_subobject", :Name => 'DB-Sub-Object',
                                                            :Title      => "DB-Sub-Object / Partition #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}",
                                                            :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["Service"]     = {:sql => "sv.Service_Name",     :sql_alias => "service",            :Name => 'Service',       :Title =>'TNS-Service' }
      @session_statistics_key_rules_hash["Data-File"]   = {:sql => "s.Current_File_No",   :sql_alias => "file_no",            :Name => 'Data-File#',    :Title => "Data-file number", :info_sql => "(SELECT f.File_Name||' TS='||f.Tablespace_Name FROM DBA_Data_Files f WHERE f.File_ID=s.Current_File_No)", :info_caption => "Tablespace-Name" }
      @session_statistics_key_rules_hash["Program"]     = {:sql => "s.Program",           :sql_alias => "program",            :Name => 'Program',       :Title      => "Client program" }
      @session_statistics_key_rules_hash["Machine"]     = {:sql => "s.Machine",           :sql_alias => "machine",            :Name => 'Machine',       :Title      => "Client machine" } if session[:version] >= "11.2"
      @session_statistics_key_rules_hash["Modus"]       = {:sql => "s.Modus",             :sql_alias => "modus",              :Name => 'Mode',          :Title      => "Mode in which session is executed" } if session[:version] >= "11.2"
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
    unless @groupfilter_values_hash
      @groupfilter_values_hash = {}
      @groupfilter_values_hash["DBID"]                  = {:sql => "s.DBID",                          :hide_content => true}
      @groupfilter_values_hash["Min_Snap_ID"]           = {:sql => "s.snap_id >= ?",                  :hide_content => true, :already_bound => true  }
      @groupfilter_values_hash["Max_Snap_ID"]           = {:sql => "s.snap_id <= ?",                  :hide_content => true, :already_bound => true  }
      @groupfilter_values_hash["Plan-Line-ID"]          = {:sql => "s.SQL_Plan_Line_ID" }
      @groupfilter_values_hash["Plan-Hash-Value"]       = {:sql => "s.SQL_Plan_Hash_Value"}
      @groupfilter_values_hash["Session-ID"]            = {:sql => "s.Session_ID"}
      @groupfilter_values_hash["SerialNo"]              = {:sql => "s.Session_Serial_No"}
      @groupfilter_values_hash["time_selection_start"]  = {:sql => "s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')", :already_bound => true }
      @groupfilter_values_hash["time_selection_end"]    = {:sql => "s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')", :already_bound => true }
      @groupfilter_values_hash["Idle_Wait1"]            = {:sql => "NVL(s.Event, s.Session_State) != ?", :hide_content =>true, :already_bound => true}
      @groupfilter_values_hash["Owner"]                 = {:sql => "UPPER(o.Owner)"}
      @groupfilter_values_hash["Object_Name"]           = {:sql => "o.Object_Name"}
      @groupfilter_values_hash["SubObject_Name"]        = {:sql => "o.SubObject_Name"}
      @groupfilter_values_hash["Current_Obj_No"]        = {:sql => "s.Current_Obj_No"}
      @groupfilter_values_hash["User-ID"]               = {:sql => "s.User_ID"}
      @groupfilter_values_hash["Additional Filter"]     = {:sql => "UPPER(s.Session_ID||s.Module||s.Action||s.Program#{session[:version] >= '11.2' ? '|| s.Machine' : ''}) LIKE UPPER('%'||?||'%')", :already_bound => true }  # Such-Filter

    end

    retval = @groupfilter_values_hash[key]                                      # 1. Versuch aus Liste der zusätzlich definierten
    retval = { :sql => session_statistics_key_rule(key)[:sql] } unless retval   # 2. Versuch aus Liste der Gruppierungskriterien
    raise "groupfilter_value: unknown key '#{key}'" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      if value && value != ''
        retval[:sql] = "#{retval[:sql]} = ?"
      else
        if retval[:sql]["?"]
          puts retval.to_s
        end
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
      @groupfilter.delete(key) if value.nil? || value == ''
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


end