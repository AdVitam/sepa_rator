# Changelog

This project is an [AdVitam](https://github.com/AdVitam) fork of
[salesking/sepa_king](https://github.com/salesking/sepa_king).

## [0.15.0] - 2026-04-03

### Added

- Support for `pain.001.001.09` and `pain.001.001.13` credit transfer schemas
- Support for `pain.008.001.08` and `pain.008.001.12` direct debit schemas
- BICFI element support for newer schemas (replaces BIC)
- Date wrapping (`Dt` sub-element) for newer credit transfer schemas
- Lefthook pre-commit hook for automated testing
- SimpleCov test coverage reporting

### Changed

- Minimum Ruby version: 3.1 (was 2.7)
- Minimum ActiveModel version: 7.0 (was 6.1)
- Extracted shared XML helpers (`build_agent_bic`, `build_remittance_information`, `format_amount`) to `Message` base class
- Polymorphic `build_group_header` — creditor identifier rendering moved to `CreditorAccount`
- Replaced `inject(0)` with `sum`, `collect` with `map`
- Added `frozen_string_literal: true` to all spec files
- Full Rubocop compliance (448 offenses resolved)
- Updated gemspec, README, LICENSE, and CONTRIBUTING for AdVitam fork

### Fixed

- Factory typo: `direct_debt_transaction` renamed to `direct_debit_transaction`
- Removed duplicate `debtor_address` attr_accessor in `DirectDebitTransaction`
- All high, medium, and low severity audit issues (see AUDIT.md)

### Security

- Added `rubygems_mfa_required` metadata
- Replaced `send` with `public_send` in converter macro
- Strengthened input validation for amounts, text fields, and identifiers

## [0.14.0] - 2022

Last release by [salesking/sepa_king](https://github.com/salesking/sepa_king).
See [original releases](https://github.com/salesking/sepa_king/releases) for prior history.
