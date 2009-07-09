require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'adapter_shared_spec'))

describe BigRecord::ConnectionAdapters::AbstractAdapter do

  before do
    @adapter = BigRecord::ConnectionAdapters::AbstractAdapter.new("")
  end

  it_should_behave_like 'a BigRecord Adapter'

  it "should raise NotImplementedError when #update_raw is called" do
    lambda{ @adapter.update_raw(:table_name, :row, :values, :timestamp) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #update is called" do
    lambda{ @adapter.update(:table_name, :row, :values, :timestamp) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #get_raw is called" do
    lambda{ @adapter.get_raw(:table_name, :row, :column, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #get is called" do
    lambda{ @adapter.get(:table_name, :row, :column, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #get_columns_raw is called" do
    lambda{ @adapter.get_columns_raw(:table_name, :row, :columns, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #get_columns is called" do
    lambda{ @adapter.get_columns(:table_name, :row, :columns, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #delete is called" do
    lambda{ @adapter.delete(:table_name, :row) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #delete_all is called" do
    lambda{ @adapter.delete_all(:table_name) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #table_exists? is called" do
    lambda{ @adapter.table_exists?(:table_name) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #create_table is called" do
    lambda{ @adapter.create_table(:table_name, :column_families) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #drop_table is called" do
    lambda{ @adapter.drop_table(:table_name) }.should raise_error(NotImplementedError)
  end

end
