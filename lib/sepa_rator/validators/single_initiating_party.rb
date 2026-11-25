# frozen_string_literal: true

module SEPA
  module Validators
    # Only the message's own account feeds `<InitgPty>`; data it cannot hold
    # under a single-child profile is rejected rather than dropped.
    class SingleInitiatingParty
      ID_ATTRIBUTES = %i[initiating_party_identifier initiating_party_bic initiating_party_lei].freeze

      def self.validate(account, profile)
        if profile.single_child?('GrpHdr/InitgPty/Id/OrgId') && id_count(account) > 1
          raise SEPA::ValidationError,
                "[#{profile.id}] account accepts a single initiating party identification " \
                "(#{ID_ATTRIBUTES.join(', ')})"
        end

        return unless profile.single_child?('GrpHdr/InitgPty') && account.contact_details

        raise SEPA::ValidationError,
              "[#{profile.id}] account.contact_details is not allowed: InitgPty only accepts Nm or Id"
      end

      def self.id_count(account)
        ID_ATTRIBUTES.count { |attribute| account.respond_to?(attribute) && !account.public_send(attribute).to_s.empty? }
      end
      private_class_method :id_count
    end
  end
end
