# frozen_string_literal: true

module SEPA
  module Profiles
    # EPC (European Payments Council) SEPA profiles. These reuse the ISO XSDs
    # but tighten them with the EPC rulebook (EUR only, explicit SvcLvl=SEPA,
    # charge bearer SLEV, CORE/B2B local instrument for SDD).
    #
    # The acceptance lambdas themselves live in `ISO::CT_EPC_RULES` and
    # `ISO::DD_EPC_RULES` (defined first in load order) — we simply reuse
    # them here so a bugfix in one place flows to both the ISO AOS variants
    # (`pain.001.002.03`, `pain.001.003.03`, …) and the EPC-flavoured
    # wrappers around pain.001.001.09/.13 and pain.008.001.08/.12.
    #
    # EPC sits between ISO and the national layers (CFONB, DK/DFÜ). Country
    # profiles that carry SEPA semantics compose from EPC, not from ISO.
    #
    # The SEPA character set is enforced at assignment time by the `Converter`
    # DSL (text sanitisation), so no dedicated validator is needed here.
    module EPC
      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        ISO::SCT_03.with(id: 'epc.sct.03', accept_transaction: ISO::CT_EPC_RULES)
      )

      SCT_09 = ProfileRegistry.register(
        ISO::SCT_09.with(id: 'epc.sct.09', accept_transaction: ISO::CT_EPC_RULES)
      )

      SCT_13 = ProfileRegistry.register(
        ISO::SCT_13.with(id: 'epc.sct.13', accept_transaction: ISO::CT_EPC_RULES)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        ISO::SDD_02.with(id: 'epc.sdd.02', accept_transaction: ISO::DD_EPC_RULES)
      )

      SDD_08 = ProfileRegistry.register(
        ISO::SDD_08.with(id: 'epc.sdd.08', accept_transaction: ISO::DD_EPC_RULES)
      )

      SDD_12 = ProfileRegistry.register(
        ISO::SDD_12.with(id: 'epc.sdd.12', accept_transaction: ISO::DD_EPC_RULES)
      )
    end
  end
end
