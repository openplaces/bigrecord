module BigRecord
  module HrAssociations
    class CachedItemProxyFactory

      include Singleton

      def create(id, owner, reflection)
        cache = owner[CachedItemProxy::CACHE_ATTRIBUTE]
        cached_attributes = cache["#{reflection.klass.name}:#{id}"] if cache
        cached_attributes ||= {}
        cached_attributes["id"] = id
        proxy = reflection.klass.instantiate(cached_attributes)
        proxy.extend CachedItemProxy
        proxy.instance_variable_set(:@owner, owner)
        proxy.instance_variable_set(:@reflection, reflection)
        proxy.reset

        # Overload the cached methods
        reflection.options[:cache].each do |attribute_name|
          eval "def proxy.#{attribute_name}\n"+
               "  proxy_cache[\"#{attribute_name}\"] ||= super\n"+
               "end"
        end

        proxy
      end

#      def extended_class(reflection)
#        @extended_classes ||= {}
#        @extended_classes[reflection.klass.name] ||= create_extended_class(reflection)
#      end
#
#      def create_extended_class(reflection)
#        extended_class = Class.new(reflection.klass)
#        extended_class.class_eval do
#          include CachedItemProxy
#
#          attr_reader :reflection
#          alias_method :proxy_respond_to?, :respond_to?
#          alias_method :proxy_extend, :extend
##          delegate :to_param, :to => :proxy_target
#
#          # Overload the methods
#          instance_methods.each do |m|
#            if reflection.options[:cache].include?(m.to_sym)
#              define_method m do
#                proxy_cache[m.to_s] ||= super
#              end
#            end
#          end
#
#          def class
#            reflection.klass
#          end
#
#        end
#        extended_class
#      end

    end
  end
end
