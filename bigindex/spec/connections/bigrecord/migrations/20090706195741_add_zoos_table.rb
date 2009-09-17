class AddZoosTable < BigRecord::Migration

  def self.up
    create_table :zoos, :force => true do |t|
      t.family :attr, :versions => 100
    end
  end

  def self.down
    drop_table :zoos
  end

end