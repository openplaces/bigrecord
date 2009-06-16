module BigRecord
  module EmbeddedAssociations
    class AssociationProxy #:nodoc:
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_)/ }

#      def initialize(owner, reflection)
#        @owner, @reflection = owner, reflection
#        Array(reflection.options[:extend]).each { |ext| proxy_extend(ext) }
#        reset
#      end

      def find(id)
        @target.select{|s| s.id == id}.first
      end

      # Remove +records+ from this association.  Does not destroy +records+.
      def delete(*records)
        records = flatten_deeper(records)
        #records.each { |record| raise_on_type_mismatch(record) }
        records.reject! { |record| @target.delete(record)}
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

      protected
        def dependent?
          @reflection.options[:dependent] || false
        end

        def quoted_record_ids(records)
          records.map { |record| record.quoted_id }.join(',')
        end

        def extract_options_from_args!(args)
          @owner.send(:extract_options_from_args!, args)
        end

        def set_belongs_to_association_for(record)
          if @reflection.options[:as]
            record["#{@reflection.options[:as]}_id"]   = @owner.id unless @owner.new_record?
            record["#{@reflection.options[:as]}_type"] = @owner.class.base_class.name.to_s
          else
            record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
          end
        end

        def merge_options_from_reflection!(options)
          options.reverse_merge!(
            :group   => @reflection.options[:group],
            :limit   => @reflection.options[:limit],
            :offset  => @reflection.options[:offset],
            :joins   => @reflection.options[:joins],
            :include => @reflection.options[:include],
            :select  => @reflection.options[:select]
          )
        end

      private
        def method_missing(method, *args, &block)
          if load_target
            @target.send(method, *args, &block)
          end
        end

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

        # Can be overwritten by associations that might have the foreign key available for an association without
        # having the object itself (and still being a new record). Currently, only belongs_to present this scenario.
        def foreign_key_present
          false
        end

        def raise_on_type_mismatch(record)
          unless record.is_a?(@reflection.klass)
            raise BigRecord::AssociationTypeMismatch, "#{@reflection.class_name} expected, got #{record.class}"
          end
        end

        # Array#flatten has problems with recursive arrays. Going one level deeper solves the majority of the problems.
        def flatten_deeper(array)
          array.collect { |element| element.respond_to?(:flatten) ? element.flatten : element }.flatten
        end
    end
  end
end
