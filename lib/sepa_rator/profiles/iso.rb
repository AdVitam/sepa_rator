# frozen_string_literal: true

module SEPA
  module Profiles
    # ISO 20022 generic profiles. These apply the raw ISO XSDs with no
    # community-level restriction. They are the base from which EPC, CFONB,
    # DK/DFÜ, CGI-MP etc. are composed via `Profile#with`.
    module ISO
      CT_STAGE = Builders::CreditTransfer::Transaction
      DD_STAGE = Builders::DirectDebit::Transaction
      private_constant :CT_STAGE, :DD_STAGE

      # XSD element order: PmtId → Amt → [MndtRltdInf] → [UltmtDbtr] → [CdtrAgt] →
      #   [Cdtr] → [CdtrAcct] → [UltmtCdtr] → [InstrForCdtrAgt] →
      #   [InstrForDbtrAgt] → [Purp] → [RgltryRptg] → [RmtInf]
      CREDIT_TRANSFER_STAGES = [
        CT_STAGE::PaymentId,
        CT_STAGE::Amount,
        CT_STAGE::CreditTransferMandate,
        CT_STAGE::UltimateDebtor,
        CT_STAGE::CreditorAgent,
        CT_STAGE::Creditor,
        CT_STAGE::CreditorAccount,
        CT_STAGE::UltimateCreditor,
        CT_STAGE::InstructionsForCreditorAgent,
        CT_STAGE::TxnInstructionForDebtorAgent,
        CT_STAGE::Purpose,
        CT_STAGE::RegulatoryReporting,
        CT_STAGE::RemittanceInformation
      ].freeze

      # XSD element order: PmtId → InstdAmt → DrctDbtTx → [UltmtCdtr] → DbtrAgt →
      #   Dbtr → DbtrAcct → [UltmtDbtr] → [Purp] → [RmtInf]
      DIRECT_DEBIT_STAGES = [
        DD_STAGE::PaymentId,
        DD_STAGE::Amount,
        DD_STAGE::DirectDebitInfo,
        DD_STAGE::UltimateCreditor,
        DD_STAGE::DebtorAgent,
        DD_STAGE::Debtor,
        DD_STAGE::DebtorAccount,
        DD_STAGE::UltimateDebtor,
        DD_STAGE::Purpose,
        DD_STAGE::RemittanceInformation
      ].freeze

      CREDIT_TRANSFER_GROUP_HEADER_STAGES = [Builders::CreditTransfer::GroupHeader].freeze
      CREDIT_TRANSFER_PAYMENT_INFO_STAGES = [Builders::CreditTransfer::PaymentInformation].freeze
      DIRECT_DEBIT_GROUP_HEADER_STAGES = [Builders::DirectDebit::GroupHeader].freeze
      DIRECT_DEBIT_PAYMENT_INFO_STAGES = [Builders::DirectDebit::PaymentInformation].freeze

      # ─── Credit Transfer (pain.001) ──────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        Profile.new(
          id: 'iso.pain.001.001.03',
          family: :credit_transfer,
          iso_schema: 'pain.001.001.03',
          xsd_path: 'iso/pain.001.001.03.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.03',
          features: ProfileFeatures.default.merge(
            bic_tag: :BIC,
            wrap_date: false,
            org_bic_tag: :BICOrBEI,
            instr_for_dbtr_agt_format: :text,
            regulatory_reporting_version: :v3
          ),
          validators: [].freeze,
          capabilities: %i[
            instructions_for_creditor_agent
            txn_instruction_for_debtor_agent
            regulatory_reporting
          ].freeze,
          transaction_stages: CREDIT_TRANSFER_STAGES,
          payment_info_stages: CREDIT_TRANSFER_PAYMENT_INFO_STAGES,
          group_header_stages: CREDIT_TRANSFER_GROUP_HEADER_STAGES,
          accept_transaction: nil
        )
      )

      SCT_09 = ProfileRegistry.register(
        SCT_03.with(
          id: 'iso.pain.001.001.09',
          iso_schema: 'pain.001.001.09',
          xsd_path: 'iso/pain.001.001.09.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.09',
          features: { bic_tag: :BICFI, wrap_date: true, org_bic_tag: :AnyBIC },
          capabilities: %i[uetr lei pmtinf_debtor_agent_instruction]
        )
      )

      SCT_13 = ProfileRegistry.register(
        SCT_09.with(
          id: 'iso.pain.001.001.13',
          iso_schema: 'pain.001.001.13',
          xsd_path: 'iso/pain.001.001.13.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.13',
          features: {
            instr_for_dbtr_agt_format: :structured,
            instr_for_cdtr_agt_code_type: :external_code,
            regulatory_reporting_version: :v10
          },
          capabilities: %i[mandate_related_info initiation_source]
        )
      )

      # EPC AOS rules for CT: EUR only, charge_bearer SLEV-or-nil, SEPA
      # service level is required (not nullable — the EPC rulebook mandates
      # an explicit SvcLvl=SEPA in the emitted XML).
      CT_EPC_RULES = lambda do |txn, _profile|
        (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
          txn.currency == 'EUR' &&
          txn.service_level == 'SEPA'
      end

      # pain.001.002.03 (EPC AOS — requires BIC, SEPA-only)
      SCT_EPC_002_03 = ProfileRegistry.register(
        SCT_03.with(
          id: 'iso.pain.001.002.03',
          iso_schema: 'pain.001.002.03',
          xsd_path: 'iso/pain.001.002.03.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.002.03',
          features: { requires_bic: true, charset: Charset::EPC },
          # EPC AOS drops InstrForCdtrAgt, InstrForDbtrAgt and RgltryRptg —
          # `{ replace: }` clears SCT_03's capabilities rather than appending.
          capabilities: { replace: [].freeze },
          transaction_stages: [
            CT_STAGE::PaymentId,
            CT_STAGE::Amount,
            CT_STAGE::UltimateDebtor,
            CT_STAGE::CreditorAgent,
            CT_STAGE::Creditor,
            CT_STAGE::CreditorAccount,
            CT_STAGE::UltimateCreditor,
            CT_STAGE::Purpose,
            CT_STAGE::RemittanceInformation
          ].freeze,
          accept_transaction: CT_EPC_RULES
        )
      )

      # pain.001.003.03 (EPC AOS — SEPA only)
      SCT_EPC_003_03 = ProfileRegistry.register(
        SCT_EPC_002_03.with(
          id: 'iso.pain.001.003.03',
          iso_schema: 'pain.001.003.03',
          xsd_path: 'iso/pain.001.003.03.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.003.03',
          features: { requires_bic: false }
        )
      )

      # ─── Direct Debit (pain.008) ─────────────────────────────────────────

      # pain.008.001.02 accepts only v1 sequence types (RPRE was added in v08+).
      DD_V1_SEQUENCE_TYPES = %w[FRST OOFF RCUR FNAL].freeze

      # EPC AOS rules for DD: EUR only, no instruction_priority, charge_bearer SLEV-or-nil,
      # only v1 sequence types, CORE or B2B local instrument.
      DD_EPC_RULES = lambda do |txn, _profile|
        txn.instruction_priority.nil? &&
          (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
          txn.currency == 'EUR' &&
          DD_V1_SEQUENCE_TYPES.include?(txn.sequence_type) &&
          %w[CORE B2B].include?(txn.local_instrument)
      end

      SDD_02 = ProfileRegistry.register(
        Profile.new(
          id: 'iso.pain.008.001.02',
          family: :direct_debit,
          iso_schema: 'pain.008.001.02',
          xsd_path: 'iso/pain.008.001.02.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.008.001.02',
          features: ProfileFeatures.default.merge(
            bic_tag: :BIC,
            wrap_date: false,
            org_bic_tag: :BICOrBEI
          ),
          validators: [].freeze,
          capabilities: [].freeze,
          transaction_stages: DIRECT_DEBIT_STAGES,
          payment_info_stages: DIRECT_DEBIT_PAYMENT_INFO_STAGES,
          group_header_stages: DIRECT_DEBIT_GROUP_HEADER_STAGES,
          accept_transaction: ->(txn, _profile) { DD_V1_SEQUENCE_TYPES.include?(txn.sequence_type) }
        )
      )

      SDD_08 = ProfileRegistry.register(
        SDD_02.with(
          id: 'iso.pain.008.001.08',
          iso_schema: 'pain.008.001.08',
          xsd_path: 'iso/pain.008.001.08.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.008.001.08',
          features: { bic_tag: :BICFI, org_bic_tag: :AnyBIC },
          capabilities: %i[uetr lei],
          # v08+ lifts the v1 sequence type constraint (RPRE supported).
          accept_transaction: nil
        )
      )

      SDD_12 = ProfileRegistry.register(
        SDD_08.with(
          id: 'iso.pain.008.001.12',
          iso_schema: 'pain.008.001.12',
          xsd_path: 'iso/pain.008.001.12.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.008.001.12'
        )
      )

      SDD_EPC_002_02 = ProfileRegistry.register(
        SDD_02.with(
          id: 'iso.pain.008.002.02',
          iso_schema: 'pain.008.002.02',
          xsd_path: 'iso/pain.008.002.02.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.008.002.02',
          features: { requires_bic: true, charset: Charset::EPC },
          accept_transaction: DD_EPC_RULES
        )
      )

      SDD_EPC_003_02 = ProfileRegistry.register(
        SDD_02.with(
          id: 'iso.pain.008.003.02',
          iso_schema: 'pain.008.003.02',
          xsd_path: 'iso/pain.008.003.02.xsd',
          namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.008.003.02',
          features: { charset: Charset::EPC },
          accept_transaction: DD_EPC_RULES
        )
      )
    end
  end
end
