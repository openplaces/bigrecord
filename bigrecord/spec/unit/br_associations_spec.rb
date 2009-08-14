require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::BrAssociations do

  # Clear the tables before and after these tests
  before(:all) do
    Animal.delete_all
    Employee.delete_all
    Zoo.delete_all
  end

  it "should list associations in #reflections" do
    Animal.reflections.should have_key(:zoo)
    Animal.reflections.should have_key(:books)

    Animal.reflections[:zoo].macro.should == :belongs_to_big_record
    Animal.reflections[:books].macro.should == :belongs_to_many

    Employee.reflections.should have_key(:company)
    Employee.reflections[:company].macro.should == :belongs_to_big_record

    Zoo.reflections.should have_key(:animals)
    Zoo.reflections[:animals].macro.should == :belongs_to_many
  end

  it "should mixin all the helper methods into the model for :belongs_to associations" do
    animal = Animal.new

    animal.should respond_to(:zoo)
    animal.should respond_to(:zoo=)
    animal.should respond_to(:build_zoo)
    animal.should respond_to(:create_zoo)
  end

  it "should mixin all the helper methods into the model for :belongs_to_many associations" do
    zoo = Zoo.new

    zoo.should respond_to(:animals)
    zoo.should respond_to(:animals=)
    zoo.should respond_to(:animal_ids)
    zoo.should respond_to(:animal_ids=)
    zoo.animals.should respond_to(:<<)
    zoo.animals.should respond_to(:delete)
    zoo.animals.should respond_to(:clear)
    zoo.animals.should respond_to(:empty?)
    zoo.animals.should respond_to(:size)

    p zoo.animals.proxy_reflection
  end

  it "should mixin build() and create() methods into collection assocations" do
    pending "This needs to be implemented"

    zoo = Zoo.new

    zoo.animals.should respond_to(:build)
    zoo.animals.should respond_to(:create)
  end

end
