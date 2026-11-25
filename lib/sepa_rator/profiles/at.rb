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
    # transmission.  XSD 1.1 `xs:assert` elements have been stripped from
    # v09/v08 schemas so Nokogiri/libxml2 (XSD 1.0 only) can load them.
    module AT
      VALIDATORS = [Validators::MinAmount].freeze
      SDD_VALIDATORS = [*VALIDATORS, Validators::SingleAmendmentDetail].freeze

      # "GENAU/NUR EIN FOLGE-ELEMENT" types of the PSA XSDs: asserts in v08/v09,
      # documentation only in v02/v03, so `single_child_paths` enforces them.
      LEGACY_SINGLE_CHILD_PATHS = %w[GrpHdr/InitgPty GrpHdr/InitgPty/Id/OrgId RmtInf FinInstnId].freeze
      SINGLE_CHILD_PATHS = [*LEGACY_SINGLE_CHILD_PATHS, 'UltmtCdtr', 'UltmtDbtr'].freeze
      SDD_SINGLE_CHILD_PATHS = [*SINGLE_CHILD_PATHS, 'AmdmntInfDtls', 'OrgnlCdtrSchmeId'].freeze

      FEATURES = {
        charset: Charset::AT,
        min_amount: BigDecimal('0.01'),
        requires_structured_address: true,
        single_child_paths: SINGLE_CHILD_PATHS
      }.freeze
      SDD_FEATURES = FEATURES.merge(single_child_paths: SDD_SINGLE_CHILD_PATHS).freeze

      # PSA v03/v02 PostalAddress6 only supports Ctry + AdrLine, not the
      # full structured fields — so we must not require structured addresses.
      LEGACY_FEATURES = {
        charset: Charset::AT,
        min_amount: BigDecimal('0.01'),
        single_child_paths: LEGACY_SINGLE_CHILD_PATHS
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
                         features: SDD_FEATURES, validators: SDD_VALIDATORS)
      )

      SDD_12 = ProfileRegistry.register(
        EPC::SDD_12.with(id: 'at.sdd.12', features: SDD_FEATURES, validators: SDD_VALIDATORS)
      )
    end
  end
end
