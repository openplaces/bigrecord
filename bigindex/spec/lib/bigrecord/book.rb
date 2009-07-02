class Book < BigRecord::Base
  include BigIndex::Resource

  column 'attribute:title',       'string'
  column 'attribute:author',      'string'
  column 'attribute:description', 'string'

  index :title => :string
  index :author => :string
  index :description => :text
  index :current_time => :text

  def current_time
    Time.now.to_s
  end

end
