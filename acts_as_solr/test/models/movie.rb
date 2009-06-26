# Table fields for 'movies'
# - id
# - name
# - description

class Movie < ActiveRecord::Base
  acts_as_solr :additional_fields => [:current_time]

  def current_time
    Time.now.to_s
  end

end