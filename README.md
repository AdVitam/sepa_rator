# Ruby gem for creating SEPA XML files

[![Build Status](https://github.com/AdVitam/sepa_king/workflows/Test/badge.svg?branch=master)](https://github.com/AdVitam/sepa_king/actions)

> **AdVitam fork** of [salesking/sepa_king](https://github.com/salesking/sepa_king).
> Adds support for newer SEPA schemas (`pain.001.001.09`, `pain.001.001.13`,
> `pain.008.001.08`, `pain.008.001.12`) and includes extensive code quality
> and security improvements. The original gem has been unmaintained since 2022.

## Features

* **Credit Transfer** (`pain.001`) — schemas `.001.13`, `.001.09`, `.003.03`, `.002.03`, `.001.03`, `.001.03.ch.02`
* **Direct Debit** (`pain.008`) — schemas `.001.12`, `.001.08`, `.003.02`, `.002.02`, `.001.02`
* Full XSD validation on every generated XML
* Postal addresses, contact details, LEI, regulatory reporting
* Flexible charge bearer (SLEV, DEBT, CRED, SHAR)
* Mandate amendment support (original mandate ID, debtor account, creditor scheme)

**pain** = **Pa**yment **In**itiation (ISO 20022).

## Requirements

* Ruby 3.1+
* ActiveModel 7.0+ (including 8.1)

## Installation

```ruby
gem 'sepa_king', git: 'https://github.com/AdVitam/sepa_king.git'
```

## Quick start

### Credit Transfer

```ruby
sct = SEPA::CreditTransfer.new(
  name: 'Debtor Inc.',
  bic:  'BANKDEFFXXX',
  iban: 'DE87200500001234567890'
)

sct.add_transaction(
  name:   'Creditor AG',
  bic:    'PBNKDEFF370',
  iban:   'DE37112589611964645802',
  amount: 102.50,
  reference: 'XYZ-1234/123',
  remittance_information: 'Invoice 123'
)

xml = sct.to_xml                          # pain.001.001.03 (default)
xml = sct.to_xml('pain.001.001.09')       # newer schema
xml = sct.to_xml('pain.001.001.13')       # latest schema
```

### Direct Debit

```ruby
sdd = SEPA::DirectDebit.new(
  name:                'Creditor Inc.',
  bic:                 'BANKDEFFXXX',
  iban:                'DE87200500001234567890',
  creditor_identifier: 'DE98ZZZ09999999999'
)

sdd.add_transaction(
  name:                      'Debtor Corp.',
  bic:                       'SPUEDE2UXXX',
  iban:                      'DE21500500009876543210',
  amount:                    39.99,
  reference:                 'XYZ/2013-08-ABO/6789',
  mandate_id:                'K-02-2011-12345',
  mandate_date_of_signature: Date.new(2011, 1, 25),
  sequence_type:             'OOFF'
)

xml = sdd.to_xml                          # pain.008.001.02 (default)
xml = sdd.to_xml('pain.008.001.08')       # newer schema
xml = sdd.to_xml('pain.008.001.12')       # latest schema
```

### Validators

Reuse SEPA validators in your own models:

```ruby
class BankAccount < ActiveRecord::Base
  validates_with SEPA::IBANValidator, field_name: :iban
  validates_with SEPA::BICValidator,  field_name: :bic
end
```

## Documentation

For the full list of options (addresses, charge bearer, amendment info, batch booking, service level, etc.), see [DOCUMENTATION.md](DOCUMENTATION.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributors

* [Original contributors](https://github.com/salesking/sepa_king/graphs/contributors) (salesking/sepa_king)
* [Fork contributors](https://github.com/AdVitam/sepa_king/graphs/contributors) (AdVitam/sepa_king)

## Resources

* [ISO 20022 message definitions](https://www.iso20022.org/iso-20022-message-definitions)
* <https://www.ebics.de/de/datenformate>

## License

Released under the [MIT License](LICENSE.txt).

Originally copyright (c) 2013-2022 Georg Leciejewski (SalesKing), Georg Ledermann.
Copyright (c) 2025-2026 AdVitam.
