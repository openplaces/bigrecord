require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# Not exactly the most comprehensive testing for this function.
describe Hash do

  before(:each) do
    @hash1 = { :key1 => "value1", :key2 => "value2", :key3 => "value3" }
    @hash2 = { :key1 => "value1", :key2 => "value2", :key3 => "value3", :key4 => "value4" }
    @hash3 = { :key1 => "value4", :key2 => "value3", :key3 => "value1", :key4 => "value2" }
    @hash4 = { :key2 => "value2", :key3 => "value3" }
  end

  it "#subset_of? should compare 2 hashes correctly (when one really is a subset of the other)" do
    @hash1.subset_of?(@hash2).should be_true
    @hash2.subset_of?(@hash1).should be_false
  end

  it "#superset_of? should compare 2 hashes correctly (when one really is a superset of the other)" do
    @hash1.superset_of?(@hash2).should be_false
    @hash2.superset_of?(@hash1).should be_true
  end

  it "#subset_of? and #superset_of? should be true when comparing the same hash to itself" do
    @hash1.subset_of?(@hash1).should be_true
    @hash1.superset_of?(@hash1).should be_true

    @hash2.subset_of?(@hash2).should be_true
    @hash2.superset_of?(@hash2).should be_true
  end

  it "should return false when there's a mismatch of key/value pairs" do
    @hash2.subset_of?(@hash3).should be_false
    @hash2.superset_of?(@hash3).should be_false
  end

  it "should compare properly with missing keys in one of the hashes (even if all the other pairs match)" do
    # false because @hash4 is missing :key1
    @hash1.subset_of?(@hash4).should be_false

    # it is a superset because all of the key/value pairs of @hash4 are contained within @hash1
    @hash1.superset_of?(@hash4).should be_true
  end

end
