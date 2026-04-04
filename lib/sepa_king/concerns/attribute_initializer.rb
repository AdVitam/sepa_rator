# frozen_string_literal: true

module SEPA
  module AttributeInitializer
    extend ActiveSupport::Concern

    included do
      include ActiveModel::AttributeAssignment
    end

    def initialize(attributes = {})
      assign_attributes(attributes)
    rescue ActiveModel::UnknownAttributeError => e
      raise ArgumentError, "Unknown attribute: #{e.attribute}"
    end
  end
end
