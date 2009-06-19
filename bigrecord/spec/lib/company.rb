class Company < BigRecord::Base

  column 'attribute:name',        'string'
  column 'attribute:address',     'string'
  column 'attribute:employees',   'integer'
  column 'attribute:readonly',    'string'

  column 'log:change',            'string', :alias => 'change_log', :collection => true

  # attr_create_accessible :name
  # attr_protected :employees
  # attr_readonly :readonly

end
