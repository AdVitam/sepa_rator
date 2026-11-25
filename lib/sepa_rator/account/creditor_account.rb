# frozen_string_literal: true

module SEPA
  class CreditorAccount < Account
    attr_accessor :creditor_identifier, :initiating_party_lei, :initiating_party_bic

    validates_with CreditorIdentifierValidator, message: 'is invalid'
    validates_with LEIValidator, field_name: :initiating_party_lei, message: 'is invalid'
    validates_with BICValidator, field_name: :initiating_party_bic, message: 'is invalid'

    requires_capabilities initiating_party_lei: :lei

    def initiating_party_id(builder, profile)
      # Exclusive `InitgPty` allows a single `OrgId` child; the creditor
      # identifier still reaches the bank through `CdtrSchmeId`.
      identifier = creditor_identifier unless profile.features.exclusive_initiating_party
      build_organisation_id(builder, identifier, profile,
                            lei: initiating_party_lei, org_bic: initiating_party_bic)
    end

    def initiating_party_identifiers = [initiating_party_bic, initiating_party_lei].compact
  end
end
