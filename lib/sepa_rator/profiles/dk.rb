# frozen_string_literal: true

module SEPA
  module Profiles
    # Deutsche Kreditwirtschaft (DK) / DFÜ-Abkommen profiles for EBICS.
    #
    # DK publishes its own XSDs (GBIC3 for v03/v02, GBIC5 for v09/v08) that
    # tighten the ISO baseline with a minimum transaction amount of 0.01,
    # structured postal addresses (GBIC5) or `Ctry` + `AdrLine` only (GBIC3),
    # no `CtctDtls` and (GBIC5) no LEI in
    # `FinInstnId`. v13/v12 have no DK schema and follow the ISO one. The
    # vendored XSDs live in the `sepa_rator-dk` gem (downloaded from
    # https://www.ebics.de).
    module DK
      VALIDATORS = [Validators::DK::MinAmount].freeze

      FEATURES = {
        charset: Charset::DK,
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      # GBIC3 (v03/v02) PostalAddressSEPA only supports Ctry + AdrLine.
      LEGACY_FEATURES = {
        charset: Charset::DK,
        min_amount: BigDecimal('0.01')
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03_GBIC3 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'dk.sct.03.gbic3', xsd_path: 'dk/pain.001.001.03_GBIC_3.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details structured_address] })
      )

      SCT_09_GBIC5 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'dk.sct.09.gbic5', xsd_path: 'dk/pain.001.001.09_GBIC_5.xsd',
                         features: FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details agent_lei] })
      )

      SCT_13_GBIC5 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'dk.sct.13.gbic5', features: FEATURES, validators: VALIDATORS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02_GBIC3 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'dk.sdd.02.gbic3', xsd_path: 'dk/pain.008.001.02_GBIC_3.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details structured_address] })
      )

      SDD_08_GBIC5 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'dk.sdd.08.gbic5', xsd_path: 'dk/pain.008.001.08_GBIC_5.xsd',
                         features: FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details agent_lei] })
      )

      SDD_12_GBIC5 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'dk.sdd.12.gbic5', features: FEATURES, validators: VALIDATORS)
      )
    end
  end
end
