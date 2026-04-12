# frozen_string_literal: true

module SEPA
  module Profiles
    # PSA (Payment Services Austria) / Stuzza profiles.
    #
    # PSA publishes Austrian "Technical Validation Subsets" that tighten the
    # ISO baseline with a minimum amount of 0.01 and (for v09+) structured
    # postal addresses.  The vendored XSDs live in `lib/schema/at/`
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
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true
      }.freeze

      # PSA v03/v02 PostalAddress6 only supports Ctry + AdrLine, not the
      # full structured fields — so we must not require structured addresses.
      LEGACY_FEATURES = {
        min_amount: BigDecimal('0.01')
      }.freeze

      # ─── SEPA Credit Transfer ────────────────────────────────────────────

      SCT_03 = ProfileRegistry.register(
        EPC::SCT_03.with(id: 'at.sct.03', xsd_path: 'at/pain.001.001.03.at.004.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS)
      )

      SCT_09 = ProfileRegistry.register(
        EPC::SCT_09.with(id: 'at.sct.09', xsd_path: 'at/pain.001.001.09.at.005.xsd',
                         features: FEATURES, validators: VALIDATORS)
      )

      SCT_13 = ProfileRegistry.register(
        EPC::SCT_13.with(id: 'at.sct.13', features: FEATURES, validators: VALIDATORS)
      )

      # ─── SEPA Direct Debit ───────────────────────────────────────────────

      SDD_02 = ProfileRegistry.register(
        EPC::SDD_02.with(id: 'at.sdd.02', xsd_path: 'at/pain.008.001.02.at.004.xsd',
                         features: LEGACY_FEATURES, validators: VALIDATORS)
      )

      SDD_08 = ProfileRegistry.register(
        EPC::SDD_08.with(id: 'at.sdd.08', xsd_path: 'at/pain.008.001.08.at.004.xsd',
                         features: FEATURES, validators: VALIDATORS)
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'at.sdd.12', features: FEATURES, validators: VALIDATORS)
      )
    end
  end
end
