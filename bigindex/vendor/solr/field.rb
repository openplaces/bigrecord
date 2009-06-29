module Solr
class Field

  DEFAULT_BOOST = 1.0

  attr_accessor :name
  attr_accessor :values

  def initialize
    @values = []
  end

  def add_value(value, options={})
    boost = options[:boost] || DEFAULT_BOOST
    @values << {value => boost}
  end
end
end
