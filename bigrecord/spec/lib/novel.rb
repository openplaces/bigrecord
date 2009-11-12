require File.join(File.dirname(__FILE__), "book")

class Novel < Book

  column :publisher,    :string

end