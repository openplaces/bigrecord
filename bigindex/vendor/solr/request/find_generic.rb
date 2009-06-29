module Solr
  module Request

class FindGeneric < Solr::Request::Select

  VALID_PARAMS = [:query, :field_list, :rows, :model]

  def initialize(params)
    super('generic')

    raise "Invalid parameters: #{(params.keys - VALID_PARAMS).join(',')}" unless
      (params.keys - VALID_PARAMS).empty?

    raise ":query parameter required" unless params[:query]

    @params = params.dup

    # Validate start, rows can be transformed to ints
    @params[:rows] = params[:rows].to_i if params[:rows]
    @params[:field_list] ||= ["*","score"]
  end

  def to_hash
    hash = {}

    # common parameter processing
    hash[:q] = @params[:query]
    hash[:fl] = @params[:field_list]
    hash[:rows] = @params[:rows]
    hash[:model] = @params[:model]

    hash.merge(super.to_hash)
  end

end

  end
end