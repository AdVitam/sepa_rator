# frozen_string_literal: true

module SEPA
  module Profiles
    # NL (Betaalvereniging / Dutch Payments Association) profiles.
    # Dutch banks follow the EPC SEPA rulebook and add their own
    # implementation guidelines on top — the Betaalvereniging NL IG C2B
    # SCT/SDD 2023 v1.0 covers pain.001.001.09 and pain.008.001.08.
    #
    # NL profiles inherit everything from EPC and require postal addresses
    # to be carried as structured fields (StrtNm, PstCd, TwnNm, …), enforced
    # via `features.requires_structured_address`.
    module NL
      REQUIRES_STRUCTURED_ADDRESS = { requires_structured_address: true }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'nl.sct.03', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SCT_09 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'nl.sct.09', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SCT_13 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'nl.sct.13', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'nl.sdd.02', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SDD_08 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'nl.sdd.08', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'nl.sdd.12', features: REQUIRES_STRUCTURED_ADDRESS)
      )
    end
  end
end
