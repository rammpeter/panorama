# encoding: utf-8

module LongtermTrendHelper

  def longterm_trend_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@longterm_trend_key_rules_hash) || @longterm_trend_key_rules_hash.nil?
      @longterm_trend_key_rules_hash = {}

      @longterm_trend_key_rules_hash['Instance']        = {sql: "t.Instance_Number",  sql_alias: 'Instance_Number', title: 'Instance number' }
      @longterm_trend_key_rules_hash['Wait Event']      = {sql: "we.Name",            sql_alias: 'Wait_Event',      title: 'Name of wait event',    data_title: '#{explain_wait_event(rec.wait_event)}' }
      @longterm_trend_key_rules_hash['Wait Class']      = {sql: "wc.Name",            sql_alias: 'Wait_Class',      title: 'Name of wait class' }
      @longterm_trend_key_rules_hash['User-Name']       = {sql: "u.Name",             sql_alias: 'User_Name',       title: 'Name of database user' }
      @longterm_trend_key_rules_hash['Service-Name']    = {sql: "s.Name",             sql_alias: 'Service_Name',    title: 'Name of TNS service' }
      @longterm_trend_key_rules_hash['Machine']         = {sql: "ma.Name",            sql_alias: 'Machine',         title: 'Client machine name' }
      @longterm_trend_key_rules_hash['Module']          = {sql: "mo.Name",            sql_alias: 'Module',          title: 'Module name' }
      @longterm_trend_key_rules_hash['Action']          = {sql: "a.Name",             sql_alias: 'Action',          title: 'Action name' }
    end
    @longterm_trend_key_rules_hash
  end

  def longterm_trend_key_rule(key)
    retval = longterm_trend_key_rules[key]
    raise "longterm_trend_key_rule: unknown key '#{key}'" unless retval
    retval
  end




end