describe "a model with BigIndex", :shared => true do

  it "should mixin index related class methods into the model" do
    @model_class.should respond_to(:indexed?)
    @model_class.indexed?.should be_true

    # Verifying the index setup methods
    @model_class.should respond_to(:index)
    @model_class.should respond_to(:rebuild_index)
    @model_class.should respond_to(:process_index_batch)

    # Verifying that all the find methods are present
    @model_class.should respond_to(:find_with_index)
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