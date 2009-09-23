namespace :db do

  desc "Migrate the Bigrecord database through scripts in db/bigrecord_migrate. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => :environment do
    Rake::Task["bigrecord:migrate"].invoke
  end

end


namespace :bigrecord do

  desc "Migrate the Bigrecord database through scripts in db/bigrecord_migrate. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => :environment do
    BigRecord::Migrator.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    BigRecord::Migrator.migrate("db/bigrecord_migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  namespace :migrate do
    desc 'Rollbacks the database one migration and re migrate up. If you want to rollback more than one step, define STEP=x. Target specific version with VERSION=x.'
    task :redo => :environment do
      if ENV["VERSION"]
        Rake::Task["bigrecord:migrate:down"].invoke
        Rake::Task["bigrecord:migrate:up"].invoke
      else
        Rake::Task["bigrecord:rollback"].invoke
        Rake::Task["bigrecord:migrate"].invoke
      end
    end

    desc 'Runs the "up" for a given migration VERSION.'
    task :up => :environment do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      BigRecord::Migrator.run(:up, "db/bigrecord_migrate/", version)
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task :down => :environment do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      BigRecord::Migrator.run(:up, "db/bigrecord_migrate/", version)
    end
  end

  desc 'Rolls the schema back to the previous version. Specify the number of steps with STEP=n'
  task :rollback => :environment do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    BigRecord::Migrator.rollback('db/bigrecord_migrate/', step)
  end

  desc 'Pushes the schema to the next version. Specify the number of steps with STEP=n'
  task :forward => :environment do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    BigRecord::Migrator.forward('db/bigrecord_migrate/', step)
  end

end