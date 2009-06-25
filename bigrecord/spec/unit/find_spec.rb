require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'uuidtools'

describe BigRecord::Base do

  describe "#find" do

    it "should dispatch properly to #find_every_from_bigrecord when given :first" do
      zoo = Zoo.new

      Zoo.should_receive(:find_every_from_bigrecord).with(hash_including(:limit => 1)).and_return([zoo])

      Zoo.find(:first).should == zoo
    end

    it "should dispatch properly to #find_every_from_bigrecord when given :all" do
      zoo = Zoo.new

      Zoo.should_receive(:find_every_from_bigrecord).and_return([zoo])

      Zoo.find(:all).should == [zoo]
    end

    it "should dispatch properly to #find_from_ids when given anything else" do
      zoo = Zoo.new
      id = UUID.timestamp_create.to_s

      Zoo.should_receive(:find_from_ids).with([id], an_instance_of(Hash)).and_return([zoo])

      Zoo.find(id).should == [zoo]
    end

  end

  describe "dynamic attribute-based finders" do

    it "should respond to #find_by_(attr)" do
      pending "This will need to be implemented in the BigIndex project"
      Book.should respond_to(:find_by_title)
      Book.should respond_to(:find_by_author)
    end

    it "should dispatch to #find with the proper conditions" do
      pending "This will need to be implemented in the BigIndex project"
      book = Book.new
      Book.should_receive(:find).with(:first, an_instance_of(Hash)).and_return(book)
    end

  end

end