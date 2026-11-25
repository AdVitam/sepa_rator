# frozen_string_literal: true

module SEPA
  module Profiles
    # Vendored PSA XSDs keep the ISO namespace banks require, not STUZZA's, and drop
    # XSD 1.1 asserts libxml2 cannot load. v13/v12 have no PSA subset: plain ISO.
    module AT
      VALIDATORS = [Validators::MinAmount].freeze

      FEATURES = {
        charset: Charset::AT,
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      # PSA credit transfer schemas drop these; `remove` is a no-op for direct debit profiles.
      UNSUPPORTED_CT_CAPABILITIES = %i[txn_instruction_for_debtor_agent instructions_for_creditor_agent regulatory_reporting].freeze

      SUBSET = {
        features: FEATURES.merge(exclusive_initiating_party: true),
        validators: VALIDATORS,
        capabilities: { remove: %i[contact_details agent_lei account_address] + UNSUPPORTED_CT_CAPABILITIES }
      }.freeze

      # PSA v03/v02 PostalAddress6 only supports Ctry + AdrLine.
      LEGACY_SUBSET = {
        features: { charset: Charset::AT, min_amount: BigDecimal('0.01'), exclusive_initiating_party: true },
        validators: VALIDATORS,
        capabilities: { remove: %i[contact_details structured_address] + UNSUPPORTED_CT_CAPABILITIES }
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'at.sct.03', xsd_path: 'at/pain.001.001.03.at.004.xsd', **LEGACY_SUBSET)
      )

      SCT_09 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'at.sct.09', xsd_path: 'at/pain.001.001.09.at.005.xsd', **SUBSET)
      )

      SCT_13 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'at.sct.13', features: FEATURES, validators: VALIDATORS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'at.sdd.02', xsd_path: 'at/pain.008.001.02.at.004.xsd', **LEGACY_SUBSET)
      )

      SDD_08 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'at.sdd.08', xsd_path: 'at/pain.008.001.08.at.004.xsd', **SUBSET)
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'at.sdd.12', features: FEATURES, validators: VALIDATORS)
      )
    end
  end
end
