# encoding: utf-8
module DbaSgaHelper
  include ActionView::Helpers::TranslationHelper

  # Gruppierungskriterien für historic resize operations
  def historic_resize_grouping_options
    {
        second:   t(:second, :default=>'Second'),
        minute:   'Minute',
        hour:     t(:hour,  :default => 'Hour'),
        day:      t(:day,  :default => 'Day'),
        week:     t(:week, :default => 'Week')
    }

  end

  def historic_resize_link_ops(update_area, rec, value, org_value, component, oper_type)
    if org_value.nil? || org_value == 0
      value
    else
      ajax_link(value, {
          :controller    => :dba_sga,
          :action        => :list_resize_operations_historic_single_record,
          :instance      => @instance,
          component:    component,
          oper_type:    oper_type,
          time_selection_start: localeDateTime(rec.min_start_time),
          time_selection_end:   localeDateTime(rec.max_end_time),
          :update_area => update_area
      },
                :title=> "Show single resize operations for this period#{" and component = #{component}" if component}#{" and operation_type = #{oper_type}" if oper_type}")
    end
  end

  # @param modus: 'GV$SQLArea' or 'GV$SQL'
  def sql_area_sort_criteria(modus)
    result = {
        ElapsedTimePerExecute:  { title: 'Elapsed time per execute',            sql: "ELAPSED_TIME_SECS_PER_EXECUTE DESC" },
        ElapsedTimeTotal:       { title: 'Elapsed time total',                  sql: "ELAPSED_TIME_SECS DESC" },
        ExecutionCount:         { title: 'Total number of executions',          sql: "Executions DESC" },
        ParseCalls:             { title: 'Total number of parse calls',         sql: 'Parse_Calls DESC' },
        RowsProcessed:          { title: 'Number of rows processed',            sql: "Rows_Processed DESC" },
        CPUTime:                { title: 'CPU-time total',                      sql: "CPU_Time_Secs DESC" },
        DiskReads:              { title: 'Number of disk-read operations',      sql: "Disk_Reads DESC" },
        ExecsPerDisk:           { title: 'Number of executions per disk-read',  sql: "Executions/DECODE(Disk_Reads,0,1,Disk_Reads) DESC" },
        BufferGets:             { title: 'Buffer Gets total',                   sql: "Buffer_gets DESC" },
        BufferGetsPerRow:       { title: 'Buffer gets per result-row',          sql: "Buffer_Gets/DECODE(Rows_Processed,0,1,Rows_Processed) DESC" },
        ClusterWaits:           { title: 'Cluster wait time total',             sql: "Cluster_Wait_Time_Secs DESC" },
        LastActive:             { title: t(:dba_sga_show_sql_area_sort_last_active_hint, default: 'Timestamp of last execution'),   sql: "Last_Active_Time DESC NULLS LAST" },
        Memory:                 { title: t(:dba_sga_show_sql_area_sort_memory_hint, default: 'Amount of allocated memory in SGA'),  sql: "SHARABLE_MEM+PERSISTENT_MEM+RUNTIME_MEM DESC" },
    }
    result[:ChildCount] = { title: 'Number of child cursors',             sql: "Version_Count DESC" } if modus.upcase == 'GV$SQLAREA'
    result
  end

end