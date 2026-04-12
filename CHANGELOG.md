# Changelog

Successor to [salesking/sepa_king](https://github.com/salesking/sepa_king) (unmaintained since 2022).

## [1.2.0] - 2026-04-15

### Added

- Netherlands (NL) profiles following Betaalvereniging guidelines (`country: :nl`).
  Composes from EPC with structured address requirement.
  Profiles: `nl.sct.03`, `nl.sct.09`, `nl.sct.13`, `nl.sdd.02`, `nl.sdd.08`, `nl.sdd.12`.
- United Kingdom (GB) profiles for CHAPS and SEPA (`country: :gb`)
- Austria (AT) profiles with PSA/Stuzza XSD validation (`country: :at`)

### Changed

- Add Ruby 4.0 to CI test matrix (Rails 8.1 only)
- Extract shared `Validators::MinAmount` from `Validators::DK::MinAmount`
- Use `File.open` instead of `File.read` for XSD loading to support `xs:include`/`xs:redefine`
- README: condense Features section and add supported schemas & profiles table

## [1.1.0] - 2026-04-12

### Added

- Swiss Payment Standards (SPS) profiles for Switzerland (`country: :ch`).
  Extends ISO with EUR+CHF support, structured addresses, and country code
  requirement. Profiles: `sps.sct.03`, `sps.sct.09`, `sps.sct.13`,
  `sps.sdd.02`, `sps.sdd.08`, `sps.sdd.12`.
- Legacy v03/v02 profiles for EPC (`epc.sct.03`, `epc.sdd.02`), CFONB
  (`cfonb.sct.03`, `cfonb.sdd.02`), and DK (`dk.sct.03.gbic3`,
  `dk.sdd.02.gbic3`). These cover pain.001.001.03 and pain.008.001.02
  which remain widely used until November 2026.
- Vendor DK XSD files: GBIC5 (`pain.001.001.09_GBIC_5.xsd`,
  `pain.008.001.08_GBIC_5.xsd`) and GBIC3 (`pain.001.001.03_GBIC_3.xsd`,
  `pain.008.001.02_GBIC_3.xsd`). DK profiles now validate against the
  real Deutsche Kreditwirtschaft schemas instead of the ISO baseline.
- Vendor SPS XSD file (`pain.001.001.09.ch.03.xsd`) for Swiss CT schema
  validation.
- Enforce `requires_country_code_on_address` profile feature — validates
  that postal addresses include a country code when the profile mandates it.

## [1.0.0] - 2026-04-11

### Breaking

- `SEPA::CreditTransfer.new` / `SEPA::DirectDebit.new` now take
  `country:` / `version:` / `profile:` keyword arguments; `to_xml` takes
  no arguments. The string-based `to_xml('pain.001.001.09')` API is
  removed, along with `SEPA::PAIN_*` constants and `SCHEMA_FEATURES`.
- Profile compatibility is enforced at `Message.new` (account vs. profile)
  and `add_transaction` (transaction vs. profile). Previously some of
  these checks ran only at `to_xml`. Callers must now catch
  `SEPA::ValidationError` earlier in the flow. All profile-related errors
  now raise `SEPA::ValidationError` (not `SEPA::SchemaValidationError`)
  and carry `[profile.id]` in the message.
- Transaction compatibility uses `Transaction#compatible_with?(profile)`
  instead of `schema_compatible?(schema_name)`.
- Swiss variant (`pain.001.001.03.ch.02`) dropped.
- `SEPA::XmlBuilder` is now a stateless helper module (`module_function`)
  taking explicit arguments; consumers can no longer mix it in.
- XSDs moved from `lib/schema/pain.*.xsd` to `lib/schema/iso/pain.*.xsd`.

### Added

- `SEPA::Profile` value object and `SEPA::ProfileRegistry` — profiles
  describe a full variant (XSD, namespace, features, validators,
  builder stages) and compose via `#with`.
- National profiles: `SEPA::Profiles::ISO`, `EPC`, `CFONB` (🇫🇷),
  `DK` (🇩🇪).
- Public resolution via `country:` / `version:` — `country: :fr` picks
  CFONB, `country: :de` picks DK, unknown countries fall back to EPC.
- `SEPA::UnsupportedVersionError` with `country`, `version`,
  `available_versions`.

### Fixed

- XSD cache collision when two profiles share an ISO schema name but
  point to different XSD files (the cache is now keyed by
  `profile.xsd_path`).

## [0.16.0] - 2026-04-08

### Breaking

- Unknown attributes on `Account.new`, `Transaction.new`, etc. now raise `ActiveModel::UnknownAttributeError` instead of `ArgumentError`
- `SEPA::IBANValidator::REGEX` constant removed — use `IBANValidator.valid_iban?` instead
- Invalid `creditor_account` on `DirectDebitTransaction` now propagates detailed validation errors instead of the generic `'is not correct'` message

### Changed

- Replace `iban-tools` dependency with `ibandit` (GoCardless) — stricter country-specific IBAN validation, enriched error messages
- Replace custom `AttributeInitializer` with `ActiveModel::Model`
- Replace duplicated nested validation blocks with reusable `NestedModelValidator`

### Added

- `IBANValidator.valid_iban?` class method for standalone IBAN validation
- `SEPA.mod97_valid?` shared helper for ISO 7064 Mod 97-10 checksum
- `LEIValidator` now verifies mod-97 checksum (was format-only)

## [0.15.0] - 2026-04-06

### Changed

- Gem renamed from `sepa_king` to `sepa_rator`

### Added

- Support for `pain.001.001.09`, `pain.001.001.13`, `pain.008.001.08`, `pain.008.001.12` schemas
- BICFI element support for newer schemas (replaces BIC)
- RPRE sequence type for `pain.008.001.08`/`.12`
- Optional UETR field (UUIDv4) for newer schemas
- Extended PostalAddress fields (CareOf, BldgNm, Floor, Room, etc.)
- Instruction priority (`InstrPrty`: HIGH/NORM)
- Account-level postal address support for Credit Transfer (debtor) and Direct Debit (creditor)
- Flexible charge bearer (`charge_bearer`) with support for DEBT, CRED, SHAR, SLEV
- Original mandate ID support in amendment information (`original_mandate_id`)
- Credit transfer schema features: `InitnSrc`, `InstrForDbtrAgt`, `InstrForCdtrAgt`, `MndtRltdInf`, `RgltryRptg`, enhanced `RemittanceInformation`
- LEI (Legal Entity Identifier) on `FinInstnId` and `OrgId` (v09/v13)
- `BICOrBEI` / `AnyBIC` in `OrganisationIdentification`
- ContactDetails (`CtctDtls`) on parties — `SEPA::ContactDetails` class
- Complete `RegulatoryReporting` with `Authrty`, `Tp`, `Dt`, `Ctry`, `Amt`
- `LEIValidator` for reuse in external models

### Changed

- Minimum Ruby version: 3.2 (was 2.7)
- Minimum ActiveModel version: 7.0 (was 6.1)
- `SCHEMA_FEATURES` centralized hash for schema-dependent behavior
- Architecture: `AttributeInitializer`, `SchemaValidation`, `XmlBuilder` concerns, `Data.define` grouping value objects
- Full Rubocop compliance, `frozen_string_literal` on all files

### Fixed

- `known_schemas` guard in `schema_compatible?` (cross-family schemas now raise properly)
- XSD cache race condition with double-checked locking
- Empty string BIC rejection for Swiss schemas
- BIC validator now accepts `BICFIDec2014Identifier` pattern for v09/v13 schemas

### Security

- Replaced `send` with `public_send` in all validators
- Attribute allowlisting in `initialize` — unknown attributes raise `ArgumentError`
- Thread-safe schema cache with `Mutex`
- UTF-8 encoding enforcement in `convert_text`
- Strengthened input validation for amounts, text fields, and identifiers

## [0.14.0] - 2022

Last release by [salesking/sepa_king](https://github.com/salesking/sepa_king).
See [original releases](https://github.com/salesking/sepa_king/releases) for prior history.
