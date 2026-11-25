# frozen_string_literal: true

module SEPA
  module Profiles
    # PSA (Payment Services Austria) / Stuzza profiles.
    #
    # PSA publishes Austrian "Technical Validation Subsets" (v02/v03/v08/v09)
    # that tighten the ISO baseline: minimum amount of 0.01, structured
    # postal addresses (v09/v08) or `Ctry` + `AdrLine` only (v03/v02),
    # `InitgPty` holding exactly one of `Nm` or
    # `Id`, no `CtctDtls`, and (v09/v08) no LEI in `FinInstnId` and no postal
    # address on the message account. v13/v12 have no PSA subset and follow
    # the ISO schema. The vendored XSDs live in the `sepa_rator-at` gem
    # (downloaded from https://zv.psa.at).
    #
    # The original PSA XSDs use a STUZZA-specific targetNamespace
    # (`ISO:pain.*:APC:STUZZA:payments:*`); the vendored copies keep the
    # ISO namespace because Austrian banks require the ISO namespace for
    # transmission.  XSD 1.1 `xs:assert` elements (cross-field checks
    # already handled in Ruby) have been stripped from v09/v08 schemas so
    # Nokogiri/libxml2 (XSD 1.0 only) can load them.
    module AT
      VALIDATORS = [Validators::MinAmount].freeze

      FEATURES = {
        charset: Charset::AT,
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      SUBSET = {
        features: FEATURES.merge(exclusive_initiating_party: true),
        validators: VALIDATORS,
        capabilities: { remove: %i[contact_details agent_lei account_address] }
      }.freeze

      # PSA v03/v02 PostalAddress6 only supports Ctry + AdrLine.
      LEGACY_SUBSET = {
        features: { charset: Charset::AT, min_amount: BigDecimal('0.01'), exclusive_initiating_party: true },
        validators: VALIDATORS,
        capabilities: { remove: %i[contact_details structured_address] }
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
