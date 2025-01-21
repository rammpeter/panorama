# encoding: utf-8

require 'menu_extension_helper'

module MenuHelper
  include MenuExtensionHelper   # Helper-File, das von diese Engine nutzenden Apps überschrieben/überblendet werden kann
#  include ActionView::Helpers::TranslationHelper    # Include at test-helper only, otherwhise generation of content has problems


  # Bereitstellung Menü-Einträge als Array von hashes, Hash mit Spezialhandling-DB als Parameter
  def menu_content
    main_menu = [
        {class: 'menu', caption: t(:menu_dba_caption, :default => 'DBA general'), content: [
            {class: 'item', caption: t(:menu_dba_start_page_caption, :default => 'Start page'), controller: :env, action: :start_page, hint: t(:menu_dba_start_page_hint, :default => 'Show global information for choosen database')},
            {class: 'item', caption: 'Dashboard', controller: :dba, action: :show_dashboard, hint: t(:menu_dba_dashboard_hint, :default => 'Show dashboard with current performance aspects')},
            {class: 'menu', caption: 'DB-Locks', content: [
                {class: 'item', caption: t(:menu_current_caption, :default => 'Current'), controller: :dba, action: 'show_locks', hint: t(:menu_dba_locks_hint, :default => 'shows current locking state incl. blocking sessions')},
                {class: 'item', caption: t(:menu_dba_blocking_locks_historic_caption, :default => 'Blocking locks historic from ASH'), controller: 'active_session_history', action: 'show_blocking_locks_historic', hint: t(:menu_dba_blocking_locks_historic_hint, :default => 'Show historic blocking locks information from Active Session History')},
                {class: 'item', caption: t(:menu_dba_blocking_locks_historic_panorama_caption, :default => 'Blocking locks historic from Panorama-Sampler'), controller: :addition, action: :show_blocking_locks_history, hint: t(:menu_dba_blocking_locks_historic_panorama_hint, :default => 'Show historic blocking locks information from Panorama-Sampler'), condition: PanoramaSamplerStructureCheck.panorama_table_exists?('Panorama_Blocking_Locks')},
            ]
            },
            {:class => 'menu', :caption => 'Redo-Logs', :content => [
                {:class => 'item', :caption => t(:menu_current_caption, :default => 'Current'), :controller => :dba, :action => 'show_redologs', :hint => t(:menu_dba_redologs_hint, :default => 'Show current redo log info from gv$Log')},
                {:class => 'item', :caption => t(:menu_dba_redologs_log_history_caption, :default => 'Historic from gv$Log_History'), :controller => :dba, :action => :show_redologs_log_history, :hint => t(:menu_dba_redologs_log_history_hint, :default => 'Show detailed historic redo log info from gv$Log_History')},
                {:class => 'item', :caption => t(:menu_historic_awr_caption, :default => 'Historic from AWR'), :controller => :dba, :action => 'show_redologs_historic', :hint => t(:menu_dba_redologs_historic_hint, :default => 'Show historic redo log info from Active Workload Repository (AWR)')},
            ]
            },
            {:class => 'item', :caption => 'Sessions', :controller => :dba, :action => :show_sessions, :hint => t(:menu_dba_sessions_hint, :default => 'Show info of current DB-sessions')},
            {:class => 'menu', :caption => 'Database configuration', :content => [
              {:class => 'item', :caption => 'Init-Parameter', :controller => :dba, :action => :oracle_parameter, :hint => t(:menu_dba_parameter_hint, :default => 'Show init-parameters of instance(s)')},
              {:class => 'item', :caption => 'Resource limits', :controller => :dba, :action => :resource_limits, :hint => t(:menu_dba_resource_limit_hint, :default => 'Show resource limits from gv$Resource_Limit')},
              {:class => 'item', :caption => 'Optimizer hints', :controller => :dba, :action => :optimizer_hints, :hint => t(:menu_dba_optimizer_hints_hint, :default => 'Show supported optimizer hints for this database')},
              {:class => 'item', :caption => 'DB options', :controller => :env, :action => :list_options, :hint => 'Show DB options from V$Option'},
              {:class => 'item', :caption => 'TNS services', :controller => :env, :action => :list_services, :hint => 'Show TNS services from DBA_Services'},
              {:class => 'item', :caption => 'Statistics level', :controller => :dba, :action => :list_statistics_level, :hint => 'Show system defaults for statistics level from gv$Statistics_Level'},
            ]
            },
            {:class => 'menu', :caption => 'User management', :content => [
              {:class => 'item', :caption => 'Database users', :controller => :dba_schema, :action => :list_db_users, :hint => t(:menu_dba_schema_list_users_hint, :default => 'Show database users (DBA_Users)')},
              {:class => 'item', :caption => 'Roles', :controller => :dba_schema, :action => :list_roles, :hint => t(:menu_dba_schema_list_roles_hint, :default => 'Show database roles (DBA_Roles)')},
              {:class => 'item', :caption => 'System privileges', :controller => :dba_schema, :action => :list_sys_privileges, :hint => t(:menu_dba_schema_list_sys_privs_hint, :default => 'Show system privileges (DBA_Sys_Privs)')},
              {:class => 'item', :caption => 'Object privileges', :controller => :dba_schema, :action => :list_obj_privileges, :hint => t(:menu_dba_schema_list_obj_privs_hint, :default => 'Show object privileges (DBA_Tab_Privs)')},
              {:class => 'item', :caption => 'User profiles', :controller => :dba_schema, :action => :list_user_profiles, :hint => t(:menu_dba_schema_list_profiles_hint, :default => 'Show user profile settings (DBA_Profiles)')},
              {:class => 'item', :caption => 'Gradual password rollover', :controller => :dba_schema, :action => :list_gradual_password_rollover, :hint => t(:menu_dba_schema_list_profiles_hint, :default => "Show users in password rollover interval\nMay last longer because it scans Unified_Audit_Trail"), min_db_version: '19.12'},
            ]
            },
            {:class => 'menu', :caption => 'Audit Trail', :content => [
              {:class => 'item', :caption => 'Auditing config',             :controller => :dba_schema, :action => :show_audit_config, :hint => t(:menu_dba_schema_audit_config_hint, :default => 'Show configuration options for standard and unified auditing')},
              {:class => 'item', :caption => 'Auditing rules',              :controller => :dba_schema, :action => :show_audit_rules, :hint => t(:menu_dba_schema_audit_rules_hint, :default => 'Show rules for standard and fine grain auditing')},
              {:class => 'item', :caption => 'Standard audit trail + FGA',  :controller => :dba_schema, :action => :show_audit_trail, :hint => t(:menu_dba_schema_audit_trail_hint, :default => 'Show activities logged by standard audit trail and fine grain auditing (DBA_Common_Audit_Trail)')},
              {:class => 'item', :caption => 'Unified audit trail',         :controller => :dba_schema, :action => :show_unified_audit_trail, :hint => t(:menu_dba_schema_unified_audit_trail_hint, :default => 'Show activities logged by unified audit trail'), min_db_version: '12.1'},
            ]
            },
            {class: 'menu', caption: 'Server Files', content: [
                {class: 'item', caption: 'Server Log Files', controller: :dba, action: :show_server_logs, hint: t(:menu_dba_server_logs_hint, :default => 'Show content of server logs (alert.log, listener.log, ASM-log)'), min_db_version: '11.2'},
                {class: 'item', caption: 'Server Trace Files', controller: :dba, action: :show_trace_files, hint: t(:menu_dba_server_traces_hint, :default => 'Show trace files of DB server'), min_db_version: '12.2'},
            ]
            },
            {class: 'item', caption: 'Database Triggers', controller: :dba, action: :list_database_triggers, hint: t(:menu_dba_database_triggers_hint, :default => 'Show global database triggers (like LOGON etc.)')},
            {class: 'menu', caption: 'DB links', content: [
              {class: 'item', caption: 'DB links outgoing', controller: :dba, action: :list_db_links_outgoing, hint: 'Show DB link config outgoing from this DB'},
              {class: 'item', caption: 'DB links incoming', controller: :dba, action: :list_db_links_incoming, hint: 'Show DB link usage incoming to this DB' },
            ]
            },
            {:class => 'menu', :caption => 'Scheduled Jobs', :content => [
                {:class => 'item', :caption => 'Autotask jobs', :controller => :dba, :action => :show_dba_autotask_jobs, :hint => 'Show jobs from DBA_Autotask_Client', :min_db_version => '11.2'},
                {class: 'item', caption: 'Scheduler jobs', controller: :dba, action: :list_dba_scheduler_jobs, hint: 'Show jobs from DBA_Scheduler_Jobs' },
            ]
            },
            {:class => 'item', :caption => 'Feature usage', :controller => :dba, :action => :list_feature_usage, :hint => t(:menu_dba_feature_usage_hint, :default => 'Statistics about usage of features and packs of Oracle-DB')},
            {:class => 'item', :caption => 'Upgrade/patch history', :controller => :dba, :action => :list_patch_history, :hint => t(:menu_dba_patch_hint, :default => 'History of upgrades / downgrades / patches')},
        ]
        },
        { :class=> 'menu', :caption=>t(:menu_wait_caption, :default=> 'Analyses / statistics'), :content=>[
            { :class=> 'menu', :caption=> 'Session-Waits', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),         :controller=>:dba,                     :action=> 'show_session_waits',                  :hint=>t(:menu_wait_session_current_hint, :default=> 'All current session waits')   },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'active_session_history',  :action=> 'show_session_statistics_historic',    :hint=>t(:menu_wait_session_historic_hint, :default=> 'Prepared active session history from DBA_Hist_Active_Sess_History') },
                {:class=> 'item', :caption=>'CPU-Usage / DB-Time',    :controller=> :dba_waits,  :action=> :show_cpu_usage_historic,    :hint=>t(:menu_wait_session_cpu_hint, :default=> "Historic CPU-Usage and DB-Time from DBA_Hist_Active_Sess_History.\nShows you the difference between real CPU-usage and waiting for CPU\nif you don't have Resource Manager activated.\nDifference means you have more sessions waiting for CPU than your system's number of CPU-cores.") },
                {class: 'item', caption: t(:menu_wait_longterm_trend_caption, :default=>'Long-term trend'), controller: :longterm_trend, action: :show_longterm_trend, hint: t(:menu_wait_longterm_trend_hint, :default=>'Long-term trend recording of session waits'), condition: PanoramaSamplerStructureCheck.panorama_table_exists?('LongTerm_Trend')},
              ]
            },
            { :class=> 'menu', :caption=> 'Segment Statistics', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),         :controller=>:dba,          :action=> 'segment_stat',             :hint=>t(:menu_wait_segment_current_hint, :default=> 'Current waits by DB-objects'), min_db_version: '18' },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'segment_stat_historic',    :hint=>t(:menu_wait_segment_historic_hint, :default=> 'Historic values (waits etc.) by DB-objects')  },
                ]
            },
            { :class=> 'menu', :caption=> 'System-Events', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),         :controller=> 'dba_waits',          :action=> 'system_events',             :hint=>t(:menu_wait_system_events_current_hint, :default=> 'Current system events') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'show_system_events_historic',    :hint=>t(:menu_wait_system_events_historic_hint, :default=> 'Historic system events') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_system_caption, :default=> 'System statistics'), :content=>[
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'show_system_statistics_historic',    :hint=>t(:menu_wait_system_statistics_historic_hint, :default=> 'Historic system statistics') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_sysmetric_caption, :default=> 'System metric'), :content=>[
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'show_sysmetric_historic',    :hint=>t(:menu_wait_sysmetric_historic_hint, :default=> 'Historic system metric from DBA_Hist_Sysmetric_History') },
                ]
            },
            { :class=> 'menu', :caption=>'Time model', :content=>[
              {:class=> 'item', :caption=>t(:menu_historic_sys_time_model_historic, :default=> 'System time model historic'), controller: :dba_history,  action: :show_system_time_model_historic, hint: 'Historic system time model info from DBA_Hist_Sys_Time_Model' },
              ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_latch_caption, :default=> 'Latch statistics'), :content=>[
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'show_latch_statistics_historic',    :hint=>t(:menu_wait_latch_statistics_historic_hint, :default=> 'Calculated historic info from DBA_Hist_Latch') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_mutex_caption, :default=> 'Mutex statistics'), :content=>[
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'dba_history',  :action=> 'show_mutex_statistics_historic',    :hint=>t(:menu_wait_mutex_historic_hint, :default=> 'Prepared historic information based on GV$Mutex_Sleep_History (since last start of instance)')   },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_enqueue_caption, :default=> 'Enqueue statistics'), :content=>[
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),            :controller=> 'dba_history',          :action=> 'show_enqueue_statistics_historic',             :hint=>t(:menu_wait_enqueue_historic_hint, :default=> 'Calculated historic info from DBA_Hist_Enqueue_Stat') },
                {:class=> 'item', :caption=> 'RAC Blocking Enqueue',  :controller=> 'dba_waits',  :action=> 'show_ges_blocking_enqueue',    :hint=>t(:menu_wait_enqueue_rac_hint, :default=> 'Blocking enqueue locks known by RAC lock-manager') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_os_caption, :default=> 'OS statistics'), :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),             :controller=> 'dba',                  :action=> 'list_os_statistics',             :hint=>t(:menu_wait_os_current_hint, :default=> 'Current statistics of operating system from gv$OSStat') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),           :controller=> 'dba_history',          :action=> 'show_os_statistics',             :hint=>t(:menu_wait_os_historic_hint, :default=> 'Historic statistics of operating system from DBA_Hist_OSStat') },
            ]
            },
            { :class=> 'menu', :caption=> 'Genuine Oracle reports', :content=>[
                {:class=> 'item', :caption=>'Performance Hub',            :controller=>:dba_history,    :action=> 'show_performance_hub_report',     :hint=>'Genuine Oracle performance hub report by time period and instance', min_db_version: '12.1'  },
                {:class=> 'item', :caption=>'AWR report',                 :controller=>:dba_history,    :action=> 'show_awr_report',          :hint=>'Genuine Oracle active workload repository report by time period and instance' },
                {:class=> 'item', :caption=>'AWR global report (RAC)',    :controller=>:dba_history,    :action=> 'show_awr_global_report',   :hint=>'Genuine Oracle active workload repository global report for RAC by time period and instance (optional)' },
                {:class=> 'item', :caption=>'ASH report',                 :controller=>:dba_history,    :action=> 'show_ash_report',          :hint=>'Genuine Oracle active session history report by time period and instance' },
                {:class=> 'item', :caption=>'ASH global report (RAC)',    :controller=>:dba_history,    :action=> 'show_ash_global_report',   :hint=>'Genuine Oracle active session history global report for RAC by time period and instance (optional)' },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_rac, :default=> 'RAC related analysis'), condition: PanoramaConnection.rac?, :content=>[
                {:class=> 'item', :caption=> 'GC Request Latency historic',      :controller=> 'dba_waits',  :action=> 'gc_request_latency',    :hint=>t(:menu_wait_gc_historic_hint, :default=> 'Analysis of global cache activity') },
                {class: 'item', caption: t(:menu_wait_drm_historic_caption, default: 'Dynamic Remastering (DRM) events historic'),  controller: :dba_waits,  action: :show_drm_historic,    hint: t(:menu_wait_drm_historic_hint, default: 'History of master role changes for DB-objects between RAC-instances') },
            ]
            },
            { :class=> 'menu', :caption=>t(:menu_wait_special_caption, :default=> 'Special event analysis'), :content=>[
                {:class=> 'item', :caption=> 'Latch: cache buffer chains',:controller=>:dba,  :action=> 'latch_cache_buffers_chains',   :hint=>t(:menu_wait_latch_cbc_hint, :default=>"Current reasons for 'cache buffer chains' latch-waits")  },
                {:class=> 'item', :caption=> 'db file sequential read',   :controller=>:dba,  :action=> 'wait_db_file_sequential_read', :hint=>t(:menu_wait_db_file_sequential_read_hint, :default=>"Current reasons for 'db file sequential read' waits (Attention: large response time at large systems)") },
            ]
            },
            ]
        },
        { :class=> 'menu', :caption=> 'Schema / Storage', :content=>[
            {:class=> 'item', :caption=>t(:menu_storage_storage_summary_caption, :default=> 'Disk-storage summary'), :controller=>:storage,             :action=>:tablespace_usage,  :hint=>t(:menu_storage_storage_summary_hint, :default=> 'Overview over disk space/tablespace usage by schema') },
            {:class=> 'item', :caption=>t(:menu_storage_datafile_caption, :default=> 'Datafile-usage'),     :controller=>:storage,             :action=>:datafile_usage,    :hint=>t(:menu_storage_datafile_hint, :default=> 'Show data-files of DB')   },
            { :class=> 'menu', :caption=> 'UNDO-TS', :content=>[
                {:class=> 'item', :caption=>t(:menu_storage_undo_usage_caption, :default=> 'Undo segments summary'), :controller=>:storage,             :action=>:undo_usage,  :hint=>t(:menu_storage_undo_usage_hint, :default=> 'Current usage of undo space by segments') },
                {:class=> 'item', :caption=>'Active transactions', :controller=>:storage,             :action=>:list_undo_transactions,  :hint=>'Current active transactions' },
                {:class=> 'item', :caption=>t(:menu_storage_undo_history_caption, :default=> 'Undo usage historic'),     :controller=>:storage,             :action=>:show_undo_history,    :hint=>t(:menu_storage_undo_history_hint, :default=> 'Historic usage of UNDO space')   },
            ]
            },
            {:class=> 'item', :caption=> 'Tablespace-Objects',  :controller=>:dba_schema,       :action=>:show_object_size,  :hint=>t(:menu_dba_schema_ts_objects_hint, :default=> 'DB-objects by size, utilization and wastage') },
            {class: 'item', caption: t(:menu_addition_size_evolution_caption, :default => 'Object size evolution'), controller: 'addition', action: 'show_object_increase', hint: t(:menu_addition_size_evolution_hint, :default => 'Evolution of object sizes in considered time period'), condition: get_cached_panorama_object_sizes_exists},
            {:class=> 'item', :caption=> 'Describe object',     :controller=>:dba_schema,       :action=>:describe_object,  :hint=>'Describe database object (table, index, materialized view ...)' },
            {:class=> 'item', :caption=> 'Invalid objects',     :controller=>:dba_schema,       :action=>:invalid_objects,  :hint=>'List invalid objects (from DBA_Objects and DBA_Indexes)' },
            {:class=> 'item', :caption=> 'Recycle bin',     :controller=>:storage,       :action=>:list_recycle_bin,  :hint=>'Show content of recycle bin' },
            {:class=> 'item', :caption=> 'Materialized view structures',         :controller=>:storage,   :action=> 'show_materialized_views',  :hint=>t(:menu_storage_matview_hint, :default=> 'Show structure of materialzed views and MV-logs')   },
            {:class=> 'item', :caption=> t(:menu_storage_table_dependency_caption, :default=>'Table-dependencies'),         :controller=> 'table_dependencies',  :action=> 'show_frame',            :hint=> t(:menu_storage_table_dependency_hint, :default=>'Direct and indirect referential dependencies of tables')},
            { :class=> 'menu', :caption=> 'Temp usage', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                  :controller=>:storage,     :action=>:temp_usage,        :hint=>t(:menu_dba_temp_usage_hint, :default=>'Current usage of TEMP-tablespace') },
                {:class=> 'item', :caption=>t(:menu_storage_temp_usage_historic_sysmetric_caption, :default=> 'Historic from SysMetric'),      :controller=>:storage ,  :action=>:show_temp_usage_sysmetric_historic,    :hint=>t(:menu_storage_temp_usage_historic_sysmetric_hint, :default=> 'Historic usage of TEMP tablespace from system metrics of AWR snapshots (down to sampling once per minute)'), :min_db_version => '11.2' },
                {:class=> 'item', :caption=>t(:menu_storage_temp_usage_historic_ash_caption, :default=> 'Historic from ASH'),      :controller=>:active_session_history ,  :action=>:show_temp_usage_historic,    :hint=>t(:menu_storage_temp_usage_historic_ash_hint, :default=> 'Historic usage of TEMP tablespace by active sessions from Active Session History (down to sampling once per second)'), :min_db_version => '11.2' },
              ]
            },
            { :class=> 'menu', :caption=> t(:menu_storage_exadata_specific_caption, :default=>'EXADATA-specific'), condition: isExadata?,  :content=>[
                {:class=> 'item', :caption=>'Cell server config',            :controller=>:storage,     :action=>:list_exadata_cell_server,        :hint=>t(:menu_storage_exadata_specific_cell_server_hint, :default=>'Configuration of exadata cell server') },
                { class: 'menu', caption:  'Cell server disk config', content: [
                  {:class=> 'item', :caption=>'Cell server physical disks',    :controller=>:storage,     :action=>:list_exadata_cell_physical_disk,  :hint=>'List physical disks of exadata cell server' },
                  {:class=> 'item', :caption=>'Cell server cell disks',        :controller=>:storage,     :action=>:list_exadata_cell_cell_disk,      :hint=>'List configured cell disks of exadata cell server' },
                  {:class=> 'item', :caption=>'Cell server grid disks',        :controller=>:storage,     :action=>:list_exadata_cell_grid_disk,      :hint=>'List configured grid disks of exadata cell server' },
                ] },
                { class: 'menu', caption:  'Cell server load analysis', min_db_version: '19', content: [
                  { class: 'item', caption: 'Past I/O by cells and DBs',    controller: :storage,     action: :show_exadata_io_load_by_cell_db,  :hint=>'List I/O load of exadata cell servers in the past by cell and DB', min_db_version: '19' },
                ] },
                {:class=> 'item', :caption=>'I/O resource mgr. config',      :controller=>:storage,     :action=>:list_exadata_io_res_mgr_config,   :hint=>'List I/O resource manager config' },
                {:class=> 'item', :caption=>'Cell server open alerts',       :controller=>:storage,     :action=>:list_exadata_cell_open_alerts,    :hint=>'List open alerts of exadata cell server' },
              ]
            },
            { :class=> 'menu', :caption=> t(:menu_storage_asm_caption, :default=>'ASM grid infrastructure'), condition: isASM?,  :content=>[
              {:class=> 'item', :caption=>'ASM disk groups',            :controller=>:storage,     :action=>:list_asm_disk_groups,        :hint=>'Disk groups of ASM grid infrastructure' },
              {:class=> 'item', :caption=>'ASM disks',                  :controller=>:storage,     :action=>:list_asm_disks,              :hint=>'Disks of ASM grid infrastructure' },
            ]
            },
            {:class=> 'item', :caption=>t(:menu_sga_pga_object_by_file_and_block_caption, :default=> 'Object by file and block no.'),      :controller=> 'dba_schema',     :action=> 'show_object_nach_file_und_block',  :hint=>t(:menu_sga_pga_object_by_file_and_block_hint, :default=> 'Determine object-name by file- and block-no.') },
          ]
        },
        { :class=> 'menu', :caption=>t(:menu_io_caption, :default=> 'I/O analysis'), :content=>[
            {:class=> 'item', :caption=>t(:menu_io_iostat_detail_caption, :default=> 'I/O-Stat detail history'),         :controller=> 'io',             :action=> 'show_iostat_detail_history',  :hint=>t(:menu_io_iostat_detail_hint, :default=> 'I/O history based on DBA_Hist_IOStat_Detail') , :min_db_version => '11.1'  },
            {:class=> 'item', :caption=>t(:menu_io_iostat_filetype_caption, :default=> 'I/O-Stat filetype history'),         :controller=> 'io',             :action=> 'show_iostat_filetype_history',  :hint=>t(:menu_io_iostat_filetype_hint, :default=> 'I/O history based on DBA_Hist_IOStat_FileType') , :min_db_version => '11.1'  },
            {:class=> 'item', :caption=>t(:menu_io_file_caption, :default=> 'I/O history by files'),        :controller=> 'io',             :action=> 'show_io_file_history',  :hint=>t(:menu_io_file_hint, :default=> 'I/O history by files based on DBA_Hist_FileStatxs')   },
            ]
        },
        { :class=> 'menu', :caption=> 'SGA/PGA-Details', :content=>[
            {class: 'menu', caption: 'SQL-Area', content: [
                {:class => 'item', :caption => t(:menu_sga_pga_sqlarea_current_sqlid_caption, :default => 'Current SQLs (SQL-ID)'), :controller => 'dba_sga', :action => 'show_sql_area_sql_id', :hint => t(:menu_sga_pga_sqlarea_current_sqlid_hint, :default => 'Analysis of current SQL in SGA at level SQL-ID (cumulated across child-cursors)')},
                {:class => 'item', :caption => t(:menu_sga_pga_sqlarea_current_sqlid_childno_caption, :default => 'Current SQLs (SQL-ID / child-no.)'), :controller => 'dba_sga', :action => 'show_sql_area_sql_id_childno', :hint => t(:menu_sga_pga_sqlarea_current_sqlid_childno_hint, :default => 'Analysis of current SQL in SGA at level SQL-ID, child-no.')},
                {:class => 'item', :caption => t(:menu_sga_pga_sqlarea_historic_caption, :default => 'Historic SQLs'), :controller => 'dba_history', :action => 'show_sql_area_historic', :hint => t(:menu_sga_pga_sqlarea_historic_hint, :default => 'Analysis of historic SQL from DBA_Hist_SQLStat')},
                {:class => 'item', :caption => t(:menu_sga_pga_sqlarea_historic_sql_monitor_caption, :default => 'SQL-Monitor reports'), controller: :dba_history, :action => :show_sql_monitor_reports, :hint => t(:menu_sga_pga_sqlarea_historic_sql_monitor_hint, :default => 'Show recorded SQL-Monitor reports from gv$SQL_Monitor and DBA_HIST_Reports'), min_db_version: '12.1'}
            ]
            },
            {:class=> 'item', :caption=>t(:menu_sga_pga_day_compare_caption, :default=> 'SQL-Area day comparison'),         :controller=> 'dba_history', :action=> 'compare_sql_area_historic',     :hint=>t(:menu_sga_pga_day_compare_hint, :default=> 'Comparison of SQL-statements from two different days') },

            { :class=> 'menu', :caption=> 'SGA Memory', :content=>[
                {:class=> 'item', :caption=>t(:menu_sga_pga_sga_components_current_caption, :default=> 'SGA-components current'),  :controller=> 'dba_sga',     :action=> 'show_sga_components',           :hint=>t(:menu_sga_pga_sga_components_current_hint, :default=> 'Show components of current SGA') },
                {:class=> 'item', :caption=>t(:menu_sga_pga_sga_components_historic_caption, :default=> 'SGA-components historic'),  :controller=> 'dba_sga',     :action=> 'show_historic_sga_components',           :hint=>t(:menu_sga_pga_sga_components_historic_hint, :default=> 'Show history of components of SGA') },
                {:class=> 'item', :caption=>t(:menu_sga_pga_resize_operations_historic_caption, :default=>'SGA resize operations historic'), controller: :dba_sga,  action: :show_resize_operations_historic, hint: t(:menu_sga_pga_resize_operations_historic_hint, :default=>'Show historic evolution of SGA resize operations'), min_db_version: '11.1' },
              ]
            },

            { :class=> 'menu', :caption=> 'DB-Cache', :content=>[
                {:class=> 'item', :caption=>t(:menu_sga_pga_cache_usage_caption,  :default=> 'DB-cache usage current'),  :controller=> 'dba_sga',     :action=> 'db_cache_content',              :hint=>t(:menu_sga_pga_cache_usage_hint,  :default=> 'Current content of DB-cache') },
                {:class=> 'item', :caption=>t(:menu_sga_pga_cache_advice_caption, :default=> 'DB-cache advice'), :controller=> 'dba_sga',     :action=> 'show_db_cache_advice_historic', :hint=>t(:menu_sga_pga_cache_advice_hint, :default=>"Historic view on what-happens-if-analysis for change of cache size") },
                {:class=> 'item', :caption=>t(:menu_sga_pga_cache_usage_historic_caption, :default=>'DB-cache usage historic'), :controller=> 'addition', :action=> 'db_cache_ressourcen',     :hint=>t(:menu_sga_pga_cache_usage_historic_hint, :default=>'Historic view on DB-cache usage by Panorama_Cache_Objects'), condition: PanoramaSamplerStructureCheck.panorama_table_exists?('Panorama_Cache_Objects') }
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_sga_pga_object_usage_caption, :default=> 'Object usage by SQL'), :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                     :controller=> 'dba_sga',     :action=> 'show_object_usage',             :hint=>t(:menu_sga_pga_object_usage_current_hint, :default=> 'Usage of given objects in explain plan of current SQLs in SGA') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),                  :controller=> 'dba_history', :action=> 'show_object_usage_historic',    :hint=>t(:menu_sga_pga_object_usage_historic_hint, :default=> 'Usage of given objects in explain plan of historic SQLs') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_sga_pga_pga_statistics_caption, :default=> 'PGA-statistics'), :content=>[
                  {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                  :controller=> 'dba_pga',     :action=> 'show_pga_stat_current',        :hint=>t(:menu_sga_pga_pga_statistics_current_hint, :default=> 'Show current PGA-usage') },
                  {:class=> 'item', :caption=>t(:menu_sga_pga_pga_statistics_dba_hist_historic_caption, :default=> 'Historic from DBA_Hist_PGAStat'),                  :controller=> 'dba_pga',     :action=> 'show_pga_stat_historic',        :hint=>t(:menu_sga_pga_pga_statistics_historic_hint, :default=> 'Historic usage of PGA memory from DBA_Hist_PGAStat') },
                  {:class=> 'item', :caption=>t(:menu_sga_pga_pga_statistics_ash_historic_caption, :default=> 'Historic from ASH'),      :controller=>:active_session_history ,  :action=>:show_pga_usage_historic,    :hint=>t(:menu_sga_pga_pga_statistics_ash_historic_hint, :default=> 'Historic usage of PGA memory by active sessions from Active Session History (down to sampling once per second)'), :min_db_version => '11.2' },

                ]
            },
            {class: 'menu', caption: 'Result Cache', content: [
                {:class => 'item', :caption => t(:menu_current_caption, :default => 'Current'), :controller => 'dba_sga', :action => 'show_result_cache', :hint => t(:menu_sga_pga_result_cache_current_hint, :default => 'Show current usage of result cache')},
            ]
            },
            {:class=> 'item', :caption=> 'SQL plan management',        :controller=> 'dba_sga',      :action=> 'show_sql_plan_management',           :hint=>"#{t(:menu_sga_pga_sql_plan_management_hint, :default=> "Show all SQL plan management directives of database")}:\n- SQL profiles\n- SQL plan baselines\n- Stored outlines\n- SQL translations\n- SQL patches" },
            { :class=> 'menu', :caption=> 'Compare execution plans', :content=>[
                {:class=> 'item', :caption=> 'in current SGA',        :controller=> 'dba_sga',      :action=> 'show_compare_execution_plans',           :hint=>t(:menu_sga_pga_compare_execution_plans, :default=> 'Compare execution plan of two different cursors in SGA') },
                {:class=> 'item', :caption=> 'in historic AWR data',  :controller=> 'dba_history',  :action=> 'show_compare_execution_plans_historic',  :hint=>t(:menu_sga_pga_compare_execution_plans_historic, :default=> 'Compare two execution plans from AWR history') },
                ]
            },
            ]
        },
        { :class=> 'menu', :caption=>t(:menu_addition_caption, :default=> 'Spec. additions'), :content=>[
            {:class=> 'item', :caption=>t(:menu_addition_dragnet_caption, :default=> 'Dragnet investigation'), :controller=> 'dragnet', :action=> 'show_selection', :hint=>t(:menu_addition_dragnet_hint, :default=> 'Dragnet investigation for performance bottlenecks')   },
            {:class=> 'item', :caption=> t(:menu_addition_exec_with_given_parameters_caption, :default=>'Execute with given parameters') , :controller=> 'addition', :action=> 'show_recall_params', :hint=>t(:menu_addition_exec_with_given_parameters_hint, :default=>'Execute one of Panoramas functions directly with given parameters') },
            {class: 'item', caption: 'SQL worksheet', controller: :addition, action: :show_sql_worksheet, hint: 'SQL worksheet for executing and explaining SQL statements' },
            {class: 'item', caption: 'Admin login', controller: :admin, action: :master_login, :hint=> t(:menu_addition_master_login_hint, :default=>'Login with master password to activate additional admin functions'), condition: showPanoramaSampler },
        ]
        },
    ]

    if admin_jwt_valid?
      main_menu << {
         class: 'menu', caption: 'Admin', content: [
          {class: 'item', caption: 'Panorama-Sampler config', :controller=> 'panorama_sampler', :action=> 'list_config', :hint=> t(:menu_addition_panorama_sampler_config_hint, :default=>'Configure target databases for Panorama-Sampler') },
          {class: 'item', caption: 'Set log level', controller: :admin, action: :show_log_level, :hint=> t(:menu_admin_show_log_level_hint, default: 'Set the log level of Panorama server process') },
          {class: 'item', caption: 'DB connection pool', controller: :admin, action: :connection_pool, :hint=> t(:menu_admin_connection_pool_hint, default: 'Show current DB connections in connection pool and server threads of Panorama') },
          {class: 'item', caption: 'Usage history', controller: :admin, action: :show_usage_history, :hint=> t(:menu_admin_show_usage_history_hint, default: 'Show history of Panorama usage by users') },
          {class: 'item', caption: 'Server cache store sizes', controller: :admin, action: :client_info_store_sizes, :hint=> t(:menu_admin_client_info_store_sizes_hint, default: 'Show sizes of server-side cache store in folder client_info.store') },
          # {class: 'item', caption: 'Client browser tab config', controller: :admin, action: :browser_tab_ids, :hint=> t(:menu_admin_client_browser_tab_hint, default: 'Show different browser tab config of this browser instance') },
          {class: 'item', caption: 'Admin logout', controller: :admin, action: :admin_logout, :hint=> t(:menu_admin_logout_hint, default: 'Logout from admin functions') },
        ]
      }
    end

    extend_main_menu main_menu      # Erweitern des Menues in die Panorama-Engine nutzender App durch Überblenden von menu_extension_helper.rb
  end

  def showPanoramaSampler
    !Panorama::Application.config.panorama_master_password.nil?
  end

  def isExadata?
    get_db_version >= '11.2' && sql_select_one("SELECT COUNT(*) FROM (SELECT cellname FROM v$Cell_Config GROUP BY CellName)") > 0
  end

  def isASM?
    sql_select_one("SELECT COUNT(*) FROM v$asm_diskgroup") > 0
  end

  # Test ob Controller die Aktion definiert hat, Controller-Name mit _ statt CamelCase
  def controller_action_defined?(controller, action)
    controller_obj = "#{"#{controller}_controller".camelize}".constantize.new
    controller_obj.respond_to? action.to_s
  end

  # filter menu content for current database, return same structure like input from menu_content
  def menu_content_for_db
    filter_array = proc do |list|
      result = []
      list.each do |l|
        if (!l.has_key?(:min_db_version) || get_db_version >=  l[:min_db_version]) &&  # Prüfung auf unterstützte DB-Version
          (!l.has_key?(:condition)      || l[:condition])                       # Check on condition
          l[:content] = filter_array.call(l[:content]) if l[:class] == 'menu'   # Filter submenu structure
          result << l
        end
      end
      result
    end
    filter_array.call(menu_content)
  end

# Aufbau des HTML-Menües, Hash mit DB-Namen für Spezialbehandlung
  def build_menu_html
    return '' if get_current_database.nil? || get_db_version.nil?       # Abbrechen des Menüaufbaus, wenn die Versions-Strukturen gar nicht gefüllt sind

    @menu_node_id = 0                                                           # Each menu gets own ID
    output = "<ul id='menu_node_ul_#{@menu_node_id}' class='sf-menu sf-js-enabled sf-shadow'>"
    menu_content_for_db.each do |m|      # Aufruf Methode application_helper.menu_content
      output << build_menu_entry(m, "'#{m[:caption]}'")
    end
    @menu_node_id += 1
    output << "
      <li>
          <a id='menu_node_#{@menu_node_id}' class='sf-with-ul' href='#a'>#{ t :help, :default=> 'Help' }<span class='sf-sub-indicator'> »</span></a>
        <ul id='menu_node_ul_#{@menu_node_id}'>
          <li id='menu_li_help_overview'>#{ link_to t(:menu_help_overview_caption, :default=> 'Overview'), { :controller => 'help', :action=> 'overview', browser_tab_id: @browser_tab_id }, id: "menu_help_overview" ,:title=>t(:menu_help_overview_hint, :default=>'Help-overview'), :target=> '_blank'  }</li>
          <li id='menu_li_help_mailto'><a href='mailto:#{contact_mail_addr}'  id='menu_help_mailto' title='#{t :menu_help_contact_title, :default=> 'Contact to producer'}'>#{t :menu_help_contact_caption, :default=> 'Contact'}</a></li>
"
    unless Rails.env.test?                                                      # don't flood blog with requests at test
      output << "          <li id='menu_li_help_blog'><a href='https://rammpeter.blogspot.com/search/label/Panorama%20How-To' id='menu_help_blog' title='#{t :menu_help_wiki_title, :default=> 'Panorama-Blog with news and usage hints'}' target='_blank'>#{t :menu_help_wiki_caption, :default=> 'Blog'}</a></li>
"
    end

    output << "\
          <li id='menu_li_help_version_history'>#{ link_to t(:menu_help_version_history_caption, :default=> 'Version history'), { :controller => 'help', :action=> 'version_history', browser_tab_id: @browser_tab_id}, id: "menu_help_version_history", :title=>t(:menu_help_version_history_hint, :default=>'Development history of features and versions'), :target=> '_blank'  }</li>
        </ul>
      </li>
    </ul>
    "
    output.html_safe
  end

  def build_main_menu_js_code
  "$('#main_menu').html('#{j render_to_string :partial =>"env/build_main_menu" }');"
  end

  private
  # Aufbau eines Menü-Eintrages als Ajax-Call
  def menu_link_remote(title, controller, action, hint, prev_menu_caption)
      exec_controller = :env                 # Default-Controller, wenn keine eigene Action deklariert ist
      exec_action     = :render_menu_action  # Default-Action wenn keine eigene Action deklariert ist

      # Test, ob Methode im Controller existiert, dann diese ausführen
      if controller_action_defined?(controller, action)
        exec_controller = controller
        exec_action     = action
      end
      ajax_link(title,
                {
                    :controller          => exec_controller,
                    :action              => exec_action,
                    :update_area         => 'content_for_layout',     # Standard-Div für Anzeige in Layout
                    :redirect_controller => controller,
                    :redirect_action     => action,
                    :last_used_menu_controller => controller, # Merken der zuletzt aus Menü ausgeführten Action
                    :last_used_menu_action     => action,
                    :last_used_menu_caption    => title,
                    :last_used_menu_hint       => hint
                },
                {
                    :title => hint,
                    :id    => "menu_#{controller}_#{action}"
                },
                "document.title ='Panorama (#{current_tns}): #{escape_js_single_quote("#{prev_menu_caption} / '#{title}'")}';"
      )
  end

  def build_menu_entry(menu_entry, prev_menu_caption='')
    @menu_node_id += 1
    output = ''
    output << "<li id='menu_node_li_#{@menu_node_id}' >"
    output << "<a id='menu_node_#{@menu_node_id}' class='sf-with-ul' href='#a'>#{menu_entry[:caption]}<span class='sf-sub-indicator'> »</span></a>"
    output << "<ul id='menu_node_ul_#{@menu_node_id}'>
    "
    menu_entry[:content].each do |m|
      output << build_menu_entry(m, "#{prev_menu_caption} / '#{m[:caption]}'") if m[:class] == 'menu'
      output << "<li id='menu_li_#{m[:controller]}_#{m[:action]}'>#{ menu_link_remote(m[:caption], m[:controller], m[:action], m[:hint], prev_menu_caption) }</li>" if m[:class] == 'item'
    end
    output << '</ul>
    '
    output << '</li>'
    output
  end
end
