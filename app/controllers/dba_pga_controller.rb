# encoding: utf-8
class DbaPgaController < ApplicationController
  include DbaHelper
  include DbaPgaHelper

  def show_pga_stat_current
    @stats = sql_select_all "
      SELECT /*+ Panorama-Tool Ramm */ s.Inst_ID, COUNT(*) Sessions,
             SUM(pga_used_mem)/(1024*1024)      Sum_Used_Mem_MB,
             AVG(pga_used_mem)/(1024*1024)      Avg_Used_Mem_MB,
             SUM(pga_alloc_mem)/(1024*1024)     Sum_alloc_Mem_MB,
             AVG(pga_alloc_mem)/(1024*1024)     Avg_alloc_Mem_MB,
             SUM(pga_freeable_mem)/(1024*1024)  Sum_freeable_Mem_MB,
             AVG(pga_freeable_mem)/(1024*1024)  Avg_freeable_Mem_MB,
             SUM(pga_max_mem)/(1024*1024)       Sum_Max_Mem_MB,
             AVG(pga_max_mem)/(1024*1024)       Avg_Max_Mem_MB
      FROM gv$Session s
      JOIN gv$Process p ON p.Inst_ID=s.Inst_ID AND p.Addr = s.pAddr
      GROUP BY s.Inst_ID
    "

    @process_memory = sql_select_all "\
      SELECT Inst_ID, Category,
             SUM(Allocated)     / (1024*1024) Allocated_MB,
      SUM(Used)          / (1024*1024) Used_MB,
      SUM(Max_Allocated) / (1024*1024) Max_Allocated_MB
      FROM GV$Process_Memory
      GROUP BY Inst_ID, Category
      ORDER BY 3 DESC
    "

    @pgastat = sql_select_all "SELECT * FROM gv$PGAStat ORDER BY Name, Inst_ID"

    @pgastat.each do |p|
      known_stat = known_pga_stat_columns[p.name]
      if known_stat
        p[:caption]     = known_stat[:caption]
        p[:show_value]  = fn(p.value/known_stat[:divisor], known_stat[:scale])
        p[:title]       = known_stat[:title]
        p[:value_title] = size_explain(p.value/known_stat[:divisor])
      else
        p[:caption]     = p.name
        p[:show_value]  = p.value
        p[:title]       = "No explanation available for PGA area"
        p[:value_title] = nil
      end
    end
    render_partial
  end

  def list_process_memory_sessions
    prepare_param_instance
    @category = prepare_param :category
    order_by  = prepare_param :order_by

    @sessions = sql_select_iterator ["\
      SELECT m.Inst_ID, m.Category, s.SID, p.SPID, p.Program p_Program, s.Serial# Serial_No, s.OSUser, s.UserName DB_User, s.Machine, s.Program, s.Status, s.Logon_Time,
             p.PGA_Used_Mem       / (1024*1024) PGA_Used_MB,
             p.PGA_Alloc_Mem      / (1024*1024) PGA_Alloc_MB,
             p.PGA_Freeable_Mem   / (1024*1024) PGA_Freeable_MB,
             p.PGA_Max_Mem        / (1024*1024) PGA_Max_MB,
             m.Allocated          / (1024*1024) Allocated_MB,
             m.Used               / (1024*1024) Used_MB,
             m.Max_Allocated      / (1024*1024) Max_Allocated_MB
      FROM   gV$Process_Memory m
      LEFT OUTER JOIN   gv$Process p ON p.PID = m.PID AND p.Serial# = m.Serial#
      LEFT OUTER JOIN   gv$Session s ON s.PAddr = p.Addr
      WHERE  m.Category = ?
      AND    NVL(m.#{order_by}, 0) != 0
      ORDER BY m.#{order_by} DESC
    ", @category]

    render_partial
  end

  def list_pga_stat_historic
    @instance = prepare_param_instance
    @dbid     = prepare_param_dbid
    raise PopupMessageException.new("Parameter 'Instance' must be set") unless @instance
    save_session_time_selection   # werte in session puffern


    snaps = sql_select_first_row [
      " SELECT MIN(Snap_ID)-1 Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
        FROM   DBA_Hist_Snapshot
        WHERE  DBID = ?
        AND    Instance_Number = ?
        AND    Begin_Interval_Time BETWEEN  TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_end)}')
      ", @dbid, @instance, @time_selection_start, @time_selection_end ]

    raise PopupMessageException.new("There are no AWR-snapshots between #{@time_selection_start} and #{@time_selection_end}!
Please use a larger period with valid AWR data.
Min, Snap_ID = #{snaps.min_snap_id}, max,, Snap_ID = #{snaps.max_snap_id}") if snaps.min_snap_id.nil? || snaps.max_snap_id.nil?

    stats = sql_select_iterator [
      " SELECT /*+ Panorama-Tool Ramm */ ss.Begin_Interval_Time, x.Name, x.Value
        FROM   (
                          SELECT Snap_ID, DBID, Instance_Number, Name,                    Value                 FROM   DBA_Hist_PGAStat
                UNION ALL SELECT Snap_ID, DBID, Instance_Number, 'Used_' ||Category Name, Used_Total      Value FROM   DBA_Hist_Process_Mem_Summary
                UNION ALL SELECT Snap_ID, DBID, Instance_Number, 'Alloc_'||Category Name, Allocated_Total Value FROM   DBA_Hist_Process_Mem_Summary
               ) x
        JOIN   DBA_Hist_Snapshot ss ON ss.DBID = x.DBID AND ss.Instance_Number = x.Instance_Number AND ss.Snap_ID = x.Snap_ID
        WHERE  x.DBID = ?
        AND    x.Instance_Number = ?
        AND    x.Snap_ID BETWEEN ? AND ?
        ORDER BY Begin_Interval_Time
      ", @dbid, @instance, snaps.min_snap_id, snaps.max_snap_id ]

#    mem_summary =

    @stats = []          # Result-Array
    record = {}
    header = {}
    empty = true
    record.extend SelectHashHelper
    stats.each do |s|     # Iteration über einzelwerte
      empty = false
      record["begin_interval_time"] = s.begin_interval_time unless record["begin_interval_time"] # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record["begin_interval_time"] != s.begin_interval_time
        @stats << record
        record = {}
        record["begin_interval_time"] = s.begin_interval_time
        record.extend SelectHashHelper
      end
      record[s.name] = s.value      # Kreuzprodukt(Pivot) bilden
      header[s.name] = true
    end
    @stats << record unless empty    # Letzten Record in Array schreiben wenn Daten vorhanden

    last_bytes_processed = nil
    last_extra_processed = nil
    last_memory_freed    = nil
    last_recompute_count = nil
    @stats.each do |s|  # Differenzen zwischen Zeiträumen ermitteln
      act_bytes_processed = s["bytes processed"];             s["bytes processed"]             = (last_bytes_processed && act_bytes_processed ? act_bytes_processed - last_bytes_processed : 0 ); last_bytes_processed = act_bytes_processed
      act_extra_processed = s["extra bytes read/written"];    s["extra bytes read/written"]    = (last_extra_processed && act_extra_processed ? act_extra_processed - last_extra_processed : 0 ); last_extra_processed = act_extra_processed
      act_memory_freed    = s["PGA memory freed back to OS"]; s["PGA memory freed back to OS"] = (last_memory_freed    && act_memory_freed    ? act_memory_freed    - last_memory_freed    : 0 ); last_memory_freed    = act_memory_freed
      act_recompute_count = s["recompute count (total)"];     s["recompute count (total)"]     = (last_recompute_count && act_recompute_count ? act_recompute_count - last_recompute_count : 0 ); last_recompute_count = act_recompute_count

      if s["extra bytes read/written"] + s["bytes processed"] > 0
        s["cache hit percentage"] = 100.0 - ( 100 * s["extra bytes read/written"].to_f / (s["extra bytes read/written"] + s["bytes processed"]).to_f )
      else
        0
      end

      header.each do |key,value|
        s[key] = 0 unless s[key]    # Nicht belegt Felder mit valider Nummer fuellen wenn nicht im Result enthalten (Wichtig für Division)
      end

    end

    @stats.delete_at(0) unless empty # erste Zeile des Result löschen

    column_options =
      [
        {:caption=>"Timestamp",        :data=>proc{|rec| localeDateTime(rec.begin_interval_time)},  :title=>"Start of sampe period", :plot_master_time=>true},
      ]
    known_pga_stat_columns.each do |key, value|
      if header[key]  # Spalte hinzufügen wenn im Result auch wirklich vorhanden
        column_option =  {
          caption:    value[:caption],
          data:       proc{|rec| fn(rec[key]/value[:divisor], value[:scale])},
          name:       key,
          title:      value[:title],
          align:      :right
        }
        column_option[:data_title] = proc{|rec| "%t\n\n#{size_explain(rec[key]/value[:divisor])}"} if value[:divisor] == (1024*1024).to_f
        column_options << column_option
      end
    end

    # Hinzufügen der Spalten, die nicht vordeklariert sind
    header.each do |key, value|
      found = false
      column_options.each do |c|
        found = true if c[:name] == key
      end
      column_options << {:caption=>key, :data=>"rec['#{key}']", :title=>key.to_s, :align=>"right" } unless found  # Nicht in vordefinierten Spalten gefunden, dann hinzu
    end

    caption = "PGA history between #{@time_selection_start} and #{@time_selection_end} for instance = #{@instance}, DBID = '#{@dbid}'"

    output = gen_slickgrid(@stats, column_options, {
      caption: caption,
      :multiple_y_axes=>false,
      :show_y_axes=>true,
      :max_height => 450,
      show_pin_icon: 1,
    })
    respond_to do |format|
      format.html {render :html => output }
    end
  end

  def list_process_memory_detail
    @instance = prepare_param_instance
    @pid      = prepare_param :pid
    @category = prepare_param :category

    @details = sql_select_iterator ["\
SELECT m.*, m.Serial# Serial_No,
       RawToHex(m.Heap_Descriptor) Hex_Heap_Descriptor,
       RawToHex(m.Parent_Heap_Descriptor) Hex_Parent_Heap_Descriptor
FROM   gv$Process_Memory_Detail m
WHERE  m.Inst_ID  = ?
AND    m.PID      = ?
AND    m.Category = ?
      ", @instance, @pid, @category]
    render_partial
  end

end
