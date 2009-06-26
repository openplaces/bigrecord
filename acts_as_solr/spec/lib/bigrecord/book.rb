class Book < BigRecord::Base
  acts_as_solr :fields => [:title, :author, :description, :current_time]

  column 'attribute:title',       'string'
  column 'attribute:author',      'string'
  column 'attribute:description', 'string'

  def current_time
    Time.now.to_s
  end

end
