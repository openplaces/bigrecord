# Load the configuration
ActiveRecord::Base.configurations = YAML::load(File.open(File.join(File.dirname(__FILE__), "activerecord.yml")))

# Define the logger to output a debug.log file in this directory
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "..", "..", "debug.log"))

# Log some initial connection info and establish the connection to the data store.
ActiveRecord::Base.logger.info "Connecting to MySQL data store (#{ActiveRecord::Base.configurations.inspect})"
ActiveRecord::Base.establish_connection 'mysql'

# Load the various helpers for this spec suite
Dir.glob( File.join(SPEC_ROOT, "lib", "activerecord", "*.rb") ).each do |model|
  require model
end
