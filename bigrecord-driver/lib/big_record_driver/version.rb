module BigRecord
  module Driver
    VERSION = File.read(File.join(File.dirname(__FILE__), "..", "..", "VERSION")).chomp.freeze
  end
end
