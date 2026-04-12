# frozen_string_literal: true

module SEPA
  module Profiles
    # CFONB (Comité Français d'Organisation et de Normalisation Bancaires)
    # profiles. French banks follow the EPC SEPA rulebook and add their own
    # implementation guidelines on top — the CFONB guide v2.6 covers
    # pain.001.001.09, pain.001.001.13, pain.008.001.08 and pain.008.001.12.
    #
    # CFONB profiles inherit everything from EPC and require postal addresses
    # to be carried as structured fields (StrtNm, PstCd, TwnNm, …), enforced
    # via `features.requires_structured_address`.
    module CFONB
      REQUIRES_STRUCTURED_ADDRESS = { requires_structured_address: true }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'cfonb.sct.03', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SCT_09 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'cfonb.sct.09', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SCT_13 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'cfonb.sct.13', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'cfonb.sdd.02', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SDD_08 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'cfonb.sdd.08', features: REQUIRES_STRUCTURED_ADDRESS)
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'cfonb.sdd.12', features: REQUIRES_STRUCTURED_ADDRESS)
      )
    end
  end
end
