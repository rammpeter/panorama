# encoding: utf-8
module DbaHistoryHelper
  include ActionView::Helpers::TranslationHelper

  def sql_area_sort_criteria_historic
    {
        ElapsedTimePerExecute:  { title: 'Elapsed time per execute',            sql: "ELAPSED_TIME_SECS_PER_EXECUTE DESC" },
        ElapsedTimeTotal:       { title: 'Elapsed time total',                  sql: "ELAPSED_TIME_SECS DESC" },
        ExecutionCount:         { title: 'Total number of executions',          sql: "Executions DESC" },
        ParseCalls:             { title: 'Total number of parse calls',         sql: 'Parse_Calls DESC' },
        RowsProcessed:          { title: 'Number of rows processed',            sql: "Rows_Processed DESC" },
        CPUTime:                { title: 'CPU-time total',                      sql: "CPU_Time_Secs DESC" },
        DiskReads:              { title: 'Number of disk-read operations',      sql: "Disk_Reads DESC" },
        ExecsPerDisk:           { title: 'Number of executions per disk-read',  sql: "Execs_Per_Disk DESC" },
        BufferGets:             { title: 'Buffer Gets total',                   sql: "Buffer_gets DESC" },
        BufferGetsPerRow:       { title: 'Buffer gets per result-row',          sql: "Buffer_Gets_Per_Row DESC" },
        ClusterWaits:           { title: 'Cluster wait time total',             sql: "Cluster_Wait_Time DESC" },
    }
  end

end





