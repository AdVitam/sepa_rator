# frozen_string_literal: true

module SEPA
  class DebtorAccount < Account
    attr_accessor :initiating_party_identifier, :initiating_party_lei, :initiating_party_bic

    convert :initiating_party_identifier, to: :text
    # Max256Text (v13 GenericOrganisationIdentification3); stricter v03/v09 limits enforced by XSD
    validates_length_of :initiating_party_identifier, within: 1..256, allow_nil: true
    validates_with LEIValidator, field_name: :initiating_party_lei, message: 'is invalid'
    validates_with BICValidator, field_name: :initiating_party_bic, message: 'is invalid'

    def initiating_party_id(builder, schema_name)
      return unless initiating_party_identifier || initiating_party_bic || initiating_party_lei

      build_organisation_id(builder, initiating_party_identifier, schema_name,
                            lei: initiating_party_lei, org_bic: initiating_party_bic)
    end
  end
end
