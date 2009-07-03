class Animal < BigRecord::Base
  include BigIndex::Resource

  column :name,         :string
  column :type,         :integer
  column :description,  :string

  index :name
  index :description

end
