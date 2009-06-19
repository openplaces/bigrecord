class Zoo < BigRecord::Base

  self.default_family = "attr"

  column 'attr:name',         'string'
  column 'attr:address',      'string'
  column 'attr:employees',    'integer'
  column 'attr:readonly',     'string'
  column :description,       'string'
  column 'list:',             'Embedded::WebLink'

  column 'log:change',            'string', :alias => 'change_log', :collection => true

  attr_accessible :name, :address, :description

end
