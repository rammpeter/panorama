require 'java'

# Check for pathlen exceeding system limit
# to find the longest file path execute in RAILS_ROOT/app:
# find . -type f | awk '{ print length, $0 }' | sort -rn | head -1
#
# current longest file path with 91 chars is ./views/active_session_history/_list_session_statistic_historic_grouping_table_def.html.erb
#
# 124 chars is length of dir prefix in temp: example: jetty-0.0.0.0-8080-Panorama.war-_-any-513147796374658368.dir/webapp/WEB-INF/gems/bundler/gems/Panorama_Gem-815e84c2f86f/app
max_file_path_length = 124 + 91 + java.lang.System.get_property('java.io.tmpdir').length

max_possible_filepath_length = 4096                                             # Linux-limit if no other limits
max_possible_filepath_length = 260 if RbConfig::CONFIG['host_os'] =~ /mswin/

if max_file_path_length > max_possible_filepath_length
  Rails.logger.info "#######################################################################################################################################"
  Rails.logger.info "################### CAUTION !!!"
  Rails.logger.info "################### The path length of your current working dir for Panorama may be too long in respect to your system's limits."
  Rails.logger.info "################### This may lead to errors while accessing Panorama-files with longer file paths."
  Rails.logger.info "################### Current working dir is: #{java.lang.System.get_property('java.io.tmpdir')}"
  Rails.logger.info "################### Solution:"
  Rails.logger.info "################### Specify a working dir which is #{max_file_path_length-max_possible_filepath_length} chars smaller than the current"
  Rails.logger.info "################### by using '-Djava.io.tmpdir=...' at Java startup."
  Rails.logger.info "################### Example: > java -Djava.io.tmpdir=C:\\TEMP -jar Panorama.war"
  Rails.logger.info "#######################################################################################################################################"
end
