require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  before(:all) do
    Book.delete_all
    @titles = ["I Am Legend", "The Beach", "Neuromancer"]
    id1 = Book.create(:title => @titles[0], :author => "Richard Matheson").id
    id2 = Book.create(:title => @titles[1], :author => "Alex Garland").id
    id3 = Book.create(:title => @titles[2], :author => "William Gibson").id
    @ids = [id1, id2, id3]
  end

  after(:all) do
    Book.delete_all
  end

  describe "scanner functionality" do

    it "should retrieve all records with find" do
      books = Book.find(:all)
      books.size.should == 3

      @titles.each do |title|
        books.map(&:title).should include(title)
      end

      @ids.each do |id|
        books.map(&:id).should include(id)
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