# encoding: utf-8
#require 'jruby/profiler'


class ActiveSessionHistoryController < ApplicationController
  #include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include ActiveSessionHistoryHelper

  private
  # SQL-Fragment zur Mehrfachverwendung in diversen SQL
  def include_session_statistic_historic_default_select_list
    retval = " MIN(Sample_Time)             First_Occurrence,
               MAX(Sample_Time)             Last_Occurrence,
               -- So komisch wegen Konvertierung Tiemstamp nach Date für Subtraktion
               (TO_DATE(TO_CHAR(MAX(Sample_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}') -
               TO_DATE(TO_CHAR(MIN(Sample_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}'))*(24*60*60) Sample_Dauer_Secs"

    session_statistics_key_rules.each do |key, value|
      retval << ",
        COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) #{value[:sql_alias]}_Cnt,
        MIN(#{value[:sql]}) #{value[:sql_alias]}"
    end
    retval
  end

  public
  # Anzeige DBA_Hist_Active_Sess_History
  def list_session_statistic_historic
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @instance = prepare_param_instance
    params[:groupfilter] = {}
    params[:groupfilter]["DBID"]                  = prepare_param_dbid
    params[:groupfilter]["Instance"]              =  @instance if @instance
    params[:groupfilter]["Idle_Wait1"]            = 'PX Deq Credit: send blkd' unless params[:idle_waits] == '1'
    params[:groupfilter]["time_selection_start"]  = @time_selection_start
    params[:groupfilter]["time_selection_end"]    = @time_selection_end

    params[:groupfilter]['Additional Filter']     = params[:filter]  if params[:filter] && params[:filter] != ''

    list_session_statistic_historic_grouping      # Weiterleiten Request an Standard-Verarbeitung für weiteres DrillDown
  end # list_session_statistic_historic

  # Anzeige Diagramm mit Top10
  def list_session_statistic_historic_timeline
    group_seconds = params[:group_seconds].to_i

    where_from_groupfilter(params[:groupfilter], params[:groupby])
    @dbid = params[:groupfilter][:DBID]       # identische DBID verwenden wie im groupfilter bereits gesetzt


    record_modifier = proc{|rec|
      # Angenommene Anzahl Sekunden je Zyklus korrigieren, wenn Gruppierung < als Zyklus der Aufzeichnung
      divider = rec.max_sample_cycle > group_seconds ? rec.max_sample_cycle : group_seconds/rec.max_sample_cycle
      rec['diagram_value'] = rec.count_samples.to_f / divider  # Anzeige als Anzahl aktive Sessions
    }

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    singles= sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             -- Beginn eines zu betrachtenden Zeitabschnittes
             TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400 Start_Sample,
             NVL(TO_CHAR(#{session_statistics_key_rule(@groupby)[:sql]}), 'NULL') Criteria,
             SUM(s.Sample_Cycle)                            Time_Waited_Secs,  -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
             MAX(s.Sample_Cycle)                            Max_Sample_Cycle,  -- max. Abstand zwischen zwei Samples
             COUNT(1)                                       Count_Samples
      FROM   (SELECT /*+ NO_MERGE ORDERED */
                     10 Sample_Cycle, Instance_Number, #{get_ash_default_select_list}
              FROM   DBA_Hist_Active_Sess_History s
              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
              WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
              #{@dba_hist_where_string}
              UNION ALL
              SELECT 1 Sample_Cycle,  Inst_ID Instance_Number, #{get_ash_default_select_list}
              FROM   (SELECT s.Inst_ID Instance_Number, s.* FROM gv$Active_Session_History s) s
             )s
      LEFT OUTER JOIN DBA_Users             u   ON u.User_ID     = s.User_ID
      LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID   = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID  = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE 1=1 #{@global_where_string}
      GROUP BY TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY 1
     "].concat(@dba_hist_where_values).concat([@dbid]).concat(@global_where_values), record_modifier)


    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ''
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value}\", " unless groupfilter_value(key)[:hide_content]
    end

    diagram_caption = "#{t(:active_session_history_list_session_statistic_historic_timeline_header,
                                                   :default=> 'Number of waiting sessions condensed by %{group_seconds} seconds for top-10 grouped by: <b>%{groupby}</b>, Filter: %{filter}',
                                                   :group_seconds=>group_seconds, :groupby=>@groupby, :filter=>@filter
    )}"

    plot_top_x_diagramm(:data_array         => singles,
                        :time_key_name      => 'start_sample',
                        :curve_key_name     => 'criteria',
                        :value_key_name     => 'diagram_value',
                        :top_x              => 10,
                        :caption            => diagram_caption,
                        :null_points_cycle  => group_seconds,
                        :update_area        => params[:update_area]
    )
  end # list_session_statistic_historic_timeline

  private
  # Felder, die generell von DBA_Hist_Active_Sess_History und gv$Active_Session_History selektiert werden
  def get_ash_default_select_list
    retval = 'Sample_ID, Sample_Time, Session_id, Session_Type, Session_serial# Session_Serial_No, User_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Opcode,
              Session_State, Blocking_Session, Blocking_session_Status, blocking_session_serial# Blocking_session_Serial_No, NVL(Event, Session_State) Event, Event_ID, Seq# Sequence, P1Text, P1, P2Text, P2, P3Text, P3,
              Wait_Class, Wait_Time, Time_waited, Program, Module, Action, Client_ID, Current_Obj# Current_Obj_No, Current_File#  Current_File_No, Current_Block# Current_Block_No, RawToHex(XID) XID,
              PLSQL_Entry_Object_ID, PLSQL_Entry_SubProgram_ID, PLSQL_Object_ID, PLSQL_SubProgram_ID, Service_Hash, QC_Session_ID, QC_Instance_ID '
    if get_db_version >= '11.2'
      retval << ", NVL(SQL_ID, Top_Level_SQL_ID) SQL_ID,  /* Wenn keine SQL-ID, dann wenigstens Top-Level SQL-ID zeigen */
                 QC_Session_Serial#, Is_SQLID_Current, Top_Level_SQL_ID, SQL_Plan_Line_ID, SQL_Plan_Operation, SQL_Plan_Options, SQL_Exec_ID, SQL_Exec_Start,
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
    retval
  end

  # Generieren des SQL-Snippets für Alternativ-Anzeige
  def single_record_distinct_sql(column, alias_name=nil)
    unless alias_name
      alias_name = column
      alias_name = column[column.index('.')+1, column.length] if column.index('.')     # Tabellen-Alias entfernen
    end

    retval = ''
    retval << "CASE WHEN COUNT(DISTINCT #{column}) > 1 THEN NULL ELSE MIN(#{column}) END #{alias_name}, "
    retval << "COUNT(DISTINCT #{column}) #{alias_name}_Cnt"
  end


  public

  # Anlisten der Einzel-Records eines Gruppierungskriteriums
  def list_session_statistic_historic_single_record
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt


    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    if @time_groupby.nil? || @time_groupby == ''
      record_count = params[:record_count].to_i
      @time_groupby = :single        # Default
      @time_groupby = :hour if record_count > 1000
    end

    case @time_groupby.to_sym
      when :single then group_by_value = "s.Sample_ID, s.Instance_Number, s.Session_ID"         # Direkte Anzeige der Snapshots
      when :minute then group_by_value = "TRUNC(s.Sample_Time, 'MI')"
      when :hour   then group_by_value = "TRUNC(s.Sample_Time, 'HH24')"
      when :day    then group_by_value = "TRUNC(s.Sample_Time)"
      when :week   then group_by_value = "TRUNC(s.Sample_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    record_modifier = proc{|rec|
      rec['sql_operation'] = translate_opcode(rec.sql_opcode)
    }


    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             MIN(Sample_Time)       Start_Sample_Time,
             MAX(Sample_Time)       End_Sample_Time,
             COUNT(*)               Sample_Count,
             AVG(s.Sample_Cycle)    Sample_Cycle,
             #{ single_record_distinct_sql('s.Instance_Number') },
             #{ single_record_distinct_sql('s.Sample_ID') },
             #{ single_record_distinct_sql('s.Session_id') },
             #{ single_record_distinct_sql('s.Session_Type') },
             #{ single_record_distinct_sql('s.Session_Serial_No') },
             #{ single_record_distinct_sql('s.User_ID') },
             #{ single_record_distinct_sql('s.SQL_Child_Number') },
             #{ single_record_distinct_sql('s.SQL_Plan_Hash_Value') },
             #{ single_record_distinct_sql('s.SQL_Opcode') },
             #{ single_record_distinct_sql('s.Session_State') },
             #{ single_record_distinct_sql('s.Blocking_Session') },
             #{ single_record_distinct_sql('s.Blocking_session_Status') },
             #{ single_record_distinct_sql('s.Blocking_session_Serial_No') },
             #{ single_record_distinct_sql('s.Event') },
             #{ single_record_distinct_sql('s.Event_ID') },
             #{ single_record_distinct_sql('s.Sequence') },
             #{ single_record_distinct_sql('s.P1Text') },
             #{ single_record_distinct_sql('s.P1') },
             #{ single_record_distinct_sql('s.P2Text') },
             #{ single_record_distinct_sql('s.P2') },
             #{ single_record_distinct_sql('s.P3Text') },
             #{ single_record_distinct_sql('s.P3') },
             #{ single_record_distinct_sql('s.Wait_Class') },
             #{ single_record_distinct_sql('s.Program') },
             #{ single_record_distinct_sql('s.Module') },
             #{ single_record_distinct_sql('s.Action') },
             #{ single_record_distinct_sql('s.Client_ID') },
             #{ single_record_distinct_sql('s.Current_Obj_No') },
             #{ single_record_distinct_sql('s.Current_File_No') },
             #{ single_record_distinct_sql('s.Current_Block_No') },
             #{ single_record_distinct_sql('s.XID') },
             #{ single_record_distinct_sql('s.QC_Session_ID') },
             #{ single_record_distinct_sql('s.QC_Instance_ID') },
             #{ single_record_distinct_sql('s.SQL_ID') },
             SUM(s.Wait_Time)       Wait_Time,
             SUM(s.Time_waited)     Time_Waited,
             #{" #{ single_record_distinct_sql('s.Is_SQLID_Current') },
                 #{ single_record_distinct_sql('s.Top_Level_SQL_ID') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Line_ID') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Operation') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Options') },
                 #{ single_record_distinct_sql('s.SQL_Exec_ID') },
                 #{ single_record_distinct_sql('s.SQL_Exec_Start') },
                 #{ single_record_distinct_sql('s.Blocking_Inst_ID') },
                 #{ single_record_distinct_sql('s.Current_Row_No') },
                 #{ single_record_distinct_sql('s.Remote_Instance_No') },
                 #{ single_record_distinct_sql('s.Machine') },
                 #{ single_record_distinct_sql('s.Port') },
                 #{ single_record_distinct_sql('s.Modus') },
                 AVG(s.PGA_Allocated)           PGA_Allocated,
                 AVG(s.Temp_Space_Allocated)    Temp_Space_Allocated,
                 SUM(s.TM_Delta_Time_Secs)      TM_Delta_Time_Secs,
                 SUM(s.TM_Delta_CPU_Time_Secs)  TM_Delta_CPU_Time_Secs,
                 SUM(s.TM_Delta_DB_Time_Secs)   TM_Delta_DB_Time_Secs,
                 SUM(s.Delta_Time_Secs)         Delta_Time_Secs,
             " if get_db_version >= '11.2'}
             #{ single_record_distinct_sql('u.UserName') },
             '' SQL_Operation,
             #{ single_record_distinct_sql('o.Owner') },
             #{ single_record_distinct_sql('o.Object_Name') },
             #{ single_record_distinct_sql('o.SubObject_Name') },
             #{ single_record_distinct_sql('o.Data_Object_ID') },
             #{ single_record_distinct_sql('f.File_Name') },
             #{ single_record_distinct_sql('f.Tablespace_Name') },
             #{ single_record_distinct_sql('peo.Owner',           'PEO_Owner') },
             #{ single_record_distinct_sql('peo.Object_Name',     'PEO_Object_Name') },
             #{ single_record_distinct_sql('peo.Procedure_Name',  'PEO_Procedure_Name') },
             #{ single_record_distinct_sql('peo.Object_Type',     'PEO_Object_Type') },
             #{ single_record_distinct_sql('po.Owner',            'PO_Owner') },
             #{ single_record_distinct_sql('po.Object_Name',      'PO_Object_Name') },
             #{ single_record_distinct_sql('po.Procedure_Name',   'PO_Procedure_Name') },
             #{ single_record_distinct_sql('po.Object_Type',      'PO_Object_Type') },
             #{ single_record_distinct_sql('sv.Service_Name') },
             #{" #{ single_record_distinct_sql('s.QC_Session_Serial#', 'QC_Session_SerialNo') },
                 SUM(TM_Delta_CPU_Time_Secs * Sample_Cycle / TM_Delta_Time_Secs) TM_CPU_Time_Secs_Sample_Cycle,  /* CPU-Time innerhalb des Sample-Cycle */
                 SUM(TM_Delta_DB_Time_Secs  * Sample_Cycle / TM_Delta_Time_Secs) TM_DB_Time_Secs_Sample_Cycle,
                 SUM(Delta_Read_IO_Requests       * Sample_Cycle / Delta_Time_Secs)  Read_IO_Requests_Sample_Cycle,
                 SUM(Delta_Write_IO_Requests      * Sample_Cycle / Delta_Time_Secs)  Write_IO_Requests_Sample_Cycle,
                 SUM(Delta_Read_IO_kBytes         * Sample_Cycle / Delta_Time_Secs)  Read_IO_kBytes_Sample_Cycle,
                 SUM(Delta_Write_IO_kBytes        * Sample_Cycle / Delta_Time_Secs)  Write_IO_kBytes_Sample_Cycle,
                 SUM(Delta_Interconnect_IO_kBytes * Sample_Cycle / Delta_Time_Secs)  Interconn_kBytes_Sample_Cycle,
             " if get_db_version >= '11.2'}
             MIN(RowNum) Row_Num
      FROM   (SELECT /*+ NO_MERGE ORDERED */
                     10 Sample_Cycle, Instance_Number, #{get_ash_default_select_list}
              FROM   DBA_Hist_Active_Sess_History s
              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
              WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
              #{@dba_hist_where_string}
              UNION ALL
              SELECT 1 Sample_Cycle, Inst_ID Instance_Number,#{get_ash_default_select_list}
              FROM   gv$Active_Session_History
             )s
      LEFT OUTER JOIN DBA_Users u     ON u.User_ID = s.User_ID
      -- erst p2 abfragen, da bei Request=3 in row_wait_obj# das als vorletztes gelockte Object stehen kann
      LEFT OUTER JOIN DBA_Objects o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
     "
     ].concat(@dba_hist_where_values).concat([@dbid]).concat(@global_where_values), record_modifier)

    render_partial :list_session_statistic_historic_single_record
  end # list_session_statistic_historic_single_record


  # Generische Funktion zum Anlisten der verdichteten Einzel-Records eines Gruppierungskriteriums nach GroupBy
  def list_session_statistic_historic_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby])
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt

    record_modifier = proc{|rec|
      # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
      # da die Tabellen nicht auf allen DB zur Verfügung stehen
      if @groupby=='Module' || @groupby=='Action'
        info = explain_application_info(rec.group_value)
        rec.info      = info[:short_info]
        rec.info_hint = info[:long_info]
      end
    }

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             #{session_statistics_key_rule(@groupby)[:sql]}           Group_Value,
             #{if session_statistics_key_rule(@groupby)[:info_sql]
                 session_statistics_key_rule(@groupby)[:info_sql]
               else "''"
               end
              } Info,
             '' Info_Hint,
             MIN(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID,
             AVG(Wait_Time+Time_Waited)/1000  Time_Waited_Avg_ms,
             SUM(s.Sample_Cycle)          Time_Waited_Secs,  -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
             MAX(s.Sample_Cycle)          Max_Sample_Cycle,  -- Max. Abstand der Samples als Korrekturgroesse fuer Berechnung LOAD
             #{'
                SUM(TM_Delta_CPU_Time_Secs)           TM_CPU_Time_Secs,  /* CPU-Time innerhalb des Sample-Cycle */
                SUM(TM_Delta_DB_Time_Secs)            TM_DB_Time_Secs,
                SUM(Delta_Read_IO_Requests)           Delta_Read_IO_Requests,
                SUM(Delta_Write_IO_Requests)          Delta_Write_IO_Requests,
                SUM(Delta_Read_IO_kBytes)             Delta_Read_IO_kBytes,
                SUM(Delta_Write_IO_kBytes)            Delta_Write_IO_kBytes,
                SUM(Delta_Interconnect_IO_kBytes)     Delta_Interconnect_IO_kBytes,
                MAX(PGA_Allocated)/(1024*1024)        Max_PGA_MB,
                AVG(PGA_Allocated)/(1024*1024)        Avg_PGA_MB,
                MAX(Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
                AVG(Temp_Space_Allocated)/(1024*1024) Avg_Temp_MB,
             ' if get_db_version >= '11.2'}
             COUNT(1)                     Count_Samples,
             #{include_session_statistic_historic_default_select_list}
      FROM   (SELECT /*+ NO_MERGE ORDERED */
                     10 Sample_Cycle, DBID, Instance_Number, Snap_ID, #{get_ash_default_select_list}
              FROM   DBA_Hist_Active_Sess_History s
              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
              WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
              #{@dba_hist_where_string}
              UNION ALL
              SELECT 1 Sample_Cycle, #{@dbid} DBID, Inst_ID Instance_Number, NULL Snap_ID, #{get_ash_default_select_list}
              FROM   gv$Active_Session_History
             )s
      LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN DBA_Users             u   ON u.User_ID   = s.User_ID  -- LEFT OUTER JOIN verursacht Fehler
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash
      LEFT OUTER JOIN DBA_Data_Files        f   ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      GROUP BY s.DBID, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY SUM(s.Sample_Cycle) DESC
     "
     ].concat(@dba_hist_where_values).concat(@global_where_values),
                              record_modifier
    )

    #profile_data = JRuby::Profiler.profile do
      render_partial :list_session_statistic_historic_grouping
    #end

    #profile_printer = JRuby::Profiler::FlatProfilePrinter.new(profile_data)
    #profile_printer.printProfile(STDOUT)
  end

  # Auswahl von/bis
  # Vorbelegungen von diversen Filtern durch Übergabe im Param-Hash
  def show_prepared_active_session_history
    @groupfilter = {:DBID       => prepare_param_dbid }

    @groupfilter[:Instance]     =  params[:instance]  if params[:instance]
    @groupfilter['SQL-ID']      =  params[:sql_id]    if params[:sql_id]
    @groupfilter['Session/Sn.'] =  "#{params[:sid]}, #{params[:serialno]}"       if params[:sid] &&  params[:serialno]
    @groupfilter['Action']      =  params[:module_action]    if params[:module_action]

    @groupby = 'Hugo' # Default
    @groupby = 'SQL-ID' if params[:sql_id]
    @groupby = 'Session/Sn.' if params[:sid] &&  params[:serialno]
    @groupby = 'Action' if params[:module_action]

    render_partial
  end

  # Anzeige nach Eingabe von/bis in show_prepared_active_session_history
  def list_prepared_active_session_history
    save_session_time_selection
    params[:groupfilter][:time_selection_start] = @time_selection_start
    params[:groupfilter][:time_selection_end]   = @time_selection_end

    list_session_statistic_historic_grouping  # Weiterleiten
  end

  def refresh_time_selection
    params[:groupfilter][:time_selection_start] = params[:time_selection_start] if params[:time_selection_start]
    params[:groupfilter][:time_selection_end]   = params[:time_selection_end]   if params[:time_selection_end]
    params[:groupfilter].each do |key, value|
      params[:groupfilter].delete(key) if params[key] && params[key]=='' && key!='time_selection_start' && key!='time_selection_end' # Element aus groupfilter loeschen, dass namentlich im param-Hash genannt ist
      params[:groupfilter][key] = params[key] if params[key] && params[key]!=''
    end

    send(params[:repeat_action])              # Ersetzt redirect_to, da dies in Kombination winstone + FireFox nicht sauber funktioniert (Get-Request wird über Post verarbeitet)

    #redirect_to url_for(:controller => params[:repeat_controller],:action => params[:repeat_action], :params => params, :method=>:post)
    #send params[:repeat_action]    # Methode erneut aufrufen
  end

  private
  # Ermitteln der Min- und Max-Abgrenzungen auf Basis Snap_ID für Zeitraum über alle Instanzen hinweg
  def get_min_max_snap_ids(time_selection_start, time_selection_end, dbid)
    @min_snap_id = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ MIN(Snap_ID)
                                    FROM   (SELECT MAX(Snap_ID) Snap_ID
                                            FROM   DBA_Hist_Snapshot
                                            WHERE DBID = ?
                                            AND Begin_Interval_Time <= TO_DATE(?, '#{sql_datetime_minute_mask}')
                                            GROUP BY Instance_Number
                                           )
                                   ", dbid, time_selection_start
                                  ]
    unless @min_snap_id   # Start vor Beginn der Aufzeichnungen, dann kleinste existierende Snap-ID
      @min_snap_id = sql_select_one ['SELECT /*+ Panorama-Tool Ramm */ MIN(Snap_ID)
                                      FROM   DBA_Hist_Snapshot
                                      WHERE DBID = ?
                                     ', dbid
                                    ]
    end

    @max_snap_id = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ MAX(Snap_ID)
                                    FROM   (SELECT MIN(Snap_ID) Snap_ID
                                            FROM   DBA_Hist_Snapshot
                                            WHERE DBID = ?
                                            AND End_Interval_Time >= TO_DATE(?, '#{sql_datetime_minute_mask}')
                                            GROUP BY Instance_Number
                                          )
                                   ", dbid, time_selection_end
                                  ]
    unless @max_snap_id       # Letzten bekannten Snapshot werten, wenn End-Zeitpunkt in der Zukunft liegt
      @max_snap_id = sql_select_one ['SELECT /*+ Panorama-Tool Ramm */ MAX(Snap_ID)
                                      FROM   DBA_Hist_Snapshot
                                      WHERE DBID = ?
                                     ', dbid
                                    ]
    end
  end

  public


  def list_blocking_locks_historic
    @dbid = prepare_param_dbid
    save_session_time_selection
    get_min_max_snap_ids(@time_selection_start, @time_selection_end, @dbid)

    @locks = sql_select_iterator [
        "WITH /* Panorama-Tool Ramm */
                   TSSel AS ( SELECT 10 Sample_Cycle,
                                     /* auf 10 Sekunden genau gerundete Zeit */
                                     TRUNC(h.Sample_Time+INTERVAL '5' SECOND, 'MI') + TRUNC(TO_NUMBER(TO_CHAR(h.Sample_Time+INTERVAL '5' SECOND, 'SS'))/10)/8640  Rounded_Sample_Time,
                                     Snap_ID, h.Instance_Number, Session_ID, Session_Serial#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, Current_File#, Current_Block#,
                                     #{'Blocking_Inst_ID, Current_Row#, ' if get_db_version >= '11.2' }
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, User_ID, Event, Module, Action
                              FROM   DBA_Hist_Active_Sess_History h
                              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = h.Instance_Number
                              WHERE  (v.Min_Sample_Time IS NULL OR h.Sample_Time < v.Min_Sample_Time)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen  */
                              AND    h.DBID = ?
                              AND    h.Snap_ID BETWEEN ? AND ?
                              AND    h.Sample_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                              UNION ALL
                              SELECT 1 Sample_Cycle,
                                     CAST(Sample_Time + INTERVAL '0.5' SECOND AS DATE) Rounded_Sample_Time, /* auf eine Sekunde genau gerundete Zeit */
                                     NULL Snap_ID, h.Inst_ID Instance_Number, Session_ID, Session_Serial#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, Current_File#, Current_Block#,
                                     #{'Blocking_Inst_ID, Current_Row#, ' if get_db_version >= '11.2' }
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, User_ID, Event, Module, Action
                              FROM   gv$Active_Session_History h
                              WHERE  Sample_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                            )
              SELECT /*+ USE_NL(gr rhh) */
                     gr.*
                     #{if get_db_version >= '11.2'
                         ", NVL(NVL(NVL(rhh.Event, rhh.Session_State), NVL(rha.Event, rha.Session_State)), 'INACTIVE') Root_Blocking_Event
                          , NVL(rhh.Module,  rha.Module)   Root_Blocking_Module
                          , NVL(rhh.Action,  rha.Action)   Root_Blocking_Action
                          , NVL(rhh.Program, rha.Program)  Root_Blocking_Program
                          , NVL(rhh.SQL_ID,  rha.SQL_ID)   Root_Blocking_SQL_ID
                          , (SELECT UserName FROM DBA_Users u WHERE u.User_ID = NVL(rhh.User_ID, rha.User_ID)) Root_Blocking_UserName
                         "
                       end
                     }
              FROM   (
                      SELECT Root_Snap_ID, Root_Rounded_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_Serial# Root_Blocking_Session_SerialNo,
                             Root_Blocking_Session_Status, Decode(SUM(Is_Cycle), 0, NULL, 'Y') Deadlock, SUM(Is_Cycle) Is_Cycle_Sum,
                             #{if get_db_version >= '11.2'
                                 'Root_Blocking_Inst_ID,
                                  CASE WHEN COUNT(DISTINCT l.Current_File#)  = 1 THEN MIN(l.Current_File#)  ELSE NULL END Current_File_No,
                                  CASE WHEN COUNT(DISTINCT l.Current_Block#) = 1 THEN MIN(l.Current_Block#) ELSE NULL END Current_Block_No,
                                  CASE WHEN COUNT(DISTINCT l.Current_Row#)   = 1 THEN MIN(l.Current_Row#)   ELSE NULL END Current_Row_No,
                                 '
                               end
                             }
                             CASE WHEN COUNT(DISTINCT l.Session_ID) > 1 THEN  '< '||COUNT(DISTINCT l.Session_ID)||' >' ELSE MIN(TO_CHAR(l.Session_ID)) END Blocked_Sessions_Total,
                             CASE WHEN COUNT(DISTINCT l.Instance_Number) > 1 THEN  '< '||COUNT(DISTINCT l.Instance_Number)||' >' ELSE MIN(TO_CHAR(l.Instance_Number)) END Waiting_Instance,
                             CASE WHEN COUNT(DISTINCT CASE WHEN cLevel=1 THEN l.Session_ID ELSE NULL END) > 1 THEN
                               '< '||COUNT(DISTINCT CASE WHEN cLevel=1 THEN l.Session_ID ELSE NULL END)||' >'
                             ELSE
                               MIN(CASE WHEN cLevel=1 THEN TO_CHAR(l.Session_ID) ELSE NULL END)
                             END Blocked_Sessions_Direct,
                             SUM(CASE WHEN l.Wait_Time+l.Time_Waited > 0 THEN
                                  (l.Wait_Time+l.Time_Waited)/1000000
                                 ELSE
                                  l.Sample_Cycle   /* Wenn keine Wait-Time am Sample, dann statistisch annehmen dass über gesamten Cycle aktiv */
                                 END
                             ) Seconds_in_Wait_Total,
                             CASE WHEN COUNT(DISTINCT o.Owner||o.Object_Name) > 1 THEN   /* Nur anzeigen wenn eindeutig */
                               '< '||COUNT(DISTINCT o.Owner||o.Object_Name)||' >'
                             ELSE
                               MIN(LOWER(o.Object_Type)||' '||o.Owner||'.'||o.Object_Name||
                                 CASE
                                   WHEN o.Object_Name LIKE 'SYS_LOB%%' THEN
                                     ' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 8, 10)) )||')'
                                   WHEN o.Object_Name LIKE 'SYS_IL%%' THEN
                                     ' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 7, 10)) )||')'
                                   WHEN o.SubObject_Name IS NOT NULL THEN
                                     ' ('||o.SubObject_Name||')'
                                   ELSE NULL
                                 END)
                             END Root_Blocking_Object,
                             CASE WHEN COUNT(DISTINCT o.Data_Object_ID) = 1 THEN MIN(o.Data_Object_ID) ELSE NULL END Data_Object_ID,
                             CASE WHEN COUNT(DISTINCT Root_Instance_Number) > 1 THEN '< '||COUNT(DISTINCT Root_Instance_Number)||' >' ELSE MIN(TO_CHAR(Root_Instance_Number)) END Root_Instance_Number,
                             CASE WHEN COUNT(DISTINCT Root_SQL_ID)          > 1 THEN '< '||COUNT(DISTINCT Root_SQL_ID)         ||' >' ELSE MIN(Root_SQL_ID)          END Root_SQL_ID,
                             CASE WHEN COUNT(DISTINCT u.UserName)           > 1 THEN '< '||COUNT(DISTINCT u.UserName)          ||' >' ELSE MIN(u.UserName)           END Root_UserName,
                             CASE WHEN COUNT(DISTINCT Root_Event)           > 1 THEN '< '||COUNT(DISTINCT Root_Event)          ||' >' ELSE MIN(Root_Event)           END Root_Event,
                             CASE WHEN COUNT(DISTINCT Root_Module)          > 1 THEN '< '||COUNT(DISTINCT Root_Module)         ||' >' ELSE MIN(Root_Module)          END Root_Module,
                             CASE WHEN COUNT(DISTINCT Root_Action)          > 1 THEN '< '||COUNT(DISTINCT Root_Action)         ||' >' ELSE MIN(Root_Action)          END Root_Action
                      FROM   (
                              SELECT CONNECT_BY_ROOT Rounded_Sample_Time      Root_Rounded_Sample_Time,
                                     CONNECT_BY_ROOT Blocking_Session         Root_Blocking_Session,
                                     CONNECT_BY_ROOT Blocking_Session_Serial# Root_Blocking_Session_Serial#,
                                     CONNECT_BY_ROOT Blocking_Session_Status  Root_Blocking_Session_Status,
                                     #{'CONNECT_BY_ROOT Blocking_Inst_ID  Root_Blocking_Inst_ID,' if get_db_version >= '11.2'}
                                     CONNECT_BY_ROOT (CASE WHEN l.P2Text = 'object #' THEN /* Wait kennt Object */ l.P2 ELSE l.Current_Obj# END) Root_Real_Current_Object_No,
                                     CONNECT_BY_ROOT Instance_Number          Root_Instance_Number,
                                     CONNECT_BY_ROOT SQL_ID                   Root_SQL_ID,
                                     CONNECT_BY_ROOT User_ID                  Root_User_ID,
                                     CONNECT_BY_ROOT Event                    Root_Event,
                                     CONNECT_BY_ROOT Snap_ID                  Root_Snap_ID,
                                     CONNECT_BY_ROOT Module                   Root_Module,
                                     CONNECT_BY_ROOT Action                   Root_Action,
                                     l.*,
                                     Level cLevel,
                                     Connect_By_IsCycle Is_Cycle
                              FROM   TSSel l
                              CONNECT BY NOCYCLE PRIOR Rounded_Sample_Time = Rounded_Sample_Time
                                     AND PRIOR Session_ID        = Blocking_Session
                                     AND PRIOR Session_Serial#   = Blocking_Session_Serial#
                                      #{'AND PRIOR Instance_number   = Blocking_Inst_ID' if get_db_version >= '11.2'}
                             ) l
                      LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = l.Root_Real_Current_Object_No
                      LEFT OUTER JOIN DBA_Users u   ON u.User_ID = l.Root_User_ID
                      GROUP BY Root_Snap_ID, Root_Rounded_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_Serial#, Root_Blocking_Session_Status
                      #{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
                    ) gr
                    CROSS JOIN (SELECT ? DBID FROM DUAL) db
                    #{if get_db_version >= '11.2'
                   "LEFT OUTER JOIN DBA_Hist_Active_Sess_History rhh ON  rhh.DBID                       = db.DBID
                                                                      AND rhh.Snap_ID                   = gr.Root_Snap_ID  /* Snap-ID innerhalb von RAC-Instanzen ist identisch, diese koennet von anderer Instanz stammen */
                                                                      AND rhh.Instance_Number           = gr.Root_Blocking_Inst_ID
                                                                      AND TRUNC(rhh.Sample_Time+INTERVAL '5' SECOND, 'MI') + TRUNC(TO_NUMBER(TO_CHAR(rhh.Sample_Time+INTERVAL '5' SECOND, 'SS'))/10)/8640 = gr.Root_Rounded_Sample_Time /* auf 10 Sekunden gerundete Zeit */
                                                                      AND rhh.Session_ID                = gr.Root_Blocking_Session
                    LEFT OUTER JOIN gv$Active_Session_History rha     ON  rha.Inst_ID                   = gr.Root_Blocking_Inst_ID
                                                                      AND CAST(rha.Sample_Time + INTERVAL '0.5' SECOND AS DATE) = gr.Root_Rounded_Sample_Time   /* auf eine Sekunde gerundete Zeot */
                                                                      AND rha.Session_ID                = gr.Root_Blocking_Session
                    WHERE (NOT EXISTS (SELECT /*+ HASH_AJ) */ 1 FROM TSSel i    /* Nur die Knoten ohne Parent-Blocker darstellen */
                                        WHERE  i.Rounded_Sample_Time  = gr.Root_Rounded_Sample_Time
                                        AND    i.Session_ID           = gr.Root_Blocking_Session
                                        AND    i.Session_Serial#      = gr.Root_Blocking_Session_SerialNo
                                        #{'AND    i.Instance_number      = gr.Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
                                       ) OR Is_Cycle_Sum > 0   /* wenn cycle, dann Existenz eines Samples mit weiterer Referenz auf Blocking Session tolerieren */
                          )
                   "
                      end
                    }
              ORDER BY Seconds_in_Wait_Total DESC
        ", @dbid, @min_snap_id, @max_snap_id, @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end, @dbid
        ]

    render_partial
  end

  def list_blocking_locks_historic_detail
    @dbid = prepare_param_dbid
    save_session_time_selection
    @min_snap_id                = params[:min_snap_id]
    @max_snap_id                = params[:max_snap_id]
    @time_selection             = params[:time_selection]
    @blocking_instance          = params[:blocking_instance]
    @blocking_session           = params[:blocking_session]
    @blocking_session_serialno  = params[:blocking_session_serialno]

    wherevalues = [ @dbid, @min_snap_id, @max_snap_id, @time_selection , @time_selection ]
    wherevalues << @blocking_session          if @blocking_session
    wherevalues << @blocking_session_serialno if @blocking_session
    wherevalues << @blocking_instance         if @blocking_session && get_db_version >= '11.2'
    wherevalues << @blocking_session          if @blocking_session
    wherevalues << @blocking_session_serialno if @blocking_session
    wherevalues << @blocking_instance         if @blocking_session && get_db_version >= '11.2'

    @locks = sql_select_iterator [
        "WITH /* Panorama-Tool Ramm */
                   TSel AS ( SELECT 10 Sample_Cycle,
                                     h.Instance_Number, Session_ID, Session_Serial#, Current_File#, Current_Block#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, #{'Blocking_Inst_ID, Current_Row#, ' if get_db_version >= '11.2'}
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, SQL_Child_Number, User_ID, Event
                              FROM   DBA_Hist_Active_Sess_History h
                              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = h.Instance_Number
                              WHERE  (v.Min_Sample_Time IS NULL OR h.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
                              AND    h.DBID = ?
                              AND    h.Snap_ID BETWEEN ? AND ?
                              AND    TRUNC(h.Sample_Time+INTERVAL '5' SECOND, 'MI') + TRUNC(TO_NUMBER(TO_CHAR(h.Sample_Time+INTERVAL '5' SECOND, 'SS'))/10)/8640  = TO_DATE(?, '#{sql_datetime_second_mask}')
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') -- Session wartend auf Blocking-Session
                              UNION ALL
                              SELECT 1 Sample_Cycle,
                                     h.Inst_ID, Session_ID, Session_Serial#, Current_File#, Current_Block#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, #{'Blocking_Inst_ID, Current_Row#, ' if get_db_version >= '11.2'}
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, SQL_Child_Number, User_ID, Event
                              FROM   gv$Active_Session_History h
                              WHERE  CAST(Sample_Time + INTERVAL '0.5' SECOND AS DATE) = TO_DATE(?, '#{sql_datetime_second_mask}')      /* auf eine Sekunde genau gerundete Zeit */
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') -- Session wartend auf Blocking-Session
                            )
        SELECT o.Session_Serial# Session_SerialNo, u.UserName,
               o.*,
               CASE WHEN o.Wait_Time+o.Time_Waited > 0 THEN
                    (o.Wait_Time+o.Time_Waited)/1000000
               ELSE
                    o.Sample_Cycle   /* Wenn keine Wait-Time am Sample, dann statistisch annehmen dass über gesamten Cycle aktiv */
               END Direct_Wait_Seconds,
               cs.*
        FROM   TSel o
        JOIN   (-- Alle gelockten Sessions incl. mittelbare
                SELECT Root_Instance_Number, Root_Session_ID, Root_Session_SerialNo, DECODE(SUM(Is_Cycle), 0, NULL, 'Y') Deadlock,
                       COUNT(DISTINCT CASE WHEN cLevel>1 THEN Session_ID ELSE NULL END) Blocked_Sessions_Total,
                       COUNT(DISTINCT CASE WHEN cLevel=2 THEN Session_ID ELSE NULL END) Blocked_Sessions_Direct,
                       SUM(CASE WHEN CLevel>1 THEN
                                 CASE WHEN Wait_Time+Time_Waited > 0 THEN
                                  (Wait_Time+Time_Waited)/1000000
                                 ELSE
                                  Sample_Cycle   /* Wenn keine Wait-Time am Sample, dann statistisch annehmen dass über gesamten Cycle aktiv */
                                 END
                           ELSE 0 END) Seconds_in_Wait_Blocked_Total,
                       #{if get_db_version >= '11.2'
                           'CASE WHEN COUNT(DISTINCT Current_File#)  = 1 THEN MIN(Current_File#)  ELSE NULL END Current_File_No,
                            CASE WHEN COUNT(DISTINCT Current_Block#) = 1 THEN MIN(Current_Block#) ELSE NULL END Current_Block_No,
                            CASE WHEN COUNT(DISTINCT Current_Row#)   = 1 THEN MIN(Current_Row#)   ELSE NULL END Current_Row_No,
                           '
                         end
                       }
                       CASE WHEN COUNT(DISTINCT o.Owner||o.Object_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
                         '< '||COUNT(DISTINCT o.Owner||o.Object_Name)||' >'
                       ELSE
                         MIN(o.Owner||'.'||
                           CASE
                             WHEN o.Object_Name LIKE 'SYS_LOB%%' THEN
                               o.Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 8, 10)) )||')'
                             WHEN o.Object_Name LIKE 'SYS_IL%%' THEN
                             o.Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 7, 10)) )||')'
                             ELSE o.Object_Name
                           END)
                       END Root_Blocking_Object,
                       CASE WHEN COUNT(DISTINCT o.Data_Object_ID) = 1 THEN MIN(o.Data_Object_ID) ELSE NULL END Data_Object_ID
                FROM   (SELECT CONNECT_BY_ROOT Instance_Number Root_Instance_Number,
                               CONNECT_BY_ROOT Session_ID      Root_Session_ID,
                               CONNECT_BY_ROOT Session_Serial# Root_Session_SerialNo,
                               CONNECT_BY_ROOT (CASE WHEN l.P2Text = 'object #' THEN /* Wait kennt Object */ l.P2 ELSE l.Current_Obj# END) Root_Real_Current_Object_No,
                               LEVEL cLevel,
                               Connect_By_IsCycle Is_Cycle,
                               l.*
                        FROM   tSel l
                        CONNECT BY NOCYCLE PRIOR Session_ID      = Blocking_Session
                                       AND PRIOR Session_Serial# = Blocking_Session_Serial#
                                    #{'AND PRIOR Instance_number = Blocking_Inst_ID' if get_db_version >= '11.2'}
                        START WITH #{@blocking_session ? "Blocking_Session = ? AND Blocking_Session_Serial# = ? #{' AND Blocking_Inst_ID = ?' if get_db_version >= '11.2'}" : "Blocking_Session_Status='GLOBAL'"}
                       )
                LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = Root_Real_Current_Object_No
                GROUP BY Root_Instance_Number, Root_Session_ID, Root_Session_SerialNo
                ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_Session_ID = o.Session_ID AND cs.Root_Session_SerialNo = o.Session_Serial#
        LEFT OUTER JOIN DBA_Users u   ON u.User_ID = o.User_ID
        WHERE #{@blocking_session ? "o.Blocking_Session = ? AND o.Blocking_Session_Serial# = ? #{' AND Blocking_Inst_ID = ?' if get_db_version >= '11.2'}" : "o.Blocking_Session_Status='GLOBAL'"}
        ORDER BY o.Wait_Time+o.Time_Waited+cs.Seconds_In_Wait_Blocked_Total DESC"].concat(wherevalues)


    render_partial
  end

  # Einstieg aus show_temp_usage_historic
  def first_list_temp_usage_historic
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung 
    @instance = prepare_param_instance
    params[:groupfilter] = {}

    params[:groupfilter]["DBID"]                  = prepare_param_dbid
    params[:groupfilter]["Instance"]              =  @instance if @instance
    params[:groupfilter]["Idle_Wait1"]            = 'PX Deq Credit: send blkd'
    params[:groupfilter]["time_selection_start"]  = @time_selection_start
    params[:groupfilter]["time_selection_end"]    = @time_selection_end

    list_temp_usage_historic    # weiterleitung Event
  end



  def list_temp_usage_historic                  # Methode kann nur ab Version 11.2 aufgerufen werden
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt

    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    case @time_groupby.to_sym
      when :second then group_by_value = "CAST(s.Sample_Time AS DATE)"
      when :minute then group_by_value = "TRUNC(s.Sample_Time, 'MI')"
      when :hour   then group_by_value = "TRUNC(s.Sample_Time, 'HH24')"
      when :day    then group_by_value = "TRUNC(s.Sample_Time)"
      when :week   then group_by_value = "TRUNC(s.Sample_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    # All möglichen Tabellen gejoint, da Filter diese referenzieren können
    @result= sql_select_iterator ["\
      #{"WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)" if  @global_where_string['peo.'] ||  @global_where_string['po.']}
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             MIN(s.Sample_Time)   Start_Sample_Time,
             MAX(s.Sample_Time)   End_Sample_Time,
             SUM(Sample_Count)    Sample_Count,
             SUM(Time_Waited_Secs) Time_Waited_Secs,
             MAX(s.Sum_PGA_Allocated)/(1024*1024)                             Max_Sum_PGA_Allocated,
             MAX(s.Max_PGA_Allocated_per_Session)/(1024*1024)                 Max_PGA_Alloc_Per_Session,
             SUM(s.Sum_PGA_Allocated)/SUM(s.Sample_Count)/(1024*1024)         Avg_PGA_Alloc_per_Session,
             MAX(s.Sum_Temp_Space_Allocated)/(1024*1024)                      Max_Sum_Temp_Space_Allocated,
             MAX(s.Max_Temp_Space_Alloc_per_Sess)/(1024*1024)                 Max_Temp_Space_Alloc_per_Sess,
             SUM(s.Sum_Temp_Space_Allocated)/SUM(s.Sample_Count)/(1024*1024)  Avg_Temp_Space_Alloc_per_Sess
      FROM   (
              SELECT CAST (Sample_Time+INTERVAL '0.5' SECOND AS DATE) Sample_Time,
                     COUNT(*)               Sample_Count,
                     SUM(s.Sample_Cycle)            Time_Waited_Secs,               -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
                     SUM(s.PGA_Allocated)           Sum_PGA_Allocated,
                     MAX(s.PGA_Allocated)           Max_PGA_Allocated_Per_Session,
                     SUM(s.Temp_Space_Allocated)    Sum_Temp_Space_Allocated,       -- eigentlich nichtssagend, da Summe über alle Sample-Zeiten hinweg, nur benutzt fuer AVG
                     MAX(s.Temp_Space_Allocated)    Max_Temp_Space_Alloc_per_Sess
              FROM   (SELECT /*+ NO_MERGE ORDERED */
                             DBID, 10 Sample_Cycle, Instance_Number, #{get_ash_default_select_list}
                      FROM   DBA_Hist_Active_Sess_History s
                      LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
                      WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen */
                      #{@dba_hist_where_string}
                      UNION ALL
                      SELECT #{@dbid} DBID, 1 Sample_Cycle, Inst_ID Instance_Number,#{get_ash_default_select_list}
                      FROM   gv$Active_Session_History
                     )s
              #{"LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END" if @global_where_string['o.']}
              #{"LEFT OUTER JOIN DBA_Users             u   ON u.User_ID   = s.User_ID" if @global_where_string['u.']}
              #{"LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID" if @global_where_string['peo.']}
              #{"LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID" if @global_where_string['po.']}
              #{"LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash" if @global_where_string['sv.']}
              #{"LEFT OUTER JOIN DBA_Data_Files        f   ON f.File_ID = s.Current_File_No" if @global_where_string['f.']}
              WHERE  1=1
              #{@global_where_string}
              GROUP BY CAST(Sample_Time+INTERVAL '0.5' SECOND AS DATE)    -- Auf Ebene eines Samples reduzieren
             ) s
      WHERE  s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')      -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      AND    s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')      -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
      "].concat(@dba_hist_where_values).concat(@global_where_values).concat([@groupfilter['time_selection_start'], @groupfilter['time_selection_end']])

    render_partial :list_temp_usage_historic


  end

end
