class AddAnimalsTable < BigRecord::Migration

  def self.up
    create_table :animals, :force => true do |t|
      t.family :attribute, :versions => 100
    end
  end

  def self.down
    drop_table :animals
  end

end