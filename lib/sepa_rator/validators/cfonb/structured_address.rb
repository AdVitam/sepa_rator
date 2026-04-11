# frozen_string_literal: true

module SEPA
  module Validators
    module CFONB
      # CFONB (and the broader EPC 2024+ migration) requires postal addresses
      # to be carried as structured fields (StrtNm, PstCd, TwnNm, …) rather
      # than the legacy `AdrLine` unstructured format. Banks that implement
      # the CFONB guidelines reject files whose addresses are populated only
      # via `address_line1` / `address_line2`.
      #
      # This validator runs during `Message#add_transaction` and raises a
      # `ValidationError` as soon as it sees a transaction-level address
      # that uses AdrLine without any structured field.
      class StructuredAddress
        ADDRESS_ACCESSORS = %i[creditor_address debtor_address].freeze
        STRUCTURED_FIELDS = %i[street_name building_number post_code town_name].freeze

        def self.validate(transaction, profile)
          ADDRESS_ACCESSORS.each do |accessor|
            next unless transaction.respond_to?(accessor)

            address = transaction.public_send(accessor)
            next if address.nil?
            next if structured?(address)

            raise SEPA::ValidationError,
                  "[#{profile.id}] #{accessor} must use structured fields " \
                  '(StrtNm, PstCd, TwnNm, …), not AdrLine (CFONB rule)'
          end
        end

        def self.structured?(address)
          STRUCTURED_FIELDS.any? { |field| address.respond_to?(field) && address.public_send(field) }
        end
      end
    end
  end
end
