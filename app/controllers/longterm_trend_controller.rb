# encoding: utf-8
class LongtermTrendController < ApplicationController
  include LongtermTrendHelper

  def list_longterm_trend
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @instance = prepare_param_instance
    params[:groupfilter] = {}
    params[:groupfilter][:Instance]              = @instance if @instance
    params[:groupfilter][:time_selection_start]  = @time_selection_start
    params[:groupfilter][:time_selection_end]    = @time_selection_end

    params[:groupfilter][:additional_filter]     = params[:filter]  if params[:filter] && params[:filter] != ''

    list_longterm_trend_grouping      # Weiterleiten Request an Standard-Verarbeitung für weiteres DrillDown
  end

  def list_longterm_trend_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby])

    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    @sessions= PanoramaConnection.sql_select_iterator(["\
      SELECT #{longterm_trend_key_rule(@groupby)[:sql]} Group_Value,
             SUM(t.Seconds_Active)          Seconds_Active,
             COUNT(1)                       Count_Samples,
             #{include_longterm_trend_default_select_list}
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      GROUP BY #{longterm_trend_key_rule(@groupby)[:sql]}
      ORDER BY SUM(t.Seconds_Active) DESC
     "].concat(@where_values)
    )

    render_partial :list_longterm_trend_grouping
  end

  def list_longterm_trend_historic_timeline
    point_group = params[:point_group].to_sym

    time_group_expr = case point_group
                      when :week then 'DAY'
                      when :day then 'DD'
                      when :hour then 'HH24'
                      else raise "Unknown point_group #{point_group}"
                      end

    where_from_groupfilter(params[:groupfilter], params[:groupby])
    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    singles= sql_select_all ["\
      SELECT TRUNC(Snapshot_Timestamp, '#{time_group_expr}') Snapshot_Start,
             NVL(TO_CHAR(#{longterm_trend_key_rule(@groupby)[:sql]}), 'NULL') Criteria,
             SUM(Seconds_Active) / (COUNT(DISTINCT Snapshot_Timestamp) * MAX(Snapshot_Cycle_Hours) * 3600) Diagram_Value
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      GROUP BY TRUNC(Snapshot_Timestamp, '#{time_group_expr}'), #{longterm_trend_key_rule(@groupby)[:sql]}
      ORDER BY 1
     "].concat(@where_values)


    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ''
    @groupfilter.each do |key, value|
      @filter << "#{groupfilter_value(key)[:name]}=\"#{value}\", " unless groupfilter_value(key)[:hide_content]
    end

    diagram_caption = "Number of waiting sessions condensed by #{point_group} for top-10 grouped by: <b>#{@groupby}</b>, Filter: #{@filter}"

    plot_top_x_diagramm(:data_array         => singles,
                        :time_key_name      => 'snapshot_start',
                        :curve_key_name     => 'criteria',
                        :value_key_name     => 'diagram_value',
                        :top_x              => 10,
                        :caption            => diagram_caption,
                        #:null_points_cycle  => group_seconds,
                        :update_area        => params[:update_area]
    )
  end

  def refresh_time_selection
    params.require [:repeat_controller, :repeat_action]

    if params[:time_selection_start]
      params[:groupfilter][:time_selection_start] = params[:time_selection_start]
    end

    if params[:time_selection_end]
      params[:groupfilter][:time_selection_end]   = params[:time_selection_end]
    end

    params[:groupfilter].each do |key, value|
      params[:groupfilter].delete(key) if params[key] && params[key]=='' && key!='time_selection_start' && key!='time_selection_end' # Element aus groupfilter loeschen, dass namentlich im param-Hash genannt ist
      params[:groupfilter][key] = params[key] if params[key] && params[key]!=''
    end

    # send(params[:repeat_action])              # Ersetzt redirect_to, da dies in Kombination winstone + FireFox nicht sauber funktioniert (Get-Request wird über Post verarbeitet)
    redirect_to url_for(controller: params[:repeat_controller], action: params[:repeat_action], params: params.permit!, method: :post)
  end

  def list_longterm_trend_single_record
    where_from_groupfilter(params[:groupfilter], nil)

    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    if !defined?(@time_groupby) || @time_groupby.nil? || @time_groupby == ''
      record_count = params[:record_count].to_i
      @time_groupby = :single        # Default
      @time_groupby = :week if record_count > 1000
    end

    # Parameter for list_groupfilter.html.erb
    grouping_options = {
        :single    => { :name => t(:active_session_history_list_session_statistic_historic_single_record_group_no_hint, :default=>'No (single records)')},
        :hour      => { :name => t(:hour, :default => 'Hour')},
        :day       => { :name => t(:day,  :default => 'Day')},
        :week      => { :name => t(:week, :default => 'Week') },
        :month     => { :name => t(:month, :default => 'Month')},
    }

    @header = "Long-term trend:<br/>Single snapshot records for': "
    @repeat_action = :list_longterm_trend_single_record

    grouping_content =  "<span title=\"#{t(:grouping_hint, :default=>'Group listing by attribute')}\">"
    grouping_content << '<select name="time_groupby">'
    grouping_options.each do |key, value|
      grouping_content  << "<option value=\"#{key}\" #{"selected='selected'" if key.to_sym==@time_groupby}>#{value[:name]}</option>"
    end
    grouping_content << "</select>"
    grouping_content << "</span>"

    @group_filter_addition = {
        :header  => t(:grouping, :default=>'Grouping'),
        :content => grouping_content
    }


    if @time_groupby == :single
      list_longterm_trend_single_record_single
    else
      list_longterm_trend_single_record_grouping
    end
  end

  # called from list_longterm_trend_single_record
  def list_longterm_trend_single_record_single

    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    @singles = PanoramaConnection.sql_select_iterator(["\
      SELECT t.Snapshot_Timestamp, t.Seconds_Active, t.Instance_Number, t.Snapshot_Cycle_Hours,
             we.Name  Wait_Event,
             wc.Name  Wait_Class,
             u.Name   User_Name,
             s.Name   Service_Name,
             ma.Name  Machine,
             mo.Name  Module,
             a.Name   Action
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      ORDER BY Snapshot_Timestamp, Seconds_Active DESC
     "].concat(@where_values)
    )

    render_partial :list_longterm_trend_single_record_single
  end

  # called from list_longterm_trend_single_record
  def list_longterm_trend_single_record_grouping
    case @time_groupby
    when :hour      then group_by_value = "TRUNC(t.Snapshot_Timestamp, 'HH24')"
    when :day       then group_by_value = "TRUNC(t.Snapshot_Timestamp)"
#    when :week      then group_by_value = "TRUNC(t.Snapshot_Timestamp) + INTERVAL '7' DAY"
    when :week      then group_by_value = "TRUNC(t.Snapshot_Timestamp, 'DAY')"
    when :month     then group_by_value = "TRUNC(t.Snapshot_Timestamp, 'MM')"
    else
      raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    @singles = PanoramaConnection.sql_select_iterator(["\
      SELECT MIN(t.Snapshot_Timestamp)    Min_Snapshot_Timestamp,
             MAX(t.Snapshot_Timestamp)    Max_Snapshot_Timestamp,
             SUM(t.Seconds_Active)        Seconds_Active,
             MIN(t.Snapshot_Cycle_Hours)  Min_Snapshot_Cycle_Hours,
             COUNT(*)                     Samples,
             MIN(t.Instance_Number)       Instance_Number,    COUNT(DISTINCT t.Instance_Number) Instance_Number_Cnt,
             MIN(we.Name)                 Wait_Event,         COUNT(DISTINCT we.Name)           Wait_Event_Cnt,
             MIN(wc.Name)                 Wait_Class,         COUNT(DISTINCT wc.Name)           Wait_Class_Cnt,
             MIN(u.Name)                  User_Name,          COUNT(DISTINCT u.Name)            User_Name_Cnt,
             MIN(s.Name)                  Service_Name,       COUNT(DISTINCT s.Name)            Service_Name_Cnt,
             MIN(ma.Name)                 Machine,            COUNT(DISTINCT ma.Name)           Machine_Cnt,
             MIN(mo.Name)                 Module,             COUNT(DISTINCT mo.Name)           Module_Cnt,
             MIN(a.Name)                  Action,             COUNT(DISTINCT a.Name)            Action_Cnt
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
     "].concat(@where_values)
    )

    render_partial :list_longterm_trend_single_record_grouping
  end


  private
  def include_longterm_trend_default_select_list
    # Add pne cycle to duration because last occurrence points to start of last considered cycle
    retval = " MIN(Snapshot_Timestamp)             First_Occurrence,
               MAX(Snapshot_Timestamp)             Last_Occurrence,
               (MAX(Snapshot_Timestamp) - MIN(Snapshot_Timestamp)) * 24 + MAX(Snapshot_Cycle_Hours) Sample_Duration_Hours"

    longterm_trend_key_rules.each do |key, value|
      retval << ",
        COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) #{value[:sql_alias]}_Cnt,
        MIN(#{value[:sql]}) #{value[:sql_alias]}"
    end
    retval
  end

  # Ermitteln des SQL für NOT NULL oder NULL
  def groupfilter_value(key, value=nil)
    retval = case key.to_sym
             when :time_selection_start        then {:name => 'Time selection start',        :sql => "t.Snapshot_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
             when :time_selection_end          then {:name => 'Time selection end',          :sql => "t.Snapshot_Timestamp <= TO_DATE(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
             when :additional_filter           then {:name => 'Additional Filter',           :sql => "UPPER(we.Name||wc.Name||u.Name||s.Name||ma.Name||mo.Name||a.Name) LIKE UPPER('%'||?||'%')", :already_bound => true }  # Such-Filter
             else                              { name: key, sql: longterm_trend_key_rule(key.to_s)[:sql] }                              # 2. Versuch aus Liste der Gruppierungskriterien
             end

    raise "groupfilter_value: unknown key '#{key}' of class #{key.class.name}" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      retval[:sql] = "#{retval[:sql]} = ?"
    end

    retval
  end



  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @where_values = []              # Filter-werte für nachfolgendes Statement für alle Union-Tabellen

    @groupfilter.each do |key,value|
      @groupfilter[key] = value.strip if key == 'time_selection_start' || key == 'time_selection_end'                   # Whitespaces entfernen vom Rand des Zeitstempels
    end

    @groupfilter.each do |key,value|
      if key == :additional_filter
        sql = "UPPER(we.Name||wc.Name||u.Name||s.Name||ma.Name||mo.Name||a.Name) LIKE UPPER('%'||?||'%')"
      else
        sql = groupfilter_value(key, value)[:sql]
      end
      @where_string << " AND #{sql}"
      @where_values << value
    end
  end # where_from_groupfilter


end
