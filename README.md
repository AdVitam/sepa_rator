# Ruby gem for creating SEPA XML files

[![Build Status](https://github.com/AdVitam/sepa_king/workflows/Test/badge.svg?branch=master)](https://github.com/AdVitam/sepa_king/actions)

> **AdVitam fork** of [salesking/sepa_king](https://github.com/salesking/sepa_king).
> Adds support for newer SEPA schemas (`pain.001.001.09`, `pain.001.001.13`,
> `pain.008.001.08`, `pain.008.001.12`) and includes extensive code quality
> and security improvements. The original gem has been unmaintained since 2022.

## Features

This gem implements the following two messages out of the ISO 20022 standard:

* Credit Transfer Initiation (`pain.001.001.13`, `pain.001.001.09`, `pain.001.003.03`, `pain.001.002.03` and `pain.001.001.03`)
* Direct Debit Initiation (`pain.008.001.12`, `pain.008.001.08`, `pain.008.003.02`, `pain.008.002.02` and `pain.008.001.02`)

It handles the _Specification of Data Formats_ up to the latest ISO 20022 versions.

BTW: **pain** is a shortcut for **Pa**yment **In**itiation.

## Requirements

* Ruby 3.1 or newer
* ActiveModel 7.0 or newer (including 8.1)

## Installation

Add to your Gemfile:

```ruby
gem 'sepa_king', git: 'https://github.com/AdVitam/sepa_king.git'
```

## Usage

How to create the XML for **Direct Debit Initiation**:

```ruby
# First: Create the main object
sdd = SEPA::DirectDebit.new(
  # Name of the initiating party and creditor
  # String, max. 70 char
  name:       'Creditor Inc.',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor
  # String, 8 or 11 char
  bic:        'BANKDEFFXXX',

  # International Bank Account Number of the creditor
  # String, max. 34 chars
  iban:       'DE87200500001234567890',

  # Creditor Identifier
  # String, max. 35 chars
  creditor_identifier: 'DE98ZZZ09999999999'
)

# Second: Add transactions
sdd.add_transaction(
  # Name of the debtor
  # String, max. 70 char
  name:                      'Debtor Corp.',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor's account
  # String, 8 or 11 char
  bic:                       'SPUEDE2UXXX',

  # International Bank Account Number of the debtor's account
  # String, max. 34 chars
  iban:                      'DE21500500009876543210',

  # Amount
  # Number with two decimal digit
  amount:                    39.99,

  # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
  # String, 3 char
  currency:                  'EUR',

  # OPTIONAL: Instruction Identification, will not be submitted to the debtor
  # String, max. 35 char
  instruction:               '12345',

  # OPTIONAL: End-To-End-Identification, will be submitted to the debtor
  # String, max. 35 char
  reference:                 'XYZ/2013-08-ABO/6789',

  # OPTIONAL: Unstructured remittance information
  # String, max. 140 char
  remittance_information:    'Thank you for your purchase!',

  # Mandate identification
  # String, max. 35 char
  mandate_id:                'K-02-2011-12345',

  # Mandate date of signature
  # Date
  mandate_date_of_signature: Date.new(2011,1,25),

  # Local instrument
  # One of these strings:
  #   'CORE' (Core Direct Debit)
  #   'COR1' (Core Direct Debit with shortened timeline, deprecated since Nov 2017)
  #   'B2B'  (Business-to-Business Direct Debit)
  local_instrument: 'CORE',

  # Sequence type
  # One of these strings:
  #   'FRST' (First collection)
  #   'RCUR' (Recurring collection)
  #   'OOFF' (One-off collection)
  #   'FNAL' (Final collection)
  sequence_type: 'OOFF',

  # OPTIONAL: Requested collection date
  # Date
  requested_date: Date.new(2013,9,5),

  # OPTIONAL: Enables or disables batch booking
  # True or False
  batch_booking: true,

  # OPTIONAL: Use a different creditor account
  # CreditorAccount
  creditor_account: SEPA::CreditorAccount.new(
    name:                'Creditor Inc.',
    bic:                 'RABONL2U',
    iban:                'NL08RABO0135742099',
    creditor_identifier: 'NL53ZZZ091734220000'
  ),

  # OPTIONAL: Specify the country & address of the debtor
  # (REQUIRED for SEPA debits outside of EU)
  debtor_address: SEPA::DebtorAddress.new(
    country_code:        'CH',
    # Not required if individual fields are used
    address_line1:       'Musterstrasse 123a',
    address_line2:       '1234 Musterstadt',
    # Not required if address_line1 and address_line2 are used
    street_name:         'Musterstrasse',
    building_number:     '123a',
    post_code:           '1234',
    town_name:           'Musterstadt'
  )
)
sdd.add_transaction ...

# Last: create XML string
xml_string = sdd.to_xml                      # Default: pain.008.001.02
xml_string = sdd.to_xml('pain.008.002.02')   # Austrian schema
xml_string = sdd.to_xml('pain.008.001.08')   # Newer schema
xml_string = sdd.to_xml('pain.008.001.12')   # Latest schema
```

How to create the XML for **Credit Transfer Initiation**:

```ruby
# First: Create the main object
sct = SEPA::CreditTransfer.new(
  # Name of the initiating party and debtor
  # String, max. 70 char
  name: 'Debtor Inc.',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor
  # String, 8 or 11 char
  bic:  'BANKDEFFXXX',

  # International Bank Account Number of the debtor
  # String, max. 34 chars
  iban: 'DE87200500001234567890'
)

# Second: Add transactions
sct.add_transaction(
  # Name of the creditor
  # String, max. 70 char
  name:                   'Creditor AG',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor's account
  # String, 8 or 11 char
  bic:                    'PBNKDEFF370',

  # International Bank Account Number of the creditor's account
  # String, max. 34 chars
  iban:                   'DE37112589611964645802',

  # Amount
  # Number with two decimal digit
  amount:                 102.50,

  # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
  # String, 3 char
  currency:               'EUR',

  # OPTIONAL: Instruction Identification, will not be submitted to the creditor
  # String, max. 35 char
  instruction:               '12345',

  # OPTIONAL: End-To-End-Identification, will be submitted to the creditor
  # String, max. 35 char
  reference:              'XYZ-1234/123',

  # OPTIONAL: Unstructured remittance information
  # String, max. 140 char
  remittance_information: 'Invoice from 22.08.2013',

  # OPTIONAL: Requested execution date
  # Date
  requested_date: Date.new(2013,9,5),

  # OPTIONAL: Enables or disables batch booking
  # True or False
  batch_booking: true,

  # OPTIONAL: Service level
  # One of these strings:
  #   'SEPA' (SEPA payment)
  #   'URGP' (Urgent payment)
  service_level: 'URGP',

  # OPTIONAL: Category purpose code (ISO 20022)
  # String, max. 4 char
  category_purpose:         'SALA',

  # OPTIONAL: Specify the country & address of the creditor
  # (REQUIRED for SEPA transfers outside of EU)
  creditor_address: SEPA::CreditorAddress.new(
    country_code:        'CH',
    # Not required if individual fields are used
    address_line1:       'Musterstrasse 123a',
    address_line2:       '1234 Musterstadt',
    # Not required if address_line1 and address_line2 are used
    street_name:         'Musterstrasse',
    building_number:     '123a',
    post_code:           '1234',
    town_name:           'Musterstadt'
  )
)
sct.add_transaction ...

# Last: create XML string
xml_string = sct.to_xml                      # Default: pain.001.001.03
xml_string = sct.to_xml('pain.001.002.03')   # Austrian schema
xml_string = sct.to_xml('pain.001.001.09')   # Newer schema
xml_string = sct.to_xml('pain.001.001.13')   # Latest schema
```

## Validations

You can rely on internal validations, raising errors when needed, during
message creation.
To validate your models holding SEPA related information (e.g. BIC, IBAN,
mandate_id) you can use the validator classes or rely on some constants.

Examples:

```ruby
class BankAccount < ActiveRecord::Base
  # IBAN validation, by default it validates the attribute named "iban"
  validates_with SEPA::IBANValidator, field_name: :iban_the_terrible

  # BIC validation, by default it validates the attribute named "bic"
  validates_with SEPA::BICValidator, field_name: :bank_bic
end

class Payment < ActiveRecord::Base
  validates_inclusion_of :sepa_sequence_type, in: SEPA::DirectDebitTransaction::SEQUENCE_TYPES

  # Mandate ID validation, by default it validates the attribute named "mandate_id"
  validates_with SEPA::MandateIdentifierValidator, field_name: :mandate_id
end
```

**Beware:** The SEPA::IBANValidator is strict - e.g. it does not allow any spaces in the IBAN.

Also see:

* [lib/sepa_king/validator.rb](https://github.com/AdVitam/sepa_king/blob/master/lib/sepa_king/validator.rb)
* [lib/sepa_king/transaction/direct_debit_transaction.rb](https://github.com/AdVitam/sepa_king/blob/master/lib/sepa_king/transaction/direct_debit_transaction.rb)

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributors

* [Original contributors](https://github.com/salesking/sepa_king/graphs/contributors) (salesking/sepa_king)
* [Fork contributors](https://github.com/AdVitam/sepa_king/graphs/contributors) (AdVitam/sepa_king)

## Resources

* <https://www.ebics.de/de/datenformate>
* [ISO 20022 message definitions](https://www.iso20022.org/iso-20022-message-definitions)

## License

Released under the [MIT License](LICENSE.txt).

Originally copyright (c) 2013-2022 Georg Leciejewski (SalesKing), Georg Ledermann.
Copyright (c) 2025-2026 AdVitam.
