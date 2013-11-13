Rake::TaskManager.class_eval do
      def delete_task(task_name)
        @tasks.delete(task_name.to_s)
      end
      Rake.application.delete_task("db:test:load")
      Rake.application.delete_task("db:test:purge")
      Rake.application.delete_task("db:abort_if_pending_migrations")
    end
    namespace :db do
        namespace :test do
            task :load do
              puts 'Task db:test:load removed by lib/tasks/test.rake !'
            end
            task :purge do
              puts 'Task db:test:purge removed by lib/tasks/test.rake !'
            end
        end
        task :abort_if_pending_migrations do
          puts 'Task db:db:abort_if_pending_migrations removed by lib/tasks/test.rake !'
        end
    end
