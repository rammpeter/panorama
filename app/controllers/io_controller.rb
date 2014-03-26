# encoding: utf-8
class IoController < ApplicationController
  include IoHelper

  def list_io_ash_history

    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_io_ash_history" }');"}
     end

  end



  # Einstieg in Historie
  def list_io_file_history
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @groupby    = params[:groupby]
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    groupfilter = {
        :DBID                 => {:sql => "s.DBID = ?"           , :bind_value => @dbid},
        :time_selection_end   => {:sql => "s.Begin_Interval_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"    , :bind_value => @time_selection_end},
        :time_selection_start => {:sql => "s.End_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"    , :bind_value => @time_selection_start},
    }
    groupfilter[:instance]    = {:sql => "s.Instance_Number = ?" , :bind_value => @instance} if @instance

    params[:groupfilter] = groupfilter
    list_io_file_history_grouping
  end

  # Hilfsmethode
  def where_from_io_file_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @global_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @global_where_values  = []             # Filter-werte für nachfolgendes Statement für alle Union-Tabellen

    @with_where_string    = ""
    @with_where_values    = []



    @groupfilter.each {|key,value|
      if key == "time_selection_end" || key=="time_selection_start" || key=="DBID" || key=="instance"
        @with_where_string << " AND #{value[:sql]}"
        @with_where_values << value[:bind_value]
      else
        if value[:sql] != ""
          @global_where_string << " AND #{value[:sql]}"
          @global_where_values << value[:bind_value] if value[:bind_value] && value[:bind_value] != ''  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
        end
      end
    }
  end # where_from_groupfilter


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

  def list_io_file_history_grouping
    def include_io_file_history_default_select_list
      retval = ""
      io_file_key_rules.each do |key, value|
        retval << ",\nCASE WHEN COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) = 1 THEN TO_CHAR(MIN(#{value[:sql]})) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) ||' >' END #{value[:sql_alias]}"
      end
      retval
    end


    where_from_io_file_groupfilter(params[:groupfilter], params[:groupby])

    @ios = sql_select_all ["\
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


    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_io_file_history" }'); hideIndicator();"}
     end
  end

  # Anzeige der einzelnen Samples der Selektion
  def list_io_file_history_samples
    where_from_io_file_groupfilter(params[:groupfilter], nil)

    @samples = sql_select_all ["\
      WITH Snaps AS (SELECT /*+ NO_MERGE */
                            DBID, Instance_Number, Snap_ID, ROUND(Begin_Interval_Time, 'MI') Begin_Interval_Time,  End_Interval_Time
                     FROM   DBA_Hist_Snapshot s
                     WHERE  1=1 #{@with_where_string}
                    )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             f.Begin_Interval_Time,
             CASE WHEN COUNT(DISTINCT NVL(TO_CHAR(f.Instance_Number), ' ')) = 1 THEN TO_CHAR(MIN(f.Instance_Number)) ELSE '< ' || COUNT(DISTINCT NVL(TO_CHAR(f.Instance_Number), ' ')) ||' >' END Instance_Number,
             #{io_file_history_external_column_list}
      FROM   (#{io_file_history_internal_sql_select}) f
      WHERE  f.Snap_ID != f.First_Snap_ID -- Erster Treffer ist zu verwerfen wegen LAG ohne Vorgänger
             #{@global_where_string}
      GROUP BY f.Begin_Interval_Time
      ORDER BY f.Begin_Interval_Time
      " ].concat(@with_where_values).concat(@global_where_values)

    respond_to do |format|
       format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=> "list_io_file_history_samples" }'); hideIndicator();"}
     end
  end

  #Anzeige Zeitleiste als Diagramm
  def list_io_file_history_timeline
    where_from_io_file_groupfilter(params[:groupfilter], params[:groupby])
    @data_column_name = params[:data_column_name]

    data_column = nil
    io_file_values_column_options.each do |c|
      data_column = c if c[:caption] == @data_column_name
    end
    unless data_column && data_column[:raw_data]
      respond_to do |format|
        format.js {render :js => "alert('#{j "Column '#{@data_column_name}' is not supported for diagram"}');" }
      end
      return
    end


    ios = sql_select_all ["\
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
      " ].concat(@with_where_values).concat(@global_where_values)


    # Transformieren in darzustellende Werte
    ios.each do |i|
      i["diagram_value"] = data_column[:raw_data].call(i)
    end

    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ""
    @groupfilter.each do |key, value|
      @filter << "#{key}=\"#{value[:bind_value]}\", " unless value[:hide_filter]
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

end

