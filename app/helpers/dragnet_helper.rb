# encoding: utf-8

#require 'dragnet/optimal_index_storage_helper'

module DragnetHelper
  # Liste der Rasterfahndungs-SQL

  include Dragnet::OptimalIndexStorageHelper
  include Dragnet::UnnecessaryIndexesHelper
  include Dragnet::IndexPartitioningHelper
  include Dragnet::UnusedTablesHelper
  include Dragnet::SqlsPotentialDbStructuresHelper
  include Dragnet::OptimizableFullScansHelper
  include Dragnet::ProblemsWithParallelQueryHelper
  include Dragnet::UnnecessaryExecutionsHelper
  include Dragnet::UnnecessaryHighExecutionFrequencyHelper
  include Dragnet::SuboptimalIndexUsageHelper
  include Dragnet::SqlsWrongExecutionPlanHelper
  include Dragnet::DragnetSqlsTuningSgaPgaHelper
  include Dragnet::SqlsCursorRedundanciesHelper
  include Dragnet::DragnetSqlsLogwriterRedoHelper
  include Dragnet::CascadingViewsHelper
  include Dragnet::SqlsConclusionApplicationHelper
  include Dragnet::PlSqlUsageHelper


  private
  # Kompletten Menu-Baum taggen mit flag = true
  def tag_external_selections(list, flag)
    list.each do |l|
      l[flag] = true
      tag_external_selections(l[:entries], flag) if l[:entries]
    end
  end

  public
  @@dragnet_internal_list = nil

  public
  # liefert Array von Hashes mit folgender Struktur:
  #   :name           Name des Eintrages
  #   :desc           Beschreibung
  #   :entries        Array von Hashes mit selber Struktur (rekursiv), wenn belegt, dann gilt Element als Menü-Knoten
  #   :sql            SQL-Statement zur Ausführung
  #   :parameter      Array von Hshes mit folgender Struktur
  #       :name       Name des Parameters
  #       :size       Darstellungsgröße
  #       :default    Default-Wert
  #       :title      MouseOver-Hint

  def dragnet_sql_list
    if @@dragnet_internal_list.nil?
      @@dragnet_internal_list = [
          {   :name     => t(:dragnet_helper_group_potential_db_structures,  :default=> 'Potential in DB-structures'),
              :entries  => [{  :name    => t(:dragnet_helper_group_optimal_index_storage, :default => 'Ensure optimal storage parameter for indexes'),
                               :entries => optimal_index_storage
                            },
                            {  :name    => t(:dragnet_helper_group_unnecessary_indexes, :default => 'Detection of possibly unnecessary indexes'),
                               :entries => unnecessary_indexes
                            },
                            {  :name    => t(:dragnet_helper_group_index_partitioning, :default => 'Recommendations for index partitioning'),
                               :entries => index_partitioning
                            },
                            {  :name    => t(:dragnet_helper_group_unused_tables, :default => 'Detection of unused tables or columns'),
                               :entries => unused_tables
                            },

              ].concat(sqls_potential_db_structures)
          },
          {
              :name     => t(:dragnet_helper_group_wrong_execution_plan,     :default=> 'Detection of SQL with problematic execution plan'),
              :entries  => [{   :name    => t(:dragnet_helper_group_optimizable_full_scans, :default=>'Optimizable full-scan operations'),
                                :entries => optimizable_full_scans
                            },
                            {   :name    => t(:dragnet_helper_group_problems_with_parallel_query, :default=>'Potential problems with parallel query'),
                                :entries => problems_with_parallel_query
                            },
                            {   :name    => t(:dragnet_helper_group_unnecessary_executions, :default=>'Potentially unnecessary execution of SQL statements'),
                                :entries => unnecessary_executions
                            },
                            {   :name    => t(:dragnet_helper_group_unnecessary_high_execution_frequency, :default=>'Potentially unnecessary high execution/fetch-frequency of SQL statements'),
                                :entries => unnecessary_high_execution_frequency
                            },
                            {   :name    => t(:dragnet_helper_group_suboptimal_index_index, :default=>'Suboptimal index usage in SQL statements'),
                                :entries => suboptimal_index_usage
                            },
              ].concat(sqls_wrong_execution_plan)
          },
          {
              :name     => t(:dragnet_helper_group_tuning_sga_pga,           :default=> 'Tuning of / load rejection from SGA, PGA'),
              :entries  => dragnet_sqls_tuning_sga_pga
          },
          {
              :name     => t(:dragnet_helper_group_cursor_redundancies,      :default=> 'Redundant cursors / usage of bind variables'),
              :entries  => sqls_cursor_redundancies
          },
          {
              :name     => t(:dragnet_helper_group_logwriter_redo,           :default=> 'Logwriter load / redo impact'),
              :entries  => dragnet_sqls_logwriter_redo
          },
          {
              :name     => t(:dragnet_helper_group_conclusion_application,   :default=> 'Conclusions on appliction behaviour'),
              :entries  => [ {   :name    => t(:dragnet_helper_group_cascading_views, :default=>'Views with cascading dependiencies (multiple hierarchy)'),
                                 :entries => cascading_views
                             },
              ].concat(sqls_conclusion_application)
          },
          {
              :name     => t(:dragnet_helper_group_pl_sql_usage,   :default=> 'PL/SQL-usage hints'),
              :entries  => pl_sql_usage
          },
      ]

      # Estend list with predefined selections from file
      predefined_filename = "#{Panorama::Application.config.panorama_var_home}/predefined_dragnet_selections.json"
      if File.exist?(predefined_filename)
        begin
        dragnet_predefined_list = ""
        File.open(predefined_filename, 'r'){|file|
          dragnet_predefined_list = eval(file.read)
        }
        rescue Exception => e
          raise "Error \"#{e.message}\" during parse of file #{predefined_filename}"
        end
        @@dragnet_internal_list << { :name    => 'Predefined extensions from server instance',
                                     :entries => dragnet_predefined_list
        }
      end

      # Extend list with personal selections (dependent from browser cookie)
      dragnet_personal_selection_list = read_from_client_info_store(:dragnet_personal_selection_list)   # personal extensions from cache
      if dragnet_personal_selection_list && dragnet_personal_selection_list.count > 0
        tag_external_selections(dragnet_personal_selection_list, :personal)     # Mark as personal

        @@dragnet_internal_list << { :name    => 'Personal extensions (per browser-cookie)',
                                     :entries => dragnet_personal_selection_list
        }
      end


    end
    @@dragnet_internal_list
  end



end
