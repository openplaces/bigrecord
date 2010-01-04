require File.dirname(__FILE__) + '/abstract_test_client'

PORT = (ARGV[0] || 40000).to_i

class TestHbaseClient < Test::Unit::TestCase
  include AbstractTestClient

  def setup
    @big_db = BigRecord::Driver::Client.new({:zookeeper_quorum=> 'localhost', :zookeeper_client_port => '2181', :drb_port => PORT}) unless @big_db

    @big_db.drop_table(TABLE_NAME) if @big_db.table_exists?(TABLE_NAME)

    columns_descriptors = []
    columns_descriptors << BigRecord::Driver::ColumnDescriptor.new(:columnfamily1)
    columns_descriptors << BigRecord::Driver::ColumnDescriptor.new(:columnfamily2)
    @big_db.create_table(TABLE_NAME, columns_descriptors)
  end

  def teardown
    @big_db.drop_table(TABLE_NAME) if @big_db.table_exists?(TABLE_NAME)
  end
end
