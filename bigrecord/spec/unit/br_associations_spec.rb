require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::HrAssociations do

  it "should list associations with #reflections" do
    Animal.reflections.should have_key(:zoo)
  end

  it "should be renamed" do
    pending "use this as an integration spec"
    zoo = Zoo.create(:name => "Some Zoo")

    animal = Animal.new(:name => "Stampy", :type => "Elephant")
    animal.zoo = zoo
    animal.save.should be_true
  end

end
