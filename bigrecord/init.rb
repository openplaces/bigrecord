require 'big_record'

# Use the same logger as ActiveRecord to make sure that the access to the log file is properly handled
BigRecord::Base.logger = ActiveRecord::Base.logger
BigRecord::Embedded.logger = ActiveRecord::Base.logger

# Establish the connection with the database
BigRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/bigrecord.yml"))
BigRecord::Base.establish_connection

raise "Cannot connect to the data store" unless BigRecord::Base.connection.active?
