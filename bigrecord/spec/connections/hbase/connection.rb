BigRecord::Base.logger.info "Connecting to Hbase data store (#{BigRecord::Base.configurations.inspect})"
BigRecord::Base.establish_connection 'hbase'
