require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Hash do

  before(:each) do
    @hash1 = { :key1 => "value1", :key2 => "value2", :key3 => "value3" }
    @hash2 = { :key1 => "value1", :key2 => "value2", :key3 => "value3", :key4 => "value4" }
  end

  it "#subset_of? should compare 2 hashes correctly" do
    @hash1.subset_of?(@hash2).should be_true
    @hash2.subset_of?(@hash1).should be_false
  end

  it "#superset_of? should compare 2 hashes correctly" do
    @hash1.subset_of?(@hash1).should be_true
    @hash1.superset_of?(@hash1).should be_true
  end

  it "#subset_of? and #superset_of? should be true when comparing the same hash" do
    @hash1.subset_of?(@hash1).should be_true
    @hash1.superset_of?(@hash1).should be_true

    @hash2.subset_of?(@hash2).should be_true
    @hash2.superset_of?(@hash2).should be_true
  end

end
