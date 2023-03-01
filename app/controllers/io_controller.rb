# encoding: utf-8
class IoController < ApplicationController
  include IoHelper

  # Redudant zu Methode aus ActiveSessionHistoryController, da send nur innerhalb des gleichen Controllers praktikabel
  def refresh_time_selection
    params.require [:repeat_controller, :repeat_action]

    params[:groupfilter][:time_selection_start] = params[:time_selection_start] if params[:time_selection_start]
    params[:groupfilter][:time_selection_end]   = params[:time_selection_end]   if params[:time_selection_end]
    params[:groupfilter].each do |key, value|
      params[:groupfilter].delete(key) if params[key] && key!='time_selection_start' && key!='time_selection_end' # Element aus groupfilter loeschen, dass namentlich im param-Hash genannt ist
    end

    # send(params[:repeat_action])              # Ersetzt redirect_to, da dies in Kombination winstone + FireFox nicht sauber funktioniert (Get-Request wird über Post verarbeitet)
    redirect_to url_for(controller: params[:repeat_controller], action: params[:repeat_action], params: params.permit!, method: :post)
  end


  # Hilfsmethode
  def where_from_groupfilter (groupfilter, groupby, key_rule_function)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @global_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @global_where_values  = []             # Filter-werte für nachfolgendes Statement für alle Union-Tabellen

    @with_where_string    = ""
    @with_where_values    = []

    @groupfilter.each do |key,value|
      if key == :time_selection_end || key==:time_selection_start || key==:DBID
        sql = case key
              when :DBID                 then "s.DBID = ?"
              when :time_selection_end   then "s.Begin_Interval_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')"
              when :time_selection_start then "s.End_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')"
              end
        @with_where_string << " AND #{sql}"
        @with_where_values << value
      else
        sql = key_rule_function.call(key)[:sql].clone
        if value && value != ''
          sql << " = ?"
        else
          sql << " IS NULL"
        end
        @global_where_string << " AND #{sql}"
        @global_where_values << value if value && value != ''  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      end
    end
  end # where_from_groupfilter

  private

  # Sql-Code für Differenz zweier TIMESTAMP in Sekunden (aus INTERVAL)
  def timestamp_diff_secs(interval)
    "EXTRACT (DAY    FROM (#{interval}))*86400+\n
     EXTRACT (HOUR   FROM (#{interval}))*3600+\n
     EXTRACT (MINUTE FROM (#{interval}))*60+\n
     EXTRACT (SECOND FROM (#{interval})) "
  end

  public
  ############################################ io_file ###########################################################


  # Einstieg in Historie
  def list_io_file_history
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @groupby    = params[:groupby]
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    groupfilter = {
        :DBID                 => @dbid,
        :time_selection_end   => @time_selection_end,
        :time_selection_start => @time_selection_start,
    }
    groupfilter[:Instance]    = @instance if @instance

    params[:groupfilter] = groupfilter
    list_io_file_history_grouping
  end


  # Union Select gegen DBA_Hist_FileStatxs und DBA_Hist_TempStatxs
  def io_file_history_internal_sql_select
    def single_table_select(table_name, type)
      "SELECT s.Begin_Interval_Time, s.End_Interval_Time, f.Instance_Number, f.Snap_ID, f.FileName, f.TSName, Block_Size, '#{type}' File_Type,
              PhyRds         - LAG(PhyRds,         1, PhyRds)         OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) PhyRds,
              PhyWrts        - LAG(PhyWrts,        1, PhyWrts)        OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) PhyWrts,
              SingleBlkRds   - LAG(SingleBlkRds,   1, SingleBlkRds)   OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) SingleBlkRds,
              ReadTim        - LAG(ReadTim,        1, ReadTim)        OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) ReadTim,
              WriteTim       - LAG(WriteTim,       1, WriteTim)       OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) WriteTim,
              SingleBlkRdTim - LAG(SingleBlkRdTim, 1, SingleBlkRdTim) OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) SingleBlkRdTim,
              PhyBlkRd       - LAG(PhyBlkRd,       1, PhyBlkRd)       OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) PhyBlkRd,
              PhyBlkWrt      - LAG(PhyBlkWrt,      1, PhyBlkWrt)      OVER (PARTITION BY f.DBID, f.Instance_Number, f.File# ORDER BY f.Snap_ID) PhyBlkWrt,
              MIN(f.Snap_ID) KEEP (DENSE_RANK FIRST ORDER BY f.Snap_ID) OVER (PARTITION BY f.Instance_Number) First_Snap_ID -- Erster Treffer zu verwerfen wegen LAG
       FROM   Snaps s
       JOIN   #{table_name} f ON f.DBID=s.DBID AND f.Instance_Number = s.Instance_Number AND f.Snap_ID=s.Snap_ID
      "
    end

    "#{single_table_select("DBA_Hist_FileStatxs", "DATA")}
     UNION ALL
     #{single_table_select("DBA_Hist_TempStatxs", "TEMP")}
    "
  end

  # Liste der Spalten für Selektion in Result-Set (aeusseres SELECT)
  def io_file_history_external_column_list
    "SUM(f.PhyRds)          Physical_Reads,
     SUM(f.PhyRds*f.Block_Size)/1048576  Physical_Reads_MB,
     SUM(f.PhyWrts)         Physical_Writes,
     SUM(f.PhyWrts*f.Block_Size)/1048576  Physical_Writes_MB,
     SUM(f.SingleBlkRds)    Single_Block_Reads,
     SUM(f.SingleBlkRds*f.Block_Size)/1048576  Single_Block_Reads_MB,
     SUM(f.ReadTim)/100     Read_Time_Secs,
     SUM(f.WriteTim)/100    Write_Time_Secs,
     SUM(f.SingleBlkRdTim)/100 Single_Block_Read_Time_Secs,
     SUM(f.PhyBlkRd)        Physical_Blocks_Read,
     SUM(f.PhyBlkWrt)       Physical_Blocks_Written,
     CASE WHEN COUNT(DISTINCT NVL(File_Type, ' ')) = 1 THEN MIN(File_Type) ELSE '< ' || COUNT(DISTINCT NVL(File_Type, ' ')) ||' >' END File_Type,
     (TO_DATE(TO_CHAR(MAX(f.End_Interval_Time), 'DD.MM.YYYY HH24:MI:SS'), 'DD.MM.YYYY HH24:MI:SS') -
              TO_DATE(TO_CHAR(MIN(f.Begin_Interval_Time), 'DD.MM.YYYY HH24:MI:SS'), 'DD.MM.YYYY HH24:MI:SS'))*(24*60*60) Avg_Sample_Secs
    "
  end

  private
  def include_io_file_history_default_select_list
    retval = ""
    io_file_key_rules.each do |key, value|
      retval << ",\nCASE WHEN COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) = 1 THEN TO_CHAR(MIN(#{value[:sql]})) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) ||' >' END #{value[:sql_alias]}"
    end
    retval
  end

  public
  def list_io_file_history_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| io_file_key_rule(key)})

    @ios = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{io_file_key_rule(@groupby)[:sql]}           Group_Value,
             MIN(f.Begin_Interval_Time)                    First_Occurrence,
             MAX(f.End_Interval_Time)                      Last_Occurrence,
             -- So komisch wegen Konvertierung Timestamp nach Date für Subtraktion
             (TO_DATE(TO_CHAR(MAX(f.End_Interval_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}') -
              TO_DATE(TO_CHAR(MIN(f.Begin_Interval_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}'))*(24*60*60) Sample_Dauer_Secs
             #{include_io_file_history_default_select_list},
             COUNT(DISTINCT ROUND(f.Begin_Interval_Time, 'MI'))         Samples,
             #{io_file_history_external_column_list}
      FROM   (#{io_file_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID -- Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger
             #{@global_where_string}
      GROUP BY #{io_file_key_rule(@groupby)[:sql]}
      ORDER BY SUM(f.PhyRds)+SUM(f.PhyWrts) DESC
      " ].concat(@with_where_values).concat(@global_where_values)


    render_partial :list_io_file_history
  end

  # Anzeige der einzelnen Samples der Selektion
  def list_io_file_history_samples
    where_from_groupfilter(params[:groupfilter], nil, proc{|key| io_file_key_rule(key)})

    @samples = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(Begin_Interval_Time, 'MI') Begin_Interval_Time,  End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             f.Begin_Interval_Time,
             #{io_file_history_external_column_list}
      FROM   (#{io_file_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID -- Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger
             #{@global_where_string}
      GROUP BY f.Begin_Interval_Time
      ORDER BY f.Begin_Interval_Time
      " ].concat(@with_where_values).concat(@global_where_values)

    render_partial :list_io_file_history_samples
  end

  #Anzeige Zeitleiste als Diagramm
  def list_io_file_history_timeline
    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| io_file_key_rule(key)})
    @data_column_name = params[:data_column_name]

    data_column = nil
    io_file_values_column_options.each do |c|
      data_column = c if c[:caption] == @data_column_name
    end
    unless data_column && data_column[:raw_data]
      show_popup_message "Column '#{@data_column_name}' is not supported for diagram"
      return
    end

    record_modifier = proc{|rec|
      rec["diagram_value"] = data_column[:raw_data].call(rec)                   # Berechnen des konkreten Wertes
    }

    ios = sql_select_iterator(["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{io_file_key_rule(@groupby)[:sql]}           Group_Value,
             ROUND(f.End_Interval_Time, 'MI')              End_Interval_Time,
             #{io_file_history_external_column_list}
             --#{data_column[:group_operation]}(#{data_column[:data_column]}) Value
      FROM   (#{io_file_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID -- Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger
             #{@global_where_string}
      GROUP BY ROUND(f.End_Interval_Time, 'MI'), #{io_file_key_rule(@groupby)[:sql]}
      ORDER BY ROUND(f.End_Interval_Time, 'MI'), #{io_file_key_rule(@groupby)[:sql]}
      " ].concat(@with_where_values).concat(@global_where_values), record_modifier)

    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ""
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value}\", "
    end
    diagram_caption = "Timeline for #{@data_column_name}, Filter: #{@filter}"

    plot_top_x_diagramm(:data_array     => ios,
                        :time_key_name  => "end_interval_time",
                        :curve_key_name => "group_value",
                        :value_key_name => "diagram_value",
                        :top_x          => 20,
                        :caption        => diagram_caption,
                        :update_area    => params[:update_area]
    )

  end

  ############################################ iostat_detail ###########################################################

  # Einstieg in Historie
  def list_iostat_detail_history
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @groupby    = params[:groupby]
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    groupfilter = {
        :DBID                 => @dbid,
        :time_selection_end   => @time_selection_end,
        :time_selection_start => @time_selection_start,
    }
    groupfilter[:Instance]    = @instance if @instance

    params[:groupfilter] = groupfilter
    list_iostat_detail_history_grouping
  end

  private

  # Liste der Spalten für Selektion in Result-Set (aeusseres SELECT)
  def iostat_detail_history_external_column_list
    "SUM(f.Small_Read_Megabytes)          Small_Read_Megabytes,
     SUM(f.Small_Write_Megabytes)         Small_Write_Megabytes,
     SUM(f.Large_Read_Megabytes)          Large_Read_Megabytes,
     SUM(f.Large_Write_Megabytes)         Large_Write_Megabytes,
     SUM(f.Small_Read_Reqs)               Small_Read_Reqs,
     SUM(f.Small_Write_Reqs)              Small_Write_Reqs,
     SUM(f.Large_Read_Reqs)               Large_Read_Reqs,
     SUM(f.Large_Write_Reqs)              Large_Write_Reqs,
     SUM(f.Number_of_Waits)               Number_of_Waits,
     SUM(f.Wait_Time)                     Wait_Time
    "
  end

  def iostat_detail_history_internal_sql_select
    result = "SELECT s.*, f.Function_Name, f.FileType_Name,
             "

    def iostat_detail_history_internal_sql_select_column(column)
      "#{column} - LAG(#{column}, 1, #{column}) OVER (PARTITION BY f.DBID, f.Instance_Number, f.Function_ID, f.FileType_ID ORDER BY f.Snap_ID) #{column},\n"
    end

    result << iostat_detail_history_internal_sql_select_column('Small_Read_Megabytes')
    result << iostat_detail_history_internal_sql_select_column('Small_Write_Megabytes')
    result << iostat_detail_history_internal_sql_select_column('Large_Read_Megabytes')
    result << iostat_detail_history_internal_sql_select_column('Large_Write_Megabytes')
    result << iostat_detail_history_internal_sql_select_column('Small_Read_Reqs')
    result << iostat_detail_history_internal_sql_select_column('Small_Write_Reqs')
    result << iostat_detail_history_internal_sql_select_column('Large_Read_Reqs')
    result << iostat_detail_history_internal_sql_select_column('Large_Write_Reqs')
    result << iostat_detail_history_internal_sql_select_column('Number_Of_Waits')
    result << iostat_detail_history_internal_sql_select_column('Wait_Time')
    result << "MIN(f.Snap_ID) KEEP (DENSE_RANK FIRST ORDER BY f.Snap_ID) OVER (PARTITION BY f.Instance_Number) First_Snap_ID /* Erster Treffer zu verwerfen wegen LAG */
     FROM   Snaps s
     JOIN   DBA_Hist_IOStat_Detail f ON f.DBID=s.DBID AND f.Instance_Number = s.Instance_Number AND f.Snap_ID=s.Snap_ID
    "
    result
  end

  def include_iostat_detail_history_default_select_list
    retval = ""
    iostat_detail_key_rules.each do |key, value|
      retval << ",\nCASE WHEN COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) = 1 THEN TO_CHAR(MIN(#{value[:sql]})) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) ||' >' END #{value[:sql_alias]}"
    end
    retval
  end

  public

  def list_iostat_detail_history_grouping

    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| iostat_detail_key_rule(key)})

    @ios = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{iostat_detail_key_rule(@groupby)[:sql]}           Group_Value,
             MIN(f.Begin_Interval_Time)                    First_Occurrence,
             MAX(f.End_Interval_Time)                      Last_Occurrence,
             #{timestamp_diff_secs('MAX(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs
             #{include_iostat_detail_history_default_select_list},
             COUNT(DISTINCT ROUND(f.Begin_Interval_Time, 'MI')) Samples,
             #{iostat_detail_history_external_column_list}
      FROM   (#{iostat_detail_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY #{iostat_detail_key_rule(@groupby)[:sql]}
      ORDER BY SUM(f.Number_of_Waits) DESC
      " ].concat(@with_where_values).concat(@global_where_values)

    render_partial "list_iostat_detail_history"
  end

  # Anzeige der einzelnen Samples der Selektion
  def list_iostat_detail_history_samples
    where_from_groupfilter(params[:groupfilter], nil, proc{|key| iostat_detail_key_rule(key)})

    @samples = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(Begin_Interval_Time, 'MI') Round_Begin_Interval_Time, Begin_Interval_Time,  End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             f.Round_Begin_Interval_Time Begin_Interval_Time,
             #{timestamp_diff_secs('MIN(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs,
             #{iostat_detail_history_external_column_list}
      FROM   (#{iostat_detail_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY f.Round_Begin_Interval_Time
      ORDER BY f.Round_Begin_Interval_Time
      " ].concat(@with_where_values).concat(@global_where_values)

    render_partial :list_iostat_detail_history_samples
  end

  #Anzeige Zeitleiste als Diagramm
  def list_iostat_detail_history_timeline
    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| iostat_detail_key_rule(key)})
    @data_column_name = params[:data_column_name]

    data_column = nil
    iostat_detail_values_column_options.each do |c|
      data_column = c if c[:caption] == @data_column_name
    end
    unless data_column && data_column[:raw_data]
      show_popup_message "Column '#{@data_column_name}' is not supported for diagram"
      return
    end

    record_modifier = proc{|rec|
      rec["diagram_value"] = data_column[:raw_data].call(rec)                   # Berechnen des konkreten Wertes
    }

    ios = sql_select_iterator(["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(End_Interval_Time, 'MI') Round_End_Interval_Time, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{iostat_detail_key_rule(@groupby)[:sql]}           Group_Value,
             Round_End_Interval_Time,
             #{timestamp_diff_secs('MIN(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs,
             #{iostat_detail_history_external_column_list}
             --#{data_column[:group_operation]}(#{data_column[:data_column]}) Value
      FROM   (#{iostat_detail_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY Round_End_Interval_Time, #{iostat_detail_key_rule(@groupby)[:sql]}
      ORDER BY Round_End_Interval_Time, #{iostat_detail_key_rule(@groupby)[:sql]}
                          " ].concat(@with_where_values).concat(@global_where_values), record_modifier)

    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ""
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value}\", "
    end
    diagram_caption = "Timeline for #{@data_column_name}, Filter: #{@filter}"

    plot_top_x_diagramm(:data_array     => ios,
                        :time_key_name  => "round_end_interval_time",
                        :curve_key_name => "group_value",
                        :value_key_name => "diagram_value",
                        :top_x          => 20,
                        :caption        => diagram_caption,
                        :update_area    => params[:update_area]
    )

  end

  ############################################ iostat_filetype ###########################################################

  # Einstieg in Historie
  def list_iostat_filetype_history
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @groupby    = params[:groupby]
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    groupfilter = {
        :DBID                 => @dbid,
        :time_selection_end   => @time_selection_end,
        :time_selection_start => @time_selection_start,
    }
    groupfilter[:Instance]    = @instance if @instance

    params[:groupfilter] = groupfilter
    list_iostat_filetype_history_grouping
  end

  private

  # Liste der Spalten für Selektion in Result-Set (aeusseres SELECT)
  def iostat_filetype_history_external_column_list
    "SUM(f.Small_Read_Megabytes)          Small_Read_Megabytes,
     SUM(f.Small_Write_Megabytes)         Small_Write_Megabytes,
     SUM(f.Large_Read_Megabytes)          Large_Read_Megabytes,
     SUM(f.Large_Write_Megabytes)         Large_Write_Megabytes,
     SUM(f.Small_Read_Reqs)               Small_Read_Reqs,
     SUM(f.Small_Write_Reqs)              Small_Write_Reqs,
     SUM(f.Small_Sync_Read_Reqs)          Small_Sync_Read_Reqs,
     SUM(f.Large_Read_Reqs)               Large_Read_Reqs,
     SUM(f.Large_Write_Reqs)              Large_Write_Reqs,
     SUM(Small_Read_ServiceTime)          Small_Read_ServiceTime,
     SUM(Small_Write_ServiceTime)         Small_Write_ServiceTime,
     SUM(Small_Sync_Read_Latency)         Small_Sync_Read_Latency,
     SUM(Large_Read_ServiceTime)          Large_Read_ServiceTime,
     SUM(Large_Write_ServiceTime)         Large_Write_ServiceTime,
     SUM(Retries_On_Error)                Retries_On_Error
    "
  end

  def iostat_filetype_history_internal_sql_select
    result = "SELECT s.*, f.FileType_Name,
             "

    def iostat_filetype_history_internal_sql_select_column(column)
      "#{column} - LAG(#{column}, 1, #{column}) OVER (PARTITION BY f.DBID, f.Instance_Number, f.FileType_ID ORDER BY f.Snap_ID) #{column},\n"
    end

    result << iostat_filetype_history_internal_sql_select_column('Small_Read_Megabytes')
    result << iostat_filetype_history_internal_sql_select_column('Small_Write_Megabytes')
    result << iostat_filetype_history_internal_sql_select_column('Large_Read_Megabytes')
    result << iostat_filetype_history_internal_sql_select_column('Large_Write_Megabytes')
    result << iostat_filetype_history_internal_sql_select_column('Small_Read_Reqs')
    result << iostat_filetype_history_internal_sql_select_column('Small_Write_Reqs')
    result << iostat_filetype_history_internal_sql_select_column('Small_Sync_Read_Reqs')
    result << iostat_filetype_history_internal_sql_select_column('Large_Read_Reqs')
    result << iostat_filetype_history_internal_sql_select_column('Large_Write_Reqs')
    result << iostat_filetype_history_internal_sql_select_column('Small_Read_ServiceTime')
    result << iostat_filetype_history_internal_sql_select_column('Small_Write_ServiceTime')
    result << iostat_filetype_history_internal_sql_select_column('Small_Sync_Read_Latency')
    result << iostat_filetype_history_internal_sql_select_column('Large_Read_ServiceTime')
    result << iostat_filetype_history_internal_sql_select_column('Large_Write_ServiceTime')
    result << iostat_filetype_history_internal_sql_select_column('Retries_On_Error')

    result << "MIN(f.Snap_ID) KEEP (DENSE_RANK FIRST ORDER BY f.Snap_ID) OVER (PARTITION BY f.Instance_Number) First_Snap_ID /* Erster Treffer zu verwerfen wegen LAG */
     FROM   Snaps s
     JOIN   DBA_Hist_IOStat_FileType f ON f.DBID=s.DBID AND f.Instance_Number = s.Instance_Number AND f.Snap_ID=s.Snap_ID
    "
    result
  end

  def include_iostat_filetype_history_default_select_list
    retval = ""
    iostat_filetype_key_rules.each do |key, value|
      retval << ",\nCASE WHEN COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) = 1 THEN TO_CHAR(MIN(#{value[:sql]})) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) ||' >' END #{value[:sql_alias]}"
    end
    retval
  end

  public

  def list_iostat_filetype_history_grouping

    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| iostat_filetype_key_rule(key)})

    @ios = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{iostat_filetype_key_rule(@groupby)[:sql]}           Group_Value,
             MIN(f.Begin_Interval_Time)                    First_Occurrence,
             MAX(f.End_Interval_Time)                      Last_Occurrence,
             #{timestamp_diff_secs('MAX(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs
             #{include_iostat_filetype_history_default_select_list},
             COUNT(DISTINCT ROUND(f.Begin_Interval_Time, 'MI')) Samples,
             #{iostat_filetype_history_external_column_list}
      FROM   (#{iostat_filetype_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY #{iostat_filetype_key_rule(@groupby)[:sql]}
      ORDER BY SUM(f.Small_Read_Reqs) DESC
      " ].concat(@with_where_values).concat(@global_where_values)

    render_partial "list_iostat_filetype_history"
  end

  # Anzeige der einzelnen Samples der Selektion
  def list_iostat_filetype_history_samples
    where_from_groupfilter(params[:groupfilter], nil, proc{|key| iostat_filetype_key_rule(key)})

    @samples = sql_select_iterator ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(Begin_Interval_Time, 'MI') Round_Begin_Interval_Time, Begin_Interval_Time,  End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             f.Round_Begin_Interval_Time Begin_Interval_Time,
             #{timestamp_diff_secs('MIN(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs,
             #{iostat_filetype_history_external_column_list}
      FROM   (#{iostat_filetype_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY f.Round_Begin_Interval_Time
      ORDER BY f.Round_Begin_Interval_Time
      " ].concat(@with_where_values).concat(@global_where_values)

    render_partial :list_iostat_filetype_history_samples
  end

  #Anzeige Zeitleiste als Diagramm
  def list_iostat_filetype_history_timeline
    where_from_groupfilter(params[:groupfilter], params[:groupby], proc{|key| iostat_filetype_key_rule(key)})
    @data_column_name = params[:data_column_name]

    data_column = nil
    iostat_filetype_values_column_options.each do |c|
      data_column = c if c[:caption] == @data_column_name
    end
    unless data_column && data_column[:raw_data]
      show_popup_message "Column '#{@data_column_name}' is not supported for diagram"
      return
    end

    record_modifier = proc{|rec|
      rec["diagram_value"] = data_column[:raw_data].call(rec)                   # Berechnen des konkreten Wertes
    }

    ios = sql_select_iterator(["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(End_Interval_Time, 'MI') Round_End_Interval_Time, Begin_Interval_Time, End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             #{iostat_filetype_key_rule(@groupby)[:sql]}           Group_Value,
             Round_End_Interval_Time,
             #{timestamp_diff_secs('MIN(f.End_Interval_Time) - MIN(f.Begin_Interval_Time)')} Sample_Dauer_Secs,
             #{iostat_filetype_history_external_column_list}
             --#{data_column[:group_operation]}(#{data_column[:data_column]}) Value
      FROM   (#{iostat_filetype_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID /* Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger */
             #{@global_where_string}
      GROUP BY Round_End_Interval_Time, #{iostat_filetype_key_rule(@groupby)[:sql]}
      ORDER BY Round_End_Interval_Time, #{iostat_filetype_key_rule(@groupby)[:sql]}
                          " ].concat(@with_where_values).concat(@global_where_values), record_modifier)

    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ""
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value}\", "
    end
    diagram_caption = "Timeline for #{@data_column_name}, Filter: #{@filter}"

    plot_top_x_diagramm(:data_array     => ios,
                        :time_key_name  => "round_end_interval_time",
                        :curve_key_name => "group_value",
                        :value_key_name => "diagram_value",
                        :top_x          => 20,
                        :caption        => diagram_caption,
                        :update_area    => params[:update_area]
    )

  end


end
