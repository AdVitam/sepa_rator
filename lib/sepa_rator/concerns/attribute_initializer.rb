# frozen_string_literal: true

module SEPA
  module AttributeInitializer
    def self.included(base)
      base.include ActiveModel::AttributeAssignment
      base.extend ClassMethods
    end

    module ClassMethods
      def permitted_attributes
        @permitted_attributes ||= begin
          own_setters = instance_methods(false)
                        .select { |m| m.to_s.end_with?('=') }
                        .to_set { |m| m.to_s.chomp('=') }

          if superclass.respond_to?(:permitted_attributes)
            own_setters | superclass.permitted_attributes
          else
            own_setters
          end
        end.freeze
      end
    end

    def initialize(attributes = {})
      assign_attributes(attributes)
    rescue ActiveModel::UnknownAttributeError => e
      raise ArgumentError, "Unknown attribute: #{e.attribute}"
    end

    private

    def _assign_attribute(key, value)
      raise ArgumentError, "Unknown attribute: #{key}" unless self.class.permitted_attributes.include?(key.to_s)

      public_send("#{key}=", value)
    end
  end
end
