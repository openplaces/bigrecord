require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Base do

  class FlaggedDeletionBook < Book
    column :deleted, :boolean
  end

  before(:all) do
    FlaggedDeletionBook.delete_all
    @book = FlaggedDeletionBook.create(:title => "I Am Legend", :author => "Richard Matheson")
    @book.destroy
  end

  after(:all) do
    FlaggedDeletionBook.delete_all
  end

  describe "flagged deletion functionality" do

    it "should not be found by normal finders" do
      lambda {
        FlaggedDeletionBook.find(@book)
      }.should raise_error BigRecord::RecordNotFound
    end

    it "should be found using the :include_deleted option" do
      lambda {
        FlaggedDeletionBook.find(@book, :include_deleted => true)
      }.should_not raise_error
    end

  end

end
