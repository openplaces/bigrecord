# Table fields for 'books'
# - id
# - title
# - author
# - description

class Book < ActiveRecord::Base
  acts_as_solr :fields => [:title, :author]
end
