module Solr
  module Response

class FindArticles < Solr::Response::Ruby
  include Enumerable

  attr_reader :exact_match, :blurbs, :properties_blurb

  def initialize(ruby_code)
    super(ruby_code)
    @response = @data['response']
    @exact_match = @data['exactMatch']
    @blurbs = @data['blurbs']
    @properties_blurb = @data['properties_blurb']
    raise "response section missing" unless @response.kind_of? Hash
  end

  def total_hits
    @response['numFound']
  end

  def start
    @response['start']
  end

  def hits
    @response['docs']
  end

  def max_score
    @response['maxScore']
  end

  # supports enumeration of hits
  # TODO revisit - should this iterate through *all* hits by re-requesting more?
  def each
    @response['docs'].each {|hit| yield hit}
  end

  alias num_found total_hits
  alias total total_hits
  alias offset start
  alias docs hits
  alias exact_match? exact_match

end

  end
end
