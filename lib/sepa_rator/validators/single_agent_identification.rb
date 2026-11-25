# frozen_string_literal: true

module SEPA
  module Validators
    # Under a single-child `FinInstnId` the builders would write both, which the bank rejects.
    class SingleAgentIdentification
      def self.validate(model, profile, label:)
        return unless profile.single_child?('FinInstnId')
        return if model.bic.to_s.empty? || model.agent_lei.to_s.empty?

        raise SEPA::ValidationError, "[#{profile.id}] #{label} accepts a bic or an agent_lei, not both"
      end
    end
  end
end
