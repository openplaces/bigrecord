ENV['RAILS_ENV']  = (ENV['RAILS_ENV'] || 'development').dup 
SOLR_PATH = "#{File.dirname(File.expand_path(__FILE__))}/../../../../solr_home" unless defined? SOLR_PATH

unless defined? SOLR_PORT
  SOLR_PORT = ENV['PORT'] || case ENV['RAILS_ENV']
              when 'test' then 8981
              when 'test_java' then 8986
              when 'preprod' then 8984
              when 'production' then 8983
              when 'productionB' then 8989
              when 'migration' then 8985
              when 'factory' then 8987
              when 'functional' then 8988
              else 8982
              end
end

if ENV['RAILS_ENV'] == 'test'
  DB = (ENV['DB'] ? ENV['DB'] : 'mysql') unless defined? DB
  MYSQL_USER = (ENV['MYSQL_USER'].nil? ? 'root' : ENV['MYSQL_USER']) unless defined? MYSQL_USER
  require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'test', 'db', 'connections', DB, 'connection.rb')
end
