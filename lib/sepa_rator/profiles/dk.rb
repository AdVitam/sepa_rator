# frozen_string_literal: true

module SEPA
  module Profiles
    # Deutsche Kreditwirtschaft (DK) / DFÜ-Abkommen profiles for EBICS.
    #
    # DK publishes its own XSDs (`pain.001.001.09_AXZ_GBIC5.xsd`,
    # `pain.008.001.08_AXZ_GBIC5.xsd`) that tighten the ISO baseline with:
    #
    # - a minimum transaction amount of 0.01 (prevents zero-amount submissions)
    # - structured postal addresses only (no AdrLine)
    #
    # The XSDs themselves are not vendored in this gem (licensing) — see
    # `lib/schema/dk/README.md` for instructions on wiring them up in
    # production. Until then, DK profiles reuse the ISO baseline XSDs for
    # validation; the DK-specific business rules are enforced in Ruby via
    # the profile's validators.
    #
    # The `ProfileRegistry` XSD cache is keyed by `profile.id`, so swapping
    # in a real DK XSD later never collides with the ISO baseline even when
    # both profiles reference the same ISO schema name.
    module DK
      VALIDATORS = [
        Validators::CFONB::StructuredAddress,
        Validators::DK::MinAmount
      ].freeze

      FEATURES = {
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_09_GBIC5 = ProfileRegistry.register(
        EPC::SCT_09.with(
          id: 'dk.sct.09.gbic5',
          features: FEATURES,
          validators: VALIDATORS
        )
      )

      SCT_13_GBIC5 = ProfileRegistry.register(
        EPC::SCT_13.with(
          id: 'dk.sct.13.gbic5',
          features: FEATURES,
          validators: VALIDATORS
        )
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_08_GBIC5 = ProfileRegistry.register(
        EPC::SDD_08.with(
          id: 'dk.sdd.08.gbic5',
          features: FEATURES,
          validators: VALIDATORS
        )
      )

      SDD_12_GBIC5 = ProfileRegistry.register(
        EPC::SDD_12.with(
          id: 'dk.sdd.12.gbic5',
          features: FEATURES,
          validators: VALIDATORS
        )
      )
    end
  end
end
