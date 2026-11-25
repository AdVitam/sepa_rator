# frozen_string_literal: true

module SEPA
  class CreditTransferTransaction < Transaction
    include RegulatoryReportingValidator
    include RegulatoryReportingCharset

    attr_accessor :service_level,
                  :category_purpose,
                  :charge_bearer,
                  # PmtInf-level instruction for debtor agent (pain.001.001.09+, Max140Text).
                  :debtor_agent_instruction,
                  # Transaction-level instruction for debtor agent
                  # (Max140Text in v03/v09, structured in v13).
                  :instruction_for_debtor_agent,
                  # ExternalDebtorAgentInstruction1Code (v13 only, 1-4 chars).
                  :instruction_for_debtor_agent_code,
                  # Array<Hash{code:, instruction_info:}>
                  :instructions_for_creditor_agent,
                  # Array<Hash{indicator:, authority:, details:[…]}>
                  :regulatory_reportings,
                  # CreditTransferMandateData1 fields (v13 only).
                  :credit_transfer_mandate_id,
                  :credit_transfer_mandate_date_of_signature,
                  :credit_transfer_mandate_frequency,
                  :creditor_contact_details,
                  :creditor_address

    CHARGE_BEARERS = %w[DEBT CRED SHAR SLEV].freeze
    INSTRUCTION3_CODES = %w[CHQB HOLD PHOB TELB].freeze
    FREQUENCY_CODES = %w[YEAR MNTH QURT MIAN WEEK DAIL ADHO INDA FRTN].freeze
    REGULATORY_INDICATORS = RegulatoryReportingValidator::REGULATORY_INDICATORS

    validates_inclusion_of :service_level, in: %w[SEPA URGP], allow_nil: true
    validates_length_of :category_purpose, within: 1..4, allow_nil: true
    validates_inclusion_of :charge_bearer, in: CHARGE_BEARERS, allow_nil: true
    validates :creditor_address, :creditor_contact_details, nested_model: true, allow_nil: true

    convert :debtor_agent_instruction, :instruction_for_debtor_agent, to: :text
    convert :credit_transfer_mandate_id, to: :identifier

    validates_length_of :debtor_agent_instruction, within: 1..140, allow_nil: true
    validates_length_of :instruction_for_debtor_agent, within: 1..140, allow_nil: true
    validates_length_of :instruction_for_debtor_agent_code, within: 1..4, allow_nil: true
    validates_length_of :credit_transfer_mandate_id, within: 1..35, allow_nil: true
    validates_inclusion_of :credit_transfer_mandate_frequency, in: FREQUENCY_CODES, allow_nil: true

    validate { |t| t.validate_requested_date_after(Date.today) }
    validate :validate_instructions_for_creditor_agent
    validate :validate_regulatory_reportings
    validate :validate_credit_transfer_mandate_date_of_signature

    requires_capabilities debtor_agent_instruction: :pmtinf_debtor_agent_instruction,
                          credit_transfer_mandate_id: :mandate_related_info,
                          credit_transfer_mandate_date_of_signature: :mandate_related_info,
                          credit_transfer_mandate_frequency: :mandate_related_info,
                          instruction_for_debtor_agent: :txn_instruction_for_debtor_agent,
                          instruction_for_debtor_agent_code: :txn_instruction_for_debtor_agent,
                          instructions_for_creditor_agent: :instructions_for_creditor_agent,
                          regulatory_reportings: :regulatory_reporting,
                          creditor_contact_details: :contact_details

    def initialize(attributes = {})
      super
      # Ergonomic default: EUR transactions get SvcLvl=SEPA unless the
      # caller overrides it. EPC profiles require SvcLvl to be emitted
      # explicitly, and the alternative (URGP) is rare enough that callers
      # who want it set it explicitly. Profiles that forbid SEPA (e.g.
      # future non-EPC SEPA-zone profiles) can still override via a
      # transaction-level nil assignment.
      self.service_level ||= 'SEPA' if currency == 'EUR'
    end

    def apply_charset(charset)
      super
      @regulatory_reportings = charset_regulatory_reportings(regulatory_reportings, charset)
      @instructions_for_creditor_agent = charset_creditor_agent_instructions(charset)
      self
    end

    def credit_transfer_mandate?
      credit_transfer_mandate_id || credit_transfer_mandate_date_of_signature || credit_transfer_mandate_frequency
    end

    def compatible_features?(profile)
      super &&
        instr_for_dbtr_agt_code_compatible?(profile) &&
        instructions_for_creditor_agent_compatible?(profile) &&
        regulatory_reportings_compatible?(profile)
    end

    private

    def charset_creditor_agent_instructions(charset)
      return instructions_for_creditor_agent unless instructions_for_creditor_agent.is_a?(Array)

      instructions_for_creditor_agent.map do |instruction|
        next instruction unless instruction.is_a?(Hash) && instruction[:instruction_info]

        instruction.merge(instruction_info: charset.text(instruction[:instruction_info]))
      end
    end

    # `instruction_for_debtor_agent_code` is the `Cd` element inside the
    # structured InstrForDbtrAgt block, which only exists when the profile
    # emits that block in structured form (pain.001.001.13+).
    def instr_for_dbtr_agt_code_compatible?(profile)
      !instruction_for_debtor_agent_code || profile.features.instr_for_dbtr_agt_format == :structured
    end

    def instructions_for_creditor_agent_compatible?(profile)
      return true unless instructions_for_creditor_agent&.any?

      instructions_for_creditor_agent.all? { |instr| valid_instruction_code?(instr[:code], profile) }
    end

    def valid_instruction_code?(code, profile)
      return true unless code

      type = profile.features.instr_for_cdtr_agt_code_type
      case type
      when :external_code
        code.to_s.length.between?(1, 4)
      when :instruction3_code
        INSTRUCTION3_CODES.include?(code)
      else
        raise ArgumentError, "Unknown instr_for_cdtr_agt_code_type: #{type.inspect}"
      end
    end

    # v10 RegulatoryReporting requires DbtCdtRptgInd (indicator) and supports type_proprietary.
    # v3 StructuredRegulatoryReporting3 uses plain-text Tp, so type_proprietary is incompatible.
    def regulatory_reportings_compatible?(profile)
      return true unless regulatory_reportings&.any?

      version = profile.features.regulatory_reporting_version
      regulatory_reportings.all? { |r| regulatory_reporting_ok?(r, version) }
    end

    def regulatory_reporting_ok?(reporting, version)
      return false unless reporting.is_a?(Hash)
      return false if version == :v10 && !reporting[:indicator]
      return false if version != :v10 && type_proprietary?(reporting)

      true
    end

    def type_proprietary?(reporting)
      reporting[:details]&.any? { |d| d.is_a?(Hash) && d[:type_proprietary] }
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
        next unless instr[:instruction_info]

        len = instr[:instruction_info].to_s.length
        errors.add(:instructions_for_creditor_agent, "entry #{i} instruction_info must be 1-140 characters") unless len.between?(1, 140)
      end
    end

    def validate_credit_transfer_mandate_date_of_signature
      return unless credit_transfer_mandate_date_of_signature
      return if credit_transfer_mandate_date_of_signature.is_a?(Date)

      errors.add(:credit_transfer_mandate_date_of_signature, 'is not a Date')
    end
  end
end
