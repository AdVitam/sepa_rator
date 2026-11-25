# frozen_string_literal: true

module SEPA
  module Validators
    # Profiles whose XSD allows a single child in `AmdmntInfDtls` (AT PSA
    # SDD v08/v12) reject several amendment details instead of dropping some.
    class SingleAmendmentDetail
      def self.validate(transaction, profile)
        return unless profile.single_child?('AmdmntInfDtls')
        return unless transaction.respond_to?(:amendment_details)

        names = transaction.amendment_details.keys
        return if names.size <= 1

        raise SEPA::ValidationError,
              "[#{profile.id}] only one amendment detail is allowed, got #{names.join(', ')}"
      end
    end
  end
end
