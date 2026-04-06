# SEPA King — Full Documentation

## Table of Contents

- [Credit Transfer (pain.001)](#credit-transfer-pain001)
- [Direct Debit (pain.008)](#direct-debit-pain008)
- [Addresses](#addresses)
- [Charge Bearer](#charge-bearer)
- [UETR](#uetr-unique-end-to-end-transaction-reference)
- [Instruction Priority](#instruction-priority)
- [Purpose Code](#purpose-code)
- [Ultimate Parties](#ultimate-parties)
- [Mandate Amendments](#mandate-amendments)
- [Initiation Source](#initiation-source)
- [Instructions for Agents](#instructions-for-agents)
- [Credit Transfer Mandate](#credit-transfer-mandate)
- [Regulatory Reporting](#regulatory-reporting)
- [Remittance Information](#remittance-information)
- [Validators](#validators)
- [Supported Schemas](#supported-schemas)

---

## Credit Transfer (pain.001)

### Account (debtor)

```ruby
sct = SEPA::CreditTransfer.new(
  name: 'Debtor Inc.',             # Required, max 70 chars
  iban: 'DE87200500001234567890',  # Required
  bic:  'BANKDEFFXXX',            # Optional, 8 or 11 chars

  # Optional: organization ID emitted in InitgPty/Id/OrgId/Othr/Id
  # Some banks require this for bulk payment authorization
  initiating_party_identifier: 'DE98ZZZ09999999999',

  # Optional: postal address of the debtor at PmtInf level
  # Recommended for cross-border payments
  address: SEPA::Address.new(
    country_code: 'DE',
    post_code:    '10115',
    town_name:    'Berlin',
    street_name:  'Hauptstrasse',
    building_number: '42'
  )
)
```

### Transaction (credit)

```ruby
sct.add_transaction(
  # Required
  name:   'Creditor AG',            # max 70 chars
  iban:   'DE37112589611964645802',
  amount: 102.50,                    # positive, max 999_999_999.99

  # Optional
  bic:                    'PBNKDEFF370',       # 8 or 11 chars
  currency:               'EUR',               # ISO 4217, default: EUR
  instruction:            '12345',             # max 35 chars, not sent to creditor
  reference:              'XYZ-1234/123',      # max 35 chars (End-To-End ID)
  remittance_information: 'Invoice 123',       # max 140 chars
  requested_date:         Date.new(2024, 9, 5),
  batch_booking:          true,
  service_level:          'SEPA',              # 'SEPA' or 'URGP' (default: 'SEPA' for EUR)
  category_purpose:       'SALA',              # max 4 chars (e.g., SALA, INST)
  purpose_code:           'SALA',              # max 4 chars, transaction-level purpose (e.g., SALA, PENS, SSBE)
  charge_bearer:          'SLEV',              # see Charge Bearer section
  instruction_priority:   'HIGH',              # 'HIGH' or 'NORM' (see Instruction Priority section)
  uetr:                   '550e8400-e29b-41d4-a716-446655440000', # UUIDv4, .09/.13 only (see UETR section)
  ultimate_creditor_name: 'Final Beneficiary', # max 70 chars, when beneficiary differs from account holder

  # Optional: postal address of the creditor (required for cross-border)
  creditor_address: SEPA::CreditorAddress.new(
    country_code: 'CH',
    address_line1: 'Musterstrasse 123a',
    address_line2: '1234 Musterstadt'
  ),

  # Optional: instructions for agents (see Instructions for Agents section)
  debtor_agent_instruction: 'Process urgently',                          # .09/.13 only, PmtInf level, max 140 chars
  instruction_for_debtor_agent: 'Note for agent',                        # all versions, txn level
  instruction_for_debtor_agent_code: 'URGP',                             # .13 only, 1-4 chars
  instructions_for_creditor_agent: [{ code: 'HOLD', instruction_info: 'Hold for pickup' }],

  # Optional: credit transfer mandate (see Credit Transfer Mandate section)
  credit_transfer_mandate_id: 'MNDT-2024-001',                          # .13 only, max 35 chars
  credit_transfer_mandate_date_of_signature: Date.new(2024, 1, 15),     # .13 only
  credit_transfer_mandate_frequency: 'MNTH',                            # .13 only (Frequency6Code)

  # Optional: regulatory reporting (see Regulatory Reporting section)
  regulatory_reportings: [{ indicator: 'CRED', details: [{ code: 'ABC', information: ['Transfer info'] }] }],

  # Optional: structured remittance (see Remittance Information section)
  structured_remittance_information: 'RF712348231',                      # max 35 chars, mutually exclusive with remittance_information
  structured_remittance_reference_type: 'SCOR',                          # max 4 chars (default: 'SCOR')
  structured_remittance_issuer: 'Bank GmbH',                             # max 35 chars
  additional_remittance_information: ['Invoice 2024-001']                 # max 3 items, max 140 chars each
)
```

### Generate XML

```ruby
xml = sct.to_xml                               # pain.001.001.03 (default)
xml = sct.to_xml('pain.001.001.09')            # newer
xml = sct.to_xml('pain.001.001.13')            # latest
xml = sct.to_xml('pain.001.002.03')            # EPC (SEPA-only)
xml = sct.to_xml('pain.001.003.03')            # German DK
xml = sct.to_xml('pain.001.001.03.ch.02')      # Swiss SIX (CHF)
```

---

## Direct Debit (pain.008)

### Account (creditor)

```ruby
sdd = SEPA::DirectDebit.new(
  name:                'Creditor Inc.',          # Required, max 70 chars
  iban:                'DE87200500001234567890',  # Required
  bic:                 'BANKDEFFXXX',            # Optional
  creditor_identifier: 'DE98ZZZ09999999999',     # Required

  # Optional: postal address (recommended for cross-border)
  address: SEPA::Address.new(
    country_code: 'DE',
    town_name:    'Berlin',
    post_code:    '10115'
  )
)
```

### Transaction (debit)

```ruby
sdd.add_transaction(
  # Required
  name:                      'Debtor Corp.',
  iban:                      'DE21500500009876543210',
  amount:                    39.99,
  mandate_id:                'K-02-2011-12345',       # max 35 chars
  mandate_date_of_signature: Date.new(2011, 1, 25),

  # Optional
  bic:                    'SPUEDE2UXXX',
  currency:               'EUR',
  instruction:            '12345',
  reference:              'XYZ/2013-08-ABO/6789',
  remittance_information: 'Thank you!',
  requested_date:         Date.new(2024, 9, 5),
  batch_booking:          true,
  instruction_priority:   'HIGH',              # 'HIGH' or 'NORM' (see Instruction Priority section)
  charge_bearer:          'SLEV',              # see Charge Bearer section
  purpose_code:           'SALA',              # max 4 chars, transaction-level purpose
  uetr:                   '550e8400-e29b-41d4-a716-446655440000', # UUIDv4, .08/.12 only (see UETR section)
  ultimate_debtor_name:   'Final Payer',       # max 70 chars, when payer differs from account holder
  ultimate_creditor_name: 'Final Beneficiary', # max 70 chars

  # Local instrument: 'CORE' (default), 'B2B', or 'COR1' (deprecated)
  local_instrument: 'CORE',

  # Sequence type: 'OOFF' (default), 'FRST', 'RCUR', 'FNAL', 'RPRE' (.08/.12 only)
  sequence_type: 'OOFF',

  # Optional: use a different creditor account for this transaction
  creditor_account: SEPA::CreditorAccount.new(
    name: 'Other Creditor',
    bic: 'RABONL2U',
    iban: 'NL08RABO0135742099',
    creditor_identifier: 'NL53ZZZ091734220000'
  ),

  # Optional: postal address of the debtor (required for cross-border)
  debtor_address: SEPA::DebtorAddress.new(
    country_code: 'CH',
    street_name:  'Musterstrasse',
    building_number: '123a',
    post_code:    '1234',
    town_name:    'Musterstadt'
  ),

  # Optional: mandate amendment fields (see Mandate Amendments section)
  original_mandate_id: 'OLD-MANDATE-123',
  original_debtor_account: 'NL08RABO0135742099',
  same_mandate_new_debtor_agent: false,
  original_creditor_account: nil
)
```

### Generate XML

```ruby
xml = sdd.to_xml                               # pain.008.001.02 (default)
xml = sdd.to_xml('pain.008.001.08')            # newer
xml = sdd.to_xml('pain.008.001.12')            # latest
xml = sdd.to_xml('pain.008.002.02')            # EPC (SEPA-only)
xml = sdd.to_xml('pain.008.003.02')            # German DK
```

---

## Addresses

Addresses can be set at two levels:

1. **Account level** (`address:` on `CreditTransfer.new` or `DirectDebit.new`) — appears in `Dbtr/PstlAdr` or `Cdtr/PstlAdr` at the PmtInf level.
2. **Transaction level** (`creditor_address:` or `debtor_address:`) — appears per transaction.

### Address fields

Use `SEPA::Address.new(...)` (or `SEPA::DebtorAddress` / `SEPA::CreditorAddress`):

| Field | Max length | Schema support |
|-------|-----------|----------------|
| `country_code` | 2 (ISO 3166) | All schemas |
| `street_name` | 140 | All schemas |
| `building_number` | 16 | All schemas |
| `post_code` | 16 | All schemas |
| `town_name` | 140 | All schemas |
| `address_line1` | 70 | All schemas |
| `address_line2` | 70 | All schemas |
| `department` | 70 | .09/.08+ (PostalAddress24) |
| `sub_department` | 70 | .09/.08+ |
| `building_name` | 140 | .09/.08+ |
| `floor` | 70 | .09/.08+ |
| `post_box` | 16 | .09/.08+ |
| `room` | 70 | .09/.08+ |
| `town_location_name` | 140 | .09/.08+ |
| `district_name` | 140 | .09/.08+ |
| `country_sub_division` | 35 | .09/.08+ |
| `care_of` | 140 | .13/.12 only (PostalAddress27) |
| `unit_number` | 16 | .13/.12 only |

Fields not supported by a given schema are automatically rejected during XSD validation.

---

## Charge Bearer

The `charge_bearer` attribute controls who bears the transaction charges.

| Value | Meaning |
|-------|---------|
| `SLEV` | Following Service Level (default) |
| `DEBT` | Borne by debtor |
| `CRED` | Borne by creditor |
| `SHAR` | Shared between debtor and creditor |

**EPC schemas** (`pain.001.002.03`, `pain.001.003.03`, `pain.008.002.02`, `pain.008.003.02`) only accept `SLEV`. Using another value with these schemas raises `SEPA::Error`.

**Default behavior** (when `charge_bearer` is not set):
- Credit Transfer: emits `SLEV` when `service_level` is set, nothing otherwise
- Direct Debit: always emits `SLEV`

---

## UETR (Unique End-to-end Transaction Reference)

The `uetr` attribute is a UUIDv4 identifier used to track payments across the entire chain.

- **Format**: UUIDv4 (lowercase hex, e.g., `550e8400-e29b-41d4-a716-446655440000`)
- **Credit Transfer**: supported on `pain.001.001.09` and `pain.001.001.13` only
- **Direct Debit**: supported on `pain.008.001.08` and `pain.008.001.12` only
- Using UETR with older schemas raises `SEPA::SchemaValidationError`

---

## Instruction Priority

The `instruction_priority` attribute controls processing urgency.

| Value | Meaning |
|-------|---------|
| `HIGH` | High priority / urgent processing |
| `NORM` | Normal priority |

- Emitted in `PmtTpInf/InstrPrty` at the PmtInf level
- **EPC schemas** (`pain.001.002.03`, `pain.001.003.03`, `pain.008.002.02`, `pain.008.003.02`) do **not** support instruction priority — using it with these schemas raises an error

---

## Purpose Code

The `purpose_code` attribute classifies the payment at the **transaction level** (`Purp/Cd`). This is different from `category_purpose` which is at the `PmtTpInf` level.

Common values: `SALA` (salary), `PENS` (pension), `SSBE` (social security), `TAXS` (tax), `SUPP` (supplier payment).

- **Max length**: 4 characters
- Supported on all schemas

---

## Ultimate Parties

When the actual payer or beneficiary differs from the account holder, use ultimate party fields:

| Attribute | Message type | XML element | Max length |
|-----------|-------------|-------------|------------|
| `ultimate_creditor_name` | Credit Transfer | `UltmtCdtr/Nm` | 70 |
| `ultimate_debtor_name` | Direct Debit | `UltmtDbtr/Nm` | 70 |

Both `ultimate_creditor_name` and `ultimate_debtor_name` are available on all transaction types (CT and DD) as the XSD supports both at the transaction level.

---

## Mandate Amendments

For Direct Debit transactions, mandate amendment fields trigger `AmdmntInd = true` and generate the corresponding `AmdmntInfDtls` block:

| Attribute | Type | Purpose |
|-----------|------|---------|
| `original_mandate_id` | String (max 35) | Original mandate ID when the mandate reference changed |
| `original_debtor_account` | String (IBAN) | Original debtor IBAN when the debtor's bank account changed |
| `same_mandate_new_debtor_agent` | Boolean | Set to `true` when the debtor moved to a new bank (SMNDA) |
| `original_creditor_account` | `SEPA::CreditorAccount` | Original creditor when name or identifier changed |

These can be combined. `OrgnlMndtId` is always emitted first in the XML (per XSD sequence order).

---

## Initiation Source

The `initiation_source_name` and `initiation_source_provider` attributes identify the software that created the message. Set on the message object (not the transaction).

- **Schema support**: `pain.001.001.13` only
- `initiation_source_name` — Required when used, max 140 chars (`InitnSrc/Nm`)
- `initiation_source_provider` — Optional, max 35 chars (`InitnSrc/Prvdr`)

```ruby
sct = SEPA::CreditTransfer.new(name: 'Debtor Inc.', iban: 'DE87200500001234567890')
sct.initiation_source_name = 'MyPaymentApp'
sct.initiation_source_provider = 'Advitam'
```

Using these attributes with non-v13 schemas raises `SEPA::SchemaValidationError`.

---

## Instructions for Agents

### InstrForDbtrAgt (PmtInf level)

Instruction for the debtor's agent, emitted in the `PmtInf` block. Transactions sharing the same value are grouped together.

- **Schema support**: `pain.001.001.09` and `pain.001.001.13` only
- **Type**: `Max140Text`
- **Attribute**: `debtor_agent_instruction`

### InstrForCdtrAgt (transaction level)

Instructions for the creditor's agent, emitted per transaction. Unbounded (multiple instructions allowed).

- **Schema support**: all versions
- **Attribute**: `instructions_for_creditor_agent` — Array of Hashes

| Key | Type | Notes |
|-----|------|-------|
| `code` | String | v03/v09: `CHQB`, `HOLD`, `PHOB`, `TELB`. v13: any 1-4 char code |
| `instruction_info` | String | Free text, max 140 chars |

### InstrForDbtrAgt (transaction level)

Instruction for the debtor's agent, emitted per transaction.

- **v03/v09**: simple text (`Max140Text`) — use `instruction_for_debtor_agent`
- **v13**: structured with code + text — use `instruction_for_debtor_agent` (text) and `instruction_for_debtor_agent_code` (1-4 chars, v13 only)

---

## Credit Transfer Mandate

Support for `MndtRltdInf` (`CreditTransferMandateData1`) on credit transfer transactions.

- **Schema support**: `pain.001.001.13` only

| Attribute | Type | XSD element |
|-----------|------|-------------|
| `credit_transfer_mandate_id` | String, max 35 | `MndtId` |
| `credit_transfer_mandate_date_of_signature` | Date | `DtOfSgntr` |
| `credit_transfer_mandate_frequency` | String | `Frqcy/Tp` (Frequency6Code) |

**Frequency6Code values**: `YEAR`, `MNTH`, `QURT`, `MIAN`, `WEEK`, `DAIL`, `ADHO`, `INDA`, `FRTN`

---

## Regulatory Reporting

Support for `RgltryRptg` on credit transfer transactions. Max 10 entries per transaction.

- **Schema support**: all versions (structure differs between v03/v09 and v13)
- **Attribute**: `regulatory_reportings` — Array of Hashes

| Key | Type | Notes |
|-----|------|-------|
| `indicator` | String | `CRED`, `DEBT`, or `BOTH`. **Required** in v13 |
| `details` | Array<Hash> | Structured reporting details |
| `details[].code` | String | Max 10 chars. Emitted as `Cd` (v03/v09) or `RptgCd` (v13) |
| `details[].information` | Array<String> | Max 35 chars each, emitted as `Inf` elements |

---

## Remittance Information

Two modes (mutually exclusive):

### Unstructured

```ruby
remittance_information: 'Invoice 123'  # max 140 chars, emitted as RmtInf/Ustrd
```

### Structured

```ruby
structured_remittance_information: 'RF712348231',      # max 35 chars, emitted as CdtrRefInf/Ref
structured_remittance_reference_type: 'SCOR',           # max 4 chars (default: 'SCOR'), emitted as CdtrRefInf/Tp/CdOrPrtry/Cd
structured_remittance_issuer: 'Bank GmbH',              # max 35 chars, emitted as CdtrRefInf/Tp/Issr
additional_remittance_information: ['Invoice 2024-001'] # max 3 items x 140 chars, emitted as AddtlRmtInf
```

`structured_remittance_information` and `remittance_information` cannot be used together. `additional_remittance_information` belongs to the structured remittance block.

---

## Validators

Reuse SEPA validators in your own ActiveModel classes:

```ruby
validates_with SEPA::IBANValidator                          # validates :iban
validates_with SEPA::IBANValidator, field_name: :other_iban # custom field
validates_with SEPA::BICValidator                           # validates :bic
validates_with SEPA::MandateIdentifierValidator             # validates :mandate_id
validates_with SEPA::CreditorIdentifierValidator            # validates :creditor_identifier
```

**Note:** `SEPA::IBANValidator` is strict — no spaces allowed.

---

## Supported Schemas

### Credit Transfer (pain.001)

| Schema | Type | Notes |
|--------|------|-------|
| `pain.001.001.03` | ISO generic | Default. PostalAddress6 |
| `pain.001.001.09` | ISO 2019 | PostalAddress24, BICFI, UETR, InstrForDbtrAgt (PmtInf) |
| `pain.001.001.13` | ISO latest | PostalAddress27, BICFI, UETR, InitnSrc, MndtRltdInf, structured InstrForDbtrAgt, RegulatoryReporting10 |
| `pain.001.002.03` | EPC/SEPA | EUR only, BIC required, ChrgBr=SLEV only |
| `pain.001.003.03` | German DK | EUR only |
| `pain.001.001.03.ch.02` | Swiss SIX | CHF only |

### Direct Debit (pain.008)

| Schema | Type | Notes |
|--------|------|-------|
| `pain.008.001.02` | ISO generic | Default. PostalAddress6 |
| `pain.008.001.08` | ISO 2019 | PostalAddress24, BICFI, UETR, RPRE sequence type |
| `pain.008.001.12` | ISO latest | PostalAddress27, BICFI, UETR, RPRE sequence type |
| `pain.008.002.02` | EPC/SEPA | EUR only, BIC required, CORE/B2B only, ChrgBr=SLEV only |
| `pain.008.003.02` | German DK | EUR only |
