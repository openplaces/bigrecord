# Require BigRecord by first checking within the BigRecord project
begin
  require File.join(SPEC_ROOT.parent, "..", "bigrecord", "lib", "big_record")
rescue LoadError
  # If it wasn't found, try requiring it via gem.
  begin
    gem 'big_record'
    require 'big_record'
  rescue
    raise "Bigindex specs require the big_record gem to be installed, or use rake spec:* to run the specs against another source"
  end
end

# Load the configuration
BigRecord::Base.configurations = YAML::load(File.open(File.join(File.dirname(__FILE__), "bigrecord.yml")))

# Define the logger to output a debug.log file in the spec directory
BigRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "..", "..", "debug.log"))

# Log some initial connection info and establish the connection to the data store.
BigRecord::Base.logger.info "Connecting to Hbase data store (#{BigRecord::Base.configurations["hbase"].inspect})"
BigRecord::Base.establish_connection 'hbase'

# Load the various helpers for this spec suite
@model_path = File.join(SPEC_ROOT, "lib", "bigrecord", "*.rb")

BigRecord::Base.logger.info "Running Bigrecord migrations..."
@migrations_path = File.expand_path(File.join(File.dirname(__FILE__), "migrations"))
BigRecord::Migrator.migrate(@migrations_path)
