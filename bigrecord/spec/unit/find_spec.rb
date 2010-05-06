require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  describe "#find" do

    it "should dispatch properly to #find_every when given :first" do
      zoo = Zoo.new

      Zoo.should_receive(:find_every).with(hash_including(:limit => 1)).and_return([zoo])

      Zoo.find(:first).should == zoo
    end

    it "should dispatch properly to #find_every when given :all" do
      zoo = Zoo.new

      Zoo.should_receive(:find_every).and_return([zoo])

      Zoo.find(:all).should == [zoo]
    end

    it "should dispatch properly to #find_from_ids when given anything else" do
      zoo = Zoo.new
      id = "c6e2cf62-332d-44f0-a558-dfdfe2c7ee1e"

      Zoo.should_receive(:find_from_ids).with([id], an_instance_of(Hash)).and_return([zoo])

      Zoo.find(id).should == [zoo]
    end

    describe "limit option" do

      before(:all) do
        Book.create(:title => "I Am Legend", :author => "Richard Matheson")
        Book.create(:title => "The Beach", :author => "Alex Garland")
        Book.create(:title => "Neuromancer", :author => "William Gibson")
        Book.create(:title => "World War Z", :author => "Max Brooks")
        Book.create(:title => "The Zombie Survival Guide", :author => "Max Brooks")
      end

      after(:all) do
        Book.delete_all
      end

      it "should limit the result set properly" do
        results = Book.find(:all)
        results.size.should == 5

        Book.find(:all, :limit => 3).map(&:title).should == results.slice(0..2).map(&:title)
      end

    end

  end

end
