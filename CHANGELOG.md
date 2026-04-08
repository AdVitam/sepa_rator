# Changelog

Successor to [salesking/sepa_king](https://github.com/salesking/sepa_king) (unmaintained since 2022).

## [Unreleased]

### Changed

- **BREAKING**: Unknown attributes passed to `Account.new`, `Transaction.new`, etc. now raise `ActiveModel::UnknownAttributeError` instead of `ArgumentError`. Consumers that `rescue ArgumentError` around `.new()` must update their error handling.
- **BREAKING**: Invalid `creditor_account` on `DirectDebitTransaction` now propagates detailed validation errors instead of the generic `'is not correct'` message. Code pattern-matching on that exact string must be updated.
- **BREAKING**: `SEPA::IBANValidator::REGEX` constant removed — use `IBANValidator.valid_iban?` instead
- Replace `iban-tools` dependency with `ibandit` (GoCardless) — actively maintained, stricter country-specific IBAN validation
- Replace custom `AttributeInitializer` concern with `ActiveModel::Model` (ships with `ActiveModel::Validations` + `ActiveModel::AttributeAssignment` + `initialize` natively)
- Replace 7 duplicated nested validation blocks and `validates_address` DSL with reusable `NestedModelValidator` (`ActiveModel::EachValidator`)
- Restore `ActiveSupport::Concern` in `SchemaValidation` (reverts pure-Ruby replacement)
- IBAN error messages now include details from ibandit (e.g. "is invalid (check_digits is invalid)")

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
