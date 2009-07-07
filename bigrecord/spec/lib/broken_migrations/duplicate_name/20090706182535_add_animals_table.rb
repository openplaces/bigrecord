class AddAnimalsTable < BigRecord::Migration

  def self.up
    create_table :animals do |t|
      t.family :attribute, :versions => 5
      t.family :log, :versions => 100
    end
  end

  def self.down
    drop_table :animals
  end

end