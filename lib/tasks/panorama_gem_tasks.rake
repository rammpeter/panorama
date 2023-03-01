# desc "Explaining what the task does"
# task :panorama_gem do
#   # Task goes here
# end


=begin
desc "Run tests"
task :test do
  require 'bundler/gem_tasks'

  require 'rake/testtask'

  Rake::TestTask.new(:test) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = false
  end
end
=end


# Remove database tasks for nulldb-adapter
Rake::TaskManager.class_eval do
  def delete_task(task_name)
    @tasks.delete(task_name.to_s)
  end

  if Rails.env.test?
    Rake.application.delete_task("db:test:load")
    Rake.application.delete_task("db:test:purge")
    Rake.application.delete_task("db:abort_if_pending_migrations")

    msg = "Test-Environment at #{Time.now}:
TEST_HOST                 = #{ENV['TEST_HOST']                || 'not set, defaults to localhost'}
TEST_PORT                 = #{ENV['TEST_PORT']                || 'not set, defaults to 1521'}
TEST_SERVICENAME          = #{ENV['TEST_SERVICENAME']         || 'not set, defaults to ORCLPDB1'}
TEST_TNS                  = #{ENV['TEST_TNS']                 || 'not set, defaults to nil'}
TEST_USERNAME             = #{ENV['TEST_USERNAME']            || 'not set, defaults to panorama_test'}
TEST_PASSWORD             = #{ENV['TEST_PASSWORD']            || 'not set, defaults to panorama_test'}
TEST_SYSPASSWORD          = #{ENV['TEST_SYSPASSWORD']         || 'not set, defaults to oracle'}
MANAGEMENT_PACK_LICENSE   = #{ENV['MANAGEMENT_PACK_LICENSE']  || 'not set, defaults to :diagnostics_and_tuning_pack'}
JAVA_OPTS                 = #{ENV['JAVA_OPTS']}
JRUBY_OPTS                = #{ENV['JRUBY_OPTS']}
"
    puts msg
  end
end

namespace :db do
  namespace :test do
    task :load do
      puts 'Task db:test:load removed by lib/tasks/panorama_gem_tasks.rake !'
    end
    task :purge do
      puts 'Task db:test:purge removed by lib/tasks/panorama_gem_tasks.rake !'
    end
  end
  task :abort_if_pending_migrations do
    puts 'Task db:db:abort_if_pending_migrations removed by lib/tasks/panorama_gem_tasks.rake !'
  end
end
