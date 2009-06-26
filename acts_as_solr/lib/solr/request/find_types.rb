module Solr
  module Request

class FindTypes < Solr::Request::Select

  VALID_PARAMS = [:query, :rows, :field_list, :debug_query, :explain_other]
  
  def initialize(params)
    super('find_types')
    
    raise "Invalid parameters: #{(params.keys - VALID_PARAMS).join(',')}" unless 
      (params.keys - VALID_PARAMS).empty?
    
    raise ":query parameter required" unless params[:query]
    
    @params = params.dup
    
    # Validate start, rows can be transformed to ints
    @params[:rows] = params[:rows].to_i if params[:rows]
    @params[:field_list] ||= ["*,score"]
  end
  
  def to_hash
    hash = {}
    
    # common parameter processing
    hash[:q] = @params[:query]
    hash[:rows] = @params[:rows]
    hash[:fl] = @params[:field_list]
    hash[:debugQuery] = @params[:debug_query]
    hash[:explainOther] = @params[:explain_other]
    
    hash.merge(super.to_hash)
  end

end

  end
end