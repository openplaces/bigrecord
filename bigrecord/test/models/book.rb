class Book < BigRecord::Base

  column 'attribute:title',     'string'

  column 'family2:',            'string', :alias => :family2
  column 'log:change',          'string',    :alias => 'change_log', :collection => true

  def self.table_name
    'books'
  end

end
