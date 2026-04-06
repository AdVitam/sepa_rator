# Changelog

This project is an [AdVitam](https://github.com/AdVitam) fork of
[salesking/sepa_king](https://github.com/salesking/sepa_king).

## [Unreleased]

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
- Credit transfer schema features: `InitnSrc`, `InstrForDbtrAgt` (PmtInf + txn), `InstrForCdtrAgt`, `MndtRltdInf`, `RgltryRptg`, enhanced `RemittanceInformation`

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
