require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  it "should provide #primary_key" do
    Book.should respond_to(:primary_key)
  end

  describe '#columns' do

    before(:all) do
      # Grab the columns from a simple BigRecord model
      @columns = Book.columns
    end

    it 'should return a hash of Column objects describing the columns in the model' do
      # Verify that each entry is a Column object
      @columns.each do |column|
        column.should be_a_kind_of(BigRecord::ConnectionAdapters::Column)
      end

      # Map the names of each of the columns
      column_names = @columns.map{ |column| column.name }

      # Verify that each attribute we defined in the Book model is present
      expected_names = %w( attribute:title attribute:author attribute:description family2: log:change )
      (column_names & expected_names).sort.should == expected_names.sort
    end

    it 'should save a default alias name for each column (e.g. attribute:name become alias name automatically)' do
      lookup = {  'attribute:id' => 'id',
                  'attribute:title' => 'title',
                  'attribute:author' => 'author',
                  'attribute:description' => 'description'}

      # Go through each column and if an attribute name is found that matches the lookup table above,
      # verify that the alias name it creates is the one we expect.
      @columns.each do |column|
        if lookup.has_key?(column.name)
          column.alias.should == lookup[column.name]
        end
      end
    end

  end

  describe 'column families' do

    it 'should respond to #default_family with a default value, or with the value defined in the model' do
      Book.should respond_to(:default_family)
      Book.default_family.should == "attribute"

      Zoo.should respond_to(:default_family)
      Zoo.default_family.should == "attr"
    end

    it 'should automatically append the #default_family to columns without one defined' do
      Zoo.columns.map{|column| column.name}.should include("attr:description")
      Zoo.new.should respond_to(:description)
      Zoo.new.should respond_to(:description=)
    end

  end

  describe '#attributes' do

    before(:each) do
      @book = Book.new
    end

    it 'should have getter and setter methods for the attributes from the alias of their names' do
      # Check that the getters are responding
      @book.should respond_to(:title)
      @book.should respond_to(:author)
      @book.should respond_to(:description)

      # Check that the setters are responding
      @book.should respond_to(:title=)
      @book.should respond_to(:author=)
      @book.should respond_to(:description=)

      # Now we use the setters
      @book.title = "The Beach"
      @book.author = "Alex Garland"
      @book.description = "A furiously intelligent first novel." # this was written on the cover

      # And we check that the getters are working
      @book.title.should == "The Beach"
      @book.author.should == "Alex Garland"
      @book.description.should == "A furiously intelligent first novel."
    end

    it 'should provide a list of modified attributes with #modified_attributes' do
      book = Book.new(  :title => "The Beach",
                        :author => "Alex Garland",
                        :description => "A furiously intelligent first novel.")

      book.modified_attributes.each_pair do |key, value|
        %w( title author description ).include?(key.to_s).should be_true
      end
    end

    it 'should return a hash of attribute-names and values' do
      # Set some attributes, and verify that they get stored in the model
      @book.title = "The Beach"
      @book.author = "Alex Garland"
      @book.description = "A furiously intelligent first novel."

      expected_hash = {"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"The Beach", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}

      @book.attributes.superset_of?(expected_hash).should be_true
    end

    it "should return a hash with all nil or empty list values if the instance is new and has no default values" do
      @book.attributes.superset_of?({"log:change"=>[], "attribute:description"=>nil, "attribute:title"=>nil, "attribute:links"=>[], "attribute:author"=>nil}).should be_true
    end

  end

  describe "#attributes=" do

    it 'should be able to mass assign attributes' do
      # Check that the mass asssignment of attributes works with #new
      @book = Book.new( :title => "The Beach",
                        :author => "Alex Garland",
                        :description => "A furiously intelligent first novel.")

      @book.attributes.superset_of?({"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"The Beach", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}).should be_true

      # Check that it works with the #attributes= method
      @book.attributes = {:title => "28 Days Later"}

      @book.attributes.superset_of?({"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"28 Days Later", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}).should be_true
    end

  end

  describe "protected attributes" do

    it 'should respond to the method #protected_attributes' do
      Company.should respond_to(:protected_attributes)
    end

    it 'should list #protected_attributes' do
      Company.protected_attributes.should be_a_kind_of(Set)
      Company.protected_attributes.should include("employees")
    end

    it 'should be handled properly' do
      # Employees is a protected attribute here, so it shouldn't be saved.
      @company = Company.new(:name => "The Company", :address => "Unknown", :employees => 18000, :readonly => "secret")

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # Check it against the attributes= method
      @company.attributes = {:employees => 18000}

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # Now check that we can access it with the employees= method
      @company.employees = 18000

      @company.attributes.superset_of?({"attribute:employees"=>18000, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true
    end

  end

  describe "accessible attributes" do

    it 'should respond to the method #accessible_attributes' do
      Zoo.should respond_to(:accessible_attributes)
      Zoo.accessible_attributes.should_not be_empty
    end

    it 'should list #accessible_attributes' do
      Zoo.accessible_attributes.should be_a_kind_of(Set)
      Zoo.accessible_attributes.should include("address")
      Zoo.accessible_attributes.should include("description")
    end

    it 'should be handled properly' do
      # name, address, and description are accessible attributes here
      attributes_hash = {   :name => "San Francisco",
                            :address => "Some Address",
                            :description => "This is a pretty awesome zoo",
                            :employees => 10000,
                            :readonly => "should not work" }

      zoo = Zoo.new(attributes_hash)

      zoo.attributes.superset_of?({"attr:readonly"=>nil, "attr:address"=>"Some Address", "attr:description"=>"This is a pretty awesome zoo", "attr:employees"=>nil, "attr:name"=>"San Francisco"}).should be_true

      zoo.attributes = {:address => "1 Zoo Rd", :description => "Awesome address", :employees => 1000}

      zoo.attributes.superset_of?({"attr:readonly"=>nil, "attr:address"=>"1 Zoo Rd", "attr:description"=>"Awesome address", "attr:employees"=>nil, "attr:name"=>"San Francisco"}).should be_true

      zoo.employees = 1000

      zoo.attributes.superset_of?({"attr:readonly"=>nil, "attr:address"=>"1 Zoo Rd", "attr:description"=>"Awesome address", "attr:employees"=>1000, "attr:name"=>"San Francisco"})
    end

  end

  describe "readonly attributes" do

    it 'should respond to the method #readonly_attributes' do
      Company.should respond_to(:readonly_attributes)
    end

    it 'should list #readonly_attributes' do
      Company.readonly_attributes.should be_a_kind_of(Set)
      Company.readonly_attributes.should include("readonly")
    end

    it 'should be handled properly' do
      pending "this still needs to be implemented in BigRecord::Base"

      # readonly is the readonly attribute here
      @company = Company.new(:name => "The Company", :address => "Unknown", :readonly => "secret")

      # It should've been set successfully since this is a new record
      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # It should still also be accessible with the attributes= method
      @company.attributes = {:readonly => "another secret"}

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # Now when we save it, it should no longer be accessible with mass assignment

      # Mock new_record? so it's essentially acting like it was saved.
      @company.stub!(:new_record?).and_return(false)

      @company.attributes = {:readonly => "compromised secret"}

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # And it should still not be accessible with the explicit setter
      @company.readonly = "compromised secret"

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"Another Company"}).should be_true
    end

  end

  describe "create_accessible attributes" do

    it 'should respond to the method #create_accessible_attributes' do
      Company.should respond_to(:create_accessible_attributes)
    end

    it 'should list #create_accessible_attributes' do
      Company.create_accessible_attributes.should be_a_kind_of(Set)
      Company.create_accessible_attributes.should include("name")
    end

    it 'should be handled properly' do
      # Name is the create_accessible attribute here
      @company = Company.new(:name => "Another Company", :address => "Unknown")

      # It should've been set successfully since this is a new record
      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"Another Company"}).should be_true

      # It should still also be accessible with the attributes= method
      @company.attributes = {:name => "The Company"}

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # Now when we save it, it should no longer be accessible with mass assignment

      # Mock new_record? so it's essentially acting like it was saved.
      @company.stub!(:new_record?).and_return(false)

      @company.attributes = {:name => "Another Company"}

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"The Company"}).should be_true

      # But it should still be accessible with the explicit setter
      @company.name = "Another Company"

      @company.attributes.superset_of?({"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"Another Company"}).should be_true
    end

  end

end
