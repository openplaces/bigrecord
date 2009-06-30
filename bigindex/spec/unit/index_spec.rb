require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), "index_shared_spec"))

describe BigIndex::Resource do

  describe "included in a model" do
    before(:each) do
      @model_class = Book
    end

    it_should_behave_like "a model with BigIndex::Resource"

    it "should choose the proper fields in the model to index" do
      expected = [  {:name => :string},
                    {:author => :string},
                    {:description => :text} ]

      expected.each do |h|
        Book.index_views_hash[:default].should include(h)
      end
    end

  end

end
