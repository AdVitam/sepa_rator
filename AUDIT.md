# Global audit — sepa_king (AdVitam fork)

**Date**: 2026-04-03
**Audited version**: 0.14.0 (last release: October 2022)
**Context**: Fork to add pain.001.001.09 support (PR #117) and modernize the gem for api-advitam (Ruby 3.4, Rails 8.1)

---

## Executive summary

The gem is functional and secure for basic use, but has had no maintenance for four years: outdated schemas, overly broad dependencies, and gaps in business validation. PR #117 (pain.001.001.09 / pain.008.001.08) adds the required support but includes a critical bug and German XSDs instead of pure ISO ones.

**Deadline**: older pain.001.001.03 / pain.008.001.02 versions become obsolete in **November 2026**.

---

## CRITICAL

### C1 — PR #117 bug: `account.bic` regression in direct_debit.rb

- **File**: `lib/sepa_king/message/direct_debit.rb`, `CdtrAgt` block
- **Issue**: The PR replaces `group[:account].bic` with `account.bic` in both branches (BICFI and BIC). When a transaction uses a `creditor_account` different from the main account, the wrong BIC is emitted.
- **Impact**: Regression for **all** existing DD schemas, not only the new .08
- **Fix**: Restore `group[:account].bic` in both places

```ruby
# BEFORE (buggy)
builder.BICFI(account.bic)
builder.BIC(account.bic)

# AFTER (fixed)
builder.BICFI(group[:account].bic)
builder.BIC(group[:account].bic)
```

- [x] Fixed

### C2 — Outdated schemas (2009)

- **Issue**: Current schemas (pain.001.001.03, pain.008.001.02) date from 2009. The EPC has recommended .09/.08 since 2023; CFONB (France) mandates them for new implementations.
- **Deadline**: November 2026 for migration
- **Fix**: Merge PR #117 (with corrections)

- [x] Fixed (+ added pain.001.001.13 and pain.008.001.12)

### C3 — PR #117 XSDs = German DK subsets

- **Issue**: The `pain.001.001.09.xsd` and `pain.008.001.08.xsd` files in the PR are “Technical Validation Subsets” from Deutsche Kreditwirtschaft (DK), not official ISO 20022 XSDs. They impose Germany-specific market restrictions.
- **Impact**: Risk of rejection by French banks (different structured address rules, etc.)
- **Fix**: Replace with official ISO 20022 or EPC XSDs

- [x] Fixed (using official ISO 20022 XSDs from iso20022.org)

---

## HIGH

### H1 — Overly broad version constraints in the gemspec

- **File**: `sepa_king.gemspec`
- **Issue**: `activemodel >= 4.2` allows versions with known CVEs (Rails 4.x, 5.x). Unconstrained `nokogiri` allows old vulnerable versions.
- **Fix**: `activemodel >= 6.1, < 9` and `nokogiri >= 1.13`

- [ ] Fixed

### H2 — No XML validation tests for the new schemas (PR #117)

- **Issue**: The PR adds `schema_compatible?` tests but no `validate_against('pain.001.001.09.xsd')` or `validate_against('pain.008.001.08.xsd')`. Generated XML is never validated against the new XSDs.
- **Fix**: Add mirror tests like those for the other schemas

- [x] Fixed (24 new XSD validation tests added)

### H3 — Full duplication CreditorAddress / DebtorAddress

- **Files**: `lib/sepa_king/account/creditor_address.rb`, `lib/sepa_king/account/debtor_address.rb`
- **Issue**: 38 strictly identical lines × 2. Address XML construction in `credit_transfer.rb` and `direct_debit.rb` is also duplicated.
- **Fix**: Extract `SEPA::Address` as a base class + `build_postal_address(builder, address)` on `Message`

- [ ] Fixed

### H4 — Flat error hierarchy

- **File**: `lib/sepa_king/error.rb`
- **Issue**: Single class `SEPA::Error < RuntimeError`. Inconsistent mix with raw `ArgumentError`. No way to `rescue` selectively.
- **Fix**: Typed hierarchy: `SEPA::Error` → `SEPA::ValidationError`, `SEPA::SchemaValidationError`

- [ ] Fixed

### H5 — Potentially empty `PmtTpInf`

- **File**: `lib/sepa_king/message/credit_transfer.rb`
- **Issue**: The `PmtTpInf` block is generated even when both `service_level` and `category_purpose` are nil, producing an empty XML element that XSD may reject.
- **Fix**: Only generate the block when at least one child is present

- [ ] Fixed

### H6 — No maximum amount

- **Issue**: SEPA XSD enforces `maxInclusive 999999999.99`. Ruby validation only has `greater_than: 0`. An amount > 1 billion passes Ruby validation but fails XSD.
- **Fix**: Add `less_than_or_equal_to: 999_999_999.99` to `amount` validation

- [ ] Fixed

---

## MEDIUM

### M1 — Validation messages exposing IBAN/BIC

- **Files**: `lib/sepa_king/account.rb:11`, `lib/sepa_king/transaction.rb:33`
- **Issue**: `message: "%{value} is invalid"` exposes the actual IBAN/BIC in error messages. If logged to Sentry, financial data may leak.
- **Fix**: Use `message: "is invalid"` instead

- [ ] Fixed

### M2 — Ruby 3.4 and ActiveModel 8.x not tested in CI

- **Files**: `.github/workflows/main.yml`, `gemfiles/`
- **Issue**: CI tests Ruby 3.0–3.3, ActiveModel 6.1–7.1. api-advitam uses Ruby 3.4.7 and Rails 8.1.
- **Fix**: Add Ruby 3.4 to the matrix, add `gemfiles/Gemfile-activemodel-8.1.x`

- [ ] Fixed

### M3 — Missing `frozen_string_literal: true`

- **Issue**: No file has the pragma. All have obsolete `# encoding: utf-8` (unnecessary since Ruby 2.0).
- **Fix**: Replace `# encoding: utf-8` with `# frozen_string_literal: true` in all files

- [ ] Fixed

### M4 — Inconsistent `send` vs `public_send`

- **File**: `lib/sepa_king/transaction.rb:37`
- **Issue**: `Transaction#initialize` uses `send("#{name}=", value)` while `Account#initialize` uses `public_send`. `send` can invoke private methods.
- **Fix**: Use `public_send`

- [ ] Fixed

### M5 — `creditor_address` declared twice

- **Files**: `lib/sepa_king/transaction.rb`, `lib/sepa_king/transaction/credit_transfer_transaction.rb`
- **Issue**: `attr_accessor :creditor_address` exists on both parent and child. The child silently overrides the parent accessor.
- **Fix**: Remove the duplicate declaration from `CreditTransferTransaction`

- [ ] Fixed

### M6 — XSD schema read/parsed on every `to_xml`

- **File**: `lib/sepa_king/message.rb:163-166`
- **Issue**: `validate_final_document!` reads and reparses the XSD file on every call. For batch generation this is a significant waste.
- **Fix**: Cache in a class constant

```ruby
SCHEMA_CACHE = {}
def validate_final_document!(document, schema_name)
  xsd = SCHEMA_CACHE[schema_name] ||= Nokogiri::XML::Schema(File.read(...))
  # ...
end
```

- [ ] Fixed

### M7 — `transactions` recomputed on every call

- **File**: `lib/sepa_king/message.rb`
- **Issue**: `transactions` does `grouped_transactions.values.flatten` on every call (4+ times during `to_xml`). No memoization.
- **Fix**: Memoize with invalidation in `add_transaction`

- [ ] Fixed

### M8 — Double `transaction_group()` call in `add_transaction`

- **File**: `lib/sepa_king/message.rb`
- **Issue**: `transaction_group(transaction)` is called twice, creating two identical temporary hashes.
- **Fix**: `group = transaction_group(transaction)` then reuse

- [ ] Fixed

### M9 — `convert_decimal` fails silently

- **File**: `lib/sepa_king/converter.rb`
- **Issue**: `BigDecimal(value.to_s)` inside `rescue ArgumentError` returns `nil` silently. The follow-up validation error (“is not a number”) hides the root cause.
- **Fix**: Log or raise an explicit error

- [ ] Fixed

### M10 — No address validation on Transaction

- **File**: `lib/sepa_king/transaction.rb`
- **Issue**: `debtor_address` and `creditor_address` are never validated. An invalid address (e.g. 5-char `country_code`) reaches final XSD validation with a cryptic error.
- **Fix**: Validate addresses in `Transaction#valid?`

- [ ] Fixed

### M11 — Non-SEPA characters in `convert_text`

- **File**: `lib/sepa_king/converter.rb`
- **Issue**: The whitelist includes `&*$%`, which are not in the basic SEPA character set (`a-z A-Z 0-9 / - ? : ( ) . , ' + space`). Banks may reject them.
- **Fix**: Remove `&*$%` from the whitelist or replace them

- [ ] Fixed

### M12 — No mod-97 validation on creditor identifier

- **File**: `lib/sepa_king/validator.rb`
- **Issue**: Creditor identifier includes an ISO 7064 mod-97 check digit that is not verified. Only the regex is applied.
- **Fix**: Add mod-97 check (similar to IBAN)

- [ ] Fixed

### M13 — No structured remittance information (Strd)

- **Issue**: Only `RmtInf/Ustrd` (free text) is supported. No `RmtInf/Strd/CdtrRefInf` (ISO 11649 creditor reference). Required by some institutional creditors.
- **Fix**: Add optional `structured_remittance_information` support

- [ ] Fixed

### M14 — `PmtInfId` can exceed 35 characters

- **File**: `lib/sepa_king/message.rb`
- **Issue**: `PmtInfId` = `"#{message_identification}/#{index+1}"`. If MsgId is 30 chars and index > 9, length exceeds XSD’s 35 chars.
- **Fix**: Truncate or validate length

- [ ] Fixed

---

## LOW

### B1 — COR1 deprecated

- **File**: `lib/sepa_king/transaction/direct_debit_transaction.rb`
- `COR1` (Accelerated Direct Debit) deprecated by the EPC in November 2017. Keep for backward compatibility but add a warning.

- [ ] Fixed

### B2 — `required_ruby_version >= 2.7` too low

- **File**: `sepa_king.gemspec`
- Ruby 2.7 has been EOL since 2023. Move to `>= 3.1`.

- [ ] Fixed

### B3 — Outdated `actions/checkout@v3` in CI

- **File**: `.github/workflows/main.yml`
- v3 uses Node.js 16 (EOL). Upgrade to v4.

- [ ] Fixed

### B4 — Deprecated `add_development_dependency`

- **File**: `sepa_king.gemspec`
- Deprecated in favor of `Gemfile` since Bundler 2.x.

- [ ] Fixed

### B5 — No XML injection tests

- No tests verify behavior against XML injection attempts in text fields. Nokogiri Builder escapes automatically but tests never assert it.

- [ ] Fixed

### B6 — Fragile tests with `Date.today` and `Time.now`

- Several tests compare against `Date.today` or `Time.now.iso8601`. Risk of flaky tests around midnight.

- [ ] Fixed

### B7 — EPC character set skewed toward German

- **File**: `lib/sepa_king/converter.rb`
- The whitelist includes German umlauts (ÄÖÜäöüß) but not French/Spanish accents. Extended EPC set (EPC217-08) allows them.

- [ ] Fixed

### B8 — Undocumented `DEFAULT_REQUESTED_DATE`

- **File**: `lib/sepa_king/transaction.rb`
- `Date.new(1999, 1, 1)` is an undocumented “as soon as possible” convention.

- [ ] Fixed

### B9 — No TARGET2 business-day validation

- Execution dates on weekends/holidays are accepted but may be rejected by the bank.

- [ ] Fixed

### B10 — Assignment in condition in validator

- **File**: `lib/sepa_king/validator.rb:51`
- `if ok = creditor_identifier.to_s.match?(REGEX)` — code smell; RuboCop would flag it.

- [ ] Fixed

---

## Strengths

- **Solid XML security**: Nokogiri Builder escapes automatically; no input XML parsing (no XXE)
- **Systematic XSD validation** in `to_xml` — effective safety net
- **100% line coverage** on existing tests (204 specs, 0 failures)
- **No dangerous patterns** (eval, system, exec, Marshal, YAML.load)
- **IBAN/BIC validations** aligned with ISO 13616 / ISO 9362
- **Clear architecture** with Template Method used well
- **Converter `convert_text`** sanitizes text fields correctly (double protection with Nokogiri)

---

## Suggested action plan

### Phase 1 — Corrected PR #117 integration

- [ ] C1: Fix `group[:account].bic` bug
- [ ] C2: Apply PR #117 (pain.001.001.09 + pain.008.001.08)
- [ ] C3: Replace DK XSDs with ISO/EPC XSDs
- [ ] H2: Add XML validation tests

### Phase 2 — Security and dependencies

- [ ] H1: Tighten version constraints
- [ ] M1: Hide IBAN/BIC in validation messages
- [ ] M2: CI Ruby 3.4 + ActiveModel 8.1
- [ ] M4: `send` → `public_send`
- [ ] B2: `required_ruby_version >= 3.1`
- [ ] B3: `actions/checkout@v4`

### Phase 3 — Ruby modernization

- [ ] M3: `frozen_string_literal: true` everywhere
- [ ] M5: Remove duplicate `creditor_address`
- [ ] B4: Migrate `add_development_dependency` to Gemfile
- [ ] B10: Fix assignment in condition

### Phase 4 — Code quality and performance

- [ ] H3: Extract `SEPA::Address` + `build_postal_address`
- [ ] H4: Typed error hierarchy
- [ ] M6: XSD schema cache
- [ ] M7: Memoize `transactions`
- [ ] M8: Double `transaction_group` call
- [ ] M9: Explicit error handling in `convert_decimal`

### Phase 5 — SEPA/France compliance

- [ ] H5: Do not emit empty `PmtTpInf`
- [ ] H6: Max amount validation 999 999 999.99
- [ ] M10: Address validation on Transaction
- [ ] M11: Fix `convert_text` whitelist
- [ ] M12: Mod-97 creditor identifier validation
- [ ] M14: Truncate `PmtInfId` to 35 chars

### Phase 6 — Desirable improvements

- [ ] M13: Structured remittance information support
- [ ] B1: COR1 deprecation warning
- [ ] B5: XML injection tests
- [ ] B6: Freeze time in tests
- [ ] B7: Widen EPC character set
- [ ] B8: Document `DEFAULT_REQUESTED_DATE`
