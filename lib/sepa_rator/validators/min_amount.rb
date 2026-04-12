# frozen_string_literal: true

module SEPA
  module Validators
    # Shared minimum-amount validator used by profiles that tighten the ISO
    # baseline (e.g. DK GBIC5, AT PSA/Stuzza).  The threshold comes from
    # `profile.features.min_amount`; profiles that leave it `nil` are
    # unaffected.
    class MinAmount
      def self.validate(transaction, profile)
        min = profile.features.min_amount
        return if min.nil?
        return if transaction.amount.nil? # caught upstream by validates_numericality_of
        return if transaction.amount >= min

        raise SEPA::ValidationError,
              "[#{profile.id}] amount #{format('%.2f', transaction.amount)} is below the " \
              "required minimum #{format('%.2f', min)}"
      end
    end
  end
end
