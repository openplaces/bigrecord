module BigRecord
  module Index
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods

      def rebuild_index(options={}, finder_options={})
        if options[:drop]
          logger.info "Dropping #{self.name} index..." unless options[:silent]
          drop_solr_index
        end

        $stderr.puts "reporter:status:Indexation is under way" unless options[:silent]

        finder_options[:batch_size] ||= 100
        finder_options[:view] ||= :all

        options[:batch_size] ||= 150
        options[:commit] = true unless options.has_key?(:commit)
        options[:optimize] = true unless options.has_key?(:optimize)

        $stderr.puts "Offset: #{finder_options[:offset]}" unless options[:silent]
        $stderr.puts "Stop row: #{finder_options[:stop_row]}" unless options[:silent]

        buffer = []
        items_processed = 0
        loop = 0
        self.scan(finder_options) do |r|
          items_processed += 1
          buffer << r
          if buffer.size > options[:batch_size]
            loop += 1
            process_index_batch(buffer, loop, options)
            buffer.clear
          end
        end

        process_index_batch(buffer, loop, options) unless buffer.empty?

        if options[:optimize]
          optimize_solr_index(options)
        end

        if items_processed > 0
          $stderr.puts "Index for #{self.name} has been rebuilt (#{items_processed} records)." unless options[:silent]
        else
          $stderr.puts "Nothing to index for #{self.name}." unless options[:silent]
        end
        true
      end

      def process_index_batch(items, loop, options={})
        $stderr.puts "reporter:status:loop # #{loop}" unless options[:silent]
        $stderr.puts "Loop records starting at id=#{items.first.id}" unless options[:silent]
        $stderr.puts "#{Time.now.strftime("%H:%M:%S")} - Processing records ##{loop*options[:batch_size]+1}-#{(loop+1)*options[:batch_size]}... " unless options[:silent]

        unless items.empty?
          # FIXME: remove this... it shouldn't be here. It's a temporary fix
          # for not indexing article that are not indexable.
          items_to_index = self <= Article ? items.select { |item| item.indexable? } : items
          unless options[:silent] || items_to_index.size == items.size
            $stderr.puts "reporter:counter:openplaces,not_indexable,#{items.size - items_to_index.size}" unless options[:silent]
          end

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
              end
            else
              solr_add(docs)
              solr_commit if options[:commit]
            end
          else
            logger.info "\n" unless options[:silent]
            break
          end

          logger.info "  id=#{items.last.id}" unless items.empty? unless options[:silent]
        end
      end

      def index_view(name, columns)
        write_inheritable_attribute(:index_views_hash, read_inheritable_attribute(:index_views_hash) || default_index_views_hash)
        read_inheritable_attribute(:index_views_hash)[name] = columns
      end

      def index_views
        @index_views ||= index_views_hash.values
      end

      def index_view_names
        @index_view_names ||= index_views_hash.keys
      end

      def index_views_hash
        read_inheritable_attribute(:index_views_hash) || default_index_views_hash
      end

      def default_index_views_hash
        {:default => self.configuration[:fields]}
      end

      def set_unreturned_index_fields(fields)
        @unreturned_index_fields = fields
      end

      def unreturned_index_fields
        @unreturned_index_fields.to_a
      end

      def returned_index_fields
        unless @returned_index_fields
          fields = {}
          configuration[:solr_fields].each do |item|
            if item.is_a?(Hash)
              name = item.keys[0]
              fields.merge!(item) unless (unreturned_index_fields.find{|n| n == name} || item.values[0].to_s =~ /not_stored/)
            else
              fields[item] = :text unless unreturned_index_fields.find{|n| n == item}
            end
          end
          @returned_index_fields = fields.collect {|field, type| "#{field}_#{get_solr_field_type(type)}".to_sym}
          @returned_index_fields += [:score, :pk_s, :type_s_mv]
          @returned_index_fields.uniq!
        end
        @returned_index_fields
      end

      def index(field, options={}, &block)
        # Mixin the other methods only if the class is to be used for index, else keep it clean
        unless self.respond_to?(:acting_as_solr) and acting_as_solr
          acts_as_solr :fields => [], :auto_commit => true # (ENV['RAILS_ENV']=='test')
        end

        add_solr_field(field, block)

        field_name = field.is_a?(Hash) ? field.keys[0] : field
        finder_name = options[:finder_name] || field_name

        # default finder: exact match on the index name
        define_finder finder_name, [{:field => field, :weight => 1}]
      end

      def add_solr_field(field, block)
        if self.configuration[:fields]
          unless self.configuration[:fields].include?(field)
            self.configuration[:fields] << field
          else
            return
          end
        else
          self.configuration[:fields] = [field]
        end

        configuration[:solr_fields] << field
        field_name = field.is_a?(Hash) ? field.keys[0] : field

        define_method("#{field_name}_for_solr") do |f|
          if block
            block.call(self, f)
          elsif value = self.send(field_name.to_sym)
            f.values << value
          end
        end
      end

      private
      # add the finder method 'find_by_...()'
      def define_finder(finder_name, fields)
        class_eval <<-end_eval
          def self.find_by_#{finder_name}(user_query, options={})

              options[:fields] ||= index_views_hash[:default]

              write_inheritable_attribute(:string_finders, {}) if read_inheritable_attribute(:string_finders).nil?

              if read_inheritable_attribute(:string_finders)["#{finder_name}"].nil?
                # FIXME: this is crap... the lookup should be done using a hash
                read_inheritable_attribute(:string_finders)["#{finder_name}"] =
                    !configuration[:fields].select{|f| f.is_a?(Hash) and f.keys.first and f.keys.first.to_s == "#{finder_name}" and f.values.first==:string}.empty?
              end

              # quote the query if the field type is :string
              if read_inheritable_attribute(:string_finders)["#{finder_name}"]
                query = "#{finder_name}:(\\"\#{user_query}\\")"
              else
                query = "#{finder_name}:(\#{user_query})"
              end

              if options[:source] == :index
                results = find_values_by_solr(query,  :fields   => options[:fields],
                                                      :order    =>options[:order],
                                                      :offset   => options[:offset],
                                                      :limit    => options[:limit],
                                                      :query_function => options[:query_function],
                                                      :no_parsing   => options[:no_parsing],
                                                      :scores   => :true,
                                                      :operator => :or).docs
              else
                results = find_by_solr(query, :fields    => options[:fields],
                                              :view      => options[:view],
                                              :include_deleted => options[:include_deleted],
                                              :force_reload => options[:force_reload],
                                              :timestamp => options[:timestamp],
                                              :order     => options[:order],
                                              :offset    => options[:offset],
                                              :limit     => options[:limit],
                                              :query_function => options[:query_function],
                                              :no_parsing   => options[:no_parsing],
                                              :scores    => :true,
                                              :operator  => :or).docs
              end

              return results
            end
        end_eval
      end
    end
  end
end
