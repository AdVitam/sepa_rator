# frozen_string_literal: true

module SEPA
  module Profiles
    # Deutsche Kreditwirtschaft (DK) / DFÜ-Abkommen profiles for EBICS.
    #
    # DK publishes its own XSDs that tighten the ISO baseline with a minimum
    # transaction amount of 0.01 and structured postal addresses. The vendored
    # XSDs live in `lib/schema/dk/` (downloaded from https://www.ebics.de).
    module DK
      VALIDATORS = [Validators::DK::MinAmount].freeze

      FEATURES = {
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      # GBIC3 (v03/v02) PostalAddressSEPA only supports Ctry + AdrLine,
      # not structured fields — so we must not require structured addresses.
      LEGACY_FEATURES = {
        min_amount: BigDecimal('0.01')
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03_GBIC3 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'dk.sct.03.gbic3', xsd_path: 'dk/pain.001.001.03_GBIC_3.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS)
      )

      SCT_09_GBIC5 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'dk.sct.09.gbic5', xsd_path: 'dk/pain.001.001.09_GBIC_5.xsd',
                         features: FEATURES, validators: VALIDATORS)
      )

      SCT_13_GBIC5 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'dk.sct.13.gbic5', features: FEATURES, validators: VALIDATORS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02_GBIC3 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'dk.sdd.02.gbic3', xsd_path: 'dk/pain.008.001.02_GBIC_3.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS)
      )

      SDD_08_GBIC5 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'dk.sdd.08.gbic5', xsd_path: 'dk/pain.008.001.08_GBIC_5.xsd',
                         features: FEATURES, validators: VALIDATORS)
      )

      SDD_12_GBIC5 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'dk.sdd.12.gbic5', features: FEATURES, validators: VALIDATORS)
      )
    end
  end
end
