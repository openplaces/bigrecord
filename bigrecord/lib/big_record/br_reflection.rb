module BigRecord
  module BrReflection # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)

    end

    # Reflection allows you to interrogate Big Record classes and objects about their associations and aggregations.
    # This information can, for example, be used in a form builder that took an Big Record object and created input
    # fields for all of the attributes depending on their type and displayed the associations to other objects.
    #
    # You can find the interface for the AggregateReflection and AssociationReflection classes in the abstract MacroReflection class.
    module ClassMethods
      def create_reflection_big_record(macro, name, options, big_record)
        case macro
          when :has_many_big_records, :belongs_to_big_record, :belongs_to_many, :has_one_big_record, :has_and_belongs_to_many_big_records
            reflection = BrAssociationReflection.new(macro, name, options, big_record)
          when :composed_of_big_record
            reflection = BrAggregateReflection.new(macro, name, options, big_record)
        end
        write_inheritable_hash :reflections, name => reflection
        reflection
      end
    end

    # TODO: this sucks... aren't there a better way to do it?
    if self.class < ActiveRecord::Base
      class MacroReflectionAbstract < ActiveRecord::Reflection::MacroReflection

      end
    else
      class MacroReflectionAbstract < BigRecord::ArReflection::MacroReflection

      end
    end

    # Holds all the meta-data about an aggregation as it was specified in the Big Record class.
    class BrAggregateReflection < MacroReflectionAbstract #:nodoc:
      def klass
        @klass ||= Object.const_get(options[:class_name] || class_name)
      end

      private
        def name_to_class_name(name)
          name.capitalize.gsub(/_(.)/) { |s| $1.capitalize }
        end
    end

    # Holds all the meta-data about an association as it was specified in the Big Record class.
    class BrAssociationReflection < MacroReflectionAbstract #:nodoc:
      def klass
        @klass ||= big_record.send(:compute_type, class_name)
      end

      def table_name
        @table_name ||= klass.table_name
      end

      def primary_key_name
        return @primary_key_name if @primary_key_name
        case
          when macro == :belongs_to_big_record
            @primary_key_name = options[:foreign_key] || class_name.foreign_key
          when macro == :belongs_to_many
            @primary_key_name = options[:foreign_key] || "#{big_record.default_family}:#{class_name.tableize}_ids"
          when options[:as]
            @primary_key_name = options[:foreign_key] || "#{big_record.default_family}:#{options[:as]}_id"
          else
            @primary_key_name = options[:foreign_key] || big_record.name.foreign_key
        end
      end

      def association_foreign_key
        @association_foreign_key ||= @options[:association_foreign_key] || class_name.foreign_key
      end

      def counter_cache_column
        if options[:counter_cache] == true
          "#{big_record.name.underscore.pluralize}_count"
        elsif options[:counter_cache]
          options[:counter_cache]
        end
      end

      def through_reflection
        @through_reflection ||= options[:through] ? big_record.reflect_on_association(options[:through]) : false
      end

      # Gets an array of possible :through source reflection names
      #
      #   [singularized, pluralized]
      #
      def source_reflection_names
        @source_reflection_names ||= (options[:source] ? [options[:source]] : [name.to_s.singularize, name]).collect { |n| n.to_sym }
      end

      # Gets the source of the through reflection.  It checks both a singularized and pluralized form for :belongs_to or :has_many.
      # (The :tags association on Tagging below)
      #
      #   class Post
      #     has_many :tags, :through => :taggings
      #   end
      #
      def source_reflection
        return nil unless through_reflection
        @source_reflection ||= source_reflection_names.collect { |name| through_reflection.klass.reflect_on_association(name) }.compact.first
      end

      def check_validity!
        if options[:through]
          if through_reflection.nil?
            raise HasManyThroughAssociationNotFoundError.new(big_record.name, self)
          end

          if source_reflection.nil?
            raise HasManyThroughSourceAssociationNotFoundError.new(self)
          end

          if options[:source_type] && source_reflection.options[:polymorphic].nil?
            raise HasManyThroughAssociationPointlessSourceTypeError.new(big_record.name, self, source_reflection)
          end

          if source_reflection.options[:polymorphic] && options[:source_type].nil?
            raise HasManyThroughAssociationPolymorphicError.new(big_record.name, self, source_reflection)
          end

          unless [:belongs_to_big_record, :has_many_big_records].include?(source_reflection.macro) && source_reflection.options[:through].nil?
            raise HasManyThroughSourceAssociationMacroError.new(self)
          end
        end
      end

      private
        def name_to_class_name(name)
          if name =~ /::/
            name
          else
            if options[:class_name]
              options[:class_name]
            elsif through_reflection # get the class_name of the belongs_to association of the through reflection
              options[:source_type] || source_reflection.class_name
            else
              class_name = name.to_s.camelize
              class_name = class_name.singularize if [ :has_many_big_records, :has_and_belongs_to_many_big_records, :belongs_to_many ].include?(macro)
              class_name
            end
          end
        end
    end
  end
end
