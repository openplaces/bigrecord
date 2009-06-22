BigRecord::Base.logger.info "Connecting to Cassandra data store (#{BigRecord::Base.configurations.inspect})"
BigRecord::Base.establish_connection 'cassandra'
