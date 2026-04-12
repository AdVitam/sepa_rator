# sepa_rator — Ruby gem for creating SEPA XML files

[![Build Status](https://github.com/AdVitam/sepa_rator/workflows/Test/badge.svg?branch=master)](https://github.com/AdVitam/sepa_rator/actions)

Successor to [salesking/sepa_king](https://github.com/salesking/sepa_king) (unmaintained since 2022).
Adds support for newer SEPA schemas and a **profile-based architecture** that makes
national variants (CFONB for France, DK/DFÜ for Germany, …) first-class.

## Features

- **Credit Transfer** (`pain.001`) — schemas `.001.13`, `.001.09`, `.003.03`, `.002.03`, `.001.03`
- **Direct Debit** (`pain.008`) — schemas `.001.12`, `.001.08`, `.003.02`, `.002.02`, `.001.02`
- **National profiles** — `CFONB` (🇫🇷), `DK/DFÜ` (🇩🇪), generic `EPC` SEPA
- Resolves the right profile from a simple `country: :fr` hint
- Full XSD validation on every generated XML
- Postal addresses, contact details, LEI, regulatory reporting
- Flexible charge bearer (SLEV, DEBT, CRED, SHAR)
- Mandate amendment support (original mandate ID, debtor account, creditor scheme)

**pain** = **Pa**yment **In**itiation (ISO 20022).

## Requirements

- Ruby 3.2+
- ActiveModel 7.0+ (tested up to 8.1)

## Installation

```ruby
gem 'sepa_rator', '~> 1.0'
```

## Quick start

### The simplest possible Credit Transfer

No profile, no country, no schema name — defaults to the latest EPC SEPA profile:

```ruby
sct = SEPA::CreditTransfer.new(
  name: 'Acme Ltd',
  bic:  'BNPAFRPPXXX',
  iban: 'FR7612345678901234567890123'
)

sct.add_transaction(
  name:   'Supplier GmbH',
  iban:   'DE21500500009876543210',
  amount: 102.50,
  reference: 'INV-123',
  remittance_information: 'Invoice 123'
)

xml = sct.to_xml
```

### The simplest possible Direct Debit

```ruby
sdd = SEPA::DirectDebit.new(
  name:                'Acme Ltd',
  bic:                 'BNPAFRPPXXX',
  iban:                'FR7612345678901234567890123',
  creditor_identifier: 'FR72ZZZ123456'
)

sdd.add_transaction(
  name:                      'Customer SA',
  iban:                      'DE21500500009876543210',
  amount:                    39.99,
  reference:                 'SUB/2025-08/001',
  mandate_id:                'MND-2025-001',
  mandate_date_of_signature: Date.new(2025, 1, 15)
)

xml = sdd.to_xml
```

## The 4-level public API

`sepa_rator` exposes a progressive API: the simpler path covers 90 % of use
cases; the explicit path is there when you need it.

### Level 0 — defaults (generic SEPA)

Do nothing special and get the latest EPC SEPA profile
(`pain.001.001.13` for credit transfer, `pain.008.001.12` for direct debit):

```ruby
SEPA::CreditTransfer.new(name: ..., iban: ..., bic: ...)
SEPA::DirectDebit.new(name: ..., iban: ..., bic: ..., creditor_identifier: ...)
```

### Level 1 — hint by country

The country code is **the country of the bank that will receive and process
your XML file** — your own bank for credit transfers, the creditor's bank for
direct debits. It is **not** the country of the beneficiary.

> Example: a company with a French bank pays Italian and German suppliers.
> The file goes to the French bank, so write `country: :fr`. The suppliers'
> IBANs can be from any SEPA country.

```ruby
SEPA::CreditTransfer.new(country: :fr, name: ..., iban: ..., bic: ...)
# → SEPA::Profiles::CFONB::SCT_13

SEPA::DirectDebit.new(country: :de, name: ..., iban: ..., bic: ...,
                      creditor_identifier: ...)
# → SEPA::Profiles::DK::SDD_12_GBIC5
```

Countries without a dedicated profile (e.g. `:it`, `:es`, `:be`) fall back
to the generic EPC profile automatically.

### Level 2 — country + version

If your bank hasn't upgraded to the latest ISO version yet, pin the version:

```ruby
SEPA::CreditTransfer.new(country: :fr, version: :v09, ...)
# → SEPA::Profiles::CFONB::SCT_09
```

Supported version symbols:

| Family          | Versions                |
|-----------------|-------------------------|
| `credit_transfer` | `:v09`, `:v13`, `:latest` |
| `direct_debit`    | `:v08`, `:v12`, `:latest` |

Requesting an unknown version raises `SEPA::UnsupportedVersionError` with
the list of available versions.

The older EPC AOS schemas (`pain.001.002.03`, `pain.001.003.03`,
`pain.008.002.02`, `pain.008.003.02`) are not exposed through the
`country:` / `version:` API — use Level 3 (explicit
`SEPA::Profiles::ISO::*` constants) if you need them.

### Level 3 — explicit profile (power user)

Pass a `SEPA::Profile` constant directly when you need a specific variant:

```ruby
SEPA::CreditTransfer.new(
  profile: SEPA::Profiles::DK::SCT_09_GBIC5,
  name: ..., iban: ..., bic: ...
)
```

`profile:` is mutually exclusive with `country:` / `version:` — passing
both raises `ArgumentError`.

## Supported profiles

| Family              | Namespace        | Profiles                                                                                                                               |
|---------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| ISO (raw XSD)       | `Profiles::ISO`  | `SCT_03`, `SCT_09`, `SCT_13`, `SCT_EPC_002_03`, `SCT_EPC_003_03`, `SDD_02`, `SDD_08`, `SDD_12`, `SDD_EPC_002_02`, `SDD_EPC_003_02`     |
| EPC SEPA            | `Profiles::EPC`  | `SCT_03`, `SCT_09`, `SCT_13`, `SDD_02`, `SDD_08`, `SDD_12`                                                                             |
| CFONB (France 🇫🇷) | `Profiles::CFONB` | `SCT_03`, `SCT_09`, `SCT_13`, `SDD_02`, `SDD_08`, `SDD_12`                                                                             |
| DK / DFÜ (Germany 🇩🇪) | `Profiles::DK`   | `SCT_03_GBIC3`, `SCT_09_GBIC5`, `SCT_13_GBIC5`, `SDD_02_GBIC3`, `SDD_08_GBIC5`, `SDD_12_GBIC5`                                         |
| SPS (Switzerland 🇨🇭) | `Profiles::SPS`  | `SCT_03`, `SCT_09`, `SCT_13`, `SDD_02`, `SDD_08`, `SDD_12`                                                                              |
| GB (United Kingdom 🇬🇧) | `Profiles::GB`  | `SCT_03`, `SCT_09`, `SCT_13`, `SDD_02`, `SDD_08`, `SDD_12`                                                                              |
| AT / PSA (Austria 🇦🇹)    | `Profiles::AT`  | `SCT_03`, `SCT_09`, `SCT_13`, `SDD_02`, `SDD_08`, `SDD_12`                                                                              |

Adding a new country is a single file in `lib/sepa_rator/profiles/` plus
entries in `lib/sepa_rator/profiles/country_defaults.rb`.

## Reusing validators

```ruby
class BankAccount < ActiveRecord::Base
  validates_with SEPA::IBANValidator, field_name: :iban
  validates_with SEPA::BICValidator,  field_name: :bic
  validates_with SEPA::LEIValidator,  field_name: :agent_lei
end
```

## Documentation

For the full list of options (addresses, charge bearer, amendment info,
regulatory reporting, LEI, contact details, etc.), see
[DOCUMENTATION.md](DOCUMENTATION.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributors

- [Original contributors](https://github.com/salesking/sepa_king/graphs/contributors) (salesking/sepa_king)
- [sepa_rator contributors](https://github.com/AdVitam/sepa_rator/graphs/contributors)

## Resources

- [ISO 20022 message definitions](https://www.iso20022.org/iso-20022-message-definitions)
- [EPC rulebooks](https://www.europeanpaymentscouncil.eu/document-library)
- [CFONB guides](https://www.cfonb.org/espaces-telechargements/documents)
- [EBICS / DK data formats](https://www.ebics.de/de/datenformate)
- [Swiss Payment Standards (SIX)](https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/iso-20022.html)
- [Bank of England ISO 20022 handbook](https://www.bankofengland.co.uk/payment-and-settlement/rtgs-renewal-programme/iso-20022-handbook)

## License

Released under the [MIT License](LICENSE.txt).

- Originally copyright (c) 2013-2022 Georg Leciejewski (SalesKing), Georg Ledermann.
- Copyright (c) 2025-2026 Advitam — fork, maintenance, profile-based architecture.
