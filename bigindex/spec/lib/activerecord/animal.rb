# Table fields for 'animals'
# - id
# - name
# - type
# - description

class Animal < ActiveRecord::Base
  include BigIndex::Resource

  index :name
  index :type,          :integer
  index :description

end
