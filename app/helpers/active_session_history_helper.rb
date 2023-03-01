# encoding: utf-8

module ActiveSessionHistoryHelper


  def session_statistics_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@session_statistics_key_rules_hash) || @session_statistics_key_rules_hash.nil?
      @session_statistics_key_rules_hash = {}

      # Performant access on gv$SQLArea ist unfortunately not possible here
      sql_id_info_sql = "(SELECT TO_CHAR(SUBSTR(t.SQL_Text,1,40))
                          FROM   DBA_Hist_SQLText t
                          WHERE  t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID AND RowNum < 2
                         )"

      top_level_sql_id_info_sql = "(SELECT TO_CHAR(SUBSTR(t.SQL_Text,1,40))
                          FROM   DBA_Hist_SQLText t
                          WHERE  t.DBID=s.DBID AND t.SQL_ID=s.Top_Level_SQL_ID AND RowNum < 2
                         )"

      @session_statistics_key_rules_hash["Wait Event"]      = {:sql => "NVL(s.Event, s.Session_State)", :sql_alias => "event",    :Name => 'Wait Event',    :Title => 'Wait event (session state, if wait event = NULL)', :Data_Title => '#{explain_wait_event(rec.event)}' }
      @session_statistics_key_rules_hash["Wait Class"]      = {:sql => "NVL(s.Wait_Class, 'CPU')", :sql_alias => "wait_class",    :Name => 'Wait Class',    :Title => 'Wait class' }
      @session_statistics_key_rules_hash["Instance"]        = {:sql => "s.Instance_Number",   :sql_alias => "instance_number",    :Name => 'Inst.',         :Title => 'RAC instance' }
      @session_statistics_key_rules_hash["Con-ID"]          = {:sql => "s.Con_ID",            :sql_alias => "con_id",             :Name => 'Con.-ID',       :Title => 'Container-ID for pluggable database', :info_sql=>"(SELECT MIN(Name) FROM gv$Containers i WHERE i.Con_ID=s.Con_ID)", :info_caption=>'Container name' } if get_current_database[:cdb]
      if get_db_version >= "11.2"
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "DECODE(s.QC_instance_ID, NULL, s.Session_ID||', '||s.Session_Serial_No, s.QC_Session_ID||', '||s.QC_Session_Serial_No)",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, Serial_No. (if executed in parallel query this is SID/sn of PQ-coordinator session)',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session type" }
      else
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "s.Session_ID||', '||s.Session_Serial_No",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, Serial_No.',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session Type" }
      end
      @session_statistics_key_rules_hash["Session Type"]    = {:sql => "SUBSTR(s.Session_Type,1,1)", :sql_alias => "session_type",              :Name => 'S-T',          :Title      => "Session-type: (U)SER, (F)OREGROUND or (B)ACKGROUND" }
      @session_statistics_key_rules_hash["Transaction"]     = {:sql => "s.Tx_ID",             :sql_alias => "transaction",        :Name => 'Tx.',           :Title => 'Transaction-ID' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["User"]            = {:sql => "u.UserName",          :sql_alias => "username",           :Name => "User",          :Title => "User" }
      @session_statistics_key_rules_hash["SQL-ID"]          = {:sql => "s.SQL_ID",            :sql_alias => "sql_id",             :Name => 'SQL-ID',        :Title => 'SQL-ID of the direct executed SQL', :info_sql  => sql_id_info_sql, :info_caption => "SQL-Text (first chars)" }
      @session_statistics_key_rules_hash["SQL Exec-ID"]     = {:sql => "s.SQL_Exec_ID",       :sql_alias => "sql_exec_id",        :Name => 'SQL Exec-ID',   :Title => 'SQL Execution ID', :info_sql  => "MIN(SQL_Exec_Start)", :info_caption => "Exec. start time"} if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Top Level SQL-ID"]= {:sql => "s.Top_Level_SQL_ID",  :sql_alias => "top_level_sql_id",   :Name => 'Top Level SQL-ID',  :Title => "Top level SQL-ID\nID of the surrounding SQL if direct SQL is called recursive by another SQL", :info_sql  => top_level_sql_id_info_sql, :info_caption => "SQL-Text (first chars)" }
      @session_statistics_key_rules_hash["Operation"]       = {:sql => "RTRIM(s.SQL_Plan_Operation||' '||s.SQL_Plan_Options)", :sql_alias => "operation", :Name => 'Operation', :Title => 'Operation of explain plan line' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Module"]          = {:sql => "TRIM(s.Module)",      :sql_alias => "module",             :Name => 'Module',        :Title => 'Module set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["Action"]          = {:sql => "TRIM(s.Action)",      :sql_alias => "action",             :Name => 'Action',        :Title => 'Action set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["DB Object"]       = {:sql => "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END", :sql_alias  => "current_object", :Name => 'DB Object',
                                                           :Title => "DB Object #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}", :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["DB Subobject"]    = {:sql=> "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name|| CASE WHEN o.SubObject_Name IS NULL THEN '' ELSE ' ('||o.SubObject_Name||')' END ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END",
                                                            :sql_alias  => "current_subobject", :Name => 'DB Subobject',
                                                            :Title      => "DB Subobject / Partition #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}",
                                                            :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["Entry-PL/SQL"]    = {:sql => "peo.Object_Type||CASE WHEN peo.Owner IS NOT NULL THEN ' ' END||peo.Owner||CASE WHEN peo.Object_Name IS NOT NULL THEN '.' END||peo.Object_Name||CASE WHEN peo.Procedure_Name IS NOT NULL THEN '.' END||peo.Procedure_Name",
                                                               :sql_alias => "entry_plsql_module", :Name => 'Entry-PL/SQL',      :Title => 'outermost PL/SQL module' }
      @session_statistics_key_rules_hash["PL/SQL"]          = {:sql => "po.Object_Type||CASE WHEN po.Owner IS NOT NULL THEN ' ' END||po.Owner||CASE WHEN po.Object_Name IS NOT NULL THEN '.' END||po.Object_Name||CASE WHEN po.Procedure_Name IS NOT NULL THEN '.' END||po.Procedure_Name",
                                                               :sql_alias => "plsql_module",       :Name => 'PL/SQL',        :Title => 'currently executed PL/SQL module' }
      @session_statistics_key_rules_hash["Service"]         = {:sql => "sv.Service_Name",     :sql_alias => "service",            :Name => 'Service',       :Title =>'TNS-Service' }
      @session_statistics_key_rules_hash["Tablespace"]      = {:sql => "f.TableSpace_Name",   :sql_alias => "ts_name",            :Name => 'TS-name',       :Title => "Tablespace name" }
      @session_statistics_key_rules_hash["Datafile"]        = {:sql => "s.Current_File_No",   :sql_alias => "file_no",            :Name => 'Datafile#',     :Title => "Datafile number", :info_sql => "MIN(f.File_Name)||' TS='||MIN(f.Tablespace_Name)", :info_caption => "Tablespace-Name" }
      @session_statistics_key_rules_hash["Program"]         = {:sql => "TRIM(s.Program)",     :sql_alias => "program",            :Name => 'Program',       :Title      => "Client program" }
      @session_statistics_key_rules_hash["Machine"]         = {:sql => "TRIM(s.Machine)",     :sql_alias => "machine",            :Name => 'Machine',       :Title      => "Client machine" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Mode"]            = {:sql => "s.Modus",             :sql_alias => "modus",              :Name => 'Mode',          :Title      => "Mode in which session is executed" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["PQ"]              = {:sql => "DECODE(s.QC_Instance_ID, NULL, 'NO', s.Instance_Number||':'||s.Session_ID||', '||s.Session_Serial_No)",  :sql_alias => "pq",  :Name => 'Parallel query',  :Title => 'PQ instance and session if executed in parallel query (NO if not executed in parallel or session is PQ-coordinator)' }
      @session_statistics_key_rules_hash["Plan-Hash-Value"] = {:sql => "s.SQL_Plan_Hash_Value", :sql_alias => "plan_hash_value",  :Name => 'Plan-Hash-Value', :Title => "Plan hash value, uniquely identifies execution plan of SQL" }
      @session_statistics_key_rules_hash["Client-ID"]       = {:sql => "s.Client_ID",         :sql_alias => "client_id",          :Name => 'Client ID',     :Title => "Client-ID set by DBMS_SESSION.Set_Identifier" }
      @session_statistics_key_rules_hash['Remote Instance'] = {:sql => "s.Remote_Instance_No",:sql_alias => 'remote_instance',    :Name => 'R. I.',         :Title      => "Remote instance identifier that will serve the block that this session is waiting for.\nThis information is only available if the session was waiting for cluster events." } if get_db_version >= "11.2"
      if get_db_version >= "11.2"
        @session_statistics_key_rules_hash['Blocking Session']= {:sql => "s.Blocking_Inst_ID||DECODE(s.Blocking_Session, NULL, NULL, ':')||s.Blocking_Session||DECODE(s.Blocking_Session, NULL, NULL, ',')||s.Blocking_Session_Serial_No", :sql_alias => 'blocking_session',   :Name => 'Blocking Session',       :Title      => "Blocking Session (Instance:SID, SN) that is blocking this session.", info_sql: "MIN(s.Blocking_Session_Status)", info_caption: "Blocking Session Status" }
      elsif get_db_version >= "10.2"                                            # without Blocking_Inst_ID in 10.2 and 11.1
        @session_statistics_key_rules_hash['Blocking Session']= {:sql => "s.Blocking_Session||DECODE(s.Blocking_Session, NULL, NULL, ',')||s.Blocking_Session_Serial_No", :sql_alias => 'blocking_session',   :Name => 'Blocking Session',       :Title      => "Blocking Session (SID, SN) that is blocking this session.", info_sql: "MIN(s.Blocking_Session_Status)", info_caption: "Blocking Session Status" }
      end
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
      when 0 then 'No operation'
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
      else "Unknown, see http://download.oracle.com/docs/cd/B19306_01/server.102/b14237/dynviews_2088.htm#g1432037"
    end
  end

  # additional filter conditions that are not listed as grouping criteria in session_statistics_key_rules
  def additional_ash_filter_conditions
    retval =
      {
        Blocking_Instance:                {:name => 'Blocking_Instance',           :sql => "s.Blocking_Inst_ID"},
        Blocking_Session:                 {:name => 'Blocking_Session',            :sql => "s.Blocking_Session"},
        Blocking_Session_Serial_No:       {:name => 'Blocking_Session_Serial_No',  :sql => "s.Blocking_Session_Serial_No"},
        Blocking_Session_Status:          {:name => 'Blocking_Session_Status',     :sql => "s.Blocking_Session_Status"},
        Blocking_Event:                   {:name => 'Blocking Event',              :sql => "blocking.Event"},        # needs additional join
        DBID:                             {:name => 'DBID',                        :sql => "s.DBID",                          :hide_content => true},
        Min_Snap_ID:                      {:name => 'Min_Snap_ID',                 :sql => "s.snap_id >= ?",                  :hide_content => true, :already_bound => true  },
        Max_Snap_ID:                      {:name => 'Max_Snap_ID',                 :sql => "s.snap_id <= ?",                  :hide_content => true, :already_bound => true  },
        Plan_Line_ID:                     {:name => 'Plan-Line-ID',                :sql => "s.SQL_Plan_Line_ID" },
        SQL_Child_Number:                 {:name => 'Child number',                :sql => "s.SQL_Child_Number"},
        SQL_ID_or_Top_Level_SQL_ID:       {:name => 'SQL-ID or top level SQL-ID',  :sql => "? IN (s.SQL_ID, s.Top_Level_SQL_ID)", already_bound: true},
        Plan_Hash_Value:                  {:name => 'Plan-Hash-Value',             :sql => "s.SQL_Plan_Hash_Value"},
        Session_ID:                       {:name => 'Session-ID',                  :sql => "s.Session_ID"},
        Serial_No:                         {:name => 'Serial_No',                    :sql => "s.Session_Serial_No"},
        Idle_Wait1:                       {:name => 'Idle_Wait1',                  :sql => "NVL(s.Event, s.Session_State) != ?", :hide_content =>true, :already_bound => true},
        Owner:                            {:name => 'Owner',                       :sql => "UPPER(o.Owner)"},
        Object_Name:                      {:name => 'Object_Name',                 :sql => "o.Object_Name"},
        SubObject_Name:                   {:name => 'SubObject_Name',              :sql => "o.SubObject_Name"},
        Current_Obj_No:                   {:name => 'Current_Obj_No',              :sql => "s.Current_Obj_No"},
        User_ID:                          {:name => 'User-ID',                     :sql => "s.User_ID"},
        Additional_Filter:                {:name => 'Additional Filter',           :sql => "UPPER(u.UserName||s.Session_ID||s.SQL_ID||s.Module||s.Action||o.Object_Name||s.Program#{get_db_version >= '11.2' ? '|| s.Machine' : ''}||s.SQL_Plan_Hash_Value||s.Client_ID) LIKE UPPER('%'||?||'%')", :already_bound => true }, # Such-Filter
        Temp_Usage_MB_greater:            {:name => 'TEMP-usage (MB) > x',         :sql => "s.Temp_Space_Allocated > ?*(1024*1024)", :already_bound => true},
        Temp_TS:                          {:name => 'TEMP-TS',                     :sql => "u.Temporary_Tablespace"},
      }
    retval[:con_id] =  {:name => 'Con-ID', :sql => "Con_ID" } if get_db_version >= '12.1'
    retval
  end

  def hide_groupfilter_content?(groupfilter, key)
    if groupfilter_value(key)[:hide_content]
      case key
      when :DBID
        groupfilter[:DBID] == PanoramaConnection.dbid || groupfilter[:con_id]
      else
        true
      end
    else
      false
    end
  end

  # Ermitteln des SQL für NOT NULL oder NULL
  def groupfilter_value(key, value=nil)
    retval = case key.to_sym
             when :time_selection_start then {:name => 'time_selection_start',        :sql => "s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
             when :time_selection_end   then {:name => 'time_selection_end',          :sql => "s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
    end

    retval = additional_ash_filter_conditions[key.to_sym] if retval.nil? # 1. try to find rules

    retval = { :name => session_statistics_key_rule(key.to_s)[:Name], :sql => session_statistics_key_rule(key.to_s)[:sql] } if retval.nil?  # 2. Versuch aus Liste der Gruppierungskriterien

    raise "groupfilter_value: unknown key '#{key}' of class #{key.class.name}" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      if value && value != ''
        retval[:sql] = "#{retval[:sql]} = ?"
      else
        retval[:sql] = "#{retval[:sql]} IS NULL"
      end
    end

    retval
  end

  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter                                                  # Instanzvariablen zur nachfolgenden Nutzung
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupby    = groupby                                                       # Instanzvariablen zur nachfolgenden Nutzung
    @global_where_string  = ''                                                  # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @global_where_values = []                                                   # Filter-werte für nachfolgendes Statement für alle Union-Tabellen
    @dba_hist_where_string  = ''                                                # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für DBA_Hist_Active_Sess_History
    @dba_hist_where_values = []                                                 # Filter-werte für nachfolgendes Statement für DBA_Hist_Active_Sess_History
    @sga_ash_where_string  = ''
    @sga_ash_where_values = []

    # convert integers from strings
    @groupfilter[:DBID]         = @groupfilter[:DBID].to_i
    @groupfilter[:Min_Snap_ID]  = @groupfilter[:Min_Snap_ID].to_i if @groupfilter.has_key?(:Min_Snap_ID)
    @groupfilter[:Max_Snap_ID]  = @groupfilter[:Max_Snap_ID].to_i if @groupfilter.has_key?(:Max_Snap_ID)

    # Check if PDB is selected by DBID, than add con_id to groupfilter
    if get_db_version >= '12.1' && @groupfilter[:DBID] && @groupfilter[:DBID] != PanoramaConnection.dbid
      @groupfilter[:con_id] = sql_select_one ["SELECT Con_ID FROM gv$Containers WHERE DBID = ?", @groupfilter[:DBID]]
    end

    @groupfilter.each do |key,value|
      @groupfilter.delete(key) if value.nil? || key == 'NULL'   # '' zulassen, da dies NULL signalisiert, Dummy-Werte ausblenden
      @groupfilter.delete(key) if value == '' && [:Min_Snap_ID, :Max_Snap_ID].include?(key)   # delete empty entries for keys without NULL-meaning
      @groupfilter[key] = value.strip if key == 'time_selection_start' || key == 'time_selection_end'                   # Whitespaces entfernen vom Rand des Zeitstempels
    end

    # Set Filter on Snap_ID for partition pruning on DBA_Hist_Active_Sess_History (if not already set)
    if !@groupfilter.has_key?(:Min_Snap_ID) || !@groupfilter.has_key?(:Max_Snap_ID)
      min_snap_id, max_snap_id = get_min_max_snap_ids(@groupfilter[:time_selection_start], @groupfilter[:time_selection_end], @groupfilter[:DBID])
      @groupfilter[:Min_Snap_ID] = min_snap_id if !@groupfilter.has_key?(:Min_Snap_ID) && !min_snap_id.nil?
      @groupfilter[:Max_Snap_ID] = max_snap_id if !@groupfilter.has_key?(:Max_Snap_ID) && !max_snap_id.nil?
    end

    # Switch table access to no result if records are not needed
    @sga_ash_where_string << "1=2" unless sga_ash_needed?(@groupfilter)

    @groupfilter.each do |key,value|
      sql = groupfilter_value(key, value)[:sql]
      case key
      when :DBID, :Min_Snap_ID, :Max_Snap_ID
        @dba_hist_where_string << " AND "  if @dba_hist_where_string != ''      # suppress leading AND
        @dba_hist_where_string << sql
        if value && value != ''     # Filter weglassen, wenn nicht belegt
          bind_value = value
          bind_value += 1 if key == :Max_Snap_ID                                # Sometimes ASH Snap_ID is related to the following AWR-Snapshot instead of the current, therefore @max_snap_id+1
          @dba_hist_where_values << bind_value                                  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
        else
          @dba_hist_where_values << 0                    # Wenn kein valides Alter festgestellt über DBA_Hist_Snapshot, dann reicht gv$Active_Session_History aus für Zugriff,
          @dba_hist_where_string << "/* Zugriff auf DBA_Hist_Active_Sess_History ausblenden, da kein Wert für #{key} gefunden wurde (alle Daten kommen aus gv$Active_Session_History)*/"
        end
      when :con_id
        @sga_ash_where_string << ' AND ' if @sga_ash_where_string != ''          # suppress leading AND
        @sga_ash_where_string << sql
        @sga_ash_where_values << value
      else
        @global_where_string << " AND #{sql}" if sql
        @global_where_values << value if value && value != ''  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      end
    end
  end # where_from_groupfilter

  # Is access to gv$Active_Session_History needed for this filter conditions
  def sga_ash_needed?(groupfilter)
    # Access to gv$Active_Session_History is needed if accessing the default DBID or a local PDB
    groupfilter[:DBID] == PanoramaConnection.dbid || PanoramaConnection.pdbs.map{|p| p[:dbid]}.include?(groupfilter[:DBID])
  end

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

  def blocking_locks_historic_event_with_selection(dbid, start_time, end_time)
    min_snap_id, max_snap_id = get_min_max_snap_ids(start_time, end_time, dbid, raise_if_not_found: true)
    sql = "WITH /* Panorama-Tool Ramm */
           #{ash_select(awr_filter:     "DBID = ? AND Snap_ID BETWEEN ? AND ?",
                        global_filter:  "Sample_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND Sample_Time < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')",
                        select_rounded_sample_time: true,
                        with_cte_alias: 'TSSel'
                       )}
    "
    return sql, [dbid, min_snap_id, max_snap_id, start_time, end_time]
  end

  # Felder, die generell von DBA_Hist_Active_Sess_History und gv$Active_Session_History selektiert werden
  def get_ash_default_select_list
    retval = 'Sample_ID, Sample_Time, Session_id, Session_Type, Session_serial# Session_Serial_No, User_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Opcode,
              Session_State, Blocking_Session, Blocking_session_Status, Blocking_Session_Serial# Blocking_session_Serial_No,
              Blocking_Hangchain_Info, NVL(Event, Session_State) Event, Event_ID, Seq# Sequence, P1Text, P1, P2Text, P2, P3Text, P3,
              Wait_Class, Wait_Time, Time_waited, Time_Waited/1000000 Seconds_in_Wait, Program, Module, Action, Client_ID, Current_Obj# Current_Obj_No, Current_File#  Current_File_No, Current_Block# Current_Block_No, RawToHex(XID) Tx_ID,
              PLSQL_Entry_Object_ID, PLSQL_Entry_SubProgram_ID, PLSQL_Object_ID, PLSQL_SubProgram_ID, Service_Hash, QC_Session_ID, QC_Instance_ID '
    if get_db_version >= '11.2'
      retval << ", NVL(SQL_ID, Top_Level_SQL_ID) SQL_ID,  /* Wenn keine SQL-ID, dann wenigstens Top-Level SQL-ID zeigen */
                 QC_Session_Serial# QC_Session_Serial_No, Is_SQLID_Current, Top_Level_SQL_ID, SQL_Plan_Line_ID, SQL_Plan_Operation, SQL_Plan_Options, SQL_Exec_ID, SQL_Exec_Start,
                 Blocking_Inst_ID, Current_Row# Current_Row_No, Remote_Instance# Remote_Instance_No, Machine, Port, PGA_Allocated, Temp_Space_Allocated,
                 TM_Delta_Time/1000000 TM_Delta_Time_Secs, TM_Delta_CPU_Time/1000000 TM_Delta_CPU_Time_Secs, TM_Delta_DB_Time/1000000 TM_Delta_DB_Time_Secs,
                 Delta_Time/1000000 Delta_Time_Secs, Delta_Read_IO_Requests, Delta_Write_IO_Requests,
                 Delta_Read_IO_Bytes/1024 Delta_Read_IO_kBytes, Delta_Write_IO_Bytes/1024 Delta_Write_IO_kBytes, Delta_Interconnect_IO_Bytes/1024 Delta_Interconnect_IO_kBytes,
                 SUBSTR(DECODE(In_Connection_Mgmt,   'Y', ', connection management') ||
                 DECODE(In_Parse,             'Y', ', parse') ||
                 DECODE(In_Hard_Parse,        'Y', ', hard parse') ||
                 DECODE(In_SQL_Execution,     'Y', ', SQL exec') ||
                 DECODE(In_PLSQL_Execution,   'Y', ', PL/SQL exec') ||
                 DECODE(In_PLSQL_RPC,         'Y', ', exec inbound PL/SQL RPC calls') ||
                 DECODE(In_PLSQL_Compilation, 'Y', ', PL/SQL compile') ||
                 DECODE(In_Java_Execution,    'Y', ', Java exec') ||
                 DECODE(In_Bind,              'Y', ', bind') ||
                 DECODE(In_Cursor_Close,      'Y', ', close cursor') ||
                 DECODE(In_Sequence_Load,     'Y', ', load sequence') ||
                 DECODE(Capture_Overhead,     'Y', ', capture overhead') ||
                 DECODE(Replay_Overhead,      'Y', ', replay overhead') ||
                 DECODE(Is_Captured,          'Y', ', session captured') ||
                 DECODE(Is_Replayed,          'Y', ', session replayed'), 3) Modus
                "
    else
      retval << ', SQL_ID' # für 10er DB keine Top_Level_SQL_ID verfügbar
    end
    if get_db_version >= '12.1'
      retval << ", Con_ID"
    end
    retval
  end

  # round sample time for ASH so that samples from different RAC instances are comparable/matchable
  def rounded_sample_time_sql(sample_cycle, column='Sample_Time')
    case sample_cycle
    when 1 then  "CAST(#{column} + INTERVAL '0.5' SECOND AS DATE) "   # rounded to 1 second (gv$Active_Session_History)
    when 10 then "TRUNC(#{column} + INTERVAL '5' SECOND, 'MI') + TRUNC(TO_NUMBER(TO_CHAR(#{column} + INTERVAL '5' SECOND, 'SS'))/10)/8640"  # rounded to 10 seconds (DBA_Hist_Active_Sess_History)
    else raise "rounded_sample_time_sql: Unsupported sample_cycle #{sample_cycle}"
    end
  end

  # get SELECT for combination of V$Active_Session_History and DBA_Hist_Active_Sess_History
  # @param sga_columns: Additional columns for V$Active_Session_History
  # @param awr_columns: Additional columns for DBA_Hist_Active_Sess_History
  # @param sga_filter: Additional WHERE conditions for V$Active_Session_History, should not start with WHERE or AND
  # @param awr_filter: Additional WHERE conditions for DBA_Hist_Active_Sess_History, should not start with WHERE or AND
  # @param additional_hints: Optimizer hints for SQL
  def ash_select(awr_columns:                 get_ash_default_select_list,
                 sga_columns:                 get_ash_default_select_list,
                 awr_filter:                  nil,
                 sga_filter:                  nil,
                 global_filter:               nil,
                 additional_hints:            nil,
                 select_rounded_sample_time:  false,
                 dbid:                        nil,                              # value for pseudo-column in gv$Active_Session_History if needed in result
                 with_cte_alias:              nil                               # shape as CTE in WITH-clause
  )
    awr_filter = nil if  awr_filter == ''
    sga_filter = nil if  sga_filter == ''
    # if used within existing CTE, don't double WITH, only if first WITH element "WITH" must preceed
    "
     #{"WITH" unless with_cte_alias }
          ASH_Time AS (SELECT /*+ NO_MERGE MATERIALIZE */ i.Inst_ID, NVL(Min_Sample_Time, SYSTIMESTAMP) Min_Sample_Time
                       FROM   gv$Instance i
                       LEFT OUTER JOIN (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time
                                        FROM gv$Active_Session_History
                                        GROUP BY Inst_ID
                                       ) ash ON ash.Inst_ID = i.Inst_ID
                      )#{", #{with_cte_alias} AS (" if with_cte_alias}
     SELECT /*+ NO_MERGE #{"MATERIALIZE" if with_cte_alias} #{additional_hints} */ *
     FROM   (SELECT 10 Sample_Cycle, Instance_Number, Snap_ID, #{awr_columns}#{", dbid" if dbid}
                    #{", #{rounded_sample_time_sql(10)} Rounded_Sample_Time" if select_rounded_sample_time}
             FROM   DBA_Hist_Active_Sess_History s
             WHERE  s.Sample_Time < (SELECT Min_Sample_Time FROM Ash_Time a WHERE a.Inst_ID = s.Instance_Number)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
             #{awr_filter.nil? ? '' : " AND #{awr_filter}"}
             UNION ALL
             SELECT 1 Sample_Cycle,  Inst_ID Instance_Number, NULL Snap_ID, #{sga_columns}#{", #{dbid}" if dbid}
                    #{", #{rounded_sample_time_sql(1)} Rounded_Sample_Time /* auf eine Sekunde genau gerundete Zeit */" if select_rounded_sample_time}
             FROM gv$Active_Session_History
             #{sga_filter.nil? ? '' : " WHERE #{sga_filter}"}
            )
     #{global_filter.nil? ? '' : " WHERE #{global_filter}"}
     #{")" if with_cte_alias}
    "
  end
end