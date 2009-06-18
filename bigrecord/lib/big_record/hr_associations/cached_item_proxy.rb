module BigRecord
  module HrAssociations
    module CachedItemProxy #:nodoc:

      CACHE_ATTRIBUTE = "attribute:associations_cache"

      attr_reader :reflection
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
#      delegate :to_param, :to => :proxy_target
#      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_)/ }

      def proxy_cache
        @owner[CACHE_ATTRIBUTE] ||= {}
        @owner[CACHE_ATTRIBUTE]["#{@reflection.klass.name}:#{id}"] ||= {}
      end

      def proxy_owner
        @owner
      end

      def proxy_reflection
        @reflection
      end

      def proxy_target
        @target
      end

      def respond_to?(symbol, include_priv = false)
        proxy_respond_to?(symbol, include_priv) || (load_target && @target.respond_to?(symbol, include_priv))
      end

      # Explicitly proxy === because the instance method removal above
      # doesn't catch it.
      def ===(other)
        load_target
        other === @target
      end

      def aliased_table_name
        @reflection.klass.table_name
      end

      def reset
        @loaded = false
        @target = nil
      end

      def reload
        reset
        load_target
      end

      def loaded?
        @loaded
      end

      def loaded
        @loaded = true
      end

      def target
        @target
      end

      def target=(target)
        @target = target
        loaded
      end

#      # Returns the contents of the record as a nicely formatted string.
#      def inspect
#        if loaded?
#          @target.inspect
#        else
#          attributes_as_nice_string = @reflection.options[:cache].collect { |name|
#            column = @owner.column_for_attribute("attribute:#{name}")
#            "#{name}: #{column.type_cast(proxy_cache[name])}" if column
#          }.compact.join(", ")
#          "#<Cached#{@reflection.klass} #{attributes_as_nice_string}>"
#        end
#      end

#      def is_a?(klass)
#        @reflection.klass <= klass
#      end
#
#      def kind_of?(klass)
#        @reflection.klass <= klass
#      end
#
#      def to_param
#        @id
#      end

#      protected
#        def dependent?
#          @reflection.options[:dependent] || false
#        end
#
#        def quoted_record_ids(records)
#          records.map { |record| record.quoted_id }.join(',')
#        end
#
##        def interpolate_sql_options!(options, *keys)
##          keys.each { |key| options[key] &&= interpolate_sql(options[key]) }
##        end
##
##        def interpolate_sql(sql, record = nil)
##          @owner.send(:interpolate_sql, sql, record)
##        end
##
##        def sanitize_sql(sql)
##          @reflection.klass.send(:sanitize_sql, sql)
##        end
#
#        def extract_options_from_args!(args)
#          @owner.send(:extract_options_from_args!, args)
#        end
#
#        def set_belongs_to_association_for(record)
#          if @reflection.options[:as]
#            record["#{@reflection.options[:as]}_id"]   = @owner.id unless @owner.new_record?
#            record["#{@reflection.options[:as]}_type"] = @owner.class.base_class.name.to_s
#          else
#            record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
#          end
#        end
#
#        def merge_options_from_reflection!(options)
#          options.reverse_merge!(
#            :group   => @reflection.options[:group],
#            :limit   => @reflection.options[:limit],
#            :offset  => @reflection.options[:offset],
#            :joins   => @reflection.options[:joins],
#            :include => @reflection.options[:include],
#            :select  => @reflection.options[:select]
#          )
#        end

#      private
#        def method_missing(method_id, *args, &block)
#          if !loaded? and @reflection.options[:cache].include?(method_id)
#            # FIXME: shouldn't be hard coded
#            column = @owner.column_for_attribute("attribute:#{method_id}")
#            if column
#              if proxy_cache.has_key?(method_id)
#                column.type_cast(proxy_cache[method_id])
#              elsif load_target
#                proxy_cache[method_id] = @target.send(method_id, *args, &block)
#              end
#            else
#              @target.send(method_id, *args, &block)
#            end
#          elsif load_target
#            value = @target.send(method_id, *args, &block)
#            proxy_cache[method_id] = value if @reflection.options[:cache].include?(method_id)
#            value
#          end
#        end

        def load_target
          return nil unless defined?(@loaded)

          if !loaded? and (!@owner.new_record? || foreign_key_present)
            @target = find_target
          end

          @loaded = true
          @target
        rescue BigRecord::RecordNotFound
          reset
        end

        def find_target
          @reflection.klass.find(self.id)
        end

#        # Can be overwritten by associations that might have the foreign key available for an association without
#        # having the object itself (and still being a new record). Currently, only belongs_to present this scenario.
#        def foreign_key_present
#          false
#        end
#
#        def raise_on_type_mismatch(record)
#          unless record.is_a?(@reflection.klass)
#            raise BigRecordRecord::AssociationTypeMismatch, "#{@reflection.class_name} expected, got #{record.class}"
#          end
#        end

    end
  end
end
