$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'hbase_driver'

class TestHbaseClient < Test::Unit::TestCase

  TABLE_NAME = :animals
  @@hbase = nil

  # Prepare the connection and the test tables.
  def setup
    unless @@hbase
      Hbase::DriverManager.restart(40005)
      #TODO: don't use hard coded values for the config
      @@hbase = Hbase::Client.new(:drb_port => 40005)
    end

    @@hbase.drop_table(TABLE_NAME) if @@hbase.table_exists?(TABLE_NAME)

    # Create the test table
#    unless @@hbase.table_exists?(TABLE_NAME)
      columns_descriptors = []
      columns_descriptors << Hbase::ColumnDescriptor.new(:columnfamily1)
      columns_descriptors << Hbase::ColumnDescriptor.new(:columnfamily2)
      @@hbase.create_table(TABLE_NAME, columns_descriptors)
#    end
    
#    # Delete the content of the test table
#    @@hbase.get_consecutive_rows(TABLE_NAME, nil, nil, ['columnfamily1:', 'columnfamily2:']).each do |row|
#      @@hbase.delete(TABLE_NAME, row['attribute:id'])
#    end
  end

  def test_update_without_timestamps
    ret = @@hbase.update(TABLE_NAME, 
                         'dog-key', 
                        {'columnfamily1:name' => 'Dog', 
                         'columnfamily1:size' => 'medium', 
                         'columnfamily2:toto' => 'some value'})
    
    assert_not_nil ret, "The row was not inserted properly"
    assert_equal 'Dog', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:name'), "A saved cell couldn't be retrieved"
    assert_equal 'medium', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size'), "A saved cell couldn't be retrieved"
    assert_equal 'some value', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily2:toto'), "A saved cell couldn't be retrieved"
  end
  
  def test_update_with_timestamps_in_chronological_order
    t1 = Time.now.to_i
    t2 = t1 + 1000
    t3 = t2 + 1000
  
    ret1 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:name' => 'Dog', 
                          'columnfamily1:size' => 'medium', 
                          'columnfamily2:toto' => 'some value1'},
                          t1)
    
    ret2 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:size' => 'small', 
                          'columnfamily2:toto' => 'some value2'},
                          t2)

    ret3 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:size' => 'big'},
                          t3)

    assert_not_nil ret1, "A row was not inserted properly"
    assert_not_nil ret2, "A row was not inserted properly"
    assert_not_nil ret3, "A row was not inserted properly"

    assert_equal 'Dog', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:name'), "A saved cell couldn't be retrieved"
    assert_equal 'big', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size'), "A saved cell couldn't be retrieved"
    assert_equal 'some value2', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily2:toto'), "A saved cell couldn't be retrieved"
  end

  def test_update_with_timestamps_in_reverse_chronological_order
    t1 = Time.now.to_i
    t2 = t1 - 1000
    t3 = t2 - 1000
  
    ret1 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:name' => 'Dog', 
                          'columnfamily1:size' => 'medium', 
                          'columnfamily2:toto' => 'some value1'},
                          t1)
    
    ret2 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:size' => 'small', 
                          'columnfamily2:toto' => 'some value2'},
                          t2)

    ret3 = @@hbase.update(TABLE_NAME, 
                          'dog-key', 
                         {'columnfamily1:size' => 'big'},
                          t3)

    assert_not_nil ret1, "A row was not inserted properly"
    assert_not_nil ret2, "A row was not inserted properly"
    assert_not_nil ret3, "A row was not inserted properly"

    assert_equal 'Dog', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:name'), "A saved cell couldn't be retrieved"
    assert_equal 'medium', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size'), "A saved cell couldn't be retrieved"
    assert_equal 'some value1', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily2:toto'), "A saved cell couldn't be retrieved"
  end

  def test_get_and_get_columns
    t1 = Time.now.to_i
    t2 = t1 + 1000
    t3 = t2 + 1000
  
    @@hbase.update(TABLE_NAME, 
                    'dog-key', 
                   {'columnfamily1:name' => 'Dog', 
                    'columnfamily1:size' => 'medium', 
                    'columnfamily2:toto' => 'some value1'},
                    t1)
    
    @@hbase.update(TABLE_NAME, 
                    'dog-key', 
                   {'columnfamily1:size' => 'small', 
                    'columnfamily2:toto' => 'some value2'},
                    t2)
    
    @@hbase.update(TABLE_NAME, 
                    'dog-key', 
                   {'columnfamily1:size' => 'big'},
                    t3)
    
    # normal calls
    assert_equal 'big', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size'), "Didn't retrieved the last version of the cell"
    assert_nil @@hbase.get(TABLE_NAME, 'dog-key-that-does-not-exist', 'columnfamily1:size'), "Got a value for a cell that doesn't even exist"

    # timestamps
    assert_equal 'medium', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t1), "Didn't retrieved the requested version of the cell"
    assert_equal 'small', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t2), "Didn't retrieved the requested version of the cell"
    assert_equal 'small', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t2+500), "Didn't retrieved the requested version of the cell"
    assert_equal 'big', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t3), "Didn't retrieved the requested version of the cell"
    assert_equal 'big', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t3+1000), "Didn't retrieved the last version of the cell"
    assert_nil @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :timestamp => t1-1000), "Got a value for a cell that was not even existing at that time"
    
    # num_versions
    assert_raises ArgumentError, "Specifying a number of version = 0 should be forbidden" do
      @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 0)
    end
    assert_raises ArgumentError, "Specifying a number of version < 0 should be forbidden" do
      @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => -10)
    end
    assert_instance_of String, @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 1)
    assert_instance_of Array, @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 2)
    assert_equal 2, @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 2).size
    assert_equal 3, @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 3).size
    assert_equal 3, @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10).size
    assert_equal ['big', 'small', 'medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10)
    
    # timestamps + num_versions
    assert_equal ['big', 'small', 'medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t3+1000)
    assert_equal ['big', 'small', 'medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t3)
    assert_equal ['small', 'medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t2+500)
    assert_equal ['small', 'medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t2)
    assert_equal ['medium'], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t1)
    assert_equal [], @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 10, :timestamp => t1-1000)
    assert_equal 'small', @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 1, :timestamp => t2+500)
    assert_nil @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:size', :num_versions => 1, :timestamp => t1-500)


    ###################### GET COLUMNS ######################
    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'big', 'columnfamily2:toto' => 'some value2'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:name', 'columnfamily1:size', 'columnfamily2:toto']), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily2:toto' => 'some value2'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily2:toto']), "Didn't retrieved the expected data"

    assert_nil @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily2:toto that does not exists']), "Didn't retrieved the expected data"

    assert_nil @@hbase.get_columns(TABLE_NAME, 'dog-key-akdfjlka', ['columnfamily2:toto']), "Retrieved values for a row that doesn't even exist"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'big', 'columnfamily2:toto' => 'some value2'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:', 'columnfamily2:']), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'big', 'columnfamily2:toto' => 'some value2'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:', 'columnfamily2:']), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily2:toto' => 'some value2'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:name', 'columnfamily2:']), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'big'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:']), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'small'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:'], :timestamp => t2), "Didn't retrieved the expected data"

    assert_nil @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:'], :timestamp => t1-500), "Didn't retrieved the expected data"

    expected = {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'big'}
    assert_equal expected, @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:'], :timestamp => t3+500), "Didn't retrieved the expected data"
  end
  
  def test_get_consecutive_rows
    @@hbase.update(TABLE_NAME, 
                    'dog-key', 
                   {'columnfamily1:name' => 'Dog', 
                    'columnfamily1:size' => 'medium', 
                    'columnfamily2:description' => 'lives on earth',
                    'columnfamily2:$pt-707' => '343220'})
    @@hbase.update(TABLE_NAME, 
                    'fish-key',
                   {'columnfamily1:name' => 'Fish', 
                    'columnfamily1:size' => 'varies but usually small', 
                    'columnfamily2:description' => 'must stay in water'})
    @@hbase.update(TABLE_NAME, 
                    'mouse-key',
                   {'columnfamily1:name' => 'Mouse', 
                    'columnfamily1:size' => 'small', 
                    'columnfamily2:description' => 'cats love them'})
    @@hbase.update(TABLE_NAME, 
                    'cat-key',
                   {'columnfamily1:name' => 'Cat', 
                    'columnfamily1:size' => 'small but bigger than a mouse and smaller than a dog', 
                    'columnfamily2:description' => 'likes mice'})

    # find(:all)
    expected = [{'attribute:id' => 'cat-key', 'columnfamily1:name' => 'Cat', 'columnfamily1:size' => 'small but bigger than a mouse and smaller than a dog', 'columnfamily2:description' => 'likes mice'},
                {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'medium', 'columnfamily2:description' => 'lives on earth', 'columnfamily2:$pt-707' => '343220'},
                {'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish', 'columnfamily1:size' => 'varies but usually small', 'columnfamily2:description' => 'must stay in water'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse', 'columnfamily1:size' => 'small', 'columnfamily2:description' => 'cats love them'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, nil, ['columnfamily1:', 'columnfamily2:']), "Didn't retrieved the expected data"
    
    # find(:all, :condition => ...)
    expected = [{'attribute:id' => 'cat-key', 'columnfamily1:name' => 'Cat', 'columnfamily2:description' => 'likes mice'},
                {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily2:description' => 'lives on earth', 'columnfamily2:$pt-707' => '343220'},
                {'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish', 'columnfamily2:description' => 'must stay in water'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse', 'columnfamily2:description' => 'cats love them'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, nil, ['columnfamily1:name', 'columnfamily2:']), "Didn't retrieved the expected data"

    # find(:all, :offset => before_first_row)
    expected = [{'attribute:id' => 'cat-key', 'columnfamily1:name' => 'Cat'},
                {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog'},
                {'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, 'aaa-key', nil, ['columnfamily1:name']), "Didn't retrieved the expected data"

    # find(:all, :offset => n_row)
    expected = [{'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, 'fish-key', nil, ['columnfamily1:name']), "Didn't retrieved the expected data"

    # find(:all, :limit > highest key)
    expected = [{'attribute:id' => 'cat-key', 'columnfamily1:name' => 'Cat'},
                {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog'},
                {'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, 1000, ['columnfamily1:name']), "Didn't retrieved the expected data"

    # find(:all, :limit => x)
    expected = [{'attribute:id' => 'cat-key', 'columnfamily1:name' => 'Cat'},
                {'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, 2, ['columnfamily1:name']), "Didn't retrieved the expected data"

    # find(:all, :offset => n_row, :limit => x)
    expected = [{'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish'},
                {'attribute:id' => 'mouse-key', 'columnfamily1:name' => 'Mouse'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, 'fish-key', 2, ['columnfamily1:name']), "Didn't retrieved the expected data"

    # find(:all, :offset => n_row, :limit => 1)
    expected = [{'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish'}]

    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, 'fish-key', 1, ['columnfamily1:name']), "Didn't retrieved the expected data"
  end

  def test_delete
    @@hbase.update(TABLE_NAME, 
                    'dog-key', 
                   {'columnfamily1:name' => 'Dog', 
                    'columnfamily1:size' => 'medium', 
                    'columnfamily2:description' => 'lives on earth'})
    @@hbase.update(TABLE_NAME, 
                    'fish-key',
                   {'columnfamily1:name' => 'Fish', 
                    'columnfamily1:size' => 'varies but usually small', 
                    'columnfamily2:description' => 'must stay in water'})
    
    # make sure the cells are there
    expected = [{'attribute:id' => 'dog-key', 'columnfamily1:name' => 'Dog', 'columnfamily1:size' => 'medium', 'columnfamily2:description' => 'lives on earth'},
                {'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish', 'columnfamily1:size' => 'varies but usually small', 'columnfamily2:description' => 'must stay in water'}]
    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, nil, ['columnfamily1:', 'columnfamily2:']), "The test data was not inserted properly"
    
    # actual test
    @@hbase.delete(TABLE_NAME, 'dog-key')

    expected = [{'attribute:id' => 'fish-key', 'columnfamily1:name' => 'Fish', 'columnfamily1:size' => 'varies but usually small', 'columnfamily2:description' => 'must stay in water'}]
    assert_equal expected, @@hbase.get_consecutive_rows(TABLE_NAME, nil, nil, ['columnfamily1:', 'columnfamily2:']), "The deleted data was found by a scanner"

    assert_nil @@hbase.get(TABLE_NAME, 'dog-key', 'columnfamily1:name'), "The deleted data was found by a get()"

    assert_nil @@hbase.get_columns(TABLE_NAME, 'dog-key', ['columnfamily1:']), "The deleted data was found by a get_columns()"
  end
  
  def test_ping
    hbase = nil
    assert_nothing_raised("Couldn't initialize the client") do
      hbase = Hbase::Client.new(:drb_port => 40005)
    end
    assert_not_nil hbase, "Couldn't initialize the client"
    assert hbase.ping, "The client was initialized but we cannot communicate with hbase itself"
  end
  
  def test_table_exists
    assert @@hbase.table_exists?(TABLE_NAME)
    assert !@@hbase.table_exists?(:some_non_existent_table)
  end
  
  def test_table_names
    assert @@hbase.table_names.include?(TABLE_NAME.to_s)
  end

  def test_method_missing
    assert_raises NoMethodError do
      @@hbase.akdfjlajfl
    end
  end

  def test_invalid_column_family
    assert_raises Hbase::JavaError do
      @@hbase.get(TABLE_NAME, 'dog-key', 'nonexistentcolumnfamily:name')
    end
  end
  
end
