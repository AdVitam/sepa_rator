# frozen_string_literal: true

module SEPA
  class Account
    include ActiveModel::Model
    include CharsetApplicable
    include CapabilityRequirements
    extend Converter

    attr_accessor :name, :iban, :bic, :address, :agent_lei, :contact_details

    convert :name, to: :text

    validates_length_of :name, within: 1..70
    validates_with BICValidator, message: 'is invalid'
    validates_with IBANValidator
    validates_with LEIValidator, field_name: :agent_lei, message: 'is invalid'
    validates :address, :contact_details, nested_model: true, allow_nil: true

    requires_capabilities agent_lei: :agent_lei, contact_details: :contact_details, address: :account_address

    # @param _builder [Nokogiri::XML::Builder]
    # @param _profile [SEPA::Profile]
    # @abstract Override in subclasses to emit an `<Id>` block inside `<InitgPty>`.
    def initiating_party_id(_builder, _profile); end

    # @return [Array<String>] identifiers the caller set for `InitgPty/Id`
    # @abstract Override in subclasses that accept initiating party identifiers.
    def initiating_party_identifiers = [].freeze

    protected

    # Builds `<Id><OrgId>` with the schema-appropriate BIC tag (BICOrBEI/AnyBIC)
    # and an optional LEI.
    def build_organisation_id(builder, identifier, profile, **options)
      builder.Id do
        builder.OrgId do
          build_org_bic_and_lei(builder, profile, options)
          if identifier
            builder.Othr do
              builder.Id(identifier)
              builder.SchmeNm { builder.Prtry(options[:scheme]) } if options[:scheme]
            end
          end
        end
      end
    end

    def build_org_bic_and_lei(builder, profile, options)
      builder.__send__(profile.features.org_bic_tag, options[:org_bic]) if options[:org_bic]
      builder.LEI(options[:lei]) if options[:lei]
    end
  end
end
