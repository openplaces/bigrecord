require 'big_record'

# Use the same logger as ActiveRecord to make sure that the access to the log file is properly handled
BigRecord::Base.logger = ActiveRecord::Base.logger
BigRecord::Embedded.logger = ActiveRecord::Base.logger

# Load in the config from the RAILS_ROOT/config folder
begin
  BigRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/bigrecord.yml"))

  # Try establishing the connection
  BigRecord::Base.establish_connection
rescue Exception => e
  puts "[Bigrecord] Error encountered while loading the config file and establishing a connection. Please bootstrap Bigrecord into your application if you haven't done so already with: script/generate bigrecord\n" +
          e.message
end
