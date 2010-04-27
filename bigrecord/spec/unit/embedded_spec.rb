require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'attributes_spec'))

describe BigRecord::Embedded do

  # Clear the tables before and after these tests
  before(:all) do
    Zoo.delete_all
  end

  after(:all) do
    Zoo.delete_all
  end

  it_should_behave_like "BigRecord::Model"

  describe "embedded within a BigRecord::Base model" do

    it "should save successfully" do
      zoo = Zoo.new(  :name => "African Lion Safari",
                      :address => "RR #1 Cambridge, Ontario Canada\nN1R 5S2",
                      :description => "Canada's Original Safari Adventure")

      zoo.weblink = Embedded::WebLink.new(:title => "African Lion Safari - Wikipedia", :url => "http://en.wikipedia.org/wiki/African_Lion_Safari")
      zoo.save.should be_true
      zoo.reload

      zoo.weblink.should_not be_nil
      zoo.weblink.should be_a_kind_of(Embedded::WebLink)
      zoo.weblink.title.should == "African Lion Safari - Wikipedia"
      zoo.weblink.url.should == "http://en.wikipedia.org/wiki/African_Lion_Safari"

      zoo.weblink = Embedded::WebLink.new(:title => "African Lion Safari", :url => "http://www.lionsafari.com/")
      zoo.save.should be_true
      zoo.reload

      zoo.weblink.title.should == "African Lion Safari"
      zoo.weblink.url.should == "http://www.lionsafari.com/"
    end

  end

  describe "standalone behavior" do

    it "should generate the id in the constructor" do
      link = Embedded::WebLink.new
      link.attributes['id'].should_not be_nil
      link.id.should_not be_nil
    end

  end

end
