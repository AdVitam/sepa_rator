# Comprehensive Audit — sepa_king (AdVitam fork)

**Date**: 2026-04-03 (updated: 2026-04-03)
**Branch audited**: `fix/low-severity-audit-issues` → updated on `chore/audit-docs-attribution`
**Baseline**: 238 tests passing, 98.1% line coverage, 0 Rubocop offenses

---

## Table of Contents

- [1. Security](#1-security)
- [2. Code Quality (DRY / SOLID / Ruby Idioms)](#2-code-quality)
- [3. Functional (SEPA Schemas)](#3-functional)
- [4. Documentation & Attribution](#4-documentation--attribution)
- [5. Action Plan](#5-action-plan)

---

## 1. Security

**Overall**: Good. No critical or high-severity vulnerabilities. The gem only builds XML (no parsing), so XXE/XML bombs are not applicable. Nokogiri Builder auto-escapes, XSD validation is mandatory, all regexes are ReDoS-safe, BigDecimal handling is robust.

| ID  | Severity   | Category           | File(s)                                          | Description                                                                                     | Status |
|-----|------------|--------------------|--------------------------------------------------|-------------------------------------------------------------------------------------------------|--------|
| S1  | Low        | Input validation   | `converter.rb:13`                                | Uses `send` instead of `public_send` in converter macro                                         | [ ]    |
| S2  | Low        | Input validation   | `direct_debit_transaction.rb:13`                 | `original_debtor_account` not validated as IBAN                                                 | [ ]    |
| S3  | Low        | Thread safety      | `message.rb:123`                                 | `SCHEMA_CACHE` not thread-safe (benign race in MRI, potential issue in JRuby/TruffleRuby)       | [ ]    |
| S4  | Low        | SEPA compliance    | `direct_debit.rb:43`                             | Verify `ReqdColltnDt` wrapping for .08/.12 schemas (confirmed correct — no wrapper needed)      | [x]    |
| S5  | **Medium** | Input validation   | `transaction.rb:59`, `account.rb:15`, `address.rb:32` | `public_send` in `initialize` accepts arbitrary attribute names — risk if untrusted keys passed | [ ]    |
| S6  | Low        | Info disclosure    | `message.rb:92`                                  | Library name `SEPA-KING/` in default `message_identification`                                   | [ ]    |
| S7  | Low        | Encoding           | `converter.rb:24`                                | No encoding enforcement on input to `convert_text`                                              | [ ]    |

---

## 2. Code Quality

### 2.1 DRY Violations

| ID  | Severity   | Description                                                                                           | File(s)                                              | Status |
|-----|------------|-------------------------------------------------------------------------------------------------------|------------------------------------------------------|--------|
| D1  | **High**   | BIC/BICFI schema branching duplicated 4x across 3 files                                               | `credit_transfer.rb:62,95`, `direct_debit.rb:55,143` | [x]    |
| D2  | **High**   | `RmtInf` (remittance info) block copy-pasted between credit_transfer and direct_debit                 | `credit_transfer.rb:112-129`, `direct_debit.rb:164-182` | [x]    |
| D3  | Medium     | `NOTPROVIDED` fallback BIC pattern duplicated 3x                                                      | `credit_transfer.rb:68`, `direct_debit.rb:61,149`    | [x]    |
| D4  | Medium     | Identical `initialize` attribute assignment in 3 classes                                               | `account.rb:15`, `address.rb:32`, `transaction.rb:58` | [—]    |
| D5  | Low        | `'%.2f' % amount` formatting repeated 4x                                                              | `credit_transfer.rb:29`, `direct_debit.rb:33,132`, `message.rb:149` | [x]    |

**Recommended extractions in `Message` base class:**

- `build_bic(builder, bic_value, schema_name)` — handles BIC vs BICFI + NOTPROVIDED fallback (fixes D1, D3)
- `build_remittance_information(builder, transaction)` — shared RmtInf block (fixes D2)
- `format_amount(value)` — `'%.2f' % value` helper (fixes D5)
- `AttributeAssignment` concern for shared `initialize` (fixes D4)

### 2.2 SOLID Violations

| ID  | Severity   | Principle     | Description                                                                 | File(s)                     | Status |
|-----|------------|---------------|-----------------------------------------------------------------------------|-----------------------------|--------|
| O1  | **High**   | Open/Closed   | Schema-specific behavior scattered via `if/include?` conditionals           | `credit_transfer.rb`, `direct_debit.rb`, `message.rb` | [x]    |
| O2  | Medium     | Single Resp.  | `build_group_header` type-checks `respond_to?(:creditor_identifier)`        | `message.rb:150-161`        | [x]    |
| O3  | Low        | Dep. Inversion| XSD path hardcoded in `validate_final_document!`                            | `message.rb:191`            | [—]    |

**Recommended**: Introduce a schema feature map or descriptor object:

```ruby
SCHEMA_FEATURES = {
  PAIN_001_001_03 => { bic_tag: :BIC, date_wrapper: false },
  PAIN_001_001_09 => { bic_tag: :BICFI, date_wrapper: true },
  # ...
}.freeze
```

### 2.3 Code Smells

| ID  | Severity | Description                                                          | File(s)                                    | Status |
|-----|----------|----------------------------------------------------------------------|--------------------------------------------|--------|
| CS1 | **High** | `build_payment_informations` is 60 lines in both subclasses          | `credit_transfer.rb:20-81`, `direct_debit.rb:25-86` | [x]    |
| CS2 | Medium   | Feature envy: `build_group_header` reaches into account internals    | `message.rb:144-163`                       | [x]    |
| CS3 | Medium   | Primitive obsession: `schema_name` as raw string everywhere          | Multiple files                             | [x]    |
| CS4 | Low      | Transaction group keys are plain hashes — could be value objects     | `transaction.rb`                           | [—]    |
| CS5 | Low      | `SCHEMA_CACHE` mutable constant with rubocop disable                 | `message.rb:123`                           | [x]    |

### 2.4 Ruby Idioms

| ID  | Severity | Description                                              | File(s)              | Status |
|-----|----------|----------------------------------------------------------|----------------------|--------|
| I1  | Low      | `inject(0)` should be `sum(&:amount)`                    | `message.rb:66`      | [x]    |
| I2  | Low      | `collect` should be `map`                                | `message.rb:120`     | [x]    |
| I3  | Low      | Missing `frozen_string_literal` in all spec files        | `spec/**/*.rb`       | [x]    |
| I4  | Low      | `unless` with negative logic in `xml_schema`             | `message.rb:129`     | [x]    |

### 2.5 Error Handling

| ID  | Severity | Description                                                            | File(s)           | Status |
|-----|----------|------------------------------------------------------------------------|-------------------|--------|
| E1  | Medium   | `batch_id` returns nil silently when reference not found               | `message.rb:113`  | [x]    |
| E2  | Low      | Message-level validation deferred to `to_xml` time (asymmetry)         | `message.rb`      | [—]    |

### 2.6 Naming

| ID  | Severity | Description                                                         | File(s)                    | Status |
|-----|----------|---------------------------------------------------------------------|----------------------------|--------|
| N1  | Medium   | Factory typo: `direct_debt_transaction` → `direct_debit_transaction` | `spec/support/factories.rb` | [x]    |
| N2  | Low      | Variable shadowing: outer `builder` vs block param `builder`         | `message.rb:52`            | [x]    |

### 2.7 Rubocop

| ID  | Severity   | Description                                                    | Status |
|-----|------------|----------------------------------------------------------------|--------|
| R1  | **High**   | 448 offenses total, 437 autocorrectable (mostly in specs)      | [x]    |

**Quick fix**: `bundle exec rubocop -a` then manually fix remaining ~11 offenses.

---

## 3. Functional

**Overall**: Good. All 11 schemas are properly declared with matching XSD files. BIC/BICFI and date wrapping are correctly implemented. XSD validation catches any structural issues.

| ID  | Severity   | Description                                                                           | Status |
|-----|------------|---------------------------------------------------------------------------------------|--------|
| F1  | **Medium** | Missing `RPRE` (Represented) sequence type for pain.008.001.08/.12                    | [x]    |
| F2  | **Medium** | No detailed XML structure tests for newer schemas (BICFI, date wrapping assertions)   | [x]    |
| F3  | Low        | Optional `UETR` field (UUIDv4) not exposed for .09/.13/.08/.12                        | [x]    |
| F4  | Low        | No reference XML fixtures in `spec/examples/` for newer schemas                       | [x]    |
| F5  | Low        | PostalAddress27 new fields not exposed (CareOf, BldgNm, Flr, etc.)                   | [x]    |
| F6  | Low        | `InstrPrty` (Instruction Priority: HIGH/NORM) not exposed                             | [x]    |

---

## 4. Documentation & Attribution

**Overall**: Major work needed. The project still reads as the original salesking gem.

### 4.1 Critical (before any public release)

| ID  | Description                                                                    | File(s)              | Status |
|-----|--------------------------------------------------------------------------------|----------------------|--------|
| A1  | gemspec: homepage/authors still point to salesking, no metadata URIs           | `sepa_king.gemspec`  | [x]    |
| A2  | README: no fork mention, salesking badges, "Ruby 2.7+" instead of 3.1+, all links to salesking | `README.md` | [x]    |
| A3  | LICENSE: copyright 2013-2022, AdVitam not mentioned                            | `LICENSE.txt`        | [x]    |
| A4  | Version still 0.14.0 despite 4 new schemas + 3 audit PRs                      | `version.rb`         | [x]    |

### 4.2 Important

| ID  | Description                                                                    | File(s)              | Status |
|-----|--------------------------------------------------------------------------------|----------------------|--------|
| A5  | CONTRIBUTING.md: written from salesking perspective, outdated commands          | `CONTRIBUTING.md`    | [x]    |
| A6  | CHANGELOG.md does not exist                                                    | —                    | [x]    |
| A7  | `coveralls_reborn` in Gemfile likely unused by the fork                        | `Gemfile`            | [x]    |

### 4.3 Nice-to-have

| ID  | Description                                                                    | Status |
|-----|--------------------------------------------------------------------------------|--------|
| A8  | No Dependabot config (`.github/dependabot.yml`)                                | [ ]    |
| A9  | No CODEOWNERS file                                                             | [ ]    |
| A10 | No issue/PR templates                                                          | [ ]    |

---

## 5. Action Plan

Recommended execution order. Each item groups related audit findings.

### Phase 1 — Quick Wins

- [x] **Rubocop autofix** (R1): `bundle exec rubocop -a`, then manually fix remaining ~11 offenses
- [x] **Fix factory typo** (N1): `direct_debt_transaction` → `direct_debit_transaction`
- [x] **Ruby idioms** (I1, I2, I3, I4): `inject` → `sum`, `collect` → `map`, add frozen_string_literal to specs
- [x] **Remove duplicate attr_accessor** `debtor_address` in DirectDebitTransaction

### Phase 2 — Documentation & Attribution

- [x] **Update gemspec** (A1): authors, homepage, metadata URIs, description
- [x] **Rewrite README** (A2): fork notice, badges, correct Ruby/ActiveModel versions, update all links
- [x] **Update LICENSE** (A3): add AdVitam copyright line, update years to 2013-2026
- [x] **Rewrite CONTRIBUTING.md** (A5): AdVitam workflow, correct commands
- [x] **Create CHANGELOG.md** (A6): document new schemas and audit fixes
- [x] **Bump version** (A4): 0.15.0
- [x] **Clean Gemfile** (A7): removed `coveralls_reborn` (done in prior PR)

### Phase 3 — DRY Extractions

- [x] **Extract `build_agent_bic`** helper in Message (D1, D3): handles BIC/BICFI + NOTPROVIDED
- [x] **Extract `build_remittance_information`** in Message (D2): shared RmtInf block
- [x] **Extract `format_amount`** helper (D5)
- [~] **Extract `AttributeAssignment` module** (D4): skipped — trivial duplication, mixin adds indirection for no gain

### Phase 4 — Functional Gaps

- [x] **Add `RPRE` sequence type** (F1): for pain.008.001.08/.12
- [x] **Add structural tests for newer schemas** (F2): assert BICFI, date wrapping, etc.
- [x] **Add reference XML fixtures** (F4): for .09/.13/.08/.12 in `spec/examples/`
- [x] **Add `UETR` field** (F3): optional UUIDv4 in newer schemas
- [x] **Expose PostalAddress24/27 fields** (F5): CareOf, BldgNm, Floor, Room, UnitNb, etc.
- [x] **Add `InstrPrty` field** (F6): HIGH/NORM instruction priority

### Phase 5 — Refactoring

- [x] **Decompose `build_payment_informations`** (CS1): extracted sub-methods in both subclasses
- [x] **Introduce SCHEMA_FEATURES** (O1, CS3): frozen hash replaces scattered conditionals
- [x] **Polymorphic identity in Account** (O2, CS2): move creditor_identifier rendering to CreditorAccount
- [ ] **`send` → `public_send`** in converter (S1)

### Phase 6 — Security Hardening

- [ ] **Attribute name whitelisting** in initialize (S5): or document the constraint
- [ ] **IBAN validation for `original_debtor_account`** (S2)
- [ ] **Thread-safe schema cache** (S3): `Concurrent::Map` or accept benign race
- [ ] **Explicit nil return in `batch_id`** (E1)

### Phase 7 — Nice-to-haves

- [ ] Add Dependabot config (A8)
- [ ] Add CODEOWNERS (A9)
- [ ] Add issue/PR templates (A10)
- [x] Expose `InstrPrty` field (F6)
- [x] Expose PostalAddress27 fields (F5)
