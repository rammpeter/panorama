# encoding: utf-8

require 'json'

# especially for ash_select
include ActiveSessionHistoryHelper

# Liste der Rasterfahndungs-SQL
include Dragnet::CascadingViewsHelper
include Dragnet::DragnetSqlsLogwriterRedoHelper
include Dragnet::DragnetSqlsLongRunningHelper
include Dragnet::DragnetSqlsTuningSgaPgaHelper
include Dragnet::ForeignKeyConstraintHelper
include Dragnet::InstanceSetupTuning
include Dragnet::MaterializedViewsHelper
include Dragnet::OptimalIndexStorageHelper
include Dragnet::OptimizableFullScansHelper
include Dragnet::ParallelQueryUsage
include Dragnet::PartitioningHelper
include Dragnet::PlSqlUsageHelper
include Dragnet::ProblemsWithParallelQueryHelper
include Dragnet::SoftParseCursorCachingHelper
include Dragnet::SqlsConclusionApplicationHelper
include Dragnet::SqlsCursorRedundanciesHelper
include Dragnet::SqlsPotentialDbStructuresHelper
include Dragnet::SqlsWrongExecutionPlanHelper
include Dragnet::SuboptimalIndexUsageHelper
include Dragnet::UnnecessaryExecutionsHelper
include Dragnet::UnnecessaryHighExecutionFrequencyHelper
include Dragnet::UnnecessaryIndexesHelper
include Dragnet::UnnecessaryIndexColumnsHelper
include Dragnet::UnusedTablesHelper
include Dragnet::ViewIssuesHelper

module DragnetHelper

  private
  # Kompletten Menu-Baum taggen mit flag = true
  def tag_external_selections(list, flag)
    list.each do |l|
      l[flag] = true
      tag_external_selections(l[:entries], flag) if l[:entries]
    end
  end

  public

  public
  # liefert Array von Hashes mit folgender Struktur:
  #   :name           Name des Eintrages
  #   :desc           Beschreibung
  #   :entries        Array von Hashes mit selber Struktur (rekursiv), wenn belegt, dann gilt Element als Menü-Knoten
  #   :sql            SQL-Statement zur Ausführung
  #   :min_db_version Optional minimum DB version
  #   :not_executable Optional mark entry as not executable SQL
  #   :parameter      Array von Hashes mit folgender Struktur
  #       :name       Name des Parameters
  #       :size       Darstellungsgröße
  #       :default    Default-Wert
  #       :title      MouseOver-Hint

  def dragnet_sql_list
    dragnet_internal_list = [
        {   :name     => t(:dragnet_helper_group_potential_db_structures,  :default=> 'Potential in DB-structures'),
            :entries  => [{  :name    => t(:dragnet_helper_group_optimal_index_storage, :default => 'Ensure optimal storage parameter for indexes'),
                             :entries => optimal_index_storage
                          },
                          {  :name    => t(:dragnet_helper_group_unnecessary_indexes, :default => 'Detection of possibly unnecessary indexes'),
                             :entries => unnecessary_indexes
                          },
                          {  :name    => t(:dragnet_helper_group_unnecessary_index_columns, :default => 'Detection of possibly unnecessary index columns'),
                             :entries => unnecessary_index_columns
                          },
                          {  :name    => t(:dragnet_helper_group_partitioning, :default => 'Recommendations for partitioning'),
                             :entries => partitioning
                          },
                          {  :name    => t(:dragnet_helper_group_unused_tables, :default => 'Detection of unused tables or columns'),
                             :entries => unused_tables
                          },
                          {  :name    => t(:dragnet_helper_group_materialized_views, :default => 'Materialized_views'),
                             :entries => materialized_views
                          },
                          {  :name    => 'Foreign Key Constraints',
                             :entries => dragnet_foreign_key_constraint
                          },
            ].concat(sqls_potential_db_structures)
        },
        {
            :name     => t(:dragnet_helper_group_wrong_execution_plan,     :default=> 'Detection of SQL with problematic execution plan'),
            :entries  => [{   :name    => t(:dragnet_helper_group_optimizable_full_scans, :default=>'Optimizable full-scan operations'),
                              :entries => optimizable_full_scans
                          },
                          {   :name    => t(:dragnet_helper_group_problems_with_parallel_query, :default=>'Potential for improvement in the use of Parallel Query'),
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
            :name     => t(:dragnet_helper_group_long_running_sqls,  :default=> 'Detection of long running SQLs'),
            :entries  => dragnet_sqls_long_running
        },
        {
            :name     => t(:dragnet_helper_group_tuning_sga_pga,           :default=> 'Tuning of / load rejection from SGA, PGA'),
            entries: [
              {
                :name     => t(:dragnet_helper_group_cursor_redundancies,      :default=> 'Redundant cursors / usage of bind variables'),
                :entries  => sqls_cursor_redundancies
              },
              {
                :name     => t(:dragnet_helper_group_soft_parses_cursor_caching,  :default=> 'Soft parse activities / SQL statement cursor caching'),
                :entries  => soft_parse_cursor_caching
              },
            ].concat(dragnet_sqls_tuning_sga_pga)
        },
        {
            :name     => t(:dragnet_helper_group_logwriter_redo,           :default=> 'Logwriter load / redo impact'),
            :entries  => dragnet_sqls_logwriter_redo
        },
        {
            :name     => t(:dragnet_helper_group_conclusion_application,   :default=> 'Conclusions on appliction behaviour'),
            :entries  => [ {   :name    => t(:dragnet_helper_group_view_issues, :default=>'Potential in DB-Views'),
                               :entries => [{
                                                :name    => t(:dragnet_helper_group_cascading_views, :default=>'Views with cascading dependiencies (multiple hierarchy)'),
                                                :entries => cascading_views
                                            }
                               ].concat(view_issues)
                           },
            ].concat(sqls_conclusion_application)
        },
        {
            :name     => t(:dragnet_helper_group_pl_sql_usage,   :default=> 'PL/SQL-usage hints'),
            :entries  => pl_sql_usage
        },
        {
            :name     => t(:dragnet_helper_group_instance_setup_tuning, default: 'Instance-setup, tuning and monitoring'),
            :entries  => instance_setup_tuning
        },
    ]

    if !defined?(GenerateDragnetHtml)                                           # not for generate_dragnet_html.rb

      # Extend list with predefined selections from file
      predefined_filename = "#{Panorama::Application.config.panorama_var_home}/predefined_dragnet_selections.json"
      if File.exist?(predefined_filename)
        begin
          dragnet_predefined_list = ""
          File.open(predefined_filename, 'r'){|file|
            dragnet_predefined_list = JSON.parse(file.read)
          }
          Rails.logger.info("Predefined dragnet selections read from #{predefined_filename}")
        rescue Exception => e
          raise "Error \"#{e.message}\" during parse of file #{predefined_filename}"
        end
        deep_symbolize_keys!(dragnet_predefined_list)
        dragnet_internal_list << { :name    => t(:dragnet_helper_predefined_menu_name, :default=> 'Predefined extensions from local Panorama server instance'),
                                   :entries => dragnet_predefined_list
        }
      else
        Rails.logger.info("Predefined dragnet selections not found at #{predefined_filename}")
      end

      # Extend list with personal selections (dependent from browser cookie)
      dragnet_personal_selection_list = read_from_client_info_store(:dragnet_personal_selection_list)   # personal extensions from cache
      if dragnet_personal_selection_list && dragnet_personal_selection_list.count > 0
        tag_external_selections(dragnet_personal_selection_list, :personal)     # Mark as personal

        dragnet_internal_list << { :name    => 'Personal extensions (per browser-cookie)',
                                   :entries => dragnet_personal_selection_list
        }
      end
    end

    dragnet_internal_list
  end

  # Über zusammengesetzte ID der verschiedenen Hierarchien Objekt-Referenz in dragnet_sql_list finden
  def extract_entry_by_entry_id(entry_id)
    entry_ids = entry_id.split('_')
    entry_ids.delete_at(0)                                                        # ersten Eintrag entfernen

    entry = nil
    entry_ids.each do |e|
      if entry.nil?
        entry = dragnet_sql_list[e.to_i]                                          # x-tes Element aus erster Hierarchie-Ebene
      else
        entry = entry[:entries][e.to_i]                                           # x-tes Element aus innerer Hierarchie
      end
    end
    entry
  end

  def deep_symbolize_keys!(object)
    if object.instance_of?(Hash)
      object.symbolize_keys!
      object.each do |_key, value|
        deep_symbolize_keys!(value) if value.instance_of?(Array)
      end
    end

    if object.instance_of?(Array)
      object.each do |obj|
        deep_symbolize_keys!(obj)
      end
    end
  end

end
