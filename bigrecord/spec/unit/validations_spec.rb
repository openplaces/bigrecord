require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

module EmployeeSpecHelper
  def valid_employee_attributes
    { :first_name => "John",
      :last_name => "Smith",
      :middle_name => "Jacob",
      :email => "johnsmith@email.com",
      :title => "Developer",
      :password => "abcdefg",
      :gender => "m",
      :contract => "1",
      :age => 25
    }
  end

  def ensure_error_added(model, attribute, message = nil)
    model.errors.on(attribute).should_not be_nil
    model.errors.on(attribute).should include(message) unless message.blank?
  end
end

describe BigRecord::Validations do
  include EmployeeSpecHelper

  before(:all) do
    @error_messages = BigRecord::Errors.default_error_messages.freeze
  end

  before(:each) do
    @employee = Employee.new
  end

  describe "#validates_presence_of" do

    it "should add an error to the record if it's missing required attributes" do
      @employee.attributes = valid_employee_attributes.except(:first_name, :last_name)

      @employee.valid?.should be_false

      ensure_error_added(@employee, :first_name, @error_messages[:blank])
      ensure_error_added(@employee, :last_name, @error_messages[:blank])

      @employee.first_name = valid_employee_attributes[:first_name]
      @employee.valid?.should be_false # still missing :last_name

      ensure_error_added(@employee, :last_name, @error_messages[:blank])

      @employee.last_name = valid_employee_attributes[:last_name]
      @employee.valid?.should be_true
    end

  end

  describe "#validates_uniqueness_of" do

    it "should add an error to the record if an attribute is not unique" do
      pending "this needs to be implemented"
    end

  end

  describe "#validates_length_of" do
    it "should add an error to the record if an attribute is not of appropriate length" do
      # Employee is expecting the first_name attribute to be [2, 50]
      @employee.attributes = valid_employee_attributes.except(:first_name)
      @employee.first_name = "A"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :first_name, (@error_messages[:too_short] % 2))

      @employee.first_name = "TgsCFInjEcJScTIVVICiyiKhYIJtdOezdqdLHqAPHTJCQTqyaWG" # 51 characters
      @employee.valid?.should be_false
      ensure_error_added(@employee, :first_name, (@error_messages[:too_long] % 50))

      @employee.first_name = "John"
      @employee.valid?.should be_true
    end
  end

  describe "#validates_format_of" do
    it "should add an error to the record if an attribute is not a valid format" do
      @employee.attributes = valid_employee_attributes.except(:first_name)
      @employee.first_name = "$0m3!funky*n4m3"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :first_name, @error_messages[:invalid])

      @employee.first_name = "Valid"
      @employee.valid?.should be_true
    end

    it "should not add an error is :allow_nil => true for a validation" do
      @employee.attributes = valid_employee_attributes.except(:middle_name)
      @employee.valid?.should be_true
    end
  end

  describe "#validates_inclusion_of" do

    it "should add an error to the record if an attribute is not included in a list" do
      @employee.attributes = valid_employee_attributes.except(:gender)
      @employee.gender = "alien"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :gender, @error_messages[:inclusion])

      @employee.gender = "m"
      @employee.valid?.should be_true
    end

  end

  describe "#validates_exclusion_of" do

    it "should add an error to the record if an attribute is included in a list" do
      @employee.attributes = valid_employee_attributes.except(:first_name)
      @employee.first_name = "admin"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :first_name, @error_messages[:exclusion])

      @employee.first_name = valid_employee_attributes[:first_name]
      @employee.valid?.should be_true
    end

    it "should not add an error if :allow_nil => true for a validation" do
      @employee.attributes = valid_employee_attributes.except(:middle_name)
      @employee.valid?.should be_true
    end

  end

  describe "#validates_acceptance_of" do

    it "should add an error to the record if an acceptance agreed upon" do
      @employee.attributes = valid_employee_attributes.except(:contract)
      @employee.contract = "0"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :contract, @error_messages[:accepted])

      @employee.contract = "1"
      @employee.valid?.should be_true
    end

  end

  describe "#validates_confirmation_of" do

    it "should not trigger a validation unless the virtual attribute #attr_confirmation is added" do
      @employee.attributes = valid_employee_attributes
      @employee.valid?.should be_true

      @employee.password_confirmation = ""
      @employee.valid?.should be_false

      ensure_error_added(@employee, :password, @error_messages[:confirmation])
    end

    it "should add an error to the record if a confirmation was mismatched" do
      @employee.attributes = valid_employee_attributes
      @employee.password_confirmation = "mismatched"

      @employee.valid?.should be_false
      ensure_error_added(@employee, :password, @error_messages[:confirmation])

      @employee.password_confirmation = valid_employee_attributes[:password]
      @employee.valid?.should be_true
    end

  end

  describe "#validates_numericality_of" do

    it "should add an error to the record if an attribute listed within it is not a number" do
      pending "This needs to be implemented"
    end

  end

end