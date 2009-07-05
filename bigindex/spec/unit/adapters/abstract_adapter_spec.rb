require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'adapter_shared_spec'))

describe BigIndex::Adapters::AbstractAdapter do

  before do
    @adapter = BigIndex::Adapters::AbstractAdapter.new("test", {})
  end

  it_should_behave_like "a BigIndex Adapter"

  it "should return the right #adapter_name" do
    @adapter.adapter_name.should == 'abstract'
  end

  it "should raise NotImplementedError when #process_index_batch is called" do
    lambda{ @adapter.process_index_batch(:items, :loop, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #drop_index is called" do
    lambda{ @adapter.drop_index(:model) }.should raise_error(NotImplementedError)
  end

  it "should return the argument when #get_field_type is called" do
    @adapter.get_field_type(:field_type).should == :field_type
  end

  it "should raise NotImplementedError when #index_save is called" do
    lambda{ @adapter.index_save(:model) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #index_destroy is called" do
    lambda{ @adapter.index_destroy(:model) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #find_values_by_index is called" do
    lambda{ @adapter.find_values_by_index(:query, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #find_by_index is called" do
    lambda{ @adapter.find_by_index(:query, :options) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #find_ids_by_index is called" do
    lambda{ @adapter.find_ids_by_index(:query, :options) }.should raise_error(NotImplementedError)
  end

end