# frozen_string_literal: true

module SEPA
  module Validators
    module DK
      # The DK `pain.001.001.09_AXZ_GBIC5` / `pain.008.001.08_AXZ_GBIC5`
      # schemas tighten the ISO baseline with a minimum transaction amount.
      # DK specifies 0.01 to prevent zero-amount transactions from being
      # submitted through EBICS.
      #
      # The threshold lives on the profile (`profile.features.min_amount`);
      # this validator applies it to any profile that sets the feature.
      class MinAmount
        def self.validate(transaction, profile)
          min = profile.features.min_amount
          return if min.nil?
          return if transaction.amount && transaction.amount >= min

          raise SEPA::ValidationError,
                "[#{profile.id}] amount #{format('%.2f', transaction.amount)} is below the " \
                "required minimum #{format('%.2f', min)} (DK GBIC5 rule)"
        end
      end
    end
  end
end
