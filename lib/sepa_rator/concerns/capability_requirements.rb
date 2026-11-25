# frozen_string_literal: true

require 'active_support/concern'

module SEPA
  # Maps each optional field to the profile capability that serialises it, so
  # a field the profile's schema cannot hold is rejected before XML generation.
  module CapabilityRequirements
    extend ActiveSupport::Concern

    included do
      class_attribute :capability_requirements, instance_writer: false, default: {}.freeze
    end

    class_methods do
      # @param requirements [Hash{Symbol => Symbol}] field => capability
      def requires_capabilities(**requirements)
        self.capability_requirements = capability_requirements.merge(requirements).freeze
      end
    end

    # @return [Array(Symbol, Symbol), nil] the first `[field, capability]`
    #   pair whose field is set while the profile lacks the capability
    def capability_violation(profile)
      capability_requirements.find do |field, capability|
        !profile.supports?(capability) && field_set?(public_send(field))
      end
    end

    private

    def field_set?(value)
      value.respond_to?(:empty?) ? !value.empty? : !value.nil?
    end
  end
end
