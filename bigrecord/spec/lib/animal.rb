class Animal < BigRecord::Base

  column 'attribute:name',         'string'
  column 'attribute:type',         'integer'
  column :description,       :string

  column 'attribute:zoo_id',      'string'
  column 'attribute:book_ids',    'string', :collection => true

  belongs_to_big_record :zoo, :foreign_key => 'attribute:zoo_id'
  belongs_to_many :books, :foreign_key => 'attribute:book_ids'
end
