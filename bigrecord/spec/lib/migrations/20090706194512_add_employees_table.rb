class AddEmployeesTable < BigRecord::Migration

  def self.up
    create_table :employees, :force => true do |t|
      t.family :attribute, :versions => 100
    end
  end

  def self.down
    drop_table :employees
  end

end