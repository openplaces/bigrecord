require File.dirname(__FILE__) + '/abstract_test_client'

class TestCassandraClient < Test::Unit::TestCase
  include AbstractTestClient

  def setup
    unless @big_db
      BigDB::DriverManager.set_cmd('cassandra')
      unless BigDB::DriverManager.running?(40005)
        BigDB::DriverManager.restart(40005)
      end
      #TODO: don't use hard coded values for the config
      @big_db = BigRecord::Client.new(:drb_port => 40005)
    end
  end


  def test_update_with_timestamps_in_chronological_order
  end

  def test_update_with_timestamps_in_reverse_chronological_order
  end

  def test_get_and_get_columns
  end

  def test_get_consecutive_rows
  end

  def test_delete
  end

  def test_invalid_column_family
  end
end
