require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::HrAssociations do

  # Clear the tables before and after these tests
  before(:all) do
    Animal.delete_all
    Employee.delete_all
  end

  after(:all) do
    Animal.delete_all
    Employee.delete_all
  end

  it "should list associations in #reflections" do
    Animal.reflections.should have_key(:zoo)
    Animal.reflections.should have_key(:books)

    Animal.reflections[:zoo].macro.should == :belongs_to_big_record
    Animal.reflections[:books].macro.should == :belongs_to_many

    Employee.reflections.should have_key(:company)
    Employee.reflections[:company].macro.should == :belongs_to_big_record
  end

end
