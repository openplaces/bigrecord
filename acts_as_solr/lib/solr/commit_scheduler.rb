module Solr

class CommitScheduler
  include Singleton

  attr_accessor :update_pending
  attr_accessor :updating_solr_index

end

end
