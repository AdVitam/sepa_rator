# frozen_string_literal: true

module SEPA
  class ContactDetails
    include ActiveModel::Validations
    include AttributeInitializer
    extend Converter

    NAME_PREFIXES = %w[DOCT MADM MISS MIST MIKS].freeze
    PREFERRED_METHODS = %w[LETT MAIL PHON FAXX CELL ONLI].freeze

    # Common fields (ContactDetails2, all schemas)
    attr_accessor :name_prefix,
                  :name,
                  :phone_number,
                  :mobile_number,
                  :fax_number,
                  :email_address,
                  # Contact4 fields (v09+, XSD rejects for v03)
                  :email_purpose,
                  :job_title,
                  :responsibility,
                  :department,
                  # Contact13 fields (v13 only, XSD rejects for v03/v09)
                  :url_address,
                  # Complex/enum fields handled separately in XML builder
                  :other_contacts,   # Array<{channel_type:, id:}> (OtherContact1, v09/v13)
                  :preferred_method  # PreferredContactMethod1Code/2Code (v09/v13)

    convert :name, :phone_number, :mobile_number, :fax_number,
            :email_purpose, :job_title, :responsibility, :department, to: :text

    # Superset lengths (most permissive schema).
    # Stricter per-schema limits are enforced by XSD validation in validate_final_document!.
    validates_inclusion_of :name_prefix, in: NAME_PREFIXES, allow_nil: true
    validates_length_of :name, maximum: 140, allow_nil: true
    validates_length_of :phone_number, maximum: 30, allow_nil: true
    validates_length_of :mobile_number, maximum: 30, allow_nil: true
    validates_length_of :fax_number, maximum: 30, allow_nil: true
    validates_length_of :url_address, maximum: 2048, allow_nil: true
    validates_length_of :email_address, maximum: 2048, allow_nil: true
    validates_length_of :email_purpose, maximum: 35, allow_nil: true
    validates_length_of :job_title, maximum: 35, allow_nil: true
    validates_length_of :responsibility, maximum: 35, allow_nil: true
    validates_length_of :department, maximum: 70, allow_nil: true
    validates_inclusion_of :preferred_method, in: PREFERRED_METHODS, allow_nil: true

    validate :validate_other_contacts

    private

    def validate_other_contacts
      return unless other_contacts

      unless other_contacts.is_a?(Array)
        errors.add(:other_contacts, 'must be an Array')
        return
      end

      other_contacts.each_with_index do |contact, i|
        unless contact.is_a?(Hash) && contact[:channel_type]
          errors.add(:other_contacts, "entry #{i} must have :channel_type")
          next
        end
        errors.add(:other_contacts, "entry #{i} channel_type exceeds 4 characters") if contact[:channel_type].to_s.length > 4
        errors.add(:other_contacts, "entry #{i} id exceeds 128 characters") if contact[:id] && contact[:id].to_s.length > 128
      end
    end
  end
end
