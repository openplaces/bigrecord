describe "a model with BigIndex::Resource", :shared => true do

  it "should mixin index related class methods into the model" do
    @model_class.should respond_to(:indexed?)
    @model_class.indexed?.should be_true

    # Verifying the configuration related methods
    @model_class.should respond_to(:index_configuration)
    @model_class.should respond_to(:index_configuration=)

    # Verifying the index setup methods
    @model_class.should respond_to(:add_index_field)
    @model_class.should respond_to(:index)
    @model_class.should respond_to(:rebuild_index)

    # Verifying that the index view and name related methods are present
    @model_class.should respond_to(:index_view)
    @model_class.should respond_to(:index_views)
    @model_class.should respond_to(:index_view_names)
    @model_class.should respond_to(:index_views_hash)
    @model_class.should respond_to(:default_index_views_hash)

    # Verifying that all the find methods are present
    @model_class.should respond_to(:find_with_index)
    @model_class.should respond_to(:find_without_index)
    @model_class.should respond_to(:find_every_by_index)
  end

  it "should mixin index related instance methods into the model" do
    @model_class.new.should respond_to(:indexed?)
    @model_class.new.indexed?.should be_true
  end

  it "should override the default #find with the indexed version" do
    record = @model_class.new

    # Check that the #find method dispatches successfully to the original find method when told so.
    @model_class.should_receive(:find_without_index).and_return(record)
    @model_class.find(:first, :bypass_index => true).should == record

    @model_class.should_receive(:find_without_index).and_return([record])
    @model_class.find(:all, :bypass_index => true).should == [record]

    @model_class.should_receive(:find_without_index).and_return([record])
    @model_class.find("some-id", :bypass_index => true).should == [record]

    # Verify that the #find method is dispatching to the indexed version of find.
    @model_class.should_not_receive(:find_without_index)

    @model_class.find(:first).should be_nil

    @model_class.find(:all).should eql([])

    lambda{
      @model_class.find("some-id")
    }.should raise_error
  end

end