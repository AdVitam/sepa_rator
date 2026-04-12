# frozen_string_literal: true

module SEPA
  module Profiles
    # Swiss Payment Standards (SPS) profiles, published by the Payments
    # Committee Switzerland (PaCoS) under SIX Group governance.
    #
    # SPS profiles compose from ISO directly — not EPC — because Switzerland
    # accepts both EUR and CHF for domestic and SEPA payments, whereas EPC
    # restricts currency to EUR.
    #
    # The vendored XSDs in `lib/schema/sps/` are downloaded from
    # https://www.six-group.com (Download Center – Payment Standards).
    module SPS
      SPS_CURRENCIES = %w[EUR CHF].freeze

      # Accept EUR and CHF; charge_bearer nil or SLEV; service_level
      # optional (defaults to SEPA for EUR but not for CHF — see
      # CreditTransferTransaction#initialize).
      CT_SPS_RULES = lambda do |txn, _profile|
        (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
          SPS_CURRENCIES.include?(txn.currency) &&
          (txn.service_level.nil? || txn.service_level == 'SEPA')
      end

      # SEPA Direct Debit is EUR-only, even in Switzerland. CHF direct
      # debits use a separate Swiss domestic scheme (LSV+/BDD) outside the
      # scope of this gem.
      DD_SPS_RULES = lambda do |txn, _profile|
        txn.instruction_priority.nil? &&
          (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
          txn.currency == 'EUR' &&
          ISO::DD_V1_SEQUENCE_TYPES.include?(txn.sequence_type) &&
          %w[CORE B2B].include?(txn.local_instrument)
      end

      FEATURES = {
        requires_structured_address: true,
        requires_country_code_on_address: true
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        ISO::SCT_03.with(id: 'sps.sct.03', features: FEATURES,
                         accept_transaction: CT_SPS_RULES)
      )

      SCT_09 = ProfileRegistry.register(
        ISO::SCT_09.with(id: 'sps.sct.09', xsd_path: 'sps/pain.001.001.09.ch.03.xsd',
                         features: FEATURES, accept_transaction: CT_SPS_RULES)
      )

      SCT_13 = ProfileRegistry.register(
        ISO::SCT_13.with(id: 'sps.sct.13', features: FEATURES,
                         accept_transaction: CT_SPS_RULES)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      # The Swiss SDD v02 XSD uses a non-ISO namespace
      # (http://www.six-interbank-clearing.com/…) for Swiss domestic direct
      # debit. For standard SEPA SDD, the ISO baseline XSD applies.
      SDD_02 = ProfileRegistry.register(
        ISO::SDD_02.with(id: 'sps.sdd.02', features: FEATURES,
                         accept_transaction: DD_SPS_RULES)
      )

      SDD_08 = ProfileRegistry.register(
        ISO::SDD_08.with(id: 'sps.sdd.08', features: FEATURES,
                         accept_transaction: DD_SPS_RULES)
      )

      SDD_12 = ProfileRegistry.register(
        ISO::SDD_12.with(id: 'sps.sdd.12', features: FEATURES,
                         accept_transaction: DD_SPS_RULES)
      )
    end
  end
end
