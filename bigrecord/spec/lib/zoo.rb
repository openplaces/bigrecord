class Zoo < BigRecord::Base

  set_default_family :attr

  column 'attr:name',         'string'
  column 'attr:address',      'string'
  column 'attr:employees',    'integer'
  column 'attr:readonly',     'string'
  column :description,       :string
  column 'attr:weblink',      'Embedded::WebLink', :alias => "weblink"

  attr_accessible :name, :address, :description
end
