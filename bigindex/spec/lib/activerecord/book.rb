# Table fields for 'books'
# - id
# - title
# - author
# - description

class Book < ActiveRecord::Base
  include BigIndex::Resource

  index :title, :type => :string
  index :title_partial_match do |book|
    book.title
  end
  index :author, :type => :string
  index :author_partial_match do |book|
    book.author
  end
  index :description

end
