# frozen_string_literal: true

module SEPA
  class DirectDebitTransaction < Transaction
    SEQUENCE_TYPES = %w[FRST OOFF RCUR FNAL RPRE].freeze
    SEQUENCE_TYPES_V1 = %w[FRST OOFF RCUR FNAL].freeze
    LOCAL_INSTRUMENTS = %w[CORE COR1 B2B].freeze

    attr_accessor :mandate_id,
                  :mandate_date_of_signature,
                  :local_instrument,
                  :sequence_type,
                  :instruction_priority,
                  :creditor_account,
                  :original_debtor_account,
                  :same_mandate_new_debtor_agent,
                  :original_creditor_account

    validates_with MandateIdentifierValidator, field_name: :mandate_id, message: 'is invalid'
    validates_presence_of :mandate_date_of_signature
    validates_inclusion_of :local_instrument, in: LOCAL_INSTRUMENTS
    validates_inclusion_of :sequence_type, in: SEQUENCE_TYPES
    validates_inclusion_of :instruction_priority, in: %w[HIGH NORM], allow_nil: true
    validate { |t| t.validate_requested_date_after(Date.today.next) }

    validate do |t|
      errors.add(:creditor_account, 'is not correct') if creditor_account && !creditor_account.valid?

      if original_debtor_account.present?
        iban_str = original_debtor_account.to_s
        errors.add(:original_debtor_account, 'is not a valid IBAN') unless
          IBANTools::IBAN.valid?(iban_str) && iban_str.match?(IBANValidator::REGEX)
      end

      if t.mandate_date_of_signature.is_a?(Date)
        errors.add(:mandate_date_of_signature, 'is in the future') if t.mandate_date_of_signature > Date.today
      else
        errors.add(:mandate_date_of_signature, 'is not a Date')
      end
    end

    def initialize(attributes = {})
      super
      self.local_instrument ||= 'CORE'
      self.sequence_type ||= 'OOFF'

      return unless local_instrument == 'COR1'

      warn '[SEPA] COR1 local instrument is deprecated since November 2017. Use CORE instead.'
    end

    def amendment_informations?
      original_debtor_account || same_mandate_new_debtor_agent || original_creditor_account
    end

    UETR_SCHEMAS = %w[pain.008.001.08 pain.008.001.12].freeze
    INSTR_PRTY_UNSUPPORTED_SCHEMAS = %w[pain.008.002.02 pain.008.003.02].freeze

    def schema_compatible?(schema_name)
      return false if uetr.present? && !UETR_SCHEMAS.include?(schema_name)
      return false if instruction_priority.present? && INSTR_PRTY_UNSUPPORTED_SCHEMAS.include?(schema_name)

      case schema_name
      when PAIN_008_001_02
        SEQUENCE_TYPES_V1.include?(sequence_type)
      when PAIN_008_002_02
        bic.present? && %w[CORE B2B].include?(local_instrument) && currency == 'EUR' &&
          SEQUENCE_TYPES_V1.include?(sequence_type)
      when PAIN_008_003_02
        currency == 'EUR' && SEQUENCE_TYPES_V1.include?(sequence_type)
      when PAIN_008_001_08, PAIN_008_001_12
        true
      end
    end
  end
end
