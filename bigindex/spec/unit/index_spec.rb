require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), "index_shared_spec"))

describe BigIndex::Resource do

  describe "included in a model" do
    before(:each) do
      @model_class = Book
    end

    it_should_behave_like "a model with BigIndex"
  end

end
