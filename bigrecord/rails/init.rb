require 'big_record'

# Use the same logger as ActiveRecord to make sure that the access to the log file is properly handled
BigRecord::Base.logger = ActiveRecord::Base.logger
BigRecord::Embedded.logger = ActiveRecord::Base.logger

# Load in the config from the RAILS_ROOT/config folder
begin
  BigRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/bigrecord.yml"))
rescue
  puts "[Bigrecord] Couldn't load the config/bigrecord.yml config file. Please bootstrap it into your application with: script/generate bigrecord"
end

# Try establishing the connection
BigRecord::Base.establish_connection
