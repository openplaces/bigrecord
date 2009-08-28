class Novel < Book

  column :publisher,    :string

  index :publisher, :text

end