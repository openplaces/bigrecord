require File.dirname(__FILE__) + '/abstract_test_client'

class TestCassandraClient < Test::Unit::TestCase
  include AbstractTestClient

  def setup
    unless @big_db
      BigRecordDriver::DriverManager.set_cmd('cassandra')
      unless BigRecordDriver::DriverManager.running?(40005)
        BigRecordDriver::DriverManager.restart(40005)
      end
      #TODO: don't use hard coded values for the config
      @big_db = BigRecordDriver::Client.new(:drb_port => 40005)
    end
  end
  
 def test_update_without_timestamps

  end

  def test_update_with_timestamps_in_chronological_order
  end

  def test_update_with_timestamps_in_reverse_chronological_order
  end

  def test_get_and_get_columns
    t1 = Time.now.to_i
    t2 = t1 + 1000
    t3 = t2 + 1000
    # Temporary copy-paste until all tests passes
    @big_db.update(TABLE_NAME,
                    'dog-key',
                   {'columnfamily1:name' => 'Dog',
                    'columnfamily1:size' => 'medium',
                    'columnfamily2:toto' => 'some value1'},
                    t1)

    @big_db.update(TABLE_NAME,
                    'dog-key',
                   {'columnfamily1:size' => 'small',
                    'columnfamily2:toto' => 'some value2'},
                    t2)

    @big_db.update(TABLE_NAME,
                    'dog-key',
                   {'columnfamily1:size' => 'big'},
                    t3)

    # normal calls
    assert_equal 'big', @big_db.get(TABLE_NAME, 'dog-key', 'columnfamily1:size'), "Didn't retrieved the last version of the cell"
    assert_nil @big_db.get(TABLE_NAME, 'dog-key-that-does-not-exist', 'columnfamily1:size'), "Got a value for a cell that doesn't even exist"
  end

  def test_get_consecutive_rows
  end

  def test_delete
  end

  def test_invalid_column_family
  end
end
