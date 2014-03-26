# encoding: utf-8

module IoHelper

  def io_file_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    unless @io_file_key_rules_hash
      @io_file_key_rules_hash = {}
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

    def secure_div(divident, divisor)
      return nil if divisor == 0
      divident.to_f/divisor
    end

    unless @io_file_values_column_options

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

end

