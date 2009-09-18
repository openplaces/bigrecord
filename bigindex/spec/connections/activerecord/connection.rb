# Require ActiveRecord
begin
  gem 'activerecord'
  require 'activerecord'
rescue LoadError
  raise "Bigindex specs require the activerecord gem to be installed, or use rake spec:* to run the specs against another source"
end

# Load the configuration
ActiveRecord::Base.configurations = YAML::load(File.open(File.join(File.dirname(__FILE__), "activerecord.yml")))

# Define the logger to output a debug.log file in this directory
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "..", "..", "debug.log"))

# Log some initial connection info and establish the connection to the data store.
ActiveRecord::Base.logger.info "Connecting to MySQL data store (#{ActiveRecord::Base.configurations.inspect})"
ActiveRecord::Base.establish_connection 'mysql'

@model_path = File.join(SPEC_ROOT, "lib", "activerecord", "*.rb")
