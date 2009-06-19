$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

unless defined?(ActiveSupport)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activesupport/lib")
    require 'active_support'
  rescue LoadError
    require 'rubygems'
    gem 'activesupport'
    require 'active_support'
  end
end

unless defined?(ActiveRecord)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activerecord/lib")
    require 'active_record'
  rescue LoadError
    require 'rubygems'
    gem 'activerecord'
    require 'active_record'
  end
end

#unless defined?(BigRecordDriver)
#  begin
#    $:.unshift(File.join(File.dirname(__FILE__), "..", "..", "bigrecord-driver", "lib"))
#    require 'big_record_driver'
#  rescue
#    require 'rubygems'
#    gem 'bigrecord-driver'
#    require 'big_record_driver'
#  end
#end

# FIXME: this shouldn't be required
require 'active_record/fixtures'

require 'big_record/routing_ext'

require 'big_record/abstract_base'
require 'big_record/base'
require 'big_record/embedded'
require 'big_record/validations'
require 'big_record/callbacks'
require 'big_record/ar_reflection'
require 'big_record/hr_reflection'
require 'big_record/ar_associations'
require 'big_record/hr_associations'
require 'big_record/timestamp'
require 'big_record/attribute_methods'
require 'big_record/index'
require 'big_record/embedded_associations/association_proxy'
require 'big_record/dynamic_schema'
require 'big_record/deletion'
require 'big_record/family_span_columns'

# Add support for collections to tag builders
require 'big_record/action_view_extensions'

BigRecord::Base.class_eval do
  include BigRecord::Validations
  include BigRecord::Callbacks
  include BigRecord::Timestamp
  include BigRecord::ArAssociations
  include BigRecord::HrAssociations
  include BigRecord::ArReflection
  include BigRecord::HrReflection
  include BigRecord::AttributeMethods
  include BigRecord::Index
  include BigRecord::DynamicSchema
  include BigRecord::Deletion
  include BigRecord::FamilySpanColumns
end

BigRecord::Embedded.class_eval do
  include BigRecord::Validations
  include BigRecord::Callbacks
  include BigRecord::Timestamp
  include BigRecord::ArAssociations
  include BigRecord::HrAssociations
  include BigRecord::ArReflection
  include BigRecord::HrReflection
  include BigRecord::AttributeMethods
  include BigRecord::Index
  include BigRecord::DynamicSchema
end

# Mixin the BigRecord associations with ActiveRecord
ActiveRecord::Base.class_eval do
  include BigRecord::HrAssociations
  include BigRecord::HrReflection
end

# Patch to call the validation of the embedded objects to HbaseRecord::Base instances.
BigRecord::Base.class_eval do
  validate :validate_embeddeds

  def validate_embeddeds
    attributes.each do |k, v|
      if v.kind_of?(BigRecord::Embedded)
        errors.add(k, "is invalid: @errors=#{v.errors.full_messages.inspect}") unless v.valid?
      elsif v.is_a?(Array) and v.first.kind_of?(BigRecord::Embedded)
        v.each_with_index do |item, i|
          next if item.blank?
          unless item.valid?
            errors.add(k, "is invalid. The item ##{i} in the collection has the following errors: @errors=#{item.errors.full_messages.inspect}")
          end
        end
      end
    end
  end
end

require 'big_record/connection_adapters/hbase_adapter'
