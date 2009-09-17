# Table fields for 'books'
# - id
# - title
# - author
# - description

class Book < ActiveRecord::Base
  include BigIndex::Resource

  index :title, :string
  index :title_partial_match do |book|
    book.title
  end
  index :author, :string
  index :author_partial_match do |book|
    book.author
  end
  index :description
  index :current_time


  def current_time
    Time.now.to_s
  end

end
