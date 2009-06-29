module Solr
  module Request

class FindArticles < Solr::Request::Select

  VALID_PARAMS = [:query, :start, :rows, :field_list, :debug_query, :explain_other, :weights,
                  :filter_types, :filter_geo, :refine_related_types,
                  :refine_related_entities, :articles_only, :searchable_filter, :modified_in_promotion,
                  :blurbs, :blurbs_weights, :blurbs_length, :blurbs_debug, :properties_blurb, :properties_blurb_count]

  def initialize(params)
    super('find_articles')

    raise "Invalid parameters: #{(params.keys - VALID_PARAMS).join(',')}" unless
      (params.keys - VALID_PARAMS).empty?

    raise ":query parameter required" unless params[:query]

    @params = params.dup

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
    hash[:w] = @params[:weights]
    hash[:ft] = @params[:filter_types]
    hash[:fg] = @params[:filter_geo]
    hash[:fp] = @params[:filter_properties]
    hash[:rrt] = @params[:refine_related_types]
    hash[:rre] = @params[:refine_related_entities]
    hash[:ao] = @params[:articles_only]
    hash[:sf] = @params[:searchable_filter]
    hash[:fmp] = @params[:modified_in_promotion]
    hash[:hl] = @params[:blurbs]
    hash['hl.flw'] = @params[:blurbs_weights]
    hash['hl.length'] = @params[:blurbs_length]
    hash['hl.db'] = @params[:blurbs_debug]
    hash['ph'] = @params[:properties_blurb]
    hash['ph.count'] = @params[:properties_blurb_count]
    hash.merge(super.to_hash)
  end

end

  end
end
