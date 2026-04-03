# frozen_string_literal: true

module SEPA
  class CreditTransferTransaction < Transaction
    attr_accessor :service_level,
                  :category_purpose

    validates_inclusion_of :service_level, in: %w[SEPA URGP], allow_nil: true
    validates_length_of :category_purpose, within: 1..4, allow_nil: true

    validate { |t| t.validate_requested_date_after(Date.today) }

    def initialize(attributes = {})
      super
      self.service_level ||= 'SEPA' if currency == 'EUR'
    end

    def schema_compatible?(schema_name)
      case schema_name
      when PAIN_001_001_03, PAIN_001_001_09, PAIN_001_001_13
        !self.service_level || (self.service_level == 'SEPA' && currency == 'EUR')
      when PAIN_001_002_03
        bic.present? && self.service_level == 'SEPA' && currency == 'EUR'
      when PAIN_001_003_03
        currency == 'EUR'
      when PAIN_001_001_03_CH_02
        currency == 'CHF'
      end
    end
  end
end
