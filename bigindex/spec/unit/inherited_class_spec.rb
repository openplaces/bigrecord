require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), "index_shared_spec"))

describe BigIndex::Resource, "inheritance on" do

  describe "base class" do
    before(:each) do
      @model_class = Book
      Book.delete_all
      Book.drop_index
    end

    it_should_behave_like "a model with BigIndex::Resource"

    it "should contain its own index fields" do
      Book.index_configuration[:fields].size.should == 6

      [:title, :title_partial_match, :author, :author_partial_match, :description, :current_time].each do |field|
        Book.index_configuration[:fields].map(&:field_name).should include(field)
      end
    end
  end

  describe "child class" do
    before(:each) do
      @model_class = Novel
      Book.delete_all
      Book.drop_index
    end

    it_should_behave_like "a model with BigIndex::Resource"

    it "should contain its own index fields and the ones from its superclass" do
      Novel.index_configuration[:fields].size.should == 7

      [:title, :title_partial_match, :author, :author_partial_match, :description, :current_time, :publisher].each do |field|
        Novel.index_configuration[:fields].map(&:field_name).should include(field)
      end
    end
  end

end