require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::BrAssociations do

  # Clear the tables before and after these tests
  before(:each) do
    Animal.delete_all
    Zoo.delete_all
  end

  after(:each) do
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
      saved_animal.reload # ensure that it's not cached
      saved_animal.zoo.should be_a_kind_of(Zoo)
      saved_animal.zoo.new_record?.should be_false
      saved_animal.zoo.name.should == zoo_attributes[:name]
      saved_animal.zoo.address.should == zoo_attributes[:address]
      saved_animal.zoo.description.should == zoo_attributes[:description]
    end

  end

  describe " #belongs_to_many" do

    it "should reference the appropriate list of models" do
      # Creating the zoo
      zoo_attributes = {:name => "Some Zoo",
                        :address => "123 Address St.",
                        :description => "This is Some Zoo located at 123 Address St."}
      zoo = Zoo.new(zoo_attributes)
      zoo.save.should be_true

      # Creating the animals
      animal1 = Animal.new(:name => "Stampy", :type => "Elephant")
      animal1.zoo = zoo
      animal1.save.should be_true

      animal2 = Animal.new(:name => "Dumbo", :type => "Elephant")
      animal2.zoo = zoo
      animal2.save.should be_true

      # Associating the animals to the zoo
      zoo.animals << animal1
      zoo.animals << animal2
      zoo.save.should be_true

      # Now we'll retrieve the Zoo record and check the association
      saved_zoo = Zoo.find(zoo.id)
      saved_zoo.reload
      saved_zoo.animals.should be_a_kind_of(Array)

      saved_zoo["attr:animal_ids"].should == saved_zoo.animal_ids
      saved_zoo.animal_ids.should include(animal1.id)
      saved_zoo.animal_ids.should include(animal2.id)
      saved_zoo.animals.each{|animal| animal.should be_a_kind_of(Animal)}
    end

  end

end
