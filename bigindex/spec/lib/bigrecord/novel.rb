class Novel < Book

  # TODO: Fix this bug in BigRecord
  set_default_family :attribute

  column :publisher,    :string

  index :publisher, :text

end