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
      retval << ",\nCASE WHEN COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) = 1 THEN TO_CHAR(MIN(#{value[:sql]})) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) ||' >' END #{value[:sql_alias]}"
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



    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    singles= sql_select_all ["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             -- Beginn eines zu betrachtenden Zeitabschnittes
             TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400 Start_Sample,
             NVL(TO_CHAR(#{session_statistics_key_rule(@groupby)[:sql]}), 'NULL') Criteria,
             AVG(Wait_Time+Time_Waited)/1000                Time_Waited_Avg_ms,
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
      LEFT OUTER JOIN All_Users             u   ON u.User_ID     = s.User_ID
      LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID   = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID  = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      WHERE 1=1 #{@global_where_string}
      GROUP BY TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY 1
     "].concat(@dba_hist_where_values).concat([@dbid]).concat(@global_where_values)


    singles.each do |s|
          # Angenommene Anzahl Sekunden je Zyklus korrigieren, wenn Gruppierung < als Zyklus der Aufzeichnung
      divider = s.max_sample_cycle > group_seconds ? s.max_sample_cycle : group_seconds
      s['diagram_value'] = s.time_waited_secs.to_f / divider  # Anzeige als Anzahl aktive Sessions
    end


    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ''
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value}\", " unless groupfilter_value(key)[:hide_content]
    end

    diagram_caption = "#{t(:active_session_history_list_session_statistic_historic_timeline_header,
                                                   :default=> 'Number of waiting sessions condensed by %{group_seconds} seconds for top-10 grouped by: <b>%{groupby}</b>, Filter: %{filter}',
                                                   :group_seconds=>group_seconds, :groupby=>@groupby, :filter=>@filter
    )}"

    plot_top_x_diagramm(:data_array     => singles,
                        :time_key_name  => 'start_sample',
                        :curve_key_name => 'criteria',
                        :value_key_name => 'diagram_value',
                        :top_x          => 10,
                        :caption        => diagram_caption,
                        :update_area    => params[:update_area]
    )
  end # list_session_statistic_historic_timeline

  private
  # Felder, die generell von DBA_Hist_Active_Sess_History und gv$Active_Session_History selektiert werden
  def get_ash_default_select_list
    retval = 'Sample_ID, Sample_Time, Session_id, Session_Type, Session_serial# Session_Serial_No, User_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Opcode,
              Session_State, Blocking_Session, Blocking_session_Status, blocking_session_serial# Blocking_session_Serial_No, NVL(Event, Session_State) Event, Event_ID, Seq# Sequence, P1Text, P1, P2Text, P2, P3Text, P3,
              Wait_Class, Wait_Time, Time_waited, Program, Module, Action, Client_ID, Current_Obj# Current_Obj_No, Current_File#  Current_File_No, Current_Block# Current_Block_No, RawToHex(XID) XID,
              PLSQL_Entry_Object_ID, PLSQL_Entry_SubProgram_ID, PLSQL_Object_ID, PLSQL_SubProgram_ID, Service_Hash, QC_Session_ID, QC_Instance_ID '
    if session[:version] >= '11.2'
      retval << ", NVL(SQL_ID, Top_Level_SQL_ID) SQL_ID,  /* Wenn keine SQL-ID, dann wenigstens Top-Level SQL-ID zeigen */
                 Is_SQLID_Current, Top_Level_SQL_ID, SQL_Plan_Line_ID, SQL_Plan_Operation, SQL_Plan_Options, SQL_Exec_ID, SQL_Exec_Start,
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

  public

  # Anlisten der Einzel-Records eines Gruppierungskriteriums
  def list_session_statistic_historic_single_record
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= sql_select_all ["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             s.*,
             u.UserName, '' SQL_Operation,
             o.Owner, o.Object_Name,o.SubObject_Name, o.Data_Object_ID,
             f.File_Name, f.Tablespace_Name,
             peo.Owner PEO_Owner, peo.Object_Name PEO_Object_Name, peo.Procedure_Name PEO_Procedure_Name, peo.Object_Type PEO_Object_Type,
             po.Owner PO_Owner,   po.Object_Name  PO_Object_Name,  po.Procedure_Name  PO_Procedure_Name,  po.Object_Type  PO_Object_Type,
             sv.Service_Name, s.QC_Session_ID, s.QC_Instance_ID,
             TM_Delta_CPU_Time_Secs * Sample_Cycle / TM_Delta_Time_Secs TM_CPU_Time_Secs_Sample_Cycle,  /* CPU-Time innerhalb des Sample-Cycle */
             TM_Delta_DB_Time_Secs  * Sample_Cycle / TM_Delta_Time_Secs TM_DB_Time_Secs_Sample_Cycle,
             Delta_Read_IO_Requests       * Sample_Cycle / Delta_Time_Secs  Read_IO_Requests_Sample_Cycle,
             Delta_Write_IO_Requests      * Sample_Cycle / Delta_Time_Secs  Write_IO_Requests_Sample_Cycle,
             Delta_Read_IO_kBytes         * Sample_Cycle / Delta_Time_Secs  Read_IO_kBytes_Sample_Cycle,
             Delta_Write_IO_kBytes        * Sample_Cycle / Delta_Time_Secs  Write_IO_kBytes_Sample_Cycle,
             Delta_Interconnect_IO_kBytes * Sample_Cycle / Delta_Time_Secs  Interconn_kBytes_Sample_Cycle,
             RowNum Row_Num
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
      LEFT OUTER JOIN All_Users u     ON u.User_ID = s.User_ID
      -- erst p2 abfragen, da bei Request=3 in row_wait_obj# das als vorletztes gelockte Object stehen kann
      LEFT OUTER JOIN DBA_Objects o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      ORDER BY s.Sample_Time
     "
     ].concat(@dba_hist_where_values).concat([@dbid]).concat(@global_where_values)

    @sessions.each {|s|
      s.sql_operation = translate_opcode(s.sql_opcode)
    }

    render_partial
  end # list_session_statistic_historic_single_record

  # Anzeige der verschiedenen SQL-IDs je Instance/User falls bislang noch nicht eindeutig
  def list_sql_id_links
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt


    @sql_ids = sql_select_all ["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             s.SQL_ID, s.Instance_Number, u.UserName,
             AVG(Wait_Time+Time_Waited)/1000  Time_Waited_Avg_ms,
             SUM(s.Sample_Cycle)              Time_Waited_Secs,  -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
             MAX(s.Sample_Cycle)              Max_Sample_Cycle,  -- Max. Abstand der Samples als Korrekturgroesse fuer Berechnung LOAD
             COUNT(1)                         Count_Samples,
             MIN(Sample_Time)                 First_Occurrence,
             MAX(Sample_Time)                 Last_Occurrence,
             -- So komisch wegen Konvertierung Timestamp nach Date für Subtraktion
             (TO_DATE(TO_CHAR(MAX(Sample_Time), 'DD.MM.YYYY HH24:MI:SS'), 'DD.MM.YYYY HH24:MI:SS') -
              TO_DATE(TO_CHAR(MIN(Sample_Time), 'DD.MM.YYYY HH24:MI:SS'), 'DD.MM.YYYY HH24:MI:SS'))*(24*60*60) Sample_Dauer_Secs
      FROM   (SELECT /*+ NO_MERGE ORDERED */
                     10 Sample_Cycle, DBID, Instance_Number, #{get_ash_default_select_list}
              FROM   DBA_Hist_Active_Sess_History s
              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
              WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
              #{@dba_hist_where_string}
              UNION ALL
              SELECT 1 Sample_Cycle, #{@dbid} DBID, Inst_ID Instance_Number, #{get_ash_default_select_list}
              FROM   gv$Active_Session_History
             )s
      LEFT OUTER JOIN All_Users             u   ON u.User_ID   = s.User_ID  -- LEFT OUTER JOIN verursacht Fehler
      -- erst p2 abfragen, da bei Request=3 in row_wait_obj# das als vorletztes gelockte Object stehen kann
      LEFT OUTER JOIN DBA_Objects o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      GROUP BY s.DBID, s.SQL_ID, s.Instance_Number, u.UserName
      ORDER BY SUM(s.Sample_Cycle) DESC
     "
                              ].concat(@dba_hist_where_values).append(@dbid).concat(@global_where_values)

    render_partial
  end

  # Generische Funktion zum Anlisten der verdichteten Einzel-Records eines Gruppierungskriteriums nach GroupBy
  def list_session_statistic_historic_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby])
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= sql_select_all ["\
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
                SUM(TM_Delta_CPU_Time_Secs) TM_CPU_Time_Secs,  /* CPU-Time innerhalb des Sample-Cycle */
                SUM(TM_Delta_DB_Time_Secs)  TM_DB_Time_Secs,
                SUM(Delta_Read_IO_Requests)  Delta_Read_IO_Requests,
                SUM(Delta_Write_IO_Requests) Delta_Write_IO_Requests,
                SUM(Delta_Read_IO_kBytes)    Delta_Read_IO_kBytes,
                SUM(Delta_Write_IO_kBytes)   Delta_Write_IO_kBytes,
                SUM(Delta_Interconnect_IO_kBytes) Delta_Interconnect_IO_kBytes,
                MAX(Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
                AVG(Temp_Space_Allocated)/(1024*1024) Avg_Temp_MB,
             ' if session[:version] >= '11.2'}
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
      LEFT OUTER JOIN All_Users             u   ON u.User_ID   = s.User_ID  -- LEFT OUTER JOIN verursacht Fehler
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash
      WHERE  1=1
      #{@global_where_string}
      GROUP BY s.DBID, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY SUM(s.Sample_Cycle) DESC
     "
     ].concat(@dba_hist_where_values).concat(@global_where_values)

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @sessions.each {|s|
      if @groupby=='Module' || @groupby=='Action'
        info = explain_application_info(s.group_value)
        s.info      = info[:short_info]
        s.info_hint = info[:long_info]
      end
    }

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

    @groupby = 'Hugo' # Default
    @groupby = 'SQL-ID' if params[:sql_id]
    @groupby = 'Session/Sn.' if params[:sid] &&  params[:serialno]

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
      params[:groupfilter].delete(key) if params[key] && key!='time_selection_start' && key!='time_selection_end' # Element aus groupfilter loeschen, dass namentlich im param-Hash genannt ist
    end

    redirect_to :controller => params[:repeat_controller],:action => params[:repeat_action], :params => params
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

    @locks = sql_select_all [
        "WITH /* Panorama-Tool Ramm */
                   TSSel AS ( SELECT 10 Sample_Cycle, Sample_ID, Sample_Time, Snap_ID,
                                     h.Instance_Number, Session_ID, Session_Serial#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, Current_File#, Current_Block#,
                                     #{'Blocking_Inst_ID, Current_Row#, ' if session[:version] >= '11.2' }
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, User_ID, Event
                              FROM   DBA_Hist_Active_Sess_History h
                              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = h.Instance_Number
                              WHERE  (v.Min_Sample_Time IS NULL OR h.Sample_Time < v.Min_Sample_Time)  /* Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen  */
                              AND    h.DBID = ?
                              AND    h.Snap_ID BETWEEN ? AND ?
                              AND    h.Sample_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                              UNION ALL
                              SELECT 1 Sample_Cycle, Sample_ID, Sample_Time, NULL Snap_ID,
                                     h.Inst_ID Instance_Number, Session_ID, Session_Serial#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, Current_File#, Current_Block#,
                                     #{'Blocking_Inst_ID, Current_Row#, ' if session[:version] >= '11.2' }
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, User_ID, Event
                              FROM   gv$Active_Session_History h
                              WHERE  Sample_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                            )
              SELECT /*+ USE_NL(gr rhh) */
                     gr.*
                     #{if session[:version] >= '11.2'
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
                      SELECT Root_Snap_ID, Root_Sample_ID, Root_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_Serial# Root_Blocking_Session_SerialNo,
                             Root_Blocking_Session_Status,
                             #{if session[:version] >= '11.2'
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
                             SUM(l.Wait_Time+l.Time_Waited)/1000000                            Seconds_in_Wait_Total,
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
                             CASE WHEN COUNT(DISTINCT Root_Event)                > 1 THEN '< '||COUNT(DISTINCT Root_Event)     ||' >' ELSE MIN(Root_Event)           END Root_Event
                      FROM   (
                              SELECT CONNECT_BY_ROOT Sample_ID                Root_Sample_ID,
                                     CONNECT_BY_ROOT Sample_Time              Root_Sample_Time,
                                     CONNECT_BY_ROOT Blocking_Session         Root_Blocking_Session,
                                     CONNECT_BY_ROOT Blocking_Session_Serial# Root_Blocking_Session_Serial#,
                                     CONNECT_BY_ROOT Blocking_Session_Status  Root_Blocking_Session_Status,
                                     #{'CONNECT_BY_ROOT Blocking_Inst_ID  Root_Blocking_Inst_ID,' if session[:version] >= '11.2'}
                                     CONNECT_BY_ROOT (CASE WHEN l.P2Text = 'object #' THEN /* Wait kennt Object */ l.P2 ELSE l.Current_Obj# END) Root_Real_Current_Object_No,
                                     CONNECT_BY_ROOT Instance_Number          Root_Instance_Number,
                                     CONNECT_BY_ROOT SQL_ID                   Root_SQL_ID,
                                     CONNECT_BY_ROOT User_ID                  Root_User_ID,
                                     CONNECT_BY_ROOT Event                    Root_Event,
                                     CONNECT_BY_ROOT Snap_ID                  Root_Snap_ID,
                                     l.*,
                                     Level cLevel
                              FROM   TSSel l
                              CONNECT BY NOCYCLE PRIOR Sample_ID = Sample_ID
                                     AND PRIOR Session_ID        = Blocking_Session
                                     AND PRIOR Session_Serial#   = Blocking_Session_Serial#
                                     /* AND PRIOR Instance_number   = Blocking_Inst_ID -- 11g only  */
                             ) l
                      LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = l.Root_Real_Current_Object_No
                      LEFT OUTER JOIN DBA_Users u   ON u.User_ID = l.Root_User_ID
                      WHERE NOT EXISTS (SELECT 1 FROM TSSel i    /* Nur die Knoten ohne Parent-Blocker darstellen */
                                        WHERE  i.Sample_ID       = l.Root_Sample_ID
                                        AND    i.Session_ID      = l.Root_Blocking_Session
                                        AND    i.Session_Serial# = l.Root_Blocking_Session_Serial#
                                        /* AND    i.Instance_Number = l.Root_Blocking_Inst_ID -- 11g only  */
                                       )
                      GROUP BY Root_Snap_ID, Root_Sample_ID, Root_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_Serial#, Root_Blocking_Session_Status
                      #{', Root_Blocking_Inst_ID' if session[:version] >= '11.2'}
                    ) gr
                    JOIN (SELECT ? DBID FROM DUAL) db ON 1=1
                    #{if session[:version] >= '11.2'
                   'LEFT OUTER JOIN DBA_Hist_Active_Sess_History rhh ON  rhh.DBID                       = db.DBID
                                                                      AND rhh.Snap_ID                   = gr.Root_Snap_ID  /* Snap-ID innerhalb von RAC-Instanzen ist identisch, diese koennet von anderer Instanz stammen */
                                                                      AND rhh.Instance_Number           = gr.Root_Blocking_Inst_ID
                                                                      AND CAST(rhh.Sample_Time AS DATE) = CAST(gr.Root_Sample_Time AS DATE)
                                                                      AND rhh.Session_ID                = gr.Root_Blocking_Session
                    LEFT OUTER JOIN gv$Active_Session_History rha     ON  rha.Inst_ID                   = gr.Root_Blocking_Inst_ID
                                                                      AND CAST(rha.Sample_Time AS DATE) = CAST(gr.Root_Sample_Time AS DATE)
                                                                      AND rha.Session_ID                = gr.Root_Blocking_Session
                   '
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
    @sample_id                  = params[:sample_id]
    @time_selection             = params[:time_selection]
    @blocking_instance          = params[:blocking_instance]
    @blocking_session           = params[:blocking_session]
    @blocking_session_serialno  = params[:blocking_session_serialno]

    wherevalues = [ @dbid, @min_snap_id, @max_snap_id, @sample_id, @sample_id]
    wherevalues << @blocking_session          if @blocking_session
    wherevalues << @blocking_session_serialno if @blocking_session
    wherevalues << @blocking_instance         if @blocking_session && session[:version] >= '11.2'
    wherevalues << @blocking_session          if @blocking_session
    wherevalues << @blocking_session_serialno if @blocking_session
    wherevalues << @blocking_instance         if @blocking_session && session[:version] >= '11.2'

    @locks = sql_select_all [
        "WITH /* Panorama-Tool Ramm */
                   TSel AS ( SELECT 10 Sample_Cycle, Sample_ID, Sample_Time,
                                     h.Instance_Number, Session_ID, Session_Serial#, Current_File#, Current_Block#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, #{'Blocking_Inst_ID, Current_Row#, ' if session[:version] >= '11.2'}
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, SQL_Child_Number, User_ID, Event
                              FROM   DBA_Hist_Active_Sess_History h
                              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = h.Instance_Number
                              WHERE  (v.Min_Sample_Time IS NULL OR h.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
                              AND    h.DBID = ?
                              AND    h.Snap_ID BETWEEN ? AND ?
                              AND    h.Sample_ID = ?
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') -- Session wartend auf Blocking-Session
                              UNION ALL
                              SELECT 1 Sample_Cycle, Sample_ID, Sample_Time,
                                     h.Inst_ID, Session_ID, Session_Serial#, Current_File#, Current_Block#,
                                     Blocking_Session,Blocking_Session_Serial#, Blocking_Session_Status, #{'Blocking_Inst_ID, Current_Row#, ' if session[:version] >= '11.2'}
                                     p2, p2Text, Wait_Time, Time_Waited, Current_Obj#, SQL_ID, SQL_Child_Number, User_ID, Event
                              FROM   gv$Active_Session_History h
                              WHERE  Sample_ID = ?
                              AND    h.Blocking_Session_Status IN ('VALID', 'GLOBAL') -- Session wartend auf Blocking-Session
                            )
        SELECT o.Session_Serial# Session_SerialNo, u.UserName,
               o.*,
               cs.*
        FROM   TSel o
        JOIN   (-- Alle gelockten Sessions incl. mittelbare
                SELECT Root_Instance_Number, Root_Session_ID, Root_Session_SerialNo,
                       COUNT(DISTINCT CASE WHEN cLevel>1 THEN Session_ID ELSE NULL END) Blocked_Sessions_Total,
                       COUNT(DISTINCT CASE WHEN cLevel=2 THEN Session_ID ELSE NULL END) Blocked_Sessions_Direct,
                       SUM(CASE WHEN CLevel>1 THEN (Wait_Time+Time_Waited) ELSE 0 END )/1000000 Seconds_in_Wait_Blocked_Total,
                       #{if session[:version] >= '11.2'
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
                               l.*
                        FROM   tSel l
                        CONNECT BY NOCYCLE PRIOR Sample_ID       = Sample_ID
                                       AND PRIOR Session_ID      = Blocking_Session
                                       AND PRIOR Session_Serial# = Blocking_Session_Serial#
                                       -- AND PRIOR instance_number = blocking_Inst_ID -- 11g only
                        START WITH #{@blocking_session ? "Blocking_Session = ? AND Blocking_Session_Serial# = ? #{' AND Blocking_Inst_ID = ?' if session[:version] >= '11.2'}" : "Blocking_Session_Status='GLOBAL'"}
                       )
                LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = Root_Real_Current_Object_No
                GROUP BY Root_Instance_Number, Root_Session_ID, Root_Session_SerialNo
                ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_Session_ID = o.Session_ID AND cs.Root_Session_SerialNo = o.Session_Serial#
        LEFT OUTER JOIN DBA_Users u   ON u.User_ID = o.User_ID
        WHERE #{@blocking_session ? "o.Blocking_Session = ? AND o.Blocking_Session_Serial# = ? #{' AND Blocking_Inst_ID = ?' if session[:version] >= '11.2'}" : "o.Blocking_Session_Status='GLOBAL'"}
        ORDER BY o.Wait_Time+o.Time_Waited+cs.Seconds_In_Wait_Blocked_Total DESC"].concat(wherevalues)


    render_partial
  end

end
