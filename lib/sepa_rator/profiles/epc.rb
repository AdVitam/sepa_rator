# frozen_string_literal: true

module SEPA
  module Profiles
    # EPC (European Payments Council) SEPA profiles. These reuse the ISO XSDs
    # but tighten them with the EPC rulebook:
    #
    # - currency must be EUR
    # - service level, if set, must be SEPA (not URGP)
    # - charge bearer, if set, must be SLEV
    #
    # EPC sits between ISO and the national layers (CFONB, DK/DFÜ). Country
    # profiles that carry SEPA semantics compose from EPC, not from ISO.
    #
    # The SEPA character set is enforced at assignment time by the `Converter`
    # DSL (text sanitisation), so no dedicated validator is needed here.
    module EPC
      SCT_RULES = lambda do |txn, _profile|
        txn.currency == 'EUR' &&
          (txn.service_level.nil? || txn.service_level == 'SEPA') &&
          (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV')
      end

      SDD_RULES = lambda do |txn, _profile|
        txn.currency == 'EUR' &&
          (txn.charge_bearer.nil? || txn.charge_bearer == 'SLEV') &&
          %w[CORE B2B].include?(txn.local_instrument)
      end

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_09 = ProfileRegistry.register(
        ISO::SCT_09.with(id: 'epc.sct.09', accept_transaction: SCT_RULES)
      )

      SCT_13 = ProfileRegistry.register(
        ISO::SCT_13.with(id: 'epc.sct.13', accept_transaction: SCT_RULES)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_08 = ProfileRegistry.register(
        ISO::SDD_08.with(id: 'epc.sdd.08', accept_transaction: SDD_RULES)
      )

      SDD_12 = ProfileRegistry.register(
        ISO::SDD_12.with(id: 'epc.sdd.12', accept_transaction: SDD_RULES)
      )
    end
  end
end
