# frozen_string_literal: true

module SEPA
  class CreditTransferTransaction < Transaction
    attr_accessor :service_level,
                  :category_purpose,
                  :charge_bearer,
                  # PmtInf-level instruction for debtor agent (v09/v13, Max140Text)
                  :debtor_agent_instruction,
                  # Transaction-level instruction for debtor agent (Max140Text in v03/v09, InstrInf in v13)
                  :instruction_for_debtor_agent,
                  # ExternalDebtorAgentInstruction1Code (v13 only, 1-4 chars)
                  :instruction_for_debtor_agent_code,
                  # Array<Hash> of {code:, instruction_info:} for creditor agent instructions
                  :instructions_for_creditor_agent,
                  # Array<Hash> of {indicator:, details: [{code:, information: []}]}
                  :regulatory_reportings,
                  # CreditTransferMandateData1 fields (v13 only)
                  :credit_transfer_mandate_id,
                  :credit_transfer_mandate_date_of_signature,
                  :credit_transfer_mandate_frequency

    CHARGE_BEARERS = %w[DEBT CRED SHAR SLEV].freeze
    EPC_ONLY_SCHEMAS = %w[pain.001.002.03 pain.001.003.03].freeze
    UETR_SCHEMAS = %w[pain.001.001.09 pain.001.001.13].freeze
    PMTINF_INSTR_SCHEMAS = %w[pain.001.001.09 pain.001.001.13].freeze
    MNDT_RLTD_INF_SCHEMAS = %w[pain.001.001.13].freeze
    INSTRUCTION3_CODES = %w[CHQB HOLD PHOB TELB].freeze
    FREQUENCY_CODES = %w[YEAR MNTH QURT MIAN WEEK DAIL ADHO INDA FRTN].freeze
    REGULATORY_INDICATORS = %w[CRED DEBT BOTH].freeze

    validates_inclusion_of :service_level, in: %w[SEPA URGP], allow_nil: true
    validates_length_of :category_purpose, within: 1..4, allow_nil: true
    validates_inclusion_of :charge_bearer, in: CHARGE_BEARERS, allow_nil: true
    validates_address :creditor_address

    convert :debtor_agent_instruction, :instruction_for_debtor_agent,
            :credit_transfer_mandate_id, to: :text

    validates_length_of :debtor_agent_instruction, within: 1..140, allow_nil: true
    validates_length_of :instruction_for_debtor_agent, within: 1..140, allow_nil: true
    validates_length_of :instruction_for_debtor_agent_code, within: 1..4, allow_nil: true
    validates_length_of :credit_transfer_mandate_id, within: 1..35, allow_nil: true
    validates_inclusion_of :credit_transfer_mandate_frequency, in: FREQUENCY_CODES, allow_nil: true

    validate { |t| t.validate_requested_date_after(Date.today) }
    validate :validate_instructions_for_creditor_agent
    validate :validate_regulatory_reportings
    validate :validate_credit_transfer_mandate_date_of_signature

    def initialize(attributes = {})
      super
      self.service_level ||= 'SEPA' if currency == 'EUR'
    end

    def credit_transfer_mandate?
      credit_transfer_mandate_id || credit_transfer_mandate_date_of_signature || credit_transfer_mandate_frequency
    end

    # Fields (uetr, bic) are already validated as nil-or-non-empty
    # at add_transaction time, so a nil check is sufficient here.
    def schema_compatible?(schema_name)
      return false unless optional_fields_compatible?(schema_name)
      return false unless instructions_for_creditor_agent_compatible?(schema_name)

      case schema_name
      when PAIN_001_001_03, PAIN_001_001_09, PAIN_001_001_13
        iso_service_level_compatible?
      when PAIN_001_002_03
        bic && !bic.empty? && self.service_level == 'SEPA' && currency == 'EUR'
      when PAIN_001_003_03
        currency == 'EUR'
      when PAIN_001_001_03_CH_02
        currency == 'CHF'
      end
    end

    private

    def optional_fields_compatible?(schema_name)
      return false if uetr && !UETR_SCHEMAS.include?(schema_name)
      return false if charge_bearer && charge_bearer != 'SLEV' && EPC_ONLY_SCHEMAS.include?(schema_name)
      return false if debtor_agent_instruction && !PMTINF_INSTR_SCHEMAS.include?(schema_name)
      return false if credit_transfer_mandate? && !MNDT_RLTD_INF_SCHEMAS.include?(schema_name)
      return false if instruction_for_debtor_agent_code && schema_name != PAIN_001_001_13

      true
    end

    def iso_service_level_compatible?
      !self.service_level || self.service_level == 'URGP' || (self.service_level == 'SEPA' && currency == 'EUR')
    end

    def validate_instructions_for_creditor_agent
      return unless instructions_for_creditor_agent

      unless instructions_for_creditor_agent.is_a?(Array)
        errors.add(:instructions_for_creditor_agent, 'must be an Array')
        return
      end

      instructions_for_creditor_agent.each_with_index do |instr, i|
        unless instr.is_a?(Hash) && (instr[:code] || instr[:instruction_info])
          errors.add(:instructions_for_creditor_agent, "entry #{i} must have :code and/or :instruction_info")
          next
        end
        errors.add(:instructions_for_creditor_agent, "entry #{i} instruction_info too long") if instr[:instruction_info] && instr[:instruction_info].to_s.length > 140
      end
    end

    def validate_regulatory_reportings
      return unless regulatory_reportings

      unless regulatory_reportings.is_a?(Array)
        errors.add(:regulatory_reportings, 'must be an Array')
        return
      end

      errors.add(:regulatory_reportings, 'maximum 10 entries') if regulatory_reportings.length > 10

      regulatory_reportings.each_with_index do |reporting, i|
        if reporting[:indicator] && !REGULATORY_INDICATORS.include?(reporting[:indicator])
          errors.add(:regulatory_reportings, "entry #{i} indicator must be one of #{REGULATORY_INDICATORS.join(', ')}")
        end
        next unless reporting[:details].is_a?(Array)

        reporting[:details].each_with_index do |detail, j|
          errors.add(:regulatory_reportings, "entry #{i} detail #{j} code too long") if detail[:code] && detail[:code].to_s.length > 10
        end
      end
    end

    def validate_credit_transfer_mandate_date_of_signature
      return unless credit_transfer_mandate_date_of_signature
      return if credit_transfer_mandate_date_of_signature.is_a?(Date)

      errors.add(:credit_transfer_mandate_date_of_signature, 'is not a Date')
    end

    def instructions_for_creditor_agent_compatible?(schema_name)
      return true unless instructions_for_creditor_agent&.any?

      instructions_for_creditor_agent.each do |instr|
        next unless instr[:code]

        case schema_name
        when PAIN_001_001_03, PAIN_001_001_09, PAIN_001_002_03, PAIN_001_003_03, PAIN_001_001_03_CH_02
          return false unless INSTRUCTION3_CODES.include?(instr[:code])
        when PAIN_001_001_13
          return false unless instr[:code].length.between?(1, 4)
        end
      end
      true
    end
  end
end
