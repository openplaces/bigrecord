class <%= migration_name %> < BigRecord::Migration

  def self.up
    create_table :<%= table_name %>, :force => true do |t|
    end
  end

  def self.down
    drop_table :<%= table_name %>
  end

end
