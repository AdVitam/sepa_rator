# frozen_string_literal: true

module SEPA
  module Profiles
    # CFONB (Comité Français d'Organisation et de Normalisation Bancaires)
    # profiles. French banks follow the EPC SEPA rulebook and add their own
    # implementation guidelines on top — the CFONB guide v2.6 applies to
    # pain.001.001.03/09 and pain.008.001.02/08.
    #
    # CFONB profiles inherit everything from EPC (XSD, stages, capabilities,
    # SEPA rules) and layer on French business rules:
    #
    # - Postal addresses must be carried as structured fields (StrtNm, PstCd,
    #   TwnNm, …). French banks reject files that only populate AdrLine, in
    #   line with the EPC 2024+ structured-address migration.
    module CFONB
      REQUIRES_STRUCTURED_ADDRESS = { requires_structured_address: true }.freeze
      VALIDATORS = [Validators::CFONB::StructuredAddress].freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_09 = ProfileRegistry.register(
        EPC::SCT_09.with(
          id: 'cfonb.sct.09',
          features: REQUIRES_STRUCTURED_ADDRESS,
          validators: VALIDATORS
        )
      )

      SCT_13 = ProfileRegistry.register(
        EPC::SCT_13.with(
          id: 'cfonb.sct.13',
          features: REQUIRES_STRUCTURED_ADDRESS,
          validators: VALIDATORS
        )
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_08 = ProfileRegistry.register(
        EPC::SDD_08.with(
          id: 'cfonb.sdd.08',
          features: REQUIRES_STRUCTURED_ADDRESS,
          validators: VALIDATORS
        )
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(
          id: 'cfonb.sdd.12',
          features: REQUIRES_STRUCTURED_ADDRESS,
          validators: VALIDATORS
        )
      )
    end
  end
end
