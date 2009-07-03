class Book < BigRecord::Base
  include BigIndex::Resource

  column 'attribute:title',       'string'
  column 'attribute:author',      'string'
  column 'attribute:description', 'string'

  # index :title => :string
  # index :title_partial_match => :text do |book|
  #   book.aka => 0.34
  # end
  # index :author => :string
  # index :description => :text
  # index :current_time => :text

  index :title, :type => :string, :default_boost => 3
  index :title_partial_match do |book|
    { book.title => 0.34 }
  end
  index :author, :type => :string
  index :author_partial_match do |book|
    { book.author => 0.34 }
  end
  index :description
  index :current_time


  def current_time
    Time.now.to_s
  end

end
