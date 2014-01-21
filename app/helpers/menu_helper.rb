# encoding: utf-8
module MenuHelper

  # Bereitstellung Menü-Einträge als Array von hashes, Hash mit Spezialhandling-DB als Parameter
  def menu_content
    main_menu = [
        { :class=> 'menu', :caption=>t(:menu_dba_caption, :default=> 'DBA general'), :content=>[
            { :class=> 'menu', :caption=> 'DB-Locks', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),        :controller=>:dba,             :action=> 'show_locks',        :hint=>t(:menu_dba_locks_hint, :default=> 'shows current locking state incl. blocking sessions')   },
                {:class=> 'item', :caption=>t(:menu_dba_blocking_locks_historic_caption, :default=> 'Blocking locks historic'), :controller=> 'active_session_history',  :action=> 'show_blocking_locks_historic',   :hint=>t(:menu_dba_blocking_locks_historic_hint, :default=> 'show historic blocking locks information')   },
                ]
            },
            { :class=> 'menu', :caption=> 'Redo-Logs', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),        :controller=>:dba,             :action=> 'show_redologs',        :hint=>t(:menu_dba_redologs_hint, :default=> 'Show current redo log info') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'), :controller=>:dba,  :action=> 'show_redologs_historic',   :hint=>t(:menu_dba_redologs_historic_hint, :default=> 'Show historic redo log info')   },
                ]
            },
            {:class=> 'item', :caption=> 'Sessions',           :controller=>:dba,             :action=>:show_sessions,     :hint=>t(:menu_dba_sessions_hint, :default=> 'Show info of current DB-sessions') },
            {:class=> 'item', :caption=> 'Oracle-Parameter',   :controller=>:dba,             :action=>:oracle_parameter,  :hint=>t(:menu_dba_parameter_hint, :default=> 'Show active instance-parameters') },
            {:class=> 'item', :caption=> 'Audit Trail',        :controller=>:dba_schema,       :action=>:show_audit_trail,  :hint=>t(:menu_dba_schema_audit_trail_hint, :default=> 'Show activities logged by audit trail records') },
            { :class=> 'menu', :caption=> 'Scheduled Jobs', :content=>[
                {:class=> 'item', :caption=>'DBA autotask jobs', :controller=>:dba,          :action=>:show_dba_autotask_jobs, :hint=>'Show jobs from DBA_Autotask_Client', :min_db_version => '11.2' },
            ]
            },
            {:class=> 'item', :caption=>t(:menu_dba_used_objects_caption, :default=> 'Attached objects'), :controller=>:dba,             :action=> 'used_objects',      :hint=>t(:menu_dba_used_objects_hint, :default=> 'Currently attached objects (Attention: large response time at large systems)') },
            {:class=> 'item', :caption=> 'Explain Plan',       :controller=>:dba,             :action=> 'explain_plan',      :hint=>t(:menu_dba_explain_plan_hint, :default=> 'Show execution plan of SQL-statement') },
            {:class=> 'item', :caption=> 'Temp Usage',         :controller=>:dba,             :action=> 'temp_usage',        :hint=>t(:menu_dba_temp_usage_hint, :default=> 'Current usage of TEMP-tablespace') },
            ]
        },
        { :class=> 'menu', :caption=>t(:menu_wait_caption, :default=> 'Wait analysis'), :content=>[
            { :class=> 'menu', :caption=> 'Session-Waits', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),         :controller=>:dba,                     :action=> 'show_session_waits',                  :hint=>t(:menu_wait_session_current_hint, :default=> 'All current session waits')   },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),      :controller=> 'active_session_history',  :action=> 'show_session_statistics_historic',    :hint=>t(:menu_wait_session_historic_hint, :default=> 'Prepared active session history from DBA_Hist_Active_Sess_History') },
                ]
            },
            {:class=> 'item', :caption=> 'GC Request Latency historisch',      :controller=> 'dba_waits',  :action=> 'gc_request_latency',    :hint=>t(:menu_wait_gc_historic_hint, :default=> 'Analysis of global cache activity') },
            { :class=> 'menu', :caption=> 'Segment Statistics', :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),         :controller=>:dba,          :action=> 'segment_stat',             :hint=>t(:menu_wait_segment_current_hint, :default=> 'Current waits by DB-objects') },
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
            { :class=> 'menu', :caption=>t(:menu_wait_special_caption, :default=> 'Special event analysis'), :content=>[
                {:class=> 'item', :caption=> 'Latch: cache buffer chains',:controller=>:dba,  :action=> 'latch_cache_buffers_chains',   :hint=>t(:menu_wait_latch_cbc_hint, :default=>"Current reasons for 'cache buffer chains' latch-waits")  },
                {:class=> 'item', :caption=> 'db file sequential read',   :controller=>:dba,  :action=> 'wait_db_file_sequential_read', :hint=>t(:menu_wait_db_file_sequential_read_hint, :default=>"Current reasons for 'db file sequential read' waits (Attention: large response time at large systems)") },
                ]
            },
            ]
        },
        { :class=> 'menu', :caption=> 'Storage', :content=>[
            {:class=> 'item', :caption=>t(:menu_storage_storage_summary_caption, :default=> 'Disk-storage summary'), :controller=>:storage,             :action=>:tablespace_usage,  :hint=>t(:menu_storage_storage_summary_hint, :default=> 'Overview over disk space/tablespace usage by schema') },
            {:class=> 'item', :caption=>t(:menu_storage_datafile_caption, :default=> 'Datafile-usage'),     :controller=>:storage,             :action=>:datafile_usage,    :hint=>t(:menu_storage_datafile_hint, :default=> 'Show data-files of DB')   },
            { :class=> 'menu', :caption=> 'UNDO-TS', :content=>[
                {:class=> 'item', :caption=>t(:menu_storage_undo_usage_caption, :default=> 'Undo segments summary'), :controller=>:storage,             :action=>:undo_usage,  :hint=>t(:menu_storage_undo_usage_hint, :default=> 'Current usage of undo space by segments') },
                {:class=> 'item', :caption=>'Active transactions', :controller=>:storage,             :action=>:list_undo_transactions,  :hint=>'Current active transactions' },
                {:class=> 'item', :caption=>t(:menu_storage_undo_history_caption, :default=> 'Undo usage historic'),     :controller=>:storage,             :action=>:show_undo_history,    :hint=>t(:menu_storage_undo_history_hint, :default=> 'Historic usage of UNDO space')   },
            ]
            },
            {:class=> 'item', :caption=> 'Tablespace-Objects', :controller=>:dba_schema,       :action=>:show_object_size,  :hint=>t(:menu_dba_schema_ts_objects_hint, :default=> 'DB-objects by size, utilization and wastage') },
            {:class=> 'item', :caption=> 'Materialized view structures',         :controller=>:storage,   :action=> 'show_materialized_views',  :hint=>t(:menu_storage_matview_hint, :default=> 'Show structure of materialzed views and MV-logs')   },
            ]
        },
        { :class=> 'menu', :caption=>t(:menu_io_caption, :default=> 'I/O analysis'), :content=>[
            {:class=> 'item', :caption=>t(:menu_io_ash_caption, :default=> 'I/O history from ASH'),         :controller=> 'io',             :action=> 'show_io_ash_history',  :hint=>t(:menu_io_ash_hint, :default=> 'I/O history based on active session history')   },
            {:class=> 'item', :caption=>t(:menu_io_file_caption, :default=> 'I/O history by files'),        :controller=> 'io',             :action=> 'show_io_file_history',  :hint=>t(:menu_io_file_hint, :default=> 'I/O history by files based on DBA_Hist_FileStatxs')   },
            ]
        },
        { :class=> 'menu', :caption=> 'SGA/PGA-Details', :content=>[
            { :class=> 'menu', :caption=> 'SQL-Area', :content=>[
                {:class=> 'item', :caption=>t(:menu_sga_pga_sqlarea_current_sqlid_caption, :default=> 'Current (SQL-ID)'),            :controller=> 'dba_sga',     :action=> 'show_sql_area_sql_id',          :hint=>t(:menu_sga_pga_sqlarea_current_sqlid_hint, :default=> 'Analysis of current SQL in SGA at level SQL-ID (cumulated across child-cursors)') },
                {:class=> 'item', :caption=>t(:menu_sga_pga_sqlarea_current_sqlid_childno_caption, :default=> 'Current (SQL-ID / child-no.)'),:controller=> 'dba_sga',     :action=> 'show_sql_area_sql_id_childno',  :hint=>t(:menu_sga_pga_sqlarea_current_sqlid_childno_hint, :default=> 'Analysis of current SQL in SGA at level SQL-ID, child-no.') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),                  :controller=> 'dba_history', :action=> 'show_sql_area_historic',        :hint=>t(:menu_sga_pga_sqlarea_historic_hint, :default=> 'Analysis of historic SQL from DBA_Hist_SQLStat') },
                ]
            },
            {:class=> 'item', :caption=>t(:menu_sga_pga_day_compare_caption, :default=> 'SQL-Area day comparison'),         :controller=> 'dba_history', :action=> 'compare_sql_area_historic',     :hint=>t(:menu_sga_pga_day_compare_hint, :default=> 'Comparison of SQL-statements from two different days') },
            {:class=> 'item', :caption=>t(:menu_sga_pga_sga_components_caption, :default=> 'SGA-components'),                 :controller=> 'dba_sga',     :action=> 'show_sga_components',           :hint=>t(:menu_sga_pga_sga_components_hint, :default=> 'Show components of current SGA') },
            { :class=> 'menu', :caption=> 'DB-Cache', :content=>[
                {:class=> 'item', :caption=>t(:menu_sga_pga_cache_usage_caption,  :default=> 'DB-cache usage'),  :controller=> 'dba_sga',     :action=> 'db_cache_content',              :hint=>t(:menu_sga_pga_cache_usage_hint,  :default=> 'Current content of DB-cache') },
                {:class=> 'item', :caption=>t(:menu_sga_pga_cache_advice_caption, :default=> 'DB-cache advice'), :controller=> 'dba_sga',     :action=> 'show_db_cache_advice_historic', :hint=>t(:menu_sga_pga_cache_advice_hint, :default=>"Historic view on \"what happens if\"-analysis for change of cache size") },
            ]
            },
            { :class=> 'menu', :caption=>t(:menu_sga_pga_object_usage_caption, :default=> 'Object usage by SQL'), :content=>[
                {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                     :controller=> 'dba_sga',     :action=> 'show_object_usage',             :hint=>t(:menu_sga_pga_object_usage_current_hint, :default=> 'Usage of given objects in explain plan of current SQLs in SGA') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),                  :controller=> 'dba_history', :action=> 'show_object_usage_historic',    :hint=>t(:menu_sga_pga_object_usage_historic_hint, :default=> 'Usage of given objects in explain plan of historic SQLs') },
                ]
            },
            { :class=> 'menu', :caption=>t(:menu_sga_pga_pga_statistics_caption, :default=> 'PGA-statistics'), :content=>[
                  {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                  :controller=> 'dba_pga',     :action=> 'show_pga_stat_current',        :hint=>t(:menu_sga_pga_pga_statistics_current_hint, :default=> 'Show current PGA-usage') },
                {:class=> 'item', :caption=>t(:menu_historic_caption, :default=> 'Historic'),                  :controller=> 'dba_pga',     :action=> 'show_pga_stat_historic',        :hint=>t(:menu_sga_pga_pga_statistics_historic_hint, :default=> 'Show historic PGA-usage') },
                ]
            },
            { :class=> 'menu', :caption=> 'Result Cache (from 11g)', :content=>[
                  {:class=> 'item', :caption=>t(:menu_current_caption, :default=> 'Current'),                  :controller=> 'dba_sga',     :action=> 'show_result_cache',        :hint=>t(:menu_sga_pga_result_cache_current_hint, :default=> 'Show current usage of result cache') },
                ]
            },
            {:class=> 'item', :caption=>t(:menu_sga_pga_object_by_file_and_block_caption, :default=> 'Object by file and block no.'),      :controller=> 'dba_sga',     :action=> 'show_object_nach_file_und_block',  :hint=>t(:menu_sga_pga_object_by_file_and_block_hint, :default=> 'Determine object-name by file- and block-no.') },
            {:class=> 'item', :caption=> 'Compare execution plans',      :controller=> 'dba_sga',     :action=> 'show_compare_execution_plans',  :hint=>t(:menu_sga_pga_compare_execution_plans, :default=> 'Compare execution plan of two different cursors in SGA') },
            ]
        },
        { :class=> 'menu', :caption=>t(:menu_addition_caption, :default=> 'Spec. additions'), :content=>[
            {:class=> 'item', :caption=>t(:menu_addition_dragnet_caption, :default=> 'Dragnet investigation'), :controller=> 'dragnet', :action=> 'show_selection', :hint=>t(:menu_addition_dragnet_hint, :default=> 'Dragnet investigation for performance bottlenecks')   },
        ].concat(
            showBlockingLocksMenu ?
                [{:class=> 'item', :caption=> 'Historie Blocking Locks',    :controller=> 'noa',                 :action=> 'show_blocking_locks_history', :hint=> 'Historische Auswertung Blocking DB-Locks'}] : []
        ).concat(
            showDbCacheMenu ?
                [{:class=> 'item', :caption=> 'DB-Cache-Ressourcen',           :controller=> 'noa',                 :action=> 'db_cache_ressourcen',     :hint=> 'Historische Auswertung DB-Cache-Auslastung'}] : []
        )
    },
    ]

    noa_menu = [
        { :class=> 'menu', :caption=> 'NOA diverses', :content=>[
            {:class=> 'item', :caption=> 'Table-Abhaengigkeiten',         :controller=> 'table_dependencies',  :action=> 'show_frame',            :hint=> 'Mittelbare und unmittelbare referentielle Abhängigkeiten von Tabellen'},
            {:class=> 'item', :caption=> 'Aktuell laufende Jobs',         :controller=> 'applexec',            :action=> 'show_running_jobs',     :hint=> 'Aktuell laufende Jobs laut sysp.ApplExecution'},
            { :class=> 'menu', :caption=> 'Laufzeit-Analyse', :content=>[
                {:class=> 'item', :caption=> 'Einzelwerte je LV',         :controller=> 'customer_applexec',   :action=> 'laufzeiten',            :hint=> 'Laufzeit-Auswertung je LV'},
                {:class=> 'item', :caption=> 'Summen historisch',         :controller=> 'runtime',             :action=> 'show_summary_history',  :hint=> 'Laufzeit-summen je LV'},
                ]
            },
            ]
        },
        { :class=> 'menu', :caption=> 'NOA Online-FW', :content=>[
            {:class=> 'item', :caption=> 'Übersicht Queue',               :controller=> 'online_framework',    :action=> 'show_overview',           :hint=> 'Übersicht über wartende Messages des Online-FW'},
            {:class=> 'item', :caption=> 'Durchsatz historisch',          :controller=> 'online_framework',    :action=> 'show_history',            :hint=> 'Historischer durchsatz des Online-FW'},
            {:class=> 'item', :caption=> 'Bulkgroup-Info',                :controller=> 'online_framework',    :action=> 'show_working_ofbulkgroup',:hint=> 'Info zu wartenden und aktiv verarbeiteten Bulkgroups'},
            {:class=> 'item', :caption=> 'Worker Infos',                  :controller=> 'online_worker',       :action=> 'start_working',           :hint=> 'Unsupported'},
            {:class=> 'item', :caption=> 'Übersicht externe Queue',       :controller=> 'online_framework',    :action=> 'show_external_queue',     :hint=> 'Übersicht über auf Übertragung nach journal.OFMessage wartende Messages des Online-FW in Tabelle journal.OFExtServiceMessage'},
            ]
        },
    ]

    noa_menu[0][:content] << {:class=> 'item', :caption=> 'Wachstum von Objekten', :controller=> 'noa', :action=> 'show_object_increase', :hint=> 'Wachstum von Objekten in gegebenem Zeitraum'} if showNOAObjectIncrease


    main_menu.concat noa_menu if showNOAMenu
    main_menu
  end


    #Ausgabe eines einzelnen Menues
private
  def showBlockingLocksMenu
    res = sql_select_first_row "SELECT /* Panorama Tool Ramm */ COUNT(*) Anzahl, MIN(Owner) Owner FROM All_Tables WHERE Table_Name = 'DBA_HIST_BLOCKING_LOCKS'"
    session[:dba_hist_blocking_locks_owner] = res.owner
    Rails.logger.info "MenuHelper.showBlockingLocksMenu: #{res.anzahl} different schemas have table DBA_HIST_BLOCKING_LOCKS, function hidden" if res.anzahl > 1
    res.anzahl == 1     # Nur verwenden, wenn genau ein Schema die Daten enthält
  end

  def showDbCacheMenu
    res = sql_select_first_row "SELECT /* Panorama Tool Ramm */ COUNT(*) Anzahl, MIN(Owner) Owner FROM All_Tables WHERE Table_Name = 'DBA_HIST_CACHE_OBJECTS'"
    session[:dba_hist_cache_objects_owner] = res.owner
    Rails.logger.info "MenuHelper.showDbCacheMenu: #{res.anzahl} different schemas have table DBA_HIST_CACHE_OBJECTS, function hidden" if res.anzahl > 1
    res.anzahl == 1     # Nur verwenden, wenn genau ein Schema die Daten enthält

  end

  def showNOAMenu
    # Test auf spezielle Projekt-DB
    sql_select_one("SELECT /* Panorama Tool Ramm */ COUNT(*) FROM All_Users WHERE UserName = 'NOA'") > 0
  end

  def showNOAObjectIncrease # Test auf Vorhandensein einer Tabelle
    sql_select_one("SELECT /* Panorama Tool Ramm */ COUNT(*) FROM All_Tables WHERE Owner='DBADMIN' AND Table_Name='OG_SEG_SPACE_IN_TBS'") > 0
  end

public
  # Test ob Controller die Aktion definiert hat, Controller-Name mit _ statt CamelCase
  def controller_action_defined?(controller, action)
    controller_obj = "#{controller}_controller".camelize.constantize.new
    controller_obj.respond_to? action.to_s
  end

private
  # Aufbau eines Menü-Eintrages als Ajax-Call
  def menu_link_remote(title, controller, action, hint='')
      exec_controller = :env                 # Default-Controller, wenn keine eigene Action deklariert ist
      exec_action     = :render_menu_action  # Default-Action wenn keine eigene Action deklariert ist

      # Test, ob Methode im Controller existiert, dann diese ausführen
      if controller_action_defined?(controller, action)
        exec_controller = controller
        exec_action     = action
      end
      my_ajax_link_to(title,
                      url_for(:controller          => exec_controller,
                              :action              => exec_action,
                              :update_area         => 'content_for_layout',     # Standard-Div für Anzeige in Layout
                              :redirect_controller => controller,
                              :redirect_action     => action,
                              :last_used_menu_controller => controller, # Merken der zuletzt aus Menü ausgeführten Action
                              :last_used_menu_action     => action,
                              :last_used_menu_caption    => title,
                              :last_used_menu_hint       => hint
                        ),
                      :title => hint,
                      :id    => "menu_#{controller}_#{action}"
                     )
  end


  def build_menu_entry(menu_entry)
    if menu_entry[:min_db_version] && session[:database].version <  menu_entry[:min_db_version]
      return ''                                                                    # Keine Anzeige, da Funktion von DB-Version noch nicht unterstützt wird
    end
    output = ''
    output << '<li>'
    output << "<a class='sf-with-ul' href='#a'>#{menu_entry[:caption]}<span class='sf-sub-indicator'> »</span></a>"
    output << '<ul>
    '
    menu_entry[:content].each do |m|
      output << build_menu_entry(m) if m[:class] == 'menu'
      unless m[:min_db_version] && session[:database].version <  m[:min_db_version] # Prüfung auf unterstützte DB-Version
        output << "<li>#{ menu_link_remote(m[:caption], m[:controller], m[:action], m[:hint]) }</li>" if m[:class] == 'item'
      end
    end
    output << '</ul>
    '
    output << '</li>'
    output
  end

public
  # Aufbau des HTML-Menües, Hash mit DB-Namen für Spezialbehandlung
  def build_menu_html
    output = "<ul class='sf-menu sf-js-enabled sf-shadow'>"
    menu_content.each do |m|      # Aufruf Methode application_helper.menu_content
      output << build_menu_entry(m)
    end
    output << "
      <li>
          <a class='sf-with-ul' href='#a'>#{ t :help, :default=> 'Help' }<span class='sf-sub-indicator'> »</span></a>
        <ul>
          <li>#{ link_to t(:menu_help_overview_caption, :default=> 'Overview'), { :controller => 'help', :action=> 'overview'}, :title=>t(:menu_help_overview_hint, :default=>'Help-overview'), :target=> '_blank'  }</li>
          <li>#{ link_to t(:menu_help_content_caption,  :default=> 'Current content'),  { :controller => 'help', :action=> 'content'}, :title=>t(:menu_help_content_hint, :default=>'Help for current content'), :target=> '_blank' }</li>
          <li><a href='mailto:Peter.Ramm@ottogroup.com'  title='#{t :menu_help_contact_title, :default=> 'Contact to producer'}'>#{t :menu_help_contact_caption, :default=> 'Contact'}</a></li>
          <li><a href='http://sewiki.ov.otto.de:8080/xwiki/bin/view/TA+SYSPARA/Panorama'  title='#{t :menu_help_wiki_title, :default=> 'Panorama-Wiki incl. FAQ'}' target='_blank'>#{t :menu_help_wiki_caption, :default=> 'Wiki / FAQ'}</a></li>
          <li>#{ link_to t(:menu_help_version_history_caption, :default=> 'Version history'), { :controller => 'help', :action=> 'version_history'}, :title=>t(:menu_help_version_history_hint, :default=>'Development history of features and versions'), :target=> '_blank'  }</li>
        </ul>
      </li>
    </ul>
    "
    output.html_safe
  end



end