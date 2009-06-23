class Animal < BigRecord::Base

  column 'attribute:name',         'string'
  column 'attribute:type',         'integer'
  column :description,       :string


  column 'attribute:zoo_id',      'string'
  belongs_to_big_record :zoo, :class_name => 'Zoo', :foreign_key => 'attribute:zoo_id'

end
