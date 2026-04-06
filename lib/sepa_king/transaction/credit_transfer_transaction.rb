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
    # EPC schemas (pain.001.002.03, pain.001.003.03) do not define these elements
    INSTR_FOR_CDTR_AGT_SCHEMAS = %w[pain.001.001.03 pain.001.001.09 pain.001.001.13 pain.001.001.03.ch.02].freeze
    TXN_INSTR_FOR_DBTR_AGT_SCHEMAS = %w[pain.001.001.03 pain.001.001.09 pain.001.001.13 pain.001.001.03.ch.02].freeze
    REGULATORY_REPORTING_SCHEMAS = %w[pain.001.001.03 pain.001.001.09 pain.001.001.13 pain.001.001.03.ch.02].freeze

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
      return false unless regulatory_reportings_compatible?(schema_name)

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
      return false if charge_bearer && charge_bearer != 'SLEV' && EPC_ONLY_SCHEMAS.include?(schema_name)

      schema_allows_field?(uetr, UETR_SCHEMAS, schema_name) &&
        schema_allows_field?(debtor_agent_instruction, PMTINF_INSTR_SCHEMAS, schema_name) &&
        schema_allows_field?(credit_transfer_mandate?, MNDT_RLTD_INF_SCHEMAS, schema_name) &&
        schema_allows_field?(instruction_for_debtor_agent_code, [PAIN_001_001_13], schema_name) &&
        schema_allows_field?(instruction_for_debtor_agent, TXN_INSTR_FOR_DBTR_AGT_SCHEMAS, schema_name) &&
        schema_allows_field?(regulatory_reportings&.any?, REGULATORY_REPORTING_SCHEMAS, schema_name)
    end

    # v13 RegulatoryReporting10 requires DbtCdtRptgInd (indicator)
    def regulatory_reportings_compatible?(schema_name)
      return true unless regulatory_reportings&.any? && schema_name == PAIN_001_001_13

      regulatory_reportings.all? { |r| r.is_a?(Hash) && r[:indicator] }
    end

    def schema_allows_field?(value, allowed_schemas, schema_name)
      !value || allowed_schemas.include?(schema_name)
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
        if instr[:instruction_info]
          len = instr[:instruction_info].to_s.length
          errors.add(:instructions_for_creditor_agent, "entry #{i} instruction_info must be 1-140 characters") unless len.between?(1, 140)
        end
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
        unless reporting.is_a?(Hash)
          errors.add(:regulatory_reportings, "entry #{i} must be a Hash")
          next
        end
        if reporting[:indicator] && !REGULATORY_INDICATORS.include?(reporting[:indicator])
          errors.add(:regulatory_reportings, "entry #{i} indicator must be one of #{REGULATORY_INDICATORS.join(', ')}")
        end
        validate_regulatory_reporting_details(reporting, i)
      end
    end

    def validate_regulatory_reporting_details(reporting, entry_index)
      return unless reporting[:details]

      unless reporting[:details].is_a?(Array)
        errors.add(:regulatory_reportings, "entry #{entry_index} details must be an Array")
        return
      end

      reporting[:details].each_with_index do |detail, j|
        unless detail.is_a?(Hash)
          errors.add(:regulatory_reportings, "entry #{entry_index} detail #{j} must be a Hash")
          next
        end
        errors.add(:regulatory_reportings, "entry #{entry_index} detail #{j} code too long") if detail[:code] && detail[:code].to_s.length > 10
        Array(detail[:information]).each_with_index do |inf, k|
          errors.add(:regulatory_reportings, "entry #{entry_index} detail #{j} information #{k} exceeds 35 characters") if inf.to_s.length > 35
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
      return false unless INSTR_FOR_CDTR_AGT_SCHEMAS.include?(schema_name)

      instructions_for_creditor_agent.each do |instr|
        code = instr[:code]
        next unless code

        case schema_name
        when PAIN_001_001_03, PAIN_001_001_09, PAIN_001_001_03_CH_02
          return false unless INSTRUCTION3_CODES.include?(code)
        when PAIN_001_001_13
          return false unless code.to_s.length.between?(1, 4)
        end
      end
      true
    end
  end
end
