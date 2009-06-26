module BigRecord
  module Deletion
    def self.included(base) #:nodoc:
      base.alias_method_chain :destroy_without_callbacks, :flag_deleted
      base.extend ClassMethods

      base.class_eval do
        class << self
          alias_method_chain :find_one, :flag_deleted
          alias_method_chain :find_every, :flag_deleted
        end
      end

    end

    # Flag the record as "deleted" if it responds to "deleted", else destroy it
    def destroy_without_callbacks_with_flag_deleted #:nodoc:
      if self.respond_to?(:deleted)
        # mark as deleted
        self.deleted = true

        # set the timestamp
        if record_timestamps
          t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
          self.send(:updated_at=, t) if respond_to?(:updated_at)
          self.send(:updated_on=, t) if respond_to?(:updated_on)
        end

        self.update_without_callbacks
      else
        destroy_without_callbacks_without_flag_deleted
      end
    end

    module ClassMethods
      def find_one_with_flag_deleted(*args)
        options = args.last.is_a?(Hash) ? args.last : {}
        records = find_one_without_flag_deleted(*args)
        unless options[:include_deleted]
          if records.is_a?(Array)
            records.each{|record| check_not_deleted(record)}
          else
            check_not_deleted(records)
          end
        end
        records
      end

      def find_every_with_flag_deleted(*args)
        options = args.last.is_a?(Hash) ? args.last : {}
        records = find_every_without_flag_deleted(*args)
        unless options[:include_deleted]
          records.select do |record|
            begin
              check_not_deleted(record)
              true
            rescue
              false
            end
          end
        else
          records
        end
      end

      def check_not_deleted(record)
        raise BigRecord::RecordNotFound, "The record (id=#{record.id}) is marked as deleted." if record.respond_to?(:deleted) and record.deleted
      end
    end

  end
end
