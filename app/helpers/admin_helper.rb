# encoding: utf-8

module AdminHelper

  @@log_level_aliases = {
    0 => 'DEBUG',
    1 => 'INFO',
    2 => 'WARN',
    3 => 'ERROR',
    4 => 'FATAL',
    5 => 'UNKNOWN'
  }

  @@log_level_modes = {
    'DEBUG'   => 0,
    'INFO'    => 1,
    'WARN'    => 2,
    'ERROR'   => 3,
    'FATAL'   => 4,
    'UNKNOWN' => 5
  }
end
