# frozen_string_literal: true

module SEPA
  class DirectDebitTransaction < Transaction
    SEQUENCE_TYPES = %w[FRST OOFF RCUR FNAL].freeze
    LOCAL_INSTRUMENTS = %w[CORE COR1 B2B].freeze

    attr_accessor :mandate_id,
                  :mandate_date_of_signature,
                  :local_instrument,
                  :sequence_type,
                  :creditor_account,
                  :original_debtor_account,
                  :same_mandate_new_debtor_agent,
                  :original_creditor_account

    validates_with MandateIdentifierValidator, field_name: :mandate_id, message: 'is invalid'
    validates_presence_of :mandate_date_of_signature
    validates_inclusion_of :local_instrument, in: LOCAL_INSTRUMENTS
    validates_inclusion_of :sequence_type, in: SEQUENCE_TYPES
    validate { |t| t.validate_requested_date_after(Date.today.next) }

    validate do |t|
      errors.add(:creditor_account, 'is not correct') if creditor_account && !creditor_account.valid?

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

    def schema_compatible?(schema_name)
      case schema_name
      when PAIN_008_002_02
        bic.present? && %w[CORE B2B].include?(self.local_instrument) && currency == 'EUR'
      when PAIN_008_003_02
        currency == 'EUR'
      when PAIN_008_001_02, PAIN_008_001_08, PAIN_008_001_12
        true
      end
    end
  end
end
