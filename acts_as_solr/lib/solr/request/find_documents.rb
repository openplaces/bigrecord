module Solr
  module Request

class FindDocuments < Solr::Request::Select

  VALID_PARAMS = [:query, :start, :rows, :field_list, :debug_query, :explain_other, :articles, :min_traveliness]
                
  def initialize(params)
    super('find_documents')
    
    raise "Invalid parameters: #{(params.keys - VALID_PARAMS).join(',')}" unless 
      (params.keys - VALID_PARAMS).empty?
    
    @params = params.dup
    @params[:articles] ||= []
    # Validate start, rows can be transformed to ints
    @params[:start] = params[:start].to_i if params[:start]
    @params[:rows] = params[:rows].to_i if params[:rows]
    @params[:field_list] ||= ["*", "score"]
  end
  
  def to_hash
    hash = {}
    
    # common parameter processing
    hash[:q] = @params[:query]
    hash[:start] = @params[:start]
    hash[:rows] = @params[:rows]
    hash[:fl] = @params[:field_list].join(",")
    hash[:debugQuery] = @params[:debug_query]
    hash[:explainOther] = @params[:explain_other]
    hash[:re] = @params[:articles].join(",")
    hash[:mt] = @params[:min_traveliness]
    hash.merge(super.to_hash)
  end
end

  end
end