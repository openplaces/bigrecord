namespace :data_store do
  require 'lib/big_record'

  if ENV["HBASE_REST_ADDRESS"]
    config = YAML::load(File.open(File.join(ROOT, "spec", "connections", "bigrecord.yml")))
    config["hbase"]["api_address"] = ENV["HBASE_REST_ADDRESS"]
    BigRecord::Base.configurations = config
  else
    BigRecord::Base.configurations = YAML::load(File.open(File.join(ROOT, "spec", "connections", "bigrecord.yml")))
  end
  BigRecord::Base.logger = Logger.new(File.expand_path(File.join(ROOT, "migrate.log")))

  @migrations_path = File.expand_path(File.join(ROOT, "spec", "lib", "migrations"))

  desc 'Migrate the test schema for the data store specified by ENV=<data_store>'
  task :migrate do
    environment = ENV['ENV']
    raise ArgumentError, "Usage: rake data_store:migrate ENV=<#{DATA_STORES.join("|")}>" unless environment

    BigRecord::Base.establish_connection environment

    BigRecord::Migrator.migrate(@migrations_path, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  namespace :migrate do
    desc 'Runs the "up" for a given migration VERSION.'
    task :up do
      environment = ENV['ENV']
      raise ArgumentError, "Usage: rake data_store:migrate:up ENV=<#{DATA_STORES.join("|")}>" unless environment

      BigRecord::Base.establish_connection environment

      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version

      BigRecord::Migrator.run(:up, @migrations_path, version)
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task :down do
      environment = ENV['ENV']
      raise ArgumentError, "Usage: rake data_store:migrate:down ENV=<#{DATA_STORES.join("|")}>" unless environment

      BigRecord::Base.establish_connection environment

      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version

      BigRecord::Migrator.run(:down, @migrations_path, version)
    end
  end

end