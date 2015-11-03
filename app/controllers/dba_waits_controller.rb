# encoding: utf-8
class DbaWaitsController < ApplicationController
  
  include DbaHelper
  
  def show_system_events
    filter = params[:filter]
    filter = nil if filter == ""

    def smaller(obj1, obj2)           # Vergleich zweier Records
      return true   if obj1.inst_id < obj2.inst_id
      return false  if obj1.inst_id > obj2.inst_id
      return true if obj1.event < obj2.event
      return false
    end
    
    def get_values(filter)  # ermitteln der Aktuellen Werte
      # Sortierung des Results muss mit Methode smaller korrelieren
      where_string = ""
      where_values = []
      if params[:suppress_idle_waits]=='1'
        where_string << " Wait_Class != 'Idle' "
      end

      if filter
        where_string << " AND " if where_string != ""
        where_string = " UPPER(Event) LIKE '%'||UPPER(?)||'%'"
        where_values << filter
        where_values << filter
      end
      where_string = " WHERE " + where_string if where_string != ""

      sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
              NVL(se.Inst_ID, sw.Inst_ID)   Inst_ID,            
              NVL(se.Event, sw.Event)       Event,              
              NVL(se.Total_Waits, 0)        Total_Waits,        
              NVL(se.Total_Timeouts, 0)     Total_Timeouts,     
              NVL(se.Time_Waited,0)         Time_waited,        
              NVL(se.Wait_Class, sw.Wait_Class) Wait_Class,     
              NVL(sw.Anzahl_Sessions, 0) Anzahl_Sessions        
        FROM  (SELECT * FROM GV$System_event                    
               #{where_string}
              ) se                                              
        FULL OUTER JOIN                                         
              (SELECT Inst_ID,                                   
                      Event,                                    
                      Count(*) Anzahl_Sessions,                 
                      MIN(Wait_Class) Wait_Class                
               FROM  gV$Session_Wait    
               #{where_string}
               GROUP BY Inst_ID, Event                          
               ) sw                                             
        ON se.Inst_ID=sw.Inst_ID AND se.Event=sw.Event                   
        ORDER BY Inst_ID, Event"].concat(where_values)
    end # get_values
    
    data1 = get_values(filter)    # Snapshot vor SampleTime
    sampletime = params[:sample_length].to_i
    raise "Sampletime muss > 0 sein " if sampletime <= 0    # Kein Sample gewünscht
    sleep sampletime
    ConnectionHolder.connection.clear_query_cache # Result-Caching Ausschalten für wiederholten Zugriff
    data2 = get_values(filter)    # Snapshot nach SampleTime
    
    @data = []            # Leeres Array für Result
    d1_akt_index = 0;     # Vorlesen
    d2_akt_index = 0;     # Vorlesen
    while d1_akt_index < data1.length && d2_akt_index < data2.length # not EOF
      d1 = data1[d1_akt_index];   # Vorlauf Gruppe
      d2 = data2[d2_akt_index];   # Vorlauf Gruppe
      # Verarbeitung
      if d1.inst_id==d2.inst_id && d1.event==d2.event     # Gleicher Satz getroffen
        if d2.total_waits != d1.total_waits || (d1.anzahl_sessions.to_i+d2.anzahl_sessions.to_i) > 0
          total_waits    = d2.total_waits.to_i    - d1.total_waits.to_i
          total_timeouts = d2.total_timeouts.to_i - d1.total_timeouts.to_i
          time_waited    = d2.time_waited.to_i - d1.time_waited.to_i   # 1/100 Sekunden
          @data << {
            :instance       => d1.inst_id,
            :event          => d1.event,
            :total_waits    => formattedNumber(total_waits, 0),
            :total_timeouts => formattedNumber(total_timeouts, 0),
            :time_waited    => formattedNumber(time_waited/100.0 ,3),
            :average_wait   => total_waits > 0 ? formattedNumber((time_waited*10 / (total_waits.to_f)), 2) : "", # Millisekunden
            :wait_class     => d1.wait_class,
            :anzahl_sessions=> d2.anzahl_sessions
          }
        end
      end
      # Nachlesen für den Fall distinct Sätze
      if smaller(d1,d2)
        d1_akt_index = d1_akt_index+1
      else
        d2_akt_index = d2_akt_index+1
      end
    end
    
    respond_to do |format|
      format.js {render :js => "$('#system_events').html('#{j render_to_string :partial=>"show_system_events" }');
                                $('#session_waits').html('');"}
    end
  end # show_system_events
  
  def show_session_waits    # anzeige v$Session_Wait für gegebene Instance und Event
    @inst_id = prepare_param_instance
    @event   = params[:event]
    @session_waits = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Event, Inst_ID, Sid, Wait_Time, Seconds_in_Wait, State,
          p1text, p1, RawToHex(p1raw) P1Raw, 
          p2text, p2, RawToHex(p2raw) P2Raw, 
          p3text, p3, RawToHex(p3raw) P3Raw,
          RowNum Row_Num
        FROM  GV$Session_Wait                                   
        WHERE Inst_ID=?                                          
        AND   Event = ?",
    @inst_id, @event 
    ]
    
    respond_to do |format|
      format.js {render :js => "$('#session_waits').html('#{j render_to_string :partial=>"show_session_waits" }');"}
    end
  end # show_session_waits
  
  def show_session_wait_object
    @object = object_nach_wait_parameter(
                params[:instance],
                params[:event],
                params[:p1], params[:p1raw], params[:p1text],
                params[:p2], params[:p2raw], params[:p2text],
                params[:p3], params[:p3raw], params[:p3text]
              )
    respond_to do |format|
      format.js {render :js => "$('#session_wait_object_#{params[:line_number]}').html('#{j render_to_string :partial=>"show_session_wait_object" }');"}
    end
  end # show_session_wait_object

  def gc_request_latency
    @totals =  sql_select_all "\
                SELECT /* Panorama-Tool Ramm */ b1.INST_ID,
                       ((b1.value / DECODE(b2.value, 0, 1, b2.value)) * 10) Avg_Receive_Time_ms
                FROM   GV$SYSSTAT b1
                JOIN   GV$SYSSTAT b2 ON  b1.INST_ID = b2.INST_ID
                WHERE  b1.NAME = 'gc cr block receive time'
                AND    b2.NAME = 'gc cr blocks received'
        "

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"show_gc_request_latency" }');"}
    end
  end

  def list_gc_request_latency_history
    @instance    = prepare_param_instance
    @dbid        = prepare_param_dbid
    save_session_time_selection   # werte in session puffern

    history = sql_select_all ["
      WITH HIST AS (
          SELECT sy.Instance_Number, sy.DBID, sy.Snap_ID, sy.stat_name, ss.Min_snap_ID, -- Differenz zu vorhergehendem Record
                 sy.Value - LAG(sy.Value, 1, sy.Value) OVER (PARTITION BY sy.Instance_Number, sy.Stat_ID ORDER BY sy.Snap_ID) Value
          FROM DBA_Hist_SysStat sy
          JOIN (SELECT Instance_Number, MIN(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                FROM   DBA_Hist_Snapshot ss
                WHERE  DBID = ?
                AND    Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                AND    Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                #{@instance ? " AND Instance_Number = "+@instance.to_s : ""}
                GROUP BY Instance_Number
               ) ss ON ss.Instance_Number = sy.Instance_Number
          WHERE sy.DBID = ?
          AND   (   sy.Stat_Name LIKE 'g%c% cr block receive time'
                 OR sy.Stat_Name LIKE 'g%c% cr blocks received'
                 OR sy.Stat_Name LIKE 'g%c% current block receive time'
                 OR sy.Stat_Name LIKE 'g%c% current blocks received'
                )
          AND   sy.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
      )
      SELECT x.*,
             ((gc_cr_block_receive_time / DECODE(gc_cr_blocks_received, NULL, 1, 0, 1, gc_cr_blocks_received)) * 10) Avg_cr_Receive_time_ms,
             ((gc_current_block_receive_time / DECODE(gc_current_blocks_received, NULL, 1, 0, 1, gc_current_blocks_received)) * 10) Avg_current_Receive_time_ms
      FROM   (
              SELECT 'SUM' Typ, hist.Instance_Number, NULL Begin_Interval_Time, MIN(hist.Snap_ID) Min_Snap_ID, MAX(hist.Snap_ID) Max_Snap_ID,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% cr block receive time' THEN Value ELSE 0 END )gc_cr_block_receive_time,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% cr blocks received' THEN Value ELSE 0 END )gc_cr_blocks_received,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% current block receive time' THEN Value ELSE 0 END )gc_current_block_receive_time,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% current blocks received' THEN Value ELSE 0 END )gc_current_blocks_received
              FROM   Hist
              WHERE  hist.Snap_ID >= hist.Min_Snap_ID  -- erstes Sample vort Betrachtungszeitraum wieder weglassen (vorher wegen LAG includiert)
              GROUP BY hist.Instance_Number
              UNION ALL
              SELECT 'Detail' Typ, ss.Instance_Number, ss.Begin_Interval_Time, MIN(hist.Snap_ID) Min_Snap_ID, MAX(hist.Snap_ID) Max_Snap_ID,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% cr block receive time' THEN Value ELSE 0 END )gc_cr_block_receive_time,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% cr blocks received' THEN Value ELSE 0 END )gc_cr_blocks_received,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% current block receive time' THEN Value ELSE 0 END )gc_current_block_receive_time,
                     SUM(CASE WHEN hist.Stat_Name LIKE '% current blocks received' THEN Value ELSE 0 END )gc_current_blocks_received
              FROM   Hist
              JOIN   DBA_Hist_Snapshot ss ON ss.DBID = hist.DBID AND ss.Instance_Number = hist.Instance_Number AND ss.Snap_ID = hist.Snap_ID
              WHERE  hist.Snap_ID >= hist.Min_Snap_ID  -- erstes Sample vort Betrachtungszeitraum wieder weglassen (vorher wegen LAG includiert)
              GROUP BY ss.Instance_Number, ss.Begin_Interval_Time
             ) x
      ORDER BY x.Begin_Interval_Time, x.Instance_Number",
      @dbid, @time_selection_start, @time_selection_end, @dbid]

    @history_sum    = []
    @history_detail = []

    history.each do |h|
      @history_detail << h if h.typ == 'Detail'
      @history_sum    << h if h.typ == 'SUM'
    end
    
    respond_to do |format|
      format.js {render :js => "$('#list_gc_request_latency_area').html('#{j render_to_string :partial=>"list_gc_request_latency_history" }');"}
    end
  end # show_session_waits

  # Details zu Zeitabschnitt der gc request latency
  def list_gc_request_latency_history_detail
    @instance    = prepare_param_instance
    @dbid        = prepare_param_dbid
    @min_snap_id = params[:min_snap_id]
    @max_snap_id = params[:max_snap_id]
    @begin_interval_time = params[:begin_interval_time]

    @objects = sql_select_all ["
      SELECT *
      FROM   (
              SELECT o.Owner, o.Object_Name, o.SubObject_Name,
                     SUM(Logical_reads_Delta)           Logical_Reads_Delta,
                     SUM(Buffer_Busy_waits_Delta)       Buffer_Busy_waits_Delta,
                     SUM(DB_Block_Changes_Delta)        DB_Block_Changes_Delta,
                     SUM(Physical_Reads_Delta)          Physical_Reads_Delta,
                     SUM(Physical_Writes_Delta)         Physical_Writes_Delta,
                     SUM(Physical_Reads_Direct_Delta)   Physical_Reads_Direct_Delta,
                     SUM(Physical_Writes_Direct_Delta)  Physical_Writes_Direct_Delta,
                     SUM(ITL_Waits_Delta)               ITL_Waits_Delta,
                     SUM(Row_Lock_Waits_Delta)          Row_Lock_Waits_Delta,
                     SUM(GC_Buffer_Busy_Delta)          GC_Buffer_Busy_Delta,
                     SUM(GC_CR_Blocks_Received_Delta)   GC_CR_Blocks_Received_Delta,
                     SUM(GC_CU_Blocks_Received_Delta)   GC_CU_Blocks_Received_Delta,
                     SUM(Space_Used_Delta)              Space_Used_Delta,
                     SUM(Space_Allocated_Delta)         Space_Allocated_Delta,
                     SUM(Table_Scans_Delta)             Table_Scans_Delta
              FROM   DBA_Hist_Seg_Stat s
              JOIN   DBA_Objects o ON o.Object_ID = s.Obj#
              WHERE  s.DBID = ?
              AND    s.Instance_Number = ?
              AND    s.Snap_ID BETWEEN ? AND ?
              GROUP BY o.Owner, o.Object_Name, o.SubObject_Name
             )
      WHERE  GC_CR_Blocks_Received_Delta > 0
      ORDER BY #{params[:order_by]} DESC
      ", @dbid, @instance, @min_snap_id, @max_snap_id]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_gc_request_latency_history_detail" }');"}
    end
  end

  def show_ges_blocking_enqueue
    @locks = sql_select_all "
      SELECT
      b.inst_id,
      b.grant_level, b.request_level, b.resource_name1, b.resource_name2,
      SUBSTR(b.Resource_Name1, LENGTH(b.Resource_Name1)-3, 2) LockType,
      b.blocked, b.blocker, b.state,
      s.SID, s.Serial# SerialNo, s.UserName, s.Process, s.Machine, s.Terminal, s.Program, s.SQL_ID, s.SQL_Child_Number, s.Module, s.Action, s.Client_info,
      s.Event, s.status
      from   gv$ges_blocking_enqueue b
      JOIN   gv$Process p ON p.Inst_ID = b.Inst_ID AND p.spid = b.pid
      JOIN   gv$Session s ON s.Inst_ID = b.Inst_ID AND s.pAddr = p.Addr
      ORDER BY b.resource_name1
    "
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"show_ges_blocking_enqueue" }');"}
    end
  end


  def list_cpu_usage_historic
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @instance = prepare_param_instance

    where_string = "s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') AND s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"
    where_values = [@time_selection_start, @time_selection_end]

    if @instance
      where_string << ' AND s.Instance_Number = ?'
      where_values << @instance
    end

    @grouping = params[:grouping]

    case @grouping
      when 'dd'   then @sample_seconds = 86400
      when 'hh24' then @sample_seconds = 1440
      when 'mi'   then @sample_seconds = 60
    end

    ash_select_list = 'Sample_Time, Event, Session_State,
                       TM_Delta_CPU_Time/1000000 CPU_Time_Secs,
                       TM_Delta_DB_Time/1000000  DB_Time_Secs   '

    @waits = sql_select_all ["\
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             -- Beginn eines zu betrachtenden Zeitabschnittes
             TRUNC(s.Sample_Time, '#{params[:grouping]}')   Start_Sample,
             COUNT(1)                                       Count_Samples,
             SUM(s.CPU_Time_Secs)                           CPU_Time_Secs,
             SUM(s.DB_Time_Secs)                            DB_Time_Secs,
             SUM(CASE WHEN NVL(Event, Session_State)='ON CPU' THEN Sample_Cycle ELSE 0 END) On_CPU_Secs
      FROM   (SELECT /*+ NO_MERGE ORDERED */
                     10 Sample_Cycle, Instance_Number, #{ash_select_list}
              FROM   DBA_Hist_Active_Sess_History s
              LEFT OUTER JOIN   (SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
              WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
              #{@dba_hist_where_string}
              UNION ALL
              SELECT 1 Sample_Cycle,  Inst_ID Instance_Number, #{ash_select_list}
              FROM   (SELECT s.Inst_ID Instance_Number, s.* FROM gv$Active_Session_History s) s
             )s
      WHERE  #{where_string}
      GROUP BY TRUNC(Sample_Time, '#{params[:grouping]}')
      ORDER BY 1
    "].concat where_values

    render_partial
  end

end
