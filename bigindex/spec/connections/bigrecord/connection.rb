# Load the configuration
BigRecord::Base.configurations = YAML::load(File.open(File.join(File.dirname(__FILE__), "bigrecord.yml")))

# Define the logger to output a debug.log file in this directory
BigRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))

# Log some initial connection info and establish the connection to the data store.
BigRecord::Base.logger.info "Connecting to Hbase data store (#{BigRecord::Base.configurations["hbase"].inspect})"
BigRecord::Base.establish_connection 'hbase'

# Load the various helpers for this spec suite
Dir.glob( File.join(SPEC_ROOT, "lib", "bigrecord", "*.rb") ).each do |model|
  require model
end
