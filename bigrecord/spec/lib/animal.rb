class Animal < BigRecord::Base

  column :name,         :string
  column :type,         :integer
  column :description,  :string

  column :zoo_id,       :string
  column :book_ids,     :string, :collection => true

  belongs_to_big_record :zoo, :foreign_key => 'attribute:zoo_id'
  belongs_to_many :books, :foreign_key => 'attribute:book_ids'


  view :brief,    :name
  view :summary,  [:name, :description, :zoo_id]
  view :full,     :name, :type, :description
end
