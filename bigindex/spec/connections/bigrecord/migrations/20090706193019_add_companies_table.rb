class AddCompaniesTable < BigRecord::Migration

  def self.up
    create_table :companies, :force => true do |t|
      t.family :attribute, :versions => 100
      t.family :log, :versions => 100
    end
  end

  def self.down
    drop_table :companies
  end

end