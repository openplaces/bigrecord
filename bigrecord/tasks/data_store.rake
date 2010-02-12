namespace :data_store do
  require File.join(File.dirname(__FILE__), "..", "lib", "big_record")

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

end