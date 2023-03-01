class PackLicense

  def initialize(license_type)
    license_type = :none unless [:diagnostics_pack, :diagnostics_and_tuning_pack, :panorama_sampler, :none].include?(license_type)   # Assume at login startup that no management pack is licensed until user has acknowledged the selection
    @license_type = license_type

  end

  def self.diagnostics_pack_licensed?
    license_type = PanoramaConnection.get_threadlocal_config[:management_pack_license]&.to_sym
    license_type == :diagnostics_pack || license_type == :diagnostics_and_tuning_pack
  end

  def self.tuning_pack_licensed?
    PanoramaConnection.get_threadlocal_config[:management_pack_license]&.to_sym == :diagnostics_and_tuning_pack
  end

  def self.panorama_sampler_active?
    PanoramaConnection.get_threadlocal_config[:management_pack_license]&.to_sym == :panorama_sampler
  end

  def self.none_licensed?
    PanoramaConnection.get_threadlocal_config[:management_pack_license]&.to_sym == :none
  end


  # Is user allowed to choose the management_pack_license for this database
  # @param {management_pack_license} Symbol license type to check
  # @param {control_management_pack_access} String Current value of init parameter control_management_pack_access
  def self.management_pack_selectable(management_pack_license, control_management_pack_access)
    case management_pack_license
    when :diagnostics_pack then
      return (PanoramaConnection.edition == :enterprise && control_management_pack_access['DIAGNOSTIC']) || PanoramaConnection.edition == :express
    when :diagnostics_and_tuning_pack then
      return (PanoramaConnection.edition == :enterprise && control_management_pack_access['TUNING']) || PanoramaConnection.edition == :express
    when :panorama_sampler then
      # check if AWR/ASH-Sampling is really active for existing Panorama-Sampler-schema
      return false if PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].nil?
      return PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM All_Tables WHERE Owner = ? AND Table_Name = 'PANORAMA_SNAPSHOT'", PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]]) > 0
    when :none then return true
    end
    false
  end

  # Filter SQL string or array for unlicensed Table Access
  def self.filter_sql_for_pack_license(sql, management_pack_license: PanoramaConnection.get_threadlocal_config[:management_pack_license])
    case sql.class.name
      when 'Array' then
        sql[0] = self.new(management_pack_license).filter_sql_string_for_pack_license(sql[0]) if sql && sql.count > 0
      when 'String' then
        sql = self.new(management_pack_license).filter_sql_string_for_pack_license(sql) if sql
      else
        raise "PackLicense.filter_sql_for_pack_license: unsupported parameter class #{sql.class.name}"
    end
    sql                                                                         # return transformed SQL
  end

  # replace table_names in SQL according to license type
  def self.translate_sql_table_names(sql, license_type)
    case license_type
    when :panorama_sampler
      raise "config[:panorama_sampler_schema] must be defined if config[:management_pack_license] == :panorama_sampler" if PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].nil?
      # !!! Puma stops here if another thread is active, jetty does not stop here
      sql = PanoramaSamplerStructureCheck.transform_sql_for_sampler(sql)
    else
      if PanoramaConnection.autonomous_database?                                # Use CDB-prefix for autonomous DB (Access on DBA_Hist leads to session termination)
        # TODO: CDB_OR_DBA
        # sql.gsub!(/DBA_Hist/i, 'CDB_Hist') unless sql['NO_CDB_TRANSFORMATION']  # Translate only if not supressed
      end
    end
    sql
  end

  # Filter SQL string for unlicensed Table Access
  def filter_sql_string_for_pack_license(sql)
    sql = PackLicense.translate_sql_table_names(sql, @license_type)             # Replace table names according to license type
    case @license_type
    when :diagnostics_and_tuning_pack
      nil
    when :diagnostics_pack then
      check_for_tuning_pack_usage(sql)
    when :panorama_sampler then
      check_for_diagnostics_pack_usage(sql)
      check_for_tuning_pack_usage(sql)
    when :none, nil then
      check_for_diagnostics_pack_usage(sql)
      check_for_tuning_pack_usage(sql)
    else
      raise "Unknown license type #{@license_type}"
    end
    sql
  end

  private
  def check_existence_in_sql(sql, search_string, allowed_array, pack_name)
    sql_up = sql.upcase

    while !sql_up.nil? && sql_up[search_string]                                 # iterate over all matches of searchstring
      sql_up = sql_up[sql_up.index(search_string), sql_up.length]               # Reduce SQL to match of search_string + succeeding chars
      allowed = false                                                           # not allowd if no match in allowed_array found
      allowed_array.each do |allowed_string|
        allowed = true if sql_up[0, allowed_string.length] == allowed_string.upcase
      end

      unless allowed
        table_name = sql_up
        table_name = table_name[0, table_name.index(' ')] if table_name[' ']    # Tablename ends at ....
        table_name = table_name[0, table_name.index(',')] if table_name[',']    # Tablename ends at ....
        table_name = table_name[0, table_name.index('(')] if table_name['(']    # Tablename ends at ....
        table_name = table_name[0, table_name.index(')')] if table_name[')']    # Tablename ends at ....

        message = "Access denied on table #{table_name} because of missing license for Oracle #{pack_name} Pack!\nPanorama's config for management_pack_license is: '#{@license_type}'"
        Rails.logger.error('PackLicense.check_existence_in_sql') { message }
        Rails.logger.error('PackLicense.check_existence_in_sql') { sql }

        raise PopupMessageException.new(message)
      end
      sql_up = sql_up[search_string.length, sql_up.length]                      # Step n chars next to lookup next match
    end


  end


  public

  # raise Exception if SQL contains content violating missing diagnostic pack license
  def check_for_diagnostics_pack_usage(sql)
    # Objects allowed without diagnostics pack even if name pattern belongs to objects requiring diagnostics pack
    allowed_array = [
      'CDB_HIST_BLOCKING_LOCKS',                                              # private table
      'CDB_HIST_DATABASE_INSTANCE',
      'CDB_HIST_SEG_STAT',
      'CDB_HIST_SEG_STAT_OBJ',
      'CDB_HIST_SNAPSHOT',
      'CDB_HIST_SNAP_ERROR',
      'CDB_HIST_UNDOSTAT',
      'DBA_HIST_BLOCKING_LOCKS',                                              # private table
      'DBA_HIST_DATABASE_INSTANCE',
      'DBA_HIST_SEG_STAT',
      'DBA_HIST_SEG_STAT_OBJ',
      'DBA_HIST_SNAPSHOT',
      'DBA_HIST_SNAP_ERROR',
      'DBA_HIST_UNDOSTAT'
    ]


    # Packages Tables etc. belonging to diagnostic pack
    test_array = [
        'CDB_HIST_',
        'DBA_HIST_',
        'DBA_ADDM_',
        'DBA_ADVISOR_',                                                         #  if queries to these views return rows with the value ADDM in the ADVISOR_NAME column or a value of ADDM* in the TASK_NAME column or the corresponding TASK_ID.
        'DBA_STREAMS_TP_PATH_BOTTLENECK',
        'DBA_STREAMS_TP_COMPONENT_STAT',
        'DBMS_WORKLOAD_REPOSITORY',
        'DBMS_ADDM',
        'DBMS_ADVISOR',                                                         # requires Tuning Pack in addition
        'DBMS_AWRHUB',                                                          # requires both an Oracle Diagnostics Pack license and an OCI Operations Insights Service license subscription.
        'DBMS_PERF',                                                            # Named as part of Diagnostics Pack as well as part of Tuning Pack, unclear which pack is really needed
        'DBMS_UMF',
        'DBMS_WORKLOAD_REPLAY',                                                 # DIAGNOSTIC PACK if advisor_name => ADDM OR task_name LIKE ADDM% TUNING PACK - where advisor_name => SQL Tuning Advisor
        'DBMS_WORKLOAD_REPOSITORY',
        'DISPLAY_AWR',                                                          # DBMS_XPLAN.DISPLAY_AWR requires access on DBA_HIST_SQLSTat etc.
        'MGMT$ALERT_',
        'MGMT$AVAILABILITY_',
        'MGMT$BLACKOUT',
        'MGMT$METRIC_COLLECTIONS',
        'MGMT$ALERT_CURRENT',
        'MGMT$METRIC_',
        'MGMT$TARGET_METRIC_',
        'MGMT$TEMPLATE',
        'V_$ACTIVE_SESSION_HISTORY',
        'V$ACTIVE_SESSION_HISTORY',
        'X$ASH'
    ]

    test_array.each do |t|
      check_existence_in_sql(sql, t, allowed_array, 'Diagnostics')
    end
  end

  # raise Exception if SQL contains content violating missing tuning pack license
  def check_for_tuning_pack_usage(sql)
    allowed_array = []

    # Packages Tables etc. belonging to tuning pack
    # for 12.2 https://docs.oracle.com/en/database/oracle/oracle-database/12.2/dblic/Licensing-Information.html#GUID-68A4128C-4F52-4441-8BC0-A66F5B3EEC35
    # for 19c https://docs.oracle.com/en/database/oracle/oracle-database/19/dblic/Licensing-Information.html#GUID-C3042D9A-5596-41A3-A08A-4581FED7634F
    # for 21c https://docs.oracle.com/en/database/oracle/oracle-database/21/dblic/Licensing-Information.html#GUID-68A4128C-4F52-4441-8BC0-A66F5B3EEC35
    test_array = [
        'CDB_HIST_REPORTS',                                                     # SQL-Monitoring: CDB_HIST_REPORTS, CDB_HIST_REPORTS_DETAILS
        'DBA_HIST_REPORTS',                                                     # SQL-Monitoring: DBA_HIST_REPORTS, DBA_HIST_REPORTS_DETAILS
        'DBMS_ADVISOR',                                                         # DIAGNOSTIC PACK if advisor_name => ADDM OR task_name LIKE ADDM% TUNING PACK - where advisor_name => SQL Tuning Advisor
        'DBMS_AUTO_SQLTUNE',
        # 'DBMS_PERF',                                                            # Named as part of Diagnostics Pack as well as part of Tuning Pack, unclear which pack is really needed
        'DBMS_SQL_MONITOR',
        'DBMS_SQLTUNE.ADD_SQLSET_REFERENCE',                                    # Only this methods are part of Tuning Pack
        'DBMS_SQLTUNE.CAPTURE_CURSOR_CACHE_SQLSETS',
        'DBMS_SQLTUNE.CREATE_SQLSET',
        'DBMS_SQLTUNE.CREATE_STGTAB_SQLSET',
        'DBMS_SQLTUNE.DELETE_SQLSET',
        'DBMS_SQLTUNE.DROP_SQLSET',
        'DBMS_SQLTUNE.LOAD_SQLSET',
        'DBMS_SQLTUNE.PACK_STGTAB_SQLSET',
        'DBMS_SQLTUNE.REMOVE_SQLSET_REFERENCE',
        'DBMS_SQLTUNE.SELECT_CURSOR_CACHE',
        'DBMS_SQLTUNE.SELECT_SQLSET',
        'DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY',
        'DBMS_SQLTUNE.UNPACK_STGTAB_SQLSET',
        'DBMS_SQLTUNE.UPDATE_SQLSET',
        'GV$SQL_MONITOR',
        'V$SQL_MONITOR',
        'V_$SQL_MONITOR',
        'V$SQL_PLAN_MONITOR',
        'V_$SQL_PLAN_MONITOR'
    ]

    test_array.each do |t|
      check_existence_in_sql(sql, t, allowed_array, 'Tuning')
    end

  end

end