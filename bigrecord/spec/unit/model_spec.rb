require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  it "should provide .id" do
    Book.new.should respond_to(:id)
  end

  it "should provide hash-like attribute accessors, i.e. [] and []=" do
    Book.new.should respond_to(:[])
    Book.new.should respond_to(:[]=)
  end

  it 'should provide #create' do
    Book.should respond_to(:create)
  end

  describe '#create' do

    it 'should create a new record in the data store' do
      book = Book.create(:title => "I Am Legend", :author => "Richard Matheson")

      book.should be_a_kind_of(Book)
      book.id.should_not be_nil
      book.new_record?.should be_false

      book_confirm = Book.find(book.id)

      book_confirm.title.should == "I Am Legend"
      book_confirm.author.should == "Richard Matheson"
    end

    it 'should return the unsaved object even if a record could not be created' do
      attributes = {:title => "I Am Legend", :author => "Richard Matheson"}
      book = Book.new(attributes)

      # Mocking the #create method in Base to return a specific book object we define
      Book.should_receive(:new).and_return(book)

      # When #save is called on our book object, it'll return false.
      book.should_receive(:save).and_return(false)

      # Now we'll try the #create method on the Book class
      created_book = Book.create(attributes)

      # The save shouldn't have succeeded
      created_book.new_record?.should be_true

      # But we should still receive a book object that's the same
      created_book.should == book
    end

  end

  # Protected instance method called by #save (different than Class#create)
  it 'should provide .create' do
    Book.new.should respond_to(:create)
  end

  # Protected instance method called by #save
  it 'should provide .update' do
    Book.new.should respond_to(:update)
  end

  it 'should provide .save and .save!' do
    Book.new.should respond_to(:save)
    Book.new.should respond_to(:save!)
  end

  describe '.save and .save!' do

    describe 'with a new resource' do

      it 'should create new entries in the data store' do
        # Create a new object
        book = Book.new(  :title => "I Am Legend",
                          :author => "Richard Matheson",
                          :description => "The most clever and riveting vampire novel since Dracula.")

        book.new_record?.should be_true
        book.id.should be_nil
        book.save.should be_true

        book.new_record?.should be_false
        book.id.should_not be_nil

        # Verify that the object was saved
        book2 = Book.find(book.id)

        book2.title.should == "I Am Legend"
        book2.author.should == "Richard Matheson"
        book2.description.should == "The most clever and riveting vampire novel since Dracula."
      end

      it 'should raise an exception with .save! if a record was not saved or true if successful' do
        book = Book.new(  :title => "I Am Legend",
                          :author => "Richard Matheson",
                          :description => "The most clever and riveting vampire novel since Dracula.")

        # The actual method that's called just before the data store write is #update_big_record, which returns
        # a boolean. We're going to mock this method and have it return false.
        book.should_receive(:update_big_record).and_return(false)

        # Verify that an exception is raised
        lambda { book.save! }.should raise_error(BigRecord::RecordNotSaved)

        # Verify that true gets returned on success
        book.should_receive(:update_big_record).and_return(true)
        book.save.should be_true
      end

    end

    describe 'with an existing record' do

      before(:each) do
        # Just want to verify that the book is created properly everytime
        new_book = Book.new(  :title => "I Am Legend",
                              :author => "Richard Matheson",
                              :description => "The most clever and riveting vampire novel since Dracula.")

        new_book.save.should be_true

        # Maybe a little paranoid...
        new_book.new_record?.should be_false
        new_book.id.should_not be_nil

        # Grab the entry from the data store and verify
        @book = Book.find(new_book)
        @book.title.should == "I Am Legend"
        @book.author.should == "Richard Matheson"
        @book.description.should == "The most clever and riveting vampire novel since Dracula."
      end

      it 'should update that record' do
        @book.description = "One of the Ten All-Time Best Novels of Vampirism."
        @book.save.should be_true

        book_verify = Book.find(@book)
        book_verify.description.should == "One of the Ten All-Time Best Novels of Vampirism."
        book_verify.id.should == @book.id
      end

    end

  end

  describe 'modified attribute tracking' do

    it "should not mark attributes as modified if they are similar" do
      pending "attribute tracking needs to be implemented in BigRecord::Base"

      attributes =  {   :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula." }

      book = Book.new(attributes)
      book.save.should be_true

      book.attributes = attributes

      book.modified_attributes.should be_empty
    end

    it "should track modified attributes" do
      pending "attribute tracking needs to be implemented in BigRecord::Base"

      attributes =  {   :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula." }

      book = Book.new(attributes)
      book.save.should be_true

      book.attributes = {:description => "One of the Ten All-Time Best Novels of Vampirism."}

      book.modified_attributes.has_key?(:description).should be_true
    end

  end

  describe 'attribute functionality' do

    it "should return a list of attribute names with .attribute_names" do
      (Book.new.attribute_names & ["attribute:author", "attribute:description", "attribute:links", "attribute:title"]).should == ["attribute:author", "attribute:description", "attribute:links", "attribute:title"]
    end

    it "should provide hash-like attribute accessors, i.e. [] and []=" do
      Book.new.should respond_to(:[])
      Book.new.should respond_to(:[]=)
    end

    it "should provide attribute accessing with .read_attribute" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")

      book.save.should be_true

      book.read_attribute("attribute:title").should == "I Am Legend"
      book.read_attribute("attribute:author").should == "Richard Matheson"
      book.read_attribute("attribute:description").should == "The most clever and riveting vampire novel since Dracula."
    end

    it "should determine whether an attribute is present with .has_attribute?" do
      book = Book.new

      ["attribute:author", "attribute:description", "attribute:links", "attribute:title"].each do |attr|
        book.has_attribute?(attr).should be_true
      end
    end

    it "should determine whether an attribute is present (i.e. set either by the user or db) with .attribute_present?" do
      book = Book.new

      # Initially they should all be false
      ["attribute:author", "attribute:description", "attribute:title"].each do |attr|
        book.attribute_present?(attr).should be_false
      end

      book.attributes = { :title => "I Am Legend", :author => "Richard Matheson", :description => "The most clever and riveting vampire novel since Dracula." }

      ["attribute:author", "attribute:description", "attribute:title"].each do |attr|
        book.attribute_present?(attr).should be_true
      end
    end

    it '.update_attribute(nil) should raise an exception' do
      lambda {
        Book.new.update_attribute(nil)
      }.should raise_error(ArgumentError)
    end

    it ".update_attribute should update a single attribute of a record" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")

      book.new_record?.should be_true
      book.id.should be_nil
      book.save.should be_true

      book.update_attribute(:description, "One of the Ten All-Time Best Novels of Vampirism.")

      book.description.should == "One of the Ten All-Time Best Novels of Vampirism."
    end

    it ".update_attribute should return false if the attribute could not be updated" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")

      book.new_record?.should be_true
      book.id.should be_nil
      book.save.should be_true

      book.should_receive(:save).and_return(false)
      book.update_attribute(:description, "One of the Ten All-Time Best Novels of Vampirism.").should be_false
    end

    describe '' do

      before(:each) do
        @book = Book.new( :title => "I Am Legend",
                          :author => "Richard Matheson",
                          :description => "The most clever and riveting vampire novel since Dracula.")

        @book.new_record?.should be_true
        @book.id.should be_nil
        @book.save.should be_true

        @new_attributes = {:title => "A Stir of Echoes", :description => "One of the most important writers of the twentieth century."}
      end

      it ".update_attributes should update all attributes of a record" do
        @book.update_attributes(@new_attributes).should be_true

        @new_attributes.each do |key, value|
          @book.send(key).should == value
        end
      end

      it ".update_attributes should return false if the record couldn't be updated with those attributes" do
        @book.should_receive(:save).and_return(false)
        @book.update_attributes(@new_attributes).should be_false
      end

      it ".update_attributes! should update all attributes of a record" do
        @book.update_attributes(@new_attributes).should be_true

        @new_attributes.each do |key, value|
          @book.send(key).should == value
        end
      end

      it ".update_attributes! should raise an error when the record couldn't be updated" do
        @book.should_receive(:save!).and_raise(BigRecord::RecordNotSaved)

        lambda { @book.update_attributes!(@new_attributes) }.should raise_error(BigRecord::RecordNotSaved)
      end

    end

  end

end