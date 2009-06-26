describe "a model with BigIndex", :shared => true do

  it "should mixin index related class methods into the model" do
    @model_class.should respond_to(:indexed?)
    @model_class.indexed?.should be_true

    # Verifying the index setup methods
    @model_class.should respond_to(:index)
    @model_class.should respond_to(:rebuild_index)

    @model_class.should respond_to(:drop_solr_index)
    @model_class.should respond_to(:rebuild_solr_index)

    # Verifying that all the find methods are present
    @model_class.should respond_to(:find_with_index)
    @model_class.should respond_to(:find_every_by_solr)

    @model_class.should respond_to(:find_by_solr)
    @model_class.should respond_to(:find_id_by_solr)
    @model_class.should respond_to(:find_values_by_solr)
    @model_class.should respond_to(:multi_solr_search)
    @model_class.should respond_to(:count_by_solr)
  end

  it "should mixin index related instance methods into the model" do
    @model_class.new.should respond_to(:acting_as_solr)
    @model_class.new.should respond_to(:solr_id)
    @model_class.new.should respond_to(:solr_save)
    @model_class.new.should respond_to(:solr_destroy)
    @model_class.new.should respond_to(:solr_execute)
  end

  it "should override the default #find with the indexed version" do
    book = Book.new

    # Verify that the #find method is dispatching to the indexed version of find.
    @model_class.should_receive(:find_every_by_solr).with(hash_including(:limit => 1)).and_return([book])
    @model_class.find(:first).should == book

    @model_class.should_receive(:find_every_by_solr).and_return([book])
    @model_class.find(:all).should == [book]

    @model_class.should_receive(:find_from_ids).with(["some-id"], {}).and_return([book])
    @model_class.find("some-id").should == [book]

    # Now check that the #find method dispatches successfully to the original find method when told so.
    @model_class.should_receive(:find_without_index).and_return(book)
    @model_class.find(:first, :bypass_index => true).should == book
  end

end