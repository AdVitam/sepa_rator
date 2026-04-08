# frozen_string_literal: true

module SEPA
  module TestData
    # Debtor (Schuldner) — CreditTransfer parent account
    DEBTOR_NAME = 'Schuldner GmbH'
    DEBTOR_IBAN = 'DE87200500001234567890'
    DEBTOR_BIC  = 'BANKDEFFXXX'

    # Creditor (Gläubiger) — DirectDebit parent account
    CREDITOR_NAME       = 'Gläubiger GmbH'
    CREDITOR_IDENTIFIER = 'DE98ZZZ09999999999'

    # Credit transfer transaction recipient
    CT_TX_NAME = 'Telekomiker AG'
    CT_TX_IBAN = 'DE37112589611964645802'
    CT_TX_BIC  = 'PBNKDEFF370'

    # Direct debit transaction payer (factory profile)
    DD_TX_NAME = 'Müller & Schmidt oHG'
    DD_TX_IBAN = 'DE68210501700012345678'
    DD_TX_BIC  = 'GENODEF1JEV'

    # Direct debit transaction payer (alternate profile, used in subject blocks)
    DD_TX_ALT_NAME = 'Zahlemann & Söhne GbR'
    DD_TX_ALT_IBAN = 'DE21500500009876543210'
    DD_TX_ALT_BIC  = 'SPUEDE2UXXX'

    # LEI
    LEI      = '529900T8BM49AURSDO55'
    LEI_ALT  = '529900ABCDEFGHIJKL19'
    LEI_ALT2 = 'ABCDEFGHIJKLMNOPQR30'
  end
end

def credit_transfer_message(attributes = {})
  SEPA::CreditTransfer.new({
    name: SEPA::TestData::DEBTOR_NAME,
    bic: SEPA::TestData::DEBTOR_BIC,
    iban: SEPA::TestData::DEBTOR_IBAN
  }.merge(attributes))
end

def direct_debit_message(attributes = {})
  SEPA::DirectDebit.new({
    name: SEPA::TestData::CREDITOR_NAME,
    bic: SEPA::TestData::DEBTOR_BIC,
    iban: SEPA::TestData::DEBTOR_IBAN,
    creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER
  }.merge(attributes))
end

def credit_transfer_transaction(attributes = {})
  { name: SEPA::TestData::CT_TX_NAME,
    bic: SEPA::TestData::CT_TX_BIC,
    iban: SEPA::TestData::CT_TX_IBAN,
    amount: 102.50,
    reference: 'XYZ-1234/123',
    remittance_information: 'Rechnung vom 22.08.2013' }.merge(attributes)
end

def direct_debit_transaction(attributes = {})
  { name: SEPA::TestData::DD_TX_NAME,
    bic: SEPA::TestData::DD_TX_BIC,
    iban: SEPA::TestData::DD_TX_IBAN,
    amount: 750.00,
    reference: 'XYZ/2013-08-ABO/6789',
    remittance_information: 'Vielen Dank für Ihren Einkauf!',
    mandate_id: 'K-08-2010-42123',
    mandate_date_of_signature: Date.new(2010, 7, 25),
    requested_date: Date.today + 1 }.merge(attributes)
end

def direct_debit_transaction_alt(attributes = {})
  { name: SEPA::TestData::DD_TX_ALT_NAME,
    bic: SEPA::TestData::DD_TX_ALT_BIC,
    iban: SEPA::TestData::DD_TX_ALT_IBAN,
    amount: 39.99,
    reference: 'XYZ/2013-08-ABO/12345',
    remittance_information: 'Unsere Rechnung vom 10.08.2013',
    mandate_id: 'K-02-2011-12345',
    mandate_date_of_signature: Date.new(2011, 1, 25) }.merge(attributes)
end
