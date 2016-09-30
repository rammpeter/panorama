# encoding: utf-8

module IoHelper

  def io_file_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@io_file_key_rules_hash) || @io_file_key_rules_hash.nil?
      @io_file_key_rules_hash = {}
      @io_file_key_rules_hash["Database"]    = {:sql => "SYS_CONTEXT('USERENV', 'DB_NAME')",   :sql_alias => "database",    :Name => 'DB',         :Title => 'Sums over whole database' }
      @io_file_key_rules_hash["Instance"]    = {:sql => "f.Instance_Number",   :sql_alias => "instance_number",    :Name => 'Inst.',         :Title => 'RAC-Instance' }
      @io_file_key_rules_hash["Tablespace"]  = {:sql => "f.TSName",            :sql_alias => "tsname",             :Name => 'Tablespace',    :Title => 'Tablespace-Name' }
      @io_file_key_rules_hash["FileName"]    = {:sql => "f.FileName",          :sql_alias => "filename",           :Name => 'Filename',      :Title => 'Datafile- / Tempfile-Name' }
      @io_file_key_rules_hash["FileType"]    = {:sql => "f.File_Type",         :sql_alias => "filetype",           :Name => 'File-Type',     :Title => 'Datafile- / Tempfile' }
    end
    @io_file_key_rules_hash
  end

  def io_file_key_rule(key)
    retval = io_file_key_rules[key]
    unless retval
      retval = {
        "DBID"                 => {:sql => "s.DBID", :hide_content => true},
        "time_selection_end"   => {:sql => "s.Begin_Interval_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"  , :already_bound => true},   # SQL muss nicht mehr um =? erweitert werden
        "time_selection_start" => {:sql => "s.End_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"    , :already_bound => true},
      }[key]
    end


    raise "io_file_key_rule: unknown key '#{key}'" unless retval
    retval
  end


  # Spalten mit numerischen Werten von DBA_Hist_FileStatxs für Anwendung in mehreren Views
  def io_file_values_column_options

    if !defined?(@io_file_values_column_options) || @io_file_values_column_options.nil?

      @io_file_values_column_options = [
          {:caption=>"Phys. reads",           :data=>proc{|rec| fn(rec.physical_reads)},                                            :title=>"Number of physical reads done",              :align=>"right",  :raw_data=>proc{|rec| rec.physical_reads},                            :data_title=>proc{|rec| "%t, #{fn(rec.physical_reads_mb,2)} MB read"}},
          {:caption=>"ms / phys. read",       :data=>proc{|rec| fn(secure_div(rec.read_time_secs*1000, rec.physical_reads), 2)},    :title=>"Avg. duration of physical read in ms",       :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.read_time_secs*1000, rec.physical_reads)},   :data_title=>proc{|rec| "%t, physical read time = #{fn(rec.read_time_secs)} sec"} },
          {:caption=>"Blocks / phys. read",   :data=>proc{|rec| fn(secure_div(rec.physical_blocks_read, rec.physical_reads), 2)},   :title=>"Average blocks per physical read",           :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.physical_blocks_read, rec.physical_reads)} },
          {:caption=>"Phys. writes",          :data=>proc{|rec| formattedNumber(rec.physical_writes)},                              :title=>"Number of times DBWR is required to write",  :align=>"right",  :raw_data=>proc{|rec| rec.physical_writes},                           :data_title=>proc{|rec| "%t, #{fn(rec.physical_writes_mb,2)} MB written"}},
          {:caption=>"ms / phys. write",      :data=>proc{|rec| fn(secure_div(rec.write_time_secs*1000, rec.physical_writes), 2)},  :title=>"Avg. duration of physical write in ms",      :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.write_time_secs*1000, rec.physical_writes)}, :data_title=>proc{|rec| "%t, physical write time = #{fn(rec.write_time_secs)} sec"} },
          {:caption=>"Blocks / phys. write",  :data=>proc{|rec| fn(secure_div(rec.physical_blocks_written, rec.physical_writes), 2)}, :title=>"Average blocks per physical write",        :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.physical_blocks_written, rec.physical_writes)} },
          {:caption=>"Single block reads",    :data=>proc{|rec| fn(rec.single_block_reads)},                                        :title=>"Number of single block reads",               :align=>"right",  :raw_data=>proc{|rec| rec.single_block_reads},                        :data_title=>proc{|rec| "%t, #{fn(secure_div(rec.single_block_reads*100, rec.physical_reads), 2)} % of physical reads, #{fn(rec.single_block_reads_mb,2)} MB read by single block reads"}},
          {:caption=>"ms / single block read",:data=>proc{|rec| fn(secure_div(rec.single_block_read_time_secs*1000, rec.single_block_reads), 2)}, :title=>"Avg. duration of single block read in ms", :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.single_block_read_time_secs*1000, rec.single_block_reads)}, :data_title=>proc{|rec| "%t, single block read time = #{fn(rec.single_block_read_time_secs)} sec"} },
          {:caption=>"Blocks / multi block read",:data=>proc{|rec| fn(secure_div(rec.physical_blocks_read-rec.single_block_reads, rec.physical_reads-rec.single_block_reads), 1)}, :title=>"Avg. duration of single block read in ms", :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.physical_blocks_read-rec.single_block_reads, rec.physical_reads-rec.single_block_reads)}},
          {:caption=>"Total I/O per second",  :data=>proc{|rec| fn(secure_div(rec.physical_reads+rec.physical_writes, rec.avg_sample_secs))}, :title=>"Avg. total I/O-operations per second within sample time", :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.physical_reads+rec.physical_writes, rec.avg_sample_secs) }},
          {:caption=>"Read I/O per second",   :data=>proc{|rec| fn(secure_div(rec.physical_reads, rec.avg_sample_secs))},           :title=>"Avg. read I/O-operations per second within sample time", :align=>"right",  :raw_data=>proc{|rec| secure_div(rec.physical_reads, rec.avg_sample_secs) }},
          {:caption=>"Write I/O per second",  :data=>proc{|rec| fn(secure_div(rec.physical_writes, rec.avg_sample_secs))},          :title=>"Avg. write I/O-operations per second within sample time", :align=>"right", :raw_data=>proc{|rec| secure_div(rec.physical_writes, rec.avg_sample_secs) }},
      ]
      @io_file_values_column_options.each do |c|        # Defaults bestücken
        c[:group_operation] = "SUM" unless c[:group_operation]
      end
    end
    @io_file_values_column_options
  end

  ########################## iostat_detail #################
  def iostat_detail_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@iostat_detail_key_rules_hash) || @iostat_detail_key_rules_hash.nil?
      @iostat_detail_key_rules_hash = {}
      @iostat_detail_key_rules_hash["Database"]       = {:sql => "SYS_CONTEXT('USERENV', 'DB_NAME')",   :sql_alias => "database",    :Name => 'DB',   :Title => 'Sums over whole database' }
      @iostat_detail_key_rules_hash["Instance"]       = {:sql => "f.Instance_Number", :sql_alias => "instance_number",    :Name => 'Inst.',           :Title => 'RAC-Instance' }
      @iostat_detail_key_rules_hash["Function-Name"]  = {:sql => "f.Function_Name",   :sql_alias => "function_name",      :Name => 'Function-Name',   :Title => 'Name of function' }
      @iostat_detail_key_rules_hash["Filetype-Name"]  = {:sql => "f.Filetype_Name",   :sql_alias => "filetype_name",      :Name => 'Filetype-Name',   :Title => 'Name of file type' }
    end
    @iostat_detail_key_rules_hash
  end

  def iostat_detail_key_rule(key)
    retval = iostat_detail_key_rules[key]
    unless retval
      retval = {
          "DBID"                 => {:sql => "s.DBID", :hide_content => true},
          "time_selection_end"   => {:sql => "s.Begin_Interval_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"  , :already_bound => true},   # SQL muss nicht mehr um =? erweitert werden
          "time_selection_start" => {:sql => "s.End_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"    , :already_bound => true},
      }[key]
    end


    raise "iostat_detail_key_rule: unknown key '#{key}'" unless retval
    retval
  end

  # Spalten mit numerischen Werten von DBA_Hist_FileStatxs für Anwendung in mehreren Views
  def iostat_detail_values_column_options

    if !defined?(@iostat_detail_values_column_options) || @iostat_detail_values_column_options.nil?

      @iostat_detail_values_column_options = [
          {:caption=>"Small read (MB/sec.)",      :data=>proc{|rec| fn(secure_div(rec.small_read_megabytes,  rec.sample_dauer_secs),2)},    :title=>"Number of single block MB read per second",             :raw_data=>proc{|rec| secure_div(rec.small_read_megabytes,  rec.sample_dauer_secs)},      :data_title=>proc{|rec| "%t, #{fn(rec.small_read_megabytes,2)} MB read"}},
          {:caption=>"Small write (MB/sec.)",     :data=>proc{|rec| fn(secure_div(rec.small_write_megabytes, rec.sample_dauer_secs),2)},    :title=>"Number of single block MB written per second",          :raw_data=>proc{|rec| secure_div(rec.small_write_megabytes, rec.sample_dauer_secs)},     :data_title=>proc{|rec| "%t, #{fn(rec.small_write_megabytes,2)} MB written"}},
          {:caption=>"Large read (MB/sec.)",      :data=>proc{|rec| fn(secure_div(rec.large_read_megabytes,  rec.sample_dauer_secs),2)},    :title=>"Number of multiblock MB read per second",               :raw_data=>proc{|rec| secure_div(rec.large_read_megabytes,  rec.sample_dauer_secs)},      :data_title=>proc{|rec| "%t, #{fn(rec.large_read_megabytes,2)} MB read"}},
          {:caption=>"Large write (MB/sec.)",     :data=>proc{|rec| fn(secure_div(rec.large_write_megabytes, rec.sample_dauer_secs),2)},    :title=>"Number of multiblock MB written per second",            :raw_data=>proc{|rec| secure_div(rec.large_write_megabytes, rec.sample_dauer_secs)},     :data_title=>proc{|rec| "%t, #{fn(rec.large_write_megabytes,2)} MB written"}},
          {:caption=>"Small read requests/sec.",  :data=>proc{|rec| fn(secure_div(rec.small_read_reqs,       rec.sample_dauer_secs),1)},    :title=>"Number of single block read requests per second",       :raw_data=>proc{|rec| secure_div(rec.small_read_reqs,       rec.sample_dauer_secs)},           :data_title=>proc{|rec| "%t, #{fn(rec.small_read_reqs)} requests"}},
          {:caption=>"Small write requests/sec.", :data=>proc{|rec| fn(secure_div(rec.small_write_reqs,      rec.sample_dauer_secs),1)},    :title=>"Number of single block write requests per second",      :raw_data=>proc{|rec| secure_div(rec.small_write_reqs,      rec.sample_dauer_secs)},          :data_title=>proc{|rec| "%t, #{fn(rec.small_write_reqs)} requests"}},
          {:caption=>"Large read requests/sec.",  :data=>proc{|rec| fn(secure_div(rec.large_read_reqs,       rec.sample_dauer_secs),1)},    :title=>"Number of multiblock read requests per second",         :raw_data=>proc{|rec| secure_div(rec.large_read_reqs,       rec.sample_dauer_secs)},           :data_title=>proc{|rec| "%t, #{fn(rec.large_read_reqs)} requests"}},
          {:caption=>"Large write requests/sec.", :data=>proc{|rec| fn(secure_div(rec.large_write_reqs,      rec.sample_dauer_secs),1)},    :title=>"Number of multiblock write requests per second",        :raw_data=>proc{|rec| secure_div(rec.large_write_reqs,      rec.sample_dauer_secs)},          :data_title=>proc{|rec| "%t, #{fn(rec.large_write_reqs)} requests"}},
          {:caption=>"Wait events/sec.",          :data=>proc{|rec| fn(secure_div(rec.number_of_waits,       rec.sample_dauer_secs),1)},    :title=>"Number of I/O wait events per second",                  :raw_data=>proc{|rec| secure_div(rec.number_of_waits,       rec.sample_dauer_secs)},           :data_title=>proc{|rec| "%t, #{fn(rec.number_of_waits)} wait events occured"}},
          {:caption=>"Waiting sessions (Load)",   :data=>proc{|rec| fn(secure_div(rec.wait_time.to_f/1000,   rec.sample_dauer_secs),2)},    :title=>"Average number of waiting sessions",                    :raw_data=>proc{|rec| secure_div(rec.wait_time.to_f/1000,   rec.sample_dauer_secs)},       :data_title=>proc{|rec| "%t, #{fn(rec.wait_time.to_f/1000)} seconds waited in total"}},
      ]
      @iostat_detail_values_column_options.each do |c|        # Defaults bestücken
        c[:align] = :right
        c[:group_operation] = "SUM" unless c[:group_operation]
      end
    end
    @iostat_detail_values_column_options
  end

  ########################## iostat_filetype #################
  def iostat_filetype_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if  !defined?(@iostat_filetype_key_rules_hash) || @iostat_filetype_key_rules_hash.nil?
      @iostat_filetype_key_rules_hash = {}
      @iostat_filetype_key_rules_hash["Database"]       = {:sql => "SYS_CONTEXT('USERENV', 'DB_NAME')",   :sql_alias => "database",    :Name => 'DB',   :Title => 'Sums over whole database' }
      @iostat_filetype_key_rules_hash["Instance"]       = {:sql => "f.Instance_Number", :sql_alias => "instance_number",    :Name => 'Inst.',           :Title => 'RAC-Instance' }
      @iostat_filetype_key_rules_hash["Filetype-Name"]  = {:sql => "f.Filetype_Name",   :sql_alias => "filetype_name",      :Name => 'Filetype-Name',   :Title => 'Name of file type' }
    end
    @iostat_filetype_key_rules_hash
  end

  def iostat_filetype_key_rule(key)
    retval = iostat_filetype_key_rules[key]
    unless retval
      retval = {
          "DBID"                 => {:sql => "s.DBID", :hide_content => true},
          "time_selection_end"   => {:sql => "s.Begin_Interval_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"  , :already_bound => true},   # SQL muss nicht mehr um =? erweitert werden
          "time_selection_start" => {:sql => "s.End_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')"    , :already_bound => true},
      }[key]
    end


    raise "iostat_filetype_key_rule: unknown key '#{key}'" unless retval
    retval
  end

  # Spalten mit numerischen Werten von DBA_Hist_FileStatxs für Anwendung in mehreren Views
  def iostat_filetype_values_column_options

    if !defined?(@iostat_filetype_values_column_options) || @iostat_filetype_values_column_options.nil?

      @iostat_filetype_values_column_options = [
          {:caption=>"Small read (MB/sec.)",      :data=>proc{|rec| fn(secure_div(rec.small_read_megabytes,  rec.sample_dauer_secs),2)},    :title=>"Number of single block MB read per second",             :raw_data=>proc{|rec| secure_div(rec.small_read_megabytes,  rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.small_read_megabytes,2)} MB read"}},
          {:caption=>"Small write (MB/sec.)",     :data=>proc{|rec| fn(secure_div(rec.small_write_megabytes, rec.sample_dauer_secs),2)},    :title=>"Number of single block MB written per second",          :raw_data=>proc{|rec| secure_div(rec.small_write_megabytes, rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.small_write_megabytes,2)} MB written"}},
          {:caption=>"Large read (MB/sec.)",      :data=>proc{|rec| fn(secure_div(rec.large_read_megabytes,  rec.sample_dauer_secs),2)},    :title=>"Number of multiblock MB read per second",               :raw_data=>proc{|rec| secure_div(rec.large_read_megabytes,  rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.large_read_megabytes,2)} MB read"}},
          {:caption=>"Large write (MB/sec.)",     :data=>proc{|rec| fn(secure_div(rec.large_write_megabytes, rec.sample_dauer_secs),2)},    :title=>"Number of multiblock MB written per second",            :raw_data=>proc{|rec| secure_div(rec.large_write_megabytes, rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.large_write_megabytes,2)} MB written"}},
          {:caption=>"Small read requests /sec.", :data=>proc{|rec| fn(secure_div(rec.small_read_reqs,       rec.sample_dauer_secs),1)},    :title=>"Number of single block read requests per second",       :raw_data=>proc{|rec| secure_div(rec.small_read_reqs,       rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.small_read_reqs)} requests in total"}},
          {:caption=>"Small write requests /sec.",:data=>proc{|rec| fn(secure_div(rec.small_write_reqs,      rec.sample_dauer_secs),1)},    :title=>"Number of single block write requests per second",      :raw_data=>proc{|rec| secure_div(rec.small_write_reqs,      rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.small_write_reqs)} requests in total"}},
          {:caption=>"Small sync. read requests /sec.", :data=>proc{|rec| fn(secure_div(rec.small_sync_read_reqs, rec.sample_dauer_secs),1)},:title=>"Number of synchronous single block read requests per second (part of single block read requests)", :raw_data=>proc{|rec| secure_div(rec.small_sync_read_reqs,      rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.small_sync_read_reqs)} requests in total"}},
          {:caption=>"Large read requests /sec.", :data=>proc{|rec| fn(secure_div(rec.large_read_reqs,       rec.sample_dauer_secs),1)},    :title=>"Number of multiblock read requests per second",         :raw_data=>proc{|rec| secure_div(rec.large_read_reqs,       rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.large_read_reqs)} requests in total"}},
          {:caption=>"Large write requests /sec.",:data=>proc{|rec| fn(secure_div(rec.large_write_reqs,      rec.sample_dauer_secs),1)},    :title=>"Number of multiblock write requests per second",        :raw_data=>proc{|rec| secure_div(rec.large_write_reqs,      rec.sample_dauer_secs)},   :data_title=>proc{|rec| "%t, #{fn(rec.large_write_reqs)} requests in total"}},
          {:caption=>"Small read load (active sessions)", :data=>proc{|rec| fn(secure_div(rec.small_read_servicetime.to_f/1000, rec.sample_dauer_secs),2)},    :title=>"Average number of concurrent sessions waiting for small reads",  :raw_data=>proc{|rec| secure_div(rec.small_read_servicetime.to_f/1000, rec.sample_dauer_secs)},  :data_title=>proc{|rec| "%t, #{fn(rec.small_read_servicetime.to_f/1000)} seconds waiting for small reads"}},
          {:caption=>"Small write load (active sessions)", :data=>proc{|rec| fn(secure_div(rec.small_write_servicetime.to_f/1000, rec.sample_dauer_secs),2)},  :title=>"Average number of concurrent sessions waiting for small writes", :raw_data=>proc{|rec| secure_div(rec.small_write_servicetime.to_f/1000, rec.sample_dauer_secs)}, :data_title=>proc{|rec| "%t, #{fn(rec.small_write_servicetime.to_f/1000)} seconds waiting for small writes"}},
          {:caption=>"Large read load (active sessions)", :data=>proc{|rec| fn(secure_div(rec.large_read_servicetime.to_f/1000, rec.sample_dauer_secs),2)},    :title=>"Average number of concurrent sessions waiting for large reads",  :raw_data=>proc{|rec| secure_div(rec.large_read_servicetime.to_f/1000, rec.sample_dauer_secs)},  :data_title=>proc{|rec| "%t, #{fn(rec.large_read_servicetime.to_f/1000)} seconds waiting for large reads"}},
          {:caption=>"Large write load (active sessions)", :data=>proc{|rec| fn(secure_div(rec.large_write_servicetime.to_f/1000, rec.sample_dauer_secs),2)},  :title=>"Average number of concurrent sessions waiting for large writes", :raw_data=>proc{|rec| secure_div(rec.large_write_servicetime.to_f/1000, rec.sample_dauer_secs)}, :data_title=>proc{|rec| "%t, #{fn(rec.large_write_servicetime.to_f/1000)} seconds waiting for large writes"}},
          {:caption=>"Small read latency (ms)",   :data=>proc{|rec| fn(secure_div(rec.small_read_servicetime,rec.small_read_reqs),2)},      :title=>"Service time for single block reads (milliseconds)",     :raw_data=>proc{|rec| secure_div(rec.small_read_servicetime,rec.small_read_reqs)} },
          {:caption=>"Small write latency (ms)",  :data=>proc{|rec| fn(secure_div(rec.small_write_servicetime,rec.small_write_reqs),2)},    :title=>"Service time for single block writes (milliseconds)",    :raw_data=>proc{|rec| secure_div(rec.small_write_servicetime,rec.small_write_reqs)} },
          {:caption=>"Small sync read latency (ms)",   :data=>proc{|rec| fn(secure_div(rec.small_sync_read_latency,rec.small_sync_read_reqs),2)},               :title=>"Latency for single block synchronous reads (milliseconds)",     :raw_data=>proc{|rec| secure_div(rec.small_sync_read_latency,rec.small_sync_read_reqs)} },
          {:caption=>"Large read latency (ms)",   :data=>proc{|rec| fn(secure_div(rec.large_read_servicetime,rec.large_read_reqs),2)},      :title=>"Service time for multiblock reads (milliseconds)",      :raw_data=>proc{|rec| secure_div(rec.large_read_servicetime,rec.large_read_reqs)} },
          {:caption=>"Large write latency (ms)",  :data=>proc{|rec| fn(secure_div(rec.large_write_servicetime,rec.large_write_reqs),2)},    :title=>"Service time for multiblock writes (milliseconds)",     :raw_data=>proc{|rec| secure_div(rec.large_write_servicetime,rec.large_write_reqs)} },
          {:caption=>"Retries on error",          :data=>proc{|rec| fn(rec.retries_on_error)},                                              :title=>"Number of read retries on error",                       :raw_data=>proc{|rec| rec.retries_on_error} },
      ]
      @iostat_filetype_values_column_options.each do |c|        # Defaults bestücken
        c[:align] = :right
        c[:group_operation] = "SUM" unless c[:group_operation]
      end
    end
    @iostat_filetype_values_column_options
  end



end

