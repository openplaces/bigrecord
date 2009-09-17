class Novel < Book

  index :publisher, :text

  # This is here just so the spec will pass
  def publisher
    "PUBLISHER"
  end

end