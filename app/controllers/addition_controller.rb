# encoding: utf-8
# Zusatzfunktionen, die auf speziellen Tabellen und Prozessen aufsetzen, die nicht prinzipiell in DB vorhanden sind
class AdditionController < ApplicationController
  def list_db_cache_historic
    max_result_count = params[:maxResultCount]
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    save_session_time_selection                  # Werte puffern fuer spaetere Wiederverwendung

    if @show_partitions == '1'
      partition_expression = "PartitionName"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (SELECT Instance, Owner, Name, PartitionName,
                     AVG(BlocksTotal) AvgBlocksTotal,
                     MIN(BlocksTotal) MinBlocksTotal,
                     Max(BlocksTotal) MaxBlocksTotal,
                     SUM(BlocksTotal) SumBlocksTotal,
                     AVG(BlocksDirty) AvgBlocksDirty,
                     MIN(BlocksDirty) MinBlocksDirty,
                     MAX(BlocksDirty) MaxBlocksDirty,
                     COUNT(*)         Samples
              FROM   (SELECT Instance, Owner, Name, #{partition_expression} PartitionName,
                             SUM(BlocksTotal) BlocksTotal,
                             SUM(BlocksDirty) BlocksDirty
                      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
                      WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                      #{" AND Instance=#{@instance}" if @instance}
                      -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                      GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
                     )
              GROUP BY Instance, Owner, Name, PartitionName
              ORDER BY SUM(BlocksTotal) DESC
             )
      WHERE RowNum <= ?",
                              @time_selection_start, @time_selection_end, max_result_count
                             ]

    respond_to do |format|
      format.js {render :js => "$('#list_db_cache_historic_area').html('#{j render_to_string :partial=>"list_db_cache_historic" }');"}
    end
  end

  def list_db_cache_historic_detail
    @instance = prepare_param_instance
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @owner           = params[:owner]
    @name            = params[:name]
    @partitionname   = params[:partitionname]
    @show_partitions = params[:show_partitions]

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ SnapshotTS,
             SUM(BlocksTotal) BlocksTotal,
             SUM(BlocksDirty) BlocksDirty
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
      WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      AND    Owner    = ?
      AND    Name     = ?
      AND    Instance = ?
      #{" AND PartitionName = ?" if @partitionname}
      GROUP BY SnapshotTS
      ORDER BY SnapshotTS
      "].concat([@time_selection_start, @time_selection_end, @owner, @name, @instance].concat(@partitionname ? [@partitionname] : [])
                             )

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_db_cache_historic_detail" }');"}
    end
  end


  def list_db_cache_historic_snap
    @instance   = prepare_param_instance
    @snapshotts = params[:snapshotts]
    @show_partitions = params[:show_partitions]

    if @show_partitions == '1'
      partition_expression = "PartitionName"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Owner, Name, #{partition_expression} PartitionName,
             SUM(BlocksTotal) BlocksTotal,
             SUM(BlocksDirty) BlocksDirty
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
      WHERE  SnapshotTS = TO_DATE(?, '#{sql_datetime_second_mask}')
      AND    Instance   = ?
      GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
      ORDER BY BlocksTotal DESC
      ", @snapshotts, @instance]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_db_cache_historic_snap" }');"}
    end
  end

  def list_db_cache_historic_timeline
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]

    if @show_partitions == '1'
      partition_expression = "c.PartitionName"
    else
      partition_expression = "NULL"
    end

    singles = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             c.Instance, c.SnapshotTS, c.Owner, c.Name, #{partition_expression} PartitionName, SUM(c.BlocksTotal) BlocksTotal
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects c
      JOIN   (
              SELECT Instance, Owner, Name, PartitionName, SumBlocksTotal
              FROM   (SELECT Instance, Owner, Name, PartitionName,
                             Max(BlocksTotal) MaxBlocksTotal,
                             SUM(BlocksTotal) SumBlocksTotal
                      FROM   (SELECT Instance, Owner, Name, #{partition_expression} PartitionName,
                                     SUM(BlocksTotal) BlocksTotal
                              FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects c
                              WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              #{" AND Instance=#{@instance}" if @instance}
                              -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                              GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
                             )
                      GROUP BY Instance, Owner, Name, PartitionName
                      ORDER BY Max(BlocksTotal) DESC
                     )
              WHERE RowNum <= 10
             ) s ON s.Instance = c.Instance AND s.Owner = c.Owner AND s.Name||s.PartitionName = c.Name||#{partition_expression}
      WHERE  c.SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      #{" AND c.Instance=#{@instance}" if @instance}
      GROUP BY c.Instance, c.SnapShotTS, c.Owner, c.Name, #{partition_expression}
      ORDER BY c.SnapshotTS, MIN(s.SumBlocksTotal) DESC
      ",
                              @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end,
                             ]

    @snapshots = []           # Result-Array
    headers={}               # Spalten
    record = {}
    singles.each do |s|     # Iteration über einzelwerte
      record[:snapshotts] = s.snapshotts unless record[:snapshotts] # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record[:snapshotts] != s.snapshotts
        @snapshots << record
        record = {}
        record[:snapshotts] = s.snapshotts
      end
      colname = "#{"(#{s.instance}) " unless @instance}#{s.owner}.#{s.name} #{"(#{s.partitionname})" if s.partitionname}"
      record[colname] = s.blockstotal
      headers[colname] = true    # Merken, dass Spalte verwendet
    end
    @snapshots << record if singles.length > 0    # Letzten Record in Array schreiben wenn Daten vorhanden

    # Alle nicht belegten Werte mit 0 initialisieren
    @snapshots.each do |s|
      headers.each do |key, value|              # Initialisieren aller Werte zum Zeitpunkt mit 0, falls kein Sample existiert
        s[key] = 0 unless s[key]
      end
    end



    # JavaScript-Array aufbauen mit Daten
    output = ""
    output << "jQuery(function($){"
    output << "var data_array = ["
    headers.each do |key, value|
      output << "  { label: '#{key}',"
      output << "    data: ["
      @snapshots.each do |s|
        output << "[#{milliSec1970(s[:snapshotts])}, #{s[key]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    diagram_caption = "Top 10 Objekte im DB-Cache von #{@time_selection_start} bis #{@time_selection_end} #{"Instance=#{@instance}" if @instance}"

    plot_area_id = "plot_area_#{session[:request_counter]}"
    output << "plot_diagram('#{session[:request_counter]}', '#{plot_area_id}', '#{diagram_caption}', data_array, false, true, true);"
    output << "});"

    html="<div id='#{plot_area_id}'></div>"
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j html}');
                                #{ output}"
      }
    end
  end # list_db_cache_historic_timeline


end
