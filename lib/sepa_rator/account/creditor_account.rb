# frozen_string_literal: true

module SEPA
  class CreditorAccount < Account
    attr_accessor :creditor_identifier, :initiating_party_lei, :initiating_party_bic

    validates_with CreditorIdentifierValidator, message: 'is invalid'
    validates_with LEIValidator, field_name: :initiating_party_lei, message: 'is invalid'
    validates_with BICValidator, field_name: :initiating_party_bic, message: 'is invalid'

    def explicit_initiating_party_id?
      !(initiating_party_lei || initiating_party_bic).nil?
    end

    def initiating_party_id(builder, profile)
      identifier = creditor_identifier unless profile.single_child?('GrpHdr/InitgPty/Id/OrgId')
      build_organisation_id(builder, identifier, profile,
                            lei: initiating_party_lei, org_bic: initiating_party_bic)
    end
  end
end
