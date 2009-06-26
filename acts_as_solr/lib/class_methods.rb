require File.dirname(__FILE__) + '/common_methods'
require File.dirname(__FILE__) + '/parser_methods'

module ActsAsSolr #:nodoc:

  module ClassMethods
    include CommonMethods
    include ParserMethods
    
    def acting_as_solr
      if @acting_as_solr.nil?
        @acting_as_solr = false
        ancestors.each do |a|
          if a.respond_to?(:acting_as_solr) and a.acting_as_solr
            @acting_as_solr = true
            break
          end
        end
      end
      @acting_as_solr
    end

    def configuration
      unless @configuration
        @configuration = superclass.acting_as_solr ? superclass.configuration.dup : {}
        @configuration[:solr_fields] = @configuration[:solr_fields].dup if @configuration[:solr_fields]
        @configuration[:exclude_fields] = @configuration[:exclude_fields].dup if @configuration[:exclude_fields]
      end
      @configuration
    end

    def configuration=(conf)
      @configuration = conf
    end

    def solr_configuration
      @solr_configuration ||= superclass.acting_as_solr ? superclass.solr_configuration.dup : {}
    end

    def solr_configuration=(conf)
      @solr_configuration = conf
    end
    
    # Override this to specify a custom class name to use in solr 
    def solr_type
      name
    end

    # if request == add || delete
    #   The Solr instance will be chosen by id.hashCode % nb_shards
    # elsif request == commit.commit_all || optimize
    #   The request is sent to all instances
    # elsif request == !commit.commit_all
    #   The request is sent to the last @solr_url
    # else
    #   A random url is chosen
    def solr_execute(request, shard_url=nil)
      if solr_using_shards?
        # Handle batch update
        if request.is_a?(Solr::Request::AddDocument) and request.docs.size > 1 and !shard_url
          # Split the request into several ones if it must be sent to different shards
          sub_requests = {}
          request.docs.each do |doc|
            url = shard_url_for(doc['pk_s'])
            if sub_requests.has_key?(url)
              sub_requests[url].add_doc(doc)
            else
              sub_requests[url] = Solr::Request::AddDocument.new(doc)
            end
          end
          # Recursive execution of the sub queries
          logger.debug "Splitted batch update to send it to the following shards: #{sub_requests.keys.inspect}" if sub_requests.size > 1
          sub_requests.each{|url, sub_request| solr_execute(sub_request, url)} and return

        # Handle delete by query by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Delete) and request.query and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return

        # Handle commit by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Commit) and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return

        # Handle optimize by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Optimize) and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return
        end

        url = shard_url ? shard_url : random_shard_url
        request.shards = solr_shards if request.is_a?(Solr::Request::Select)

        logger.debug "#{request.class} using shard #{url}"

      else
        url = solr_url
      end

      connection = Solr::Connection.new(url)
      result = nil

      message = request.respond_to?(:to_hash) ? "/#{request.handler} #{request.to_hash.inspect}" : request.to_s
#      message = request.handler
      solr_log message do
        result = connection.send(request)
      end
      result
    end

    #ID_PREFIX_SIZE = 2

    def shard_url_for(id)
      unless solr_shards_urls.empty?
        if id
          id = id.to_s if id.is_a?(Integer)
          
          # pad with '0's to respect the id prefix size for the hash calculation
          id = "0"*(id.size - ID_PREFIX_SIZE) + id if id.size < ID_PREFIX_SIZE

          solr_shards_urls[id[0..(ID_PREFIX_SIZE-1)].hash.abs % solr_shards_urls.size]
        else
          random_shard_url
        end
      end
    end

    def random_shard_url
      unless solr_shards_urls.empty?
        solr_shards_urls[rand(solr_shards_urls.size)]
      end
    end

    # url for the non sharded version of solr
    def solr_url
      #@solr_url ||= YAML.load(File.new(RAILS_ROOT + '/config/solr.yml'))[RAILS_ENV]['solr_url']
      @solr_url = "http://localhost:8981/solr"
    end

    def solr_shards
      @solr_shards ||= solr_shards_urls.collect{|s|s[7..-1]} # remove http://
    end

    def solr_shards_urls
      #@solr_shards_urls ||= YAML.load(File.new(RAILS_ROOT + '/config/solr.yml'))[RAILS_ENV]['shards'] || []
      @solr_shards_url = []
    end

    def solr_using_shards?
      !solr_shards.empty?
    end

    # Finds instances of a model. Terms are ANDed by default, can be overwritten 
    # by using OR between terms
    # 
    # Here's a sample (untested) code for your controller:
    # 
    #  def search
    #    results = Book.find_by_solr params[:query]
    #  end
    # 
    # You can also search for specific fields by searching for 'field:value'
    # 
    # ====options:
    # offset:: - The first document to be retrieved (offset)
    # limit:: - The number of rows per page
    # order:: - Orders (sort by) the result set using a given criteria:
    #
    #             Book.find_by_solr 'ruby', :order => 'description asc'
    # 
    # field_types:: This option is deprecated and will be obsolete by version 1.0.
    #               There's no need to specify the :field_types anymore when doing a 
    #               search in a model that specifies a field type for a field. The field 
    #               types are automatically traced back when they're included.
    # 
    #                 class Electronic < ActiveRecord::Base
    #                   acts_as_solr :fields => [{:price => :range_float}]
    #                 end
    # 
    # facets:: This option argument accepts the following arguments:
    #          fields:: The fields to be included in the faceted search (Solr's facet.field)
    #          query:: The queries to be included in the faceted search (Solr's facet.query)
    #          zeros:: Display facets with count of zero. (true|false)
    #          sort:: Sorts the faceted resuls by highest to lowest count. (true|false)
    #          browse:: This is where the 'drill-down' of the facets work. Accepts an array of
    #                   fields in the format "facet_field:term"
    # 
    # Example:
    # 
    #   Electronic.find_by_solr "memory", :facets => {:zeros => false, :sort => true,
    #                                                 :query => ["price:[* TO 200]",
    #                                                            "price:[200 TO 500]",
    #                                                            "price:[500 TO *]"],
    #                                                 :fields => [:category, :manufacturer],
    #                                                 :browse => ["category:Memory","manufacturer:Someone"]}
    # 
    # scores:: If set to true this will return the score as a 'solr_score' attribute
    #          for each one of the instances found. Does not currently work with find_id_by_solr
    # 
    #            books = Book.find_by_solr 'ruby OR splinter', :scores => true
    #            books.records.first.solr_score
    #            => 1.21321397
    #            books.records.last.solr_score
    #            => 0.12321548
    # 
    def find_by_solr(query, options={})
      data = parse_query(query, options)
      return parse_results(data, options) if data
    end
    
    # Finds instances of a model and returns an array with the ids:
    #  Book.find_id_by_solr "rails" => [1,4,7]
    # The options accepted are the same as find_by_solr
    # 
    def find_id_by_solr(query, options={})
      data = parse_query(query, options)
      return parse_results(data, {:format => :ids}) if data
    end
    
    def find_values_by_solr(query, options={})
      data = parse_query(query, options)
      return parse_results(data, {:format => :values}) if data      
    end
    
    # This method can be used to execute a search across multiple models:
    #   Book.multi_solr_search "Napoleon OR Tom", :models => [Movie]
    # 
    # ====options:
    # Accepts the same options as find_by_solr plus:
    # models:: The additional models you'd like to include in the search
    # results_format:: Specify the format of the results found
    #                  :objects :: Will return an array with the results being objects (default). Example:
    #                               Book.multi_solr_search "Napoleon OR Tom", :models => [Movie], :results_format => :objects
    #                  :ids :: Will return an array with the ids of each entry found. Example:
    #                           Book.multi_solr_search "Napoleon OR Tom", :models => [Movie], :results_format => :ids
    #                           => [{"id" => "Movie:1"},{"id" => Book:1}]
    #                          Where the value of each array is as Model:instance_id
    # 
    def multi_solr_search(query, options = {})
      models = "AND (#{solr_configuration[:type_field]}:#{self.name}"
      options[:models].each{|m| models << " OR type_s_mv:"+m.to_s} if options[:models].is_a?(Array)
      options.update(:results_format => :objects) unless options[:results_format]
      data = parse_query(query, options, models<<")")
      result = []
      if data
        docs = data.docs
        return SearchResults.new(:docs => [], :total => 0) if data.total == 0
        if options[:results_format] == :objects
          docs.each{|doc| k = doc.fetch('id').to_s.split(':'); result << k[0].constantize.find_by_id(k[1])}
        elsif options[:results_format] == :ids
          docs.each{|doc| result << {"id"=>doc.values.pop.to_s}}
        end
        SearchResults.new :docs => result, :total => data.total
      end
    end
    
    # returns the total number of documents found in the query specified:
    #  Book.count_by_solr 'rails' => 3
    # 
    def count_by_solr(query, options = {})        
      data = parse_query(query, options)
      data.total_hits
    end
    
    def drop_solr_index
      solr_execute(Solr::Request::Delete.new(:query => "type_s_mv:\"#{self.name}\""))
    end
    
    def batch_solr_index(batch)
      solr_doc_batch = batch.collect { |o| o.to_solr_doc }
      solr_add(solr_doc_batch)
      solr_commit
    end
    
    def batch_solr_delete(batch)
      solr_batch_query = batch.collect { |o| "pk_s:#{o.id}"}.join(" OR ")
      solr_delete_query(solr_batch_query)
      solr_commit
    end
    
    def solr_disabled= bool
      @solr_disabled= bool
    end
  
    def solr_disabled
      @solr_disabled
    end
    
    def rebuild_solr_index(options={}, &finder)
      raise "Not supported for hbaserecord. Use rebuild_index() instead" if self < BigRecord::Base
      
      if options[:drop]
        logger.info "Dropping #{self.name} index..." unless options[:silent]
        drop_solr_index
      end
      
      $stderr.puts "reporter:status:Indexation is under way" unless options[:silent]
      
      options[:batch_size] ||= 0
      options[:offset] ||= 0 if self < ActiveRecord::Base
      options[:commit] = true unless options.has_key?(:commit)
      options[:optimize] = true unless options.has_key?(:optimize)
      
      $stderr.puts "Offset: #{options[:offset]}" unless options[:silent]
      $stderr.puts "Stop row: #{options[:stop_row]}" unless options[:silent]
      
      finder ||= lambda do |ar, opts|
        if ar < BigRecord::Base
          ar.find(:all, opts.merge({:view=>:all, :bypass_index=>true, :stop_row => options[:stop_row]}))
        else
          ar.find(:all, opts.merge({:order => self.primary_key}))
        end
      end
      
      items_processed = 0

      if options[:batch_size] > 0
        
        offset = options[:offset]
        
        # The main loop creates the index documents consumed by the thread above
        i = 0
        while true
          $stderr.puts "reporter:status:loop # #{i} offset #{offset} stop_row #{options[:stop_row]}" unless options[:silent]
          logger.info "#{Time.now.strftime("%H:%M:%S")} - Processing records ##{i*options[:batch_size]+1}-#{(i+1)*options[:batch_size]}... " unless options[:silent]
          i += 1

          items = finder.call(self, {:limit => options[:batch_size], :offset => offset, :stop_row => options[:stop_row]})

          logger.info "  id=#{items.last.id}" unless items.empty? unless options[:silent]
          items_processed += items.size
          $stderr.puts "reporter:counter:openplaces,items_processed,#{items.size}" unless options[:silent]
          
          unless items.empty?
              # FIXME: remove this... it shouldn't be here. It's a temporary fix
              # for not indexing article that are not indexable.
              items_to_index = self <= Article ? items.select { |item| item.indexable? } : items

              unless items_to_index.empty?
                docs = items_to_index.collect{|content| content.to_solr_doc}
                if options[:only_generate]
                  # Collect the documents. This is to be used within a mapred job.
                  docs.each do |doc|
                    key = doc['id']

                    # Cannot have \n and \t in the value since they are
                    # document and field separators respectively
                    value = doc.to_xml.to_s
                    value = value.gsub("\n", "__ENDLINE__")
                    value = value.gsub("\t", "__TAB__")

                    puts "#{key}\t#{value}"
                    $stderr.puts "reporter:counter:openplaces,generated_docs,1" unless options[:silent]
                  end
                else
                  solr_add(docs)
                  solr_commit if options[:commit]
                end
              end
          else
            logger.info "\n" unless options[:silent]
            break
          end
          
          if self < ActiveRecord::Base
            offset += items.size
          else
            offset = items.last.id
          end
        end
      else
        items = finder.call(self, {})
        items.each { |content| content.solr_save }
        items_processed = items.size
        
        solr_commit if options[:commit]
      end
      if options[:optimize]
        optimize_solr_index
      end
      
      if items_processed > 0
        $stderr.puts "Index for #{self.name} has been rebuilt (#{items_processed} records)." unless options[:silent]
      else
        $stderr.puts "Nothing to index for #{self.name}." unless options[:silent]
      end
      true
    end
    
    def optimize_solr_index(options={})
      $stderr.puts "reporter:status:Optimizing index..." unless options[:silent]
      #begin
        solr_optimize
      #rescue
        #$stderr.puts "Warning: index optimization failed."
      #end
    end
  end
  
end
