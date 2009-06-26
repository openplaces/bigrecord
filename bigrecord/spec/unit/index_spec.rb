require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'abstract_base_spec'))


describe BigRecord::Base do
  describe "indexing finds" do

    before(:each) do
      Book.truncate
      Book.rebuild_index :silent => true, :drop => true
    end

    it "should description" do
      book = Book.new(:title => "I Am Legend", :author => "Some Dude")
      book.save.should be_true
      books = Book.find(:all, :conditions => "title:\"I Am Legend\"", :source => "index")
      books.size.should == 1
      books.first.title.should == "I Am Legend"
    end
  end
end
