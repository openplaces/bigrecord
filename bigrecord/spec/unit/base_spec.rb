require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

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

  describe '#attributes' do

    before(:each) do
      @book = Book.new
    end

    it 'should have getter and setter methods for the attributes from alias names' do
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

    it 'should return a hash of attribute-names and values' do
      # Set some attributes, and verify that they get stored in the model
      @book.title = "The Beach"
      @book.author = "Alex Garland"
      @book.description = "A furiously intelligent first novel."

      @book.attributes.sort.should == {"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"The Beach", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}.sort
    end

    it "should return a hash with all nil or empty list values if the instance is new and has no default values" do
      @book.attributes.sort.should == {"log:change"=>[], "attribute:description"=>nil, "attribute:title"=>nil, "attribute:links"=>[], "attribute:author"=>nil}.sort
    end

  end

  describe "#attributes=" do

    it 'should be able to mass assign attributes' do
      # Check that the mass asssignment of attributes works with #new
      @book = Book.new( :title => "The Beach",
                        :author => "Alex Garland",
                        :description => "A furiously intelligent first novel.")

      @book.attributes.sort.should == {"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"The Beach", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}.sort

      # Check that it works with the #attributes= method
      @book.attributes = {:title => "28 Days Later"}

      @book.attributes.sort.should == {"log:change"=>[], "attribute:description"=>"A furiously intelligent first novel.", "attribute:title"=>"28 Days Later", "attribute:links"=>[], "attribute:author"=>"Alex Garland"}.sort
    end

    it 'should handle protected attributes properly' do
      # Employees is a protected attribute here, so it shouldn't be saved.
      @company = Company.new(:name => "The Company", :address => "Unknown", :employees => 18000, :readonly => "secret")

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # Check it against the attributes= method
      @company.attributes = {:employees => 18000}

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # Now check that we can access it with the employees= method
      @company.employees = 18000

      @company.attributes.sort.should == {"attribute:employees"=>18000, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort
    end

    it 'should handle accessible attributes properly' do
    end

    it 'should handle create_accessible attributes properly' do
      # Name is the create_accessible attribute here
      @company = Company.new(:name => "Another Company", :address => "Unknown")

      # It should've been set successfully since this is a new record
      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"Another Company"}.sort

      # It should still also be accessible with the attributes= method
      @company.attributes = {:name => "The Company"}

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # Now when we save it, it should no longer be accessible with mass assignment
      @company.save.should be_true

      @company.attributes = {:name => "Another Company"}

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # But it should still be accessible with the explicit setter
      @company.name = "Another Company"

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>nil, "log:change"=>[], "attribute:name"=>"Another Company"}.sort
    end

    it 'should handle readonly attributes properly' do
      # readonly is the readonly attribute here
      @company = Company.new(:name => "The Company", :address => "Unknown", :readonly => "secret")

      # It should've been set successfully since this is a new record
      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # It should still also be accessible with the attributes= method
      @company.attributes = {:readonly => "another secret"}

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # Now when we save it, it should no longer be accessible with mass assignment
      @company.save.should be_true

      @company.attributes = {:readonly => "compromised secret"}

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"The Company"}.sort

      # And it should still not be accessible with the explicit setter
      @company.readonly = "compromised secret"

      @company.attributes.sort.should == {"attribute:employees"=>nil, "attribute:address"=>"Unknown", "attribute:readonly"=>"another secret", "log:change"=>[], "attribute:name"=>"Another Company"}.sort
    end

  end


  describe '#save' do

    describe 'with a new resource' do
      it 'should set defaults before create'
      it 'should create when dirty'
      it 'should create when non-dirty, and it has a serial key'
    end

    describe 'with an existing resource' do
      it 'should update'
    end

  end

end