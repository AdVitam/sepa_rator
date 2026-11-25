# frozen_string_literal: true

module SEPA
  module Profiles
    # DK (DFÜ-Abkommen, EBICS) GBIC3/GBIC5 subsets; v13/v12 have no DK schema: plain ISO.
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

      # GBIC credit transfer schemas drop these.
      UNSUPPORTED_CT_CAPABILITIES = %i[txn_instruction_for_debtor_agent instructions_for_creditor_agent regulatory_reporting].freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03_GBIC3 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'dk.sct.03.gbic3', xsd_path: 'dk/pain.001.001.03_GBIC_3.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details structured_address] + UNSUPPORTED_CT_CAPABILITIES })
      )

      SCT_09_GBIC5 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'dk.sct.09.gbic5', xsd_path: 'dk/pain.001.001.09_GBIC_5.xsd',
                         features: FEATURES, validators: VALIDATORS,
                         capabilities: { remove: %i[contact_details agent_lei uetr pmtinf_debtor_agent_instruction] + UNSUPPORTED_CT_CAPABILITIES })
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
                         capabilities: { remove: %i[contact_details agent_lei uetr] })
      )

      SDD_12_GBIC5 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'dk.sdd.12.gbic5', features: FEATURES, validators: VALIDATORS)
      )
    end
  end
end
