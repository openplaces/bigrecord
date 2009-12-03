require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  before(:all) do
    Book.delete_all
    @titles = ["I Am Legend", "The Beach", "Neuromancer"]
    Book.create(:title => @titles[0], :author => "Richard Matheson")
    Book.create(:title => @titles[1], :author => "Alex Garland")
    Book.create(:title => @titles[2], :author => "William Gibson")
  end

  after(:all) do
    Book.delete_all
  end

  describe "scanner functionality" do

    it "should retrieve all records with find" do
      books = Book.find(:all)
      books.size.should == 3
      book_titles = books.map(&:title)

      @titles.each do |title|
        book_titles.should include(title)
      end
    end

    it "should retrieve all record with scan" do
      count = 0
      Book.scan do |book|
        count += 1
        @titles.include?(book.title).should be_true
      end
      count.should == 3
    end

  end

end