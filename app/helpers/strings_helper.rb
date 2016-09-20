# encoding: utf-8
module StringsHelper
  @@strings_list = {
      sql_monitor_link_title: "Generate SQL-Monitor report by calling DBMS_SQLTUNE.report_sql_monitor on new page.
- requires active internet connection at client
- requires Adobe Flash installed at client browser
- requires licensing of Oracle Tuning Pack
- Available only if data exists in gv$SQL_Monitor

Click link at column 'SQL exec ID' to generate SQL-Monitor report if there are multiple results",

  }
  def strings(key)
    raise "StringsHelper.strings: Key '#{key}' not found in predfined strings" unless @@strings_list[key]
    @@strings_list[key]
  end
end