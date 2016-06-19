# encoding: utf-8
class DbaPgaController < ApplicationController
  include DbaHelper

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
    column_options =
      [
        {:caption=>"I",                                   :data=>proc{|rec| rec.inst_id},                   :title=>"RAC-Instance", :align=>:right},
        {:caption=>"Sessions",                            :data=>proc{|rec| fn(rec.sessions)},              :title=>"Number of sessions", :align=>:right},
        {:caption=>"Total PGA in use (MB)",               :data=>proc{|rec| fn(rec.sum_used_mem_mb)},       :title=>"Indicates how much PGA memory is currently consumed by work areas. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java).", :align=>:right},
        {:caption=>"Avg. PGA in use per session (MB)",    :data=>proc{|rec| fn(rec.avg_used_mem_mb,2)},     :title=>"Indicates how much PGA memory is currently consumed by work areas per session. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java).", :align=>:right},
        {:caption=>"Total PGA allocated (MB)",            :data=>proc{|rec| fn(rec.sum_alloc_mem_mb)},      :title=>"Current amount of PGA memory allocated by the instance. The Oracle Database attempts to keep this number below the value of the PGA_AGGREGATE_TARGET initialization parameter. However, it is possible for the PGA allocated to exceed that value by a small percentage and for a short period of time when the work area workload is increasing very rapidly or when PGA_AGGREGATE_TARGET is set to a small value.", :align=>:right},
        {:caption=>"Avg. PGA allocated per session (MB)", :data=>proc{|rec| fn(rec.avg_alloc_mem_mb,2)},    :title=>"Current amount of PGA memory allocated by the instance per session. The Oracle Database attempts to keep this number below the value of the PGA_AGGREGATE_TARGET initialization parameter. However, it is possible for the PGA allocated to exceed that value by a small percentage and for a short period of time when the work area workload is increasing very rapidly or when PGA_AGGREGATE_TARGET is set to a small value.", :align=>:right},
        {:caption=>"Freeable PGA (MB)",                   :data=>proc{|rec| fn(rec.sum_freeable_mem_mb)},   :title=>"Number of bytes of PGA memory in all processes that could be freed back to the operating system.", :align=>:right},
        {:caption=>"Avg. freeable PGA per session (MB)",  :data=>proc{|rec| fn(rec.avg_freeable_mem_mb,2)}, :title=>"Number of bytes of PGA memory per session that could be freed back to the operating system.", :align=>:right},
        {:caption=>"Max. PGA in use (MB)",                :data=>proc{|rec| fn(rec.sum_max_mem_mb)},        :title=>"Maximum amount of PGA memory consumed at one time by work areas since instance startup.", :align=>:right},
        {:caption=>"Avg. max. PGA per session (MB)",      :data=>proc{|rec| fn(rec.avg_max_mem_mb,2)},      :title=>"Maximum amount of PGA memory per session consumed at one time by work areas since instance startup.", :align=>:right},
      ]

    output = gen_slickgrid(@stats, column_options, {
        :caption => "Current PGA at #{localeDateTime(Time.now)}",
        :max_height => 450
    })
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j output }');"
      }
    end


  end

  def list_pga_stat_historic
    @instance = prepare_param_instance
    @dbid     = prepare_param_dbid
    raise "Parameter 'Instance' must be set" unless @instance
    save_session_time_selection   # werte in session puffern


    snaps = sql_select_first_row [
      " SELECT MIN(Snap_ID)-1 Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
        FROM   DBA_Hist_Snapshot
        WHERE  DBID = ?
        AND    Instance_Number = ?
        AND    Begin_Interval_Time BETWEEN  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') AND TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      ", @dbid, @instance, @time_selection_start, @time_selection_end ]

    raise "There are no AWR-snapshots between #{@time_selection_start} and #{@time_selection_end}!\nPlease use a larger period with valid AWR data." if snaps.min_snap_id.nil? || snaps.max_snap_id.nil?

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

    million = (1024*1024).to_f

    known_columns = {
      "aggregate PGA target parameter"      => {:caption=>"aggregate PGA target parameter (MB)",      :data=>proc{|rec| formattedNumber(rec['aggregate PGA target parameter']/million,2)},      :title=>"Current value of the PGA_AGGREGATE_TARGET initialization parameter. If this parameter is not set, then its value is 0 and automatic management of PGA memory is disabled."},
      "aggregate PGA auto target"           => {:caption=>"aggregate PGA auto target (MB)",           :data=>proc{|rec| formattedNumber(rec['aggregate PGA auto target']/million,2)},           :title=>"Amount of PGA memory the Oracle Database can use for work areas running in automatic mode. This amount is dynamically derived from the value of the PGA_AGGREGATE_TARGET initialization parameter and the current work area workload, and continuously adjusted by the Oracle Database. If this value is small compared to the value of PGA_AGGREGATE_TARGET, then a large amount of PGA memory is used by other components of the system (for example, PL/SQL or Java memory) and little is left for work areas. The DBA must ensure that enough PGA memory is left for work areas running in automatic mode."},
      "global memory bound"                 => {:caption=>"global memory bound (MB)",                 :data=>proc{|rec| formattedNumber(rec['global memory bound']/million,2)},                 :title=>"Maximum size of a work area executed in automatic mode. This value is continuously adjusted by the Oracle Database to reflect the current state of the work area workload. The global memory bound generally decreases when the number of active work areas is increasing in the system. If the value of the global bound decreases below 1 MB, then the value of PGA_AGGREGATE_TARGET should be increased."},
      "total PGA inuse"                     => {:caption=>"total PGA in use (MB)",                    :data=>proc{|rec| formattedNumber(rec['total PGA inuse']/million,2)},                     :title=>"Indicates how much PGA memory is currently consumed by work areas. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java)."},
      "Used_SQL"                            => {:caption=>"PGA used for SQL (MB)",                    :data=>proc{|rec| formattedNumber(rec['Used_SQL']/million,2)},                            :title=>"Used memory for category 'SQL'."},
      "Used_PL/SQL"                         => {:caption=>"PGA used for PL/SQL (MB)",                 :data=>proc{|rec| formattedNumber(rec['Used_PL/SQL']/million,2)},                         :title=>"Used memory for category 'PL/SQL'."},
      "Used_Other"                         => {:caption=>"PGA used for Other (MB)",                   :data=>proc{|rec| formattedNumber(rec['Used_Other']/million,2)},                          :title=>"Used memory for category 'Other'."},
      "Used_Freeable"                         => {:caption=>"PGA used freeable (MB)",                 :data=>proc{|rec| formattedNumber(rec['Used_Freeable']/million,2)},                       :title=>"Used memory for category 'Freeable'."},
      "total PGA allocated"                 => {:caption=>"total PGA allocated (MB)",                 :data=>proc{|rec| formattedNumber(rec['total PGA allocated']/million,2)},                 :title=>"Current amount of PGA memory allocated by the instance. The Oracle Database attempts to keep this number below the value of the PGA_AGGREGATE_TARGET initialization parameter. However, it is possible for the PGA allocated to exceed that value by a small percentage and for a short period of time when the work area workload is increasing very rapidly or when PGA_AGGREGATE_TARGET is set to a small value."},
      "maximum PGA allocated"               => {:caption=>"maximum PGA allocated (MB)",               :data=>proc{|rec| formattedNumber(rec['maximum PGA allocated']/million, 2)},              :title=>"Maximum number of bytes of PGA memory allocated at one time since instance startup."},
      "total PGA used"                      => {:caption=>"total PGA used (MB)",                      :data=>proc{|rec| formattedNumber(rec['total PGA used']/million,2)},                      :title=>"Indicates how much PGA memory is currently consumed by work areas. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java)."},
      "total PGA used for auto workareas"   => {:caption=>"total PGA used for auto workareas (MB)",   :data=>proc{|rec| formattedNumber(rec['total PGA used for auto workareas']/million,2)},   :title=>"Indicates how much PGA memory is currently consumed by work areas running under the automatic memory management mode. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java)."},
      "maximum PGA used for auto workareas" => {:caption=>"maximum PGA used for auto workareas (MB)", :data=>proc{|rec| formattedNumber(rec['maximum PGA used for auto workareas']/million,2)}, :title=>"Maximum amount of PGA memory consumed at one time by work areas running under the automatic memory management mode since instance startup."},
      "total PGA used for manual workareas" => {:caption=>"total PGA used for manual workareas (MB)", :data=>proc{|rec| formattedNumber(rec['total PGA used for manual workareas']/million,2)}, :title=>"Indicates how much PGA memory is currently consumed by work areas running under the manual memory management mode. This number can be used to determine how much memory is consumed by other consumers of the PGA memory (for example, PL/SQL or Java)."},
      "maximum PGA used for manual workareas"=> {:caption=>"maximum PGA used for manual workareas (MB)",:data=>proc{|rec| formattedNumber(rec['maximum PGA used for manual workareas']/million,2)}, :title=>"Maximum amount of PGA memory consumed at one time by work areas running under the manual memory management mode since instance startup."},
      "over allocation count"               => {:caption=>"over allocation count",                    :data=>proc{|rec| formattedNumber(rec['over allocation count'])},                         :title=>"This statistic is cumulative since instance startup. Over allocating PGA memory can happen if the value of PGA_AGGREGATE_TARGET is too small. When this happens, the Oracle Database cannot honor the value of PGA_AGGREGATE_TARGET and extra PGA memory needs to be allocated. If over allocation occurs, then increase the value of PGA_AGGREGATE_TARGET using the information provided by the V$PGA_TARGET_ADVICE view."},
      "bytes processed"                     => {:caption=>"MBytes processed",                         :data=>proc{|rec| formattedNumber(rec['bytes processed']/million,2)},                     :title=>"Number of MBytes processed by memory intensive SQL operators."},
      "extra bytes read/written"            => {:caption=>"extra MBytes read/written",                :data=>proc{|rec| formattedNumber(rec['extra bytes read/written']/million,2)},            :title=>"Number of MBytes processed during extra passes of the input data. When a work area cannot run optimal, one or more of these extra passes is performed."},
      "cache hit percentage"                => {:caption=>"cache hit percentage",                     :data=>proc{|rec| formattedNumber(rec['cache hit percentage'],2)},                        :title=>"A metric computed by the Oracle Database to reflect the performance of the PGA memory component, cumulative since instance startup. A value of 100% means that all work areas executed by the system since instance startup have used an optimal amount of PGA memory. When a work area cannot run optimal, one or more extra passes is performed over the input data. This will reduce the cache hit percentage in proportion to the size of the input data and the number of extra passes performed."},
      "total freeable PGA memory"           => {:caption=>"total freeable PGA memory (MB)",           :data=>proc{|rec| formattedNumber(rec['total freeable PGA memory']/million,2)},           :title=>"Number of MBytes of PGA memory in all processes that could be freed back to the operating system."},
      "PGA memory freed back to OS"         => {:caption=>"PGA memory freed back to OS (MB)",         :data=>proc{|rec| formattedNumber(rec['PGA memory freed back to OS']/million,2)},         :title=>"Number of MBytes of PGA memory freed back to the operating system."},
      "recompute count (total)"             => {:caption=>"recompute count",                          :data=>proc{|rec| formattedNumber(rec['recompute count (total)'])},                       :title=>"Number of times the instance bound, which is a cap on the maximum size of each active work area, has been recomputed. Generally, the instance bound is recomputed in the background every 3 seconds, but it could be recomputed by a foreground process when the number of work areas changes rapidly in a short period of time."},

      "process count"                       => {:caption=>"process count",                            :data=>proc{|rec| formattedNumber(rec['process count'])},                                 :title=>"Number of processes active within up to the last 3 seconds."},
      "max processes count"                 => {:caption=>"max processes count",                      :data=>proc{|rec| formattedNumber(rec['max processes count'])},                           :title=>"Maximum number of processes active at any one time since instance startup."},

    }

    column_options =
      [
        {:caption=>"Timestamp",        :data=>proc{|rec| localeDateTime(rec.begin_interval_time)},  :title=>"Start of sampe period", :plot_master_time=>true},
      ]
    known_columns.each do |key, value|
      column_options << {:caption=>value[:caption], :data=>value[:data], :name=>key, :title=>value[:title], :align=>"right" } if header[key]  # Spalte hinzufüegen wenn im Result auch wirklich vorhanden
    end

    # Hinzufügen der Spalten, die nicht vordeklariert sind
    header.each do |key, value|
      found = false
      column_options.each do |c|
        found = true if c[:name] == key
      end
      column_options << {:caption=>key, :data=>"rec['#{key}']", :title=>key.to_s, :align=>"right" } unless found  # Nicht in vordefinierten Spalten gefunden, dann hinzu
    end

    output = gen_slickgrid(@stats, column_options, {
        :multiple_y_axes=>false,
        :show_y_axes=>true,
        :max_height => 450
    })
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output }');"
      }
    end
  end

end
