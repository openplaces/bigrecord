dir = File.expand_path(File.join(File.dirname(__FILE__), "br_associations"))

require dir + '/association_proxy'
require dir + '/association_collection'
require dir + '/belongs_to_association'
require dir + '/belongs_to_many_association'
require dir + '/has_one_association'
require dir + '/has_and_belongs_to_many_association'

module BigRecord
  module BrAssociations # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def has_many_big_records(association_id, options = {}, &extension)
        reflection = create_has_many_big_records_reflection(association_id, options, &extension)

        configure_dependency_for_has_many(reflection)

        if options[:through]
          collection_reader_method(reflection, HasManyThroughAssociation)
        else
          add_association_callbacks(reflection.name, reflection.options)
          collection_accessor_methods(reflection, HasManyAssociation)
        end
      end

      alias_method :has_many_bigrecords, :has_many_big_records


      def has_one_big_record(association_id, options = {})
        reflection = create_has_one_big_record_reflection(association_id, options)

        module_eval do
          after_save <<-EOF
            association = instance_variable_get("@#{reflection.name}")
            if !association.nil? && (new_record? || association.new_record? || association["#{reflection.primary_key_name}"] != id)
              association["#{reflection.primary_key_name}"] = id
              association.save(true)
            end
          EOF
        end

        association_accessor_methods_big_record(reflection, HasOneAssociation)
        association_constructor_method_big_record(:build,  reflection, HasOneAssociation)
        association_constructor_method_big_record(:create, reflection, HasOneAssociation)

        configure_dependency_for_has_one(reflection)
      end

      alias_method :has_one_bigrecord, :has_one_big_record


      def belongs_to_big_record(association_id, options = {})
        if options.include?(:class_name) && !options.include?(:foreign_key)
          ::ActiveSupport::Deprecation.warn(
          "The inferred foreign_key name will change in Rails 2.0 to use the association name instead of its class name when they differ.  When using :class_name in belongs_to, use the :foreign_key option to explicitly set the key name to avoid problems in the transition.",
          caller)
        end

        reflection = create_belongs_to_big_record_reflection(association_id, options)

        if reflection.options[:polymorphic]
          association_accessor_methods_big_record(reflection, BelongsToPolymorphicAssociation)

          module_eval do
            before_save <<-EOF
              association = instance_variable_get("@#{reflection.name}")
              if association && association.target
                if association.new_record?
                  association.save(true)
                end

                if association.updated?
                  self["#{reflection.primary_key_name}"] = association.id
                  self["#{reflection.options[:foreign_type]}"] = association.class.base_class.name.to_s
                end
              end
            EOF
          end
        else
          association_accessor_methods_big_record(reflection, BelongsToAssociation)
          association_constructor_method_big_record(:build,  reflection, BelongsToAssociation)
          association_constructor_method_big_record(:create, reflection, BelongsToAssociation)

          module_eval do
            before_save <<-EOF
              association = instance_variable_get("@#{reflection.name}")
              if !association.nil?
                if association.new_record?
                  association.save(true)
                end

                if association.updated?
                  self["#{reflection.primary_key_name}"] = association.id
                end
              end
            EOF
          end
        end

        if options[:counter_cache]
          cache_column = options[:counter_cache] == true ?
            "#{self.to_s.underscore.pluralize}_count" :
            options[:counter_cache]

          module_eval(
            "after_create '#{reflection.name}.class.increment_counter(\"#{cache_column}\", #{reflection.primary_key_name})" +
            " unless #{reflection.name}.nil?'"
          )

          module_eval(
            "before_destroy '#{reflection.name}.class.decrement_counter(\"#{cache_column}\", #{reflection.primary_key_name})" +
            " unless #{reflection.name}.nil?'"
          )
        end
      end

      alias_method :belongs_to_bigrecord, :belongs_to_big_record


      def belongs_to_many(association_id, options = {})
        if options.include?(:class_name) && !options.include?(:foreign_key)
          ::ActiveSupport::Deprecation.warn(
          "The inferred foreign_key name will change in Rails 2.0 to use the association name instead of its class name when they differ.  When using :class_name in belongs_to, use the :foreign_key option to explicitly set the key name to avoid problems in the transition.",
          caller)
        end

        reflection = create_belongs_to_many_reflection(association_id, options)

        association_accessor_methods_big_record(reflection, BelongsToManyAssociation)
        association_constructor_method_big_record(:build,  reflection, BelongsToManyAssociation)
        association_constructor_method_big_record(:create, reflection, BelongsToManyAssociation)

        module_eval do
          before_save <<-EOF
            association = instance_variable_get("@#{reflection.name}")
            if !association.nil?
              association.each do |r|
                r.save(true) if r.new_record?
              end

              if association.updated?
                self["#{reflection.primary_key_name}"] = association.collect{|r| r.id}
              end
            end
          EOF
        end

      end


      def has_and_belongs_to_many_big_records(association_id, options = {}, &extension)
        reflection = create_has_and_belongs_to_many_big_records_reflection(association_id, options, &extension)

        collection_accessor_methods(reflection, HasAndBelongsToManyAssociation)

        # Don't use a before_destroy callback since users' before_destroy
        # callbacks will be executed after the association is wiped out.
        old_method = "destroy_without_habtm_shim_for_#{reflection.name}"
        class_eval <<-end_eval
          alias_method :#{old_method}, :destroy_without_callbacks
          def destroy_without_callbacks
            #{reflection.name}.clear
            #{old_method}
          end
        end_eval

        add_association_callbacks(reflection.name, options)
      end

      alias_method :has_and_belongs_to_many_bigrecords, :has_and_belongs_to_many_big_records


    private

      def association_accessor_methods_big_record(reflection, association_proxy_class)
        define_method(reflection.name) do |*params|
          force_reload = params.first unless params.empty?
          association = instance_variable_get("@#{reflection.name}")

          if association.nil? || force_reload
            association = association_proxy_class.new(self, reflection)
            retval = association.reload
            if retval.nil? and association_proxy_class == BelongsToAssociation
              instance_variable_set("@#{reflection.name}", nil)
              return nil
            end
            instance_variable_set("@#{reflection.name}", association)
          end

          association.target.nil? ? nil : association
        end

        define_method("#{reflection.name}=") do |new_value|
          association = instance_variable_get("@#{reflection.name}")
          if association.nil?
            association = association_proxy_class.new(self, reflection)
          end

          association.replace(new_value)

          unless new_value.nil?
            instance_variable_set("@#{reflection.name}", association)
          else
            instance_variable_set("@#{reflection.name}", nil)
            return nil
          end

          association
        end

        define_method("set_#{reflection.name}_target") do |target|
          return if target.nil? and association_proxy_class == BelongsToAssociation
          association = association_proxy_class.new(self, reflection)
          association.target = target
          instance_variable_set("@#{reflection.name}", association)
        end
      end

      def association_constructor_method_big_record(constructor, reflection, association_proxy_class)
        define_method("#{constructor}_#{reflection.name}") do |*params|
          attributees      = params.first unless params.empty?
          replace_existing = params[1].nil? ? true : params[1]
          association      = instance_variable_get("@#{reflection.name}")

          if association.nil?
            association = association_proxy_class.new(self, reflection)
            instance_variable_set("@#{reflection.name}", association)
          end

          if association_proxy_class == HasOneAssociation
            association.send(constructor, attributees, replace_existing)
          else
            association.send(constructor, attributees)
          end
        end
      end

      def create_has_many_big_records_reflection(association_id, options, &extension)
        options.assert_valid_keys(
          :class_name, :table_name, :foreign_key, :exclusively_dependent, :dependent,
          :select, :conditions, :include, :order, :group, :limit, :offset, :as,
          :through, :source, :source_type, :uniq, :finder_sql, :counter_sql,
          :before_add, :after_add, :before_remove, :after_remove, :extend
        )

        options[:extend] = create_extension_module(association_id, extension) if block_given?

        create_reflection_big_record(:has_many_big_records, association_id, options, self)
      end

      def create_has_one_big_record_reflection(association_id, options)
        options.assert_valid_keys(
          :class_name, :foreign_key, :remote, :conditions, :order, :include,
          :dependent, :counter_cache, :extend, :as
        )

        create_reflection_big_record(:has_one_big_record, association_id, options, self)
      end

      def create_belongs_to_big_record_reflection(association_id, options)
        options.assert_valid_keys(
          :class_name, :foreign_key, :foreign_type, :remote, :conditions, :order,
          :include, :dependent, :counter_cache, :extend, :polymorphic
        )

        reflection = create_reflection_big_record(:belongs_to_big_record, association_id, options, self)

        if options[:polymorphic]
          reflection.options[:foreign_type] ||= reflection.class_name.underscore + "_type"
        end

        reflection
      end

      def create_belongs_to_many_reflection(association_id, options)
        options.assert_valid_keys(
          :class_name, :foreign_key, :foreign_type, :remote, :conditions, :order,
          :include, :dependent, :extend, :cache
        )

        create_reflection_big_record(:belongs_to_many, association_id, options, self)
      end

      def create_has_and_belongs_to_many_big_records_reflection(association_id, options, &extension)
        options.assert_valid_keys(
          :class_name, :table_name, :join_table, :foreign_key, :association_foreign_key,
          :select, :conditions, :include, :order, :group, :limit, :offset, :uniq,
          :finder_sql, :delete_sql, :insert_sql, :before_add, :after_add, :before_remove,
          :after_remove, :extend
        )

        options[:extend] = create_extension_module(association_id, extension) if block_given?

        reflection = create_reflection_big_record(:has_and_belongs_to_many_big_records, association_id, options, self)

        reflection.options[:join_table] ||= join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(reflection.class_name))

        reflection
      end
    end
  end
end
