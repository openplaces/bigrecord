require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::HrAssociations do

  # Clear the tables before and after these tests
  before(:all) do
    Animal.delete_all
    Zoo.delete_all
  end

  after(:all) do
    Animal.delete_all
    Zoo.delete_all
  end

  describe " #belongs_to" do

    it "should reference the appropriate model" do
      # Creating the zoo
      zoo_attributes = {:name => "Some Zoo",
                        :address => "123 Address St.",
                        :description => "This is Some Zoo located at 123 Address St."}
      zoo = Zoo.new(zoo_attributes)
      zoo.save.should be_true

      # Creating the animal
      animal = Animal.new(:name => "Stampy", :type => "Elephant")
      animal.zoo = zoo
      animal.save.should be_true

      # Now checking the association
      saved_animal = Animal.find(animal.id)
      saved_animal.zoo.should be_a_kind_of(Zoo)
      saved_animal.zoo.new_record?.should be_false
      saved_animal.zoo.name.should == zoo_attributes[:name]
      saved_animal.zoo.address.should == zoo_attributes[:address]
      saved_animal.zoo.description.should == zoo_attributes[:description]
    end

  end

end
