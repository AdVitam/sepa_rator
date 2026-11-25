# frozen_string_literal: true

module SEPA
  class DebtorAccount < Account
    attr_accessor :initiating_party_identifier, :initiating_party_scheme, :initiating_party_lei, :initiating_party_bic

    convert :initiating_party_identifier, to: :identifier
    convert :initiating_party_scheme,     to: :identifier
    # Max256Text (v13 GenericOrganisationIdentification3); stricter v03/v09
    # limits are enforced by XSD validation at output time.
    validates_length_of :initiating_party_identifier, within: 1..256, allow_nil: true
    validates_length_of :initiating_party_scheme,     within: 1..35,  allow_nil: true
    validates_with LEIValidator, field_name: :initiating_party_lei, message: 'is invalid'
    validates_with BICValidator, field_name: :initiating_party_bic, message: 'is invalid'
    validates_presence_of :initiating_party_identifier, if: :initiating_party_scheme

    requires_capabilities initiating_party_lei: :lei

    def initiating_party_id(builder, profile)
      return if initiating_party_identifiers.empty?

      build_organisation_id(builder, initiating_party_identifier, profile,
                            lei: initiating_party_lei, org_bic: initiating_party_bic,
                            scheme: initiating_party_scheme)
    end

    def initiating_party_identifiers = [initiating_party_bic, initiating_party_lei, initiating_party_identifier].compact
  end
end
