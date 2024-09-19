# encoding: utf-8
module StorageHelper

  EXADATA_CELL_DB_COLUMNS =
    {
      'disk_requests':                { sql: 'disk_requests',               caption: 'Disk requests',                       title: 'Number of disk I/O requests performed by the database.' },
      'disk_mb':                      { sql: 'disk_bytes',                  caption: 'Disk processed (MB)',                 title: 'Number of disk I/O Megabytes processed by the database.', divide: 1024*1024, size_explain: true, scale: 1 },
      'flash_requests':               { sql: 'flash_requests',              caption: 'Flash requests',                      title: 'Number of flash I/O requests performed by the database.'},
      'flash_mb':                     { sql: 'flash_bytes',                 caption: 'Flash processed (MB)',                title: 'Number of flash I/O Megabytes processed by the database.', divide: 1024*1024, size_explain: true, scale: 1 },
      'disk_small_io_reqs':           { sql: 'disk_small_io_reqs',          caption: 'Disk small requests',                 title: "Number of small IO requests issued to disks by the database.\nParallel cell metric: DB_IO_RQ_SM" },
      'disk_large_io_reqs':           { sql: 'disk_large_io_reqs',          caption: 'Disk large requests',                 title: "Number of large IO requests issued to disks by the database.\nParallel cell metric: DB_IO_RQ_LG" },
      'flash_small_io_reqs':          { sql: 'flash_small_io_reqs',         caption: 'Flash small requests',                title: "Number of small IO requests issued to flash by the database.\nParallel cell metric: DB_FD_IO_RQ_SM" },
      'flash_large_io_reqs':          { sql: 'flash_large_io_reqs',         caption: 'Flash large requests',                title: "Number of large IO requests issued to flash by the database.\nParallel cell metric: DB_FD_IO_RQ_LG" },
      'disk_small_io_service_time':   { sql: 'disk_small_io_service_time',  caption: 'Disk small service time (sec.)',      title: "The total latency (in seconds) of small IO requests issued to disks by the database within the AWR snapshot period.\nParallel cell metric: DB_IO_TM_SM", divide: 1000000000, seconds_explain: true },
      'disk_small_io_queue_time':     { sql: 'disk_small_io_queue_time',    caption: 'Disk small IORM queue time (sec.)',   title: "The total IORM wait time (in seconds) for small IO requests issued to disks by the database within the AWR snapshot period.\nParallel cell metric: DB_IO_WT_SM", divide: 1000000000, seconds_explain: true, scale: 1 },
      'disk_large_io_service_time':   { sql: 'disk_large_io_service_time',  caption: 'Disk large service time (sec.)',      title: "The total latency (in seconds) of large IO requests issued to disks by the database within the AWR snapshot period.\nParallel cell metric: DB_IO_TM_LG", divide: 1000000000, seconds_explain: true },
      'disk_large_io_queue_time':     { sql: 'disk_large_io_queue_time',    caption: 'Disk large IORM queue time (sec.)',   title: "The total IORM wait time (in seconds) for large IO requests issued to disks by the database within the AWR snapshot period.\nParallel cell metric: DB_IO_WT_LG", divide: 1000000000, seconds_explain: true, scale: 1 },
      'flash_small_io_service_time':  { sql: 'flash_small_io_service_time', caption: 'Flash small service time (sec.)',     title: "The total latency (in seconds) of small IO requests issued to flash by the database within the AWR snapshot period.\nParallel cell metric: DB_FD_IO_TM_SM", divide: 1000000000, seconds_explain: true },
      'flash_small_io_queue_time':    { sql: 'flash_small_io_queue_time',   caption: 'Flash small IORM queue time (sec.)',  title: "The total IORM wait time (in seconds) for small IO requests issued to flash by the database within the AWR snapshot period.\nParallel cell metric: DB_FD_IO_WT_SM", divide: 1000000000, seconds_explain: true, scale: 1 },
      'flash_large_io_service_time':  { sql: 'flash_large_io_service_time', caption: 'Flash large service time (sec.)',     title: "The total latency (in seconds) of large IO requests issued to flash by the database within the AWR snapshot period.\nParallel cell metric: DB_FD_IO_TM_LG", divide: 1000000000, seconds_explain: true },
      'flash_large_io_queue_time':    { sql: 'flash_large_io_queue_time',   caption: 'Flash large IORM queue time (sec.)',  title: "The total IORM wait time (in seconds) for large IO requests issued to flash by the database within the AWR snapshot period.\nParallel cell metric: DB_FD_IO_WT_LG", divide: 1000000000, seconds_explain: true, scale: 1 },
    }

  def exadata_cell_db_columns
    EXADATA_CELL_DB_COLUMNS
  end
end





