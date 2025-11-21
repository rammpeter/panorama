require 'json'
require 'fileutils'


# Remove database tasks for nulldb-adapter
Rake::TaskManager.class_eval do
  def delete_task(task_name)
    @tasks.delete(task_name.to_s)
  end
  Rake.application.delete_task("db:test:load")
  # raises: Don't know how to build task 'db:test:purge' (See the list of available tasks with `bin/rails --tasks`)
  # Rake.application.delete_task("db:test:purge")
  Rake.application.delete_task("db:abort_if_pending_migrations")
end


namespace :assets do
  task :precompile do
    puts '####### Task assets:precompile extended in lib/tasks/precompile.rake !'
    puts '####### Add native files to public/assets if requested outside from asset pipeline'

    # Kopieren aller vorcompilierten Assets in nativer Form für Images aus vendor/

    #file = File.new("../../public/assets/.sprockets-manifest*.json", "r")

    #puts Dir.glob("*")

    Dir.glob("public/assets/.sprockets-manifest*.json").each do |fname|
      manifest = IO.read(fname)
      mhash = JSON.parse(manifest)
      mhash['files'].each do |key, value|
        source = "public/assets/#{key}"
        target = "public/assets/#{value['logical_path']}"

        puts "# create #{target}"
        FileUtils.cp(source, target)
      end
    end


    #my_hash = JSON.parse('{"hello": "goodbye"}')
    #puts my_hash["hello"] => "goodbye"

  end
end
