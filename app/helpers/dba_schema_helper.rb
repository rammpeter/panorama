# encoding: utf-8
module DbaSchemaHelper

  def explain_calc_free_space_by_avg_row_len
    "
Calculated by size of all allocated extents - (Avg_Row_Len*Num_Rows) considering also block header, PCT_FREE, INI_TRANS.

May be inaccurate due to partial analyze with estimated average row length or object compression or function expressions in index.
For exact values click for calculation with DBMS_SPACE.SPACE_USAGE."
  end


  def calc_free_space_mb_by_avg_row_len(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, segment_type, leaf_blocks)
    if segment_type['TABLE']
      calc_free_space_mb_table(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    else
      if segment_type['INDEX']
        calc_free_space_mb_index(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, leaf_blocks)
      else
        nil
      end
    end
  end

  def calc_free_space_pct_by_avg_row_len(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, segment_type, leaf_blocks)
    if segment_type['TABLE']
      free_mb = calc_free_space_mb_table(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    else
      if segment_type['INDEX']
        free_mb = calc_free_space_mb_index(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, leaf_blocks)
      else
        free_mb = nil
      end
    end
    free_mb * 100.0 / size_mb rescue nil
  end

  def block_header_size(ini_trans)
    if !defined?(@block_header_size_without_ini_trans)
      @block_header_size_without_ini_trans =                                    # Ensure calling expensive calculation only once per request
        PanoramaConnection.block_common_header_size       +
        PanoramaConnection.unsigned_byte_4_size           +
        PanoramaConnection.transaction_fixed_header_size  +
        PanoramaConnection.data_header_size
    end

    if !defined?(@transaction_variable_header_size)                             # Ensure calling expensive calculation only once per request
      @transaction_variable_header_size = PanoramaConnection.transaction_variable_header_size
    end

    @block_header_size_without_ini_trans + @transaction_variable_header_size * (ini_trans - 1)
  end

  def table_directory_entry_size
    @table_directory_entry_size = PanoramaConnection.table_directory_entry_size if !defined?(@table_directory_entry_size) # Ensure calling expensive calculation only once per request
    @table_directory_entry_size
  end

  def rowid_size
    @rowid_size = PanoramaConnection.rowid_size if !defined?(@rowid_size)       # Ensure calling expensive calculation only once per request
    @rowid_size
  end

  def calc_free_space_mb_table(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    return nil if avg_row_len.nil? || num_rows.nil? || pct_free.nil? || ini_trans.nil? || size_mb.nil?
    data_size_per_block_without_row_dir =  ((blocksize - block_header_size(ini_trans)) * (1 - pct_free/100.0) - table_directory_entry_size).to_i

    rows_per_block = (data_size_per_block_without_row_dir / (avg_row_len + 5)).to_i             # Avg_Row_Len + 2 bytes row directory + 3 bytes row header. Assuming the last partial row does not fit into the block

    needed_blocks     = (num_rows / rows_per_block).to_i + 1

    size_mb - (needed_blocks * blocksize).to_f / (1024 * 1024)
  rescue
    nil
  end

  def calc_free_space_pct_table(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb)
    calc_free_space_mb_table(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb) * 100.0 / size_mb rescue nil
  end

  def calc_free_space_mb_index(
      avg_row_len,                                                              # Sum ov Avg_Col_Len of all index columns
      num_rows,                                                                 # Num_Rows of index
      pct_free,
      init_trans,
      block_size,
      size_mb,
      leaf_blocks
  )

    # available data size within one DB block
    data_size = ((block_size - block_header_size(init_trans)) * (1 - pct_free/100.0) - table_directory_entry_size).to_i rescue nil

    # allocated size in leaf blocks by rows
    net_size = num_rows * (avg_row_len + (avg_row_len > 250 ? 3 : 1) + rowid_size) rescue nil

    # remaining free space in currently allocated leaf blocks
    (data_size * leaf_blocks - net_size) / (1024.0 * 1024.0) rescue nil
  end

  def calc_free_space_pct_index(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, leaf_blocks)
    calc_free_space_mb_index(avg_row_len, num_rows, pct_free, ini_trans, blocksize, size_mb, leaf_blocks) * 100.0 / size_mb rescue nil
  end
end