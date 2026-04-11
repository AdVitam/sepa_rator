# frozen_string_literal: true

module SEPA
  module Profiles
    # Maps (family, country, version) triples to the recommended profile.
    #
    # The `country: nil` entries are the fallback for any country that does
    # not have dedicated profiles registered (e.g. Italy, Spain, Belgium,
    # …). Those callers automatically get generic EPC SEPA profiles.
    #
    # Supported symbols:
    #
    #   family  => :credit_transfer | :direct_debit
    #   country => nil | :fr | :de | …
    #   version => :latest | :v09 | :v13 | :v08 | :v12 | …
    #
    # Usage (from `Message#initialize`):
    #
    #   SEPA::CreditTransfer.new(country: :fr, version: :latest, ...)
    #
    # resolves to `SEPA::Profiles::CFONB::SCT_13` via `ProfileRegistry.recommended`.
    module CountryDefaults
      R = ProfileRegistry

      # ── Default fallback (generic SEPA — EPC) ──────────────────────────

      R.set_country_default(family: :credit_transfer, country: nil, version: :latest,
                            profile: EPC::SCT_13)
      R.set_country_default(family: :credit_transfer, country: nil, version: :v13,
                            profile: EPC::SCT_13)
      R.set_country_default(family: :credit_transfer, country: nil, version: :v09,
                            profile: EPC::SCT_09)

      R.set_country_default(family: :direct_debit, country: nil, version: :latest,
                            profile: EPC::SDD_12)
      R.set_country_default(family: :direct_debit, country: nil, version: :v12,
                            profile: EPC::SDD_12)
      R.set_country_default(family: :direct_debit, country: nil, version: :v08,
                            profile: EPC::SDD_08)

      # ── France → CFONB ────────────────────────────────────────────────

      R.set_country_default(family: :credit_transfer, country: :fr, version: :latest,
                            profile: CFONB::SCT_13)
      R.set_country_default(family: :credit_transfer, country: :fr, version: :v13,
                            profile: CFONB::SCT_13)
      R.set_country_default(family: :credit_transfer, country: :fr, version: :v09,
                            profile: CFONB::SCT_09)

      R.set_country_default(family: :direct_debit, country: :fr, version: :latest,
                            profile: CFONB::SDD_12)
      R.set_country_default(family: :direct_debit, country: :fr, version: :v12,
                            profile: CFONB::SDD_12)
      R.set_country_default(family: :direct_debit, country: :fr, version: :v08,
                            profile: CFONB::SDD_08)

      # ── Germany → DK / DFÜ (registered in the DK profile file) ────────
      # Populated by `lib/sepa_rator/profiles/dk.rb` once the DK profile is
      # introduced in the next refactor step.
    end
  end
end
