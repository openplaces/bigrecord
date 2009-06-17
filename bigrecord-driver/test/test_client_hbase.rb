require File.dirname(__FILE__) + '/abstract_test_client'

class TestHbaseClient < Test::Unit::TestCase #TestClient
  include AbstractTestClient
  # Prepare the connection and the test tables.
  def setup
    unless @big_db
      unless BigDB::DriverManager.running?(40005)
        BigDB::DriverManager.restart(40005)
      end
      #TODO: don't use hard coded values for the config
      @big_db = BigRecord::Client.new(:master => 'localhost:60000',:drb_port => 40005)
    end

    @big_db.drop_table(TABLE_NAME) if @big_db.table_exists?(TABLE_NAME)

    # Create the test table
#    unless @big_db.table_exists?(TABLE_NAME)
      columns_descriptors = []
      columns_descriptors << BigDB::ColumnDescriptor.new(:columnfamily1)
      columns_descriptors << BigDB::ColumnDescriptor.new(:columnfamily2)
      @big_db.create_table(TABLE_NAME, columns_descriptors)
#    end
  end
end
