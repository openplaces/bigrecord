require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::HrAssociations do

  it "should be renamed" do
    zoo = Zoo.create(:name => "Some Zoo")

    animal = Animal.new(:name => "Stampy", :type => "Elephant")
    animal.zoo = zoo
    animal.save.should be_true
  end

end