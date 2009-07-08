class AddBooksTable < BigRecord::Migration

  def self.up
    create_table :books, :force => true do |t|
      t.family :attribute, :versions => 100
      t.family :family2
      t.family :log, :versions => 100
    end
  end

  def self.down
    drop_table :books
  end

end