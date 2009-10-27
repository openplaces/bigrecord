require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'abstract_base_spec'))

describe BigRecord::Base do
  it_should_behave_like "BigRecord::AbstractBase"

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

    it "#columns_to_find should return full column names, even when alias names are passed to it" do
      options = {:columns => [:name, :type, 'attribute:description']}

      # Check that it resolves the alias to full column names
      Animal.columns_to_find(options).should == ['attribute:name', 'attribute:type', 'attribute:description']
    end
  end

  describe 'column views' do

    before(:all) do
      # Grab the columns from a simple BigRecord model
      @columns = Animal.columns
    end

    it "#view_names should return a list of view names" do
      [:brief, :summary, :full].each do |view|
        Animal.view_names.should include(view)
      end
    end

    it "#views_hash should return a list of View objects" do
      Animal.views_hash.each do |name,view|
        view.should be_a_kind_of(BigRecord::ConnectionAdapters::View)
      end
    end

    it "should return all the columns for a given view name" do
      Animal.views_hash[:brief].columns.size.should == 1
      Animal.views_hash[:summary].columns.size.should == 3
      Animal.views_hash[:full].columns.size.should == 3

      Animal.views_hash[:brief].columns.each do |column|
        ['attribute:name'].should include(column.name)
      end

      Animal.views_hash[:summary].columns.each do |column|
        ['attribute:name','attribute:description','attribute:zoo_id'].should include(column.name)
      end

      Animal.views_hash[:full].columns.each do |column|
        ['attribute:name','attribute:type','attribute:description'].should include(column.name)
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

end