class Zoo < BigRecord::Base

  set_default_family :attr

  column 'attr:name',         'string'
  column 'attr:address',      'string'
  column 'attr:employees',    'integer'
  column 'attr:readonly',     'string'
  column :description,        :string
  column 'attr:weblink',      'Embedded::WebLink', :alias => "weblink"
  column 'attr:animal_ids',   :string,  :collection => true


  attr_accessible :name, :address, :description

  belongs_to_many :animals, :foreign_key => 'attr:animal_ids'
end
