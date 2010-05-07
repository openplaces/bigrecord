require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::SimpleInvertedIndex do

  before(:all) do
    # Manually deleting all the index values
    Book.connection.delete_all(BigRecord::SimpleInvertedIndex::TABLE_NAME)
  end

  describe "initialization" do

    before(:each) do
      @simple_index = BigRecord::SimpleInvertedIndex.new("test_index", Animal.connection)
    end

    it "should have required methods" do
      @simple_index.should respond_to(:add_entry)
      @simple_index.should respond_to(:remove_entry)
      @simple_index.should respond_to(:generate_key)
      @simple_index.should respond_to(:get_results)
    end

  end

  describe "basic operations" do
    before(:each) do
      @simple_index = BigRecord::SimpleInvertedIndex.new("test_index", Animal.connection)
    end

    after(:each) do
      @simple_index.remove_entry("term1", "value1")
    end

    it "should be able to add entries and read them back" do
      @simple_index.add_entry("term1", "value1", "result2")
      @simple_index.add_entry("term1", "value1", "result1")
      @simple_index.add_entry("term1", "value1", "result4")
      @simple_index.add_entry("term1", "value1", "result3")

      results = @simple_index.get_results("term1", "value1")
      results.size.should == 4

      results[0].should == "result1"
      results[1].should == "result2"
      results[2].should == "result3"
      results[3].should == "result4"

      # try deleting specific results
      @simple_index.remove_entry("term1", "value1", "result2")

      results = @simple_index.get_results("term1", "value1")
      results.size.should == 3

      results[0].should == "result1"
      results[1].should == "result3"
      results[2].should == "result4"

      # now remove all
      @simple_index.remove_entry("term1", "value1")
      @simple_index.get_results("term1", "value1").should be_empty
    end

    it "should be able to return a subset of results" do
      @simple_index.add_entry("term1", "value1", "result1")
      @simple_index.add_entry("term1", "value1", "result2")
      @simple_index.add_entry("term1", "value1", "result3")
      @simple_index.add_entry("term1", "value1", "result4")
      @simple_index.add_entry("term1", "value1", "result5")
      @simple_index.add_entry("term1", "value1", "result6")
      @simple_index.add_entry("term1", "value1", "result7")
      @simple_index.add_entry("term1", "value1", "result8")
      @simple_index.add_entry("term1", "value1", "result9")

      results = @simple_index.get_results("term1", "value1", :offset => "result4", :count => 4)
      results.size.should == 4

      results[0].should == "result4"
      results[1].should == "result5"
      results[2].should == "result6"
      results[3].should == "result7"
    end

  end

  describe "model integration" do

    it "should add required methods and initialize the index properly" do
      Book.should respond_to(:simple_index)

      lambda {
        Book.simple_index(:title)
      }.should_not raise_error

      lambda {
        Book.simple_index(:blah)
      }.should raise_error ArgumentError

      Book.inverted_index.should be_a_kind_of(BigRecord::SimpleInvertedIndex)
      Book.inverted_index_terms.should include("title")
    end

    it "should trigger index adding on saves" do
      Book.simple_index(:title)
      Book.simple_index(:author)

      Book.should respond_to(:find_by_title)
      Book.should respond_to(:find_all_by_title)

      Book.should respond_to(:find_by_author)
      Book.should respond_to(:find_all_by_author)

      book1 = Book.new
      book1.title = "Book1"
      book1.author = "Author"
      book1.save

      indexed_book = Book.find_by_title("Book1")
      indexed_book.id.should == book1.id

      Book.find_by_title("DOES NOT EXIST").should be_nil

      book2 = Book.new
      book2.title = "Book2"
      book2.author = "Author"
      book2.save

      book3 = Book.new
      book3.title = "Book3"
      book3.author = "Author"
      book3.save

      author_books = Book.find_all_by_author("Author")
      author_books.size.should == 3
      author_books.map(&:id).should include(book1.id)
      author_books.map(&:id).should include(book2.id)
      author_books.map(&:id).should include(book3.id)

      book1.destroy

      author_books = Book.find_all_by_author("Author")
      author_books.size.should == 2
      author_books.map(&:id).should include(book2.id)
      author_books.map(&:id).should include(book3.id)

      # Manually deleting all the index values
      Book.connection.delete_all(BigRecord::SimpleInvertedIndex::TABLE_NAME)
    end

  end

end
