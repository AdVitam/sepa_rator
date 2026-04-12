# frozen_string_literal: true

module SEPA
  module Profiles
    # United Kingdom (GB) profiles for CHAPS (high-value GBP payments) and
    # SEPA (EUR payments). Composes from ISO directly — not EPC — because
    # CHAPS uses GBP and permits charge bearers beyond SLEV.
    #
    # No UK-specific XSD exists; the ISO baseline XSDs apply.
    module GB
      GB_CURRENCIES = %w[EUR GBP].freeze

      # EUR: SEPA rules (SLEV, service_level SEPA).
      # GBP: CHAPS-permissive (any charge_bearer, service_level nil or URGP).
      CT_GB_RULES = lambda do |txn, _profile|
        return false unless GB_CURRENCIES.include?(txn.currency)

        if txn.currency == 'EUR'
          (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
            txn.service_level == 'SEPA'
        else # GBP
          txn.service_level.nil? || txn.service_level == 'URGP'
        end
      end

      # SEPA Direct Debit is EUR-only. GBP direct debits use Bacs
      # (Standard 18 format), which is outside the scope of this gem.
      DD_GB_RULES = lambda do |txn, _profile|
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

      # ── Credit Transfer ────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        ISO::SCT_03.with(id: 'gb.sct.03', features: FEATURES, accept_transaction: CT_GB_RULES)
      )

      SCT_09 = ProfileRegistry.register(
        ISO::SCT_09.with(id: 'gb.sct.09', features: FEATURES, accept_transaction: CT_GB_RULES)
      )

      SCT_13 = ProfileRegistry.register(
        ISO::SCT_13.with(id: 'gb.sct.13', features: FEATURES, accept_transaction: CT_GB_RULES)
      )

      # ── Direct Debit ───────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        ISO::SDD_02.with(id: 'gb.sdd.02', features: FEATURES, accept_transaction: DD_GB_RULES)
      )

      SDD_08 = ProfileRegistry.register(
        ISO::SDD_08.with(id: 'gb.sdd.08', features: FEATURES, accept_transaction: DD_GB_RULES)
      )

      SDD_12 = ProfileRegistry.register(
        ISO::SDD_12.with(id: 'gb.sdd.12', features: FEATURES, accept_transaction: DD_GB_RULES)
      )
    end
  end
end
