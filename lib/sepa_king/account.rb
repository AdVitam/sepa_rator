# frozen_string_literal: true

module SEPA
  class Account
    include ActiveModel::Validations
    include AttributeInitializer
    extend Converter

    attr_accessor :name, :iban, :bic, :address, :agent_lei, :contact_details

    convert :name, to: :text

    validates_length_of :name, within: 1..70
    validates_with BICValidator, IBANValidator, message: 'is invalid'
    validates_with LEIValidator, field_name: :agent_lei, message: 'is invalid'

    validate do |record|
      next unless record.address

      unless record.address.valid?
        record.address.errors.each do |error|
          record.errors.add(:address, error.full_message)
        end
      end
    end

    validate do |record|
      next unless record.contact_details

      unless record.contact_details.valid?
        record.contact_details.errors.each do |error|
          record.errors.add(:contact_details, error.full_message)
        end
      end
    end

    def initiating_party_id(builder, schema_name); end

    protected

    # Builds Id > OrgId block. XSD sequence: BICOrBEI/AnyBIC → LEI → Othr
    def build_organisation_id(builder, identifier, schema_name, **options)
      builder.Id do
        builder.OrgId do
          build_org_bic_and_lei(builder, schema_name, options)
          if identifier
            builder.Othr do
              builder.Id(identifier)
              builder.SchmeNm { builder.Prtry(options[:scheme]) } if options[:scheme]
            end
          end
        end
      end
    end

    def build_org_bic_and_lei(builder, schema_name, options)
      if options[:org_bic]
        bic_tag = SCHEMA_FEATURES[schema_name][:org_bic_tag]
        builder.__send__(bic_tag, options[:org_bic])
      end
      builder.LEI(options[:lei]) if options[:lei] && LEI_SCHEMAS.include?(schema_name)
    end
  end
end
