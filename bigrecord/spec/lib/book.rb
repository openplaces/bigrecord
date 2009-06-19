class Book < BigRecord::Base

  column 'attribute:title',       'string'
  column 'attribute:author',      'string'
  column 'attribute:description', 'string'

  column 'attribute:links',       'Embedded::WebLink', :alias => 'links', :collection => true
  column 'family2:',              'string', :alias => :family2
  column 'log:change',            'string', :alias => 'change_log', :collection => true

end
