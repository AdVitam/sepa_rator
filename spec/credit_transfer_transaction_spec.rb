# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::CreditTransferTransaction do
  describe :initialize do
    it 'initializes a valid transaction' do
      expect(
        SEPA::CreditTransferTransaction.new(name: 'Telekomiker AG',
                                            iban: SEPA::TestData::CT_TX_IBAN,
                                            bic: SEPA::TestData::CT_TX_BIC,
                                            amount: 102.50,
                                            reference: 'XYZ-1234/123',
                                            remittance_information: 'Rechnung 123 vom 22.08.2013')
      ).to be_valid
    end
  end

  describe :schema_compatible? do
    context 'for pain.001.003.03' do
      it 'succeeds' do
        expect(SEPA::CreditTransferTransaction.new({})).to be_schema_compatible('pain.001.003.03')
      end

      it 'fails for invalid attributes' do
        expect(SEPA::CreditTransferTransaction.new(currency: 'CHF')).not_to be_schema_compatible('pain.001.003.03')
      end
    end

    context 'pain.001.002.03' do
      it 'succeeds for valid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA')).to be_schema_compatible('pain.001.002.03')
      end

      it 'fails for invalid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: nil)).not_to be_schema_compatible('pain.001.002.03')
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'URGP')).not_to be_schema_compatible('pain.001.002.03')
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, currency: 'CHF')).not_to be_schema_compatible('pain.001.002.03')
      end
    end

    context 'for pain.001.001.03' do
      it 'succeeds for valid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, currency: 'CHF')).to be_schema_compatible('pain.001.001.03')
        expect(SEPA::CreditTransferTransaction.new(bic: nil)).to be_schema_compatible('pain.001.003.03')
      end

      it 'accepts URGP service level' do
        expect(SEPA::CreditTransferTransaction.new(service_level: 'URGP')).to be_schema_compatible('pain.001.001.03')
        expect(SEPA::CreditTransferTransaction.new(service_level: 'URGP')).to be_schema_compatible('pain.001.001.09')
        expect(SEPA::CreditTransferTransaction.new(service_level: 'URGP')).to be_schema_compatible('pain.001.001.13')
      end
    end

    context 'for pain.001.001.03.ch.02' do
      it 'succeeds for valid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, currency: 'CHF')).to be_schema_compatible('pain.001.001.03.ch.02')
      end
    end

    context 'for pain.001.001.09' do
      it 'succeeds for valid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC)).to be_schema_compatible('pain.001.001.09')
        expect(SEPA::CreditTransferTransaction.new(bic: nil)).to be_schema_compatible('pain.001.001.09')
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, currency: 'CHF')).to be_schema_compatible('pain.001.001.09')
      end

      it 'accepts UETR' do
        expect(SEPA::CreditTransferTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.001.001.09')
      end
    end

    context 'for pain.001.001.13' do
      it 'succeeds for valid attributes' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC)).to be_schema_compatible('pain.001.001.13')
        expect(SEPA::CreditTransferTransaction.new(bic: nil)).to be_schema_compatible('pain.001.001.13')
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, currency: 'CHF')).to be_schema_compatible('pain.001.001.13')
      end

      it 'accepts UETR' do
        expect(SEPA::CreditTransferTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.001.001.13')
      end
    end

    context 'UETR schema compatibility' do
      it 'rejects UETR for pain.001.001.03' do
        expect(SEPA::CreditTransferTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.001.001.03')
      end

      it 'rejects UETR for pain.001.002.03' do
        expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA', uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.001.002.03')
      end
    end
  end

  context 'Requested date' do
    around { |example| travel_to(Time.new(2025, 6, 15, 12, 0, 0)) { example.run } }

    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, Date.new(1999, 1, 1), Date.today, Date.today.next, Date.today + 2, for: :requested_date)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept(Date.new(1995, 12, 21), Date.today - 1, for: :requested_date)
    end
  end

  context 'Instruction Priority' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'HIGH', 'NORM', for: :instruction_priority)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'LOW', 'high', for: :instruction_priority)
    end
  end

  context 'Charge Bearer' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'DEBT', 'CRED', 'SHAR', 'SLEV', for: :charge_bearer)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'INVALID', 'slev', for: :charge_bearer)
    end
  end

  context 'Charge Bearer schema compatibility' do
    it 'rejects non-SLEV for pain.001.002.03' do
      expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA', charge_bearer: 'SHAR'))
        .not_to be_schema_compatible('pain.001.002.03')
    end

    it 'rejects non-SLEV for pain.001.003.03' do
      expect(SEPA::CreditTransferTransaction.new(charge_bearer: 'DEBT'))
        .not_to be_schema_compatible('pain.001.003.03')
    end

    it 'accepts SLEV for pain.001.002.03' do
      expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA', charge_bearer: 'SLEV'))
        .to be_schema_compatible('pain.001.002.03')
    end

    it 'accepts any for pain.001.001.03' do
      expect(SEPA::CreditTransferTransaction.new(charge_bearer: 'SHAR'))
        .to be_schema_compatible('pain.001.001.03')
    end

    it 'accepts any for pain.001.001.09' do
      expect(SEPA::CreditTransferTransaction.new(charge_bearer: 'DEBT'))
        .to be_schema_compatible('pain.001.001.09')
    end

    it 'accepts nil for EPC schemas' do
      expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA', charge_bearer: nil))
        .to be_schema_compatible('pain.001.002.03')
    end
  end

  context 'Creditor Address' do
    it 'accepts valid address_line' do
      expect(SEPA::CreditTransferTransaction).to accept(SEPA::CreditorAddress.new(
                                                          country_code: 'CH',
                                                          address_line1: 'Musterstrasse 123',
                                                          address_line2: '1234 Musterstadt'
                                                        ), for: :creditor_address)
    end

    it 'accepts valid structured address' do
      expect(SEPA::CreditTransferTransaction).to accept(SEPA::CreditorAddress.new(
                                                          country_code: 'CH',
                                                          street_name: 'Mustergasse',
                                                          building_number: '123',
                                                          post_code: '1234',
                                                          town_name: 'Musterstadt'
                                                        ), for: :creditor_address)
    end
  end

  context 'Category Purpose' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'SALA', 'INST', 'X' * 4, for: :category_purpose)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'X' * 5, for: :category_purpose)
    end
  end

  context 'Purpose Code' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'SALA', 'PENS', 'X' * 4, for: :purpose_code)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'X' * 5, for: :purpose_code)
    end
  end

  context 'Ultimate Creditor Name' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'Ultimate Corp', 'X' * 70, for: :ultimate_creditor_name)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'X' * 71, for: :ultimate_creditor_name)
    end
  end

  context 'Ultimate Debtor Name' do
    it 'allows valid value' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, 'Ultimate Debtor', 'X' * 70, for: :ultimate_debtor_name)
    end

    it 'does not allow invalid value' do
      expect(SEPA::CreditTransferTransaction).not_to accept('', 'X' * 71, for: :ultimate_debtor_name)
    end
  end

  context 'Agent LEI' do
    it 'allows valid LEI' do
      expect(SEPA::CreditTransferTransaction).to accept(nil, SEPA::TestData::LEI, for: :agent_lei)
    end

    it 'does not allow invalid LEI' do
      expect(SEPA::CreditTransferTransaction).not_to accept('invalid', 'short', '529900t8bm49aursdo55', for: :agent_lei)
    end
  end

  context 'Creditor Contact Details' do
    it 'accepts valid contact details' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG',
        iban: SEPA::TestData::CT_TX_IBAN,
        amount: 100,
        creditor_contact_details: SEPA::ContactDetails.new(name: 'John Doe')
      )
      expect(txn.errors_on(:creditor_contact_details)).to be_empty
    end

    it 'propagates contact details validation errors' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG',
        iban: SEPA::TestData::CT_TX_IBAN,
        amount: 100,
        creditor_contact_details: SEPA::ContactDetails.new(name_prefix: 'INVALID')
      )
      expect(txn.errors_on(:creditor_contact_details)).not_to be_empty
    end

    it 'accepts nil contact details' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG',
        iban: SEPA::TestData::CT_TX_IBAN,
        amount: 100
      )
      expect(txn.errors_on(:creditor_contact_details)).to be_empty
    end
  end

  describe 'Regulatory Reportings extended validation' do
    it 'validates authority name max 140 characters' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ authority: { name: 'X' * 141 } }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/authority name exceeds 140/)
    end

    it 'validates authority country code format' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ authority: { country: 'DEU' } }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/authority country must be a 2-letter code/)
    end

    it 'validates detail date is a Date' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ date: '2025-01-01' }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/date must be a Date/)
    end

    it 'validates detail country code format' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ country: 'DEU' }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/country must be a 2-letter code/)
    end

    it 'validates detail amount requires value and currency' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ amount: { value: 100 } }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/amount must have :value and :currency/)
    end

    it 'validates detail amount currency format' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ amount: { value: 100, currency: 'EU' } }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/amount currency invalid/)
    end

    it 'validates detail amount value is numeric' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ amount: { value: 'abc', currency: 'EUR' } }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/amount value must be numeric/)
    end

    it 'validates type and type_proprietary are mutually exclusive' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ type: 'A', type_proprietary: 'B' }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/mutually exclusive/)
    end

    it 'validates detail type max 35 characters' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, amount: 100,
        regulatory_reportings: [{ details: [{ type: 'X' * 36 }] }]
      )
      expect(txn.errors_on(:regulatory_reportings).join).to match(/type too long/)
    end

    it 'accepts valid regulatory reporting with all detail fields' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Test AG', iban: SEPA::TestData::CT_TX_IBAN, bic: SEPA::TestData::CT_TX_BIC, amount: 100,
        regulatory_reportings: [{
          indicator: 'CRED',
          authority: { name: 'Bundesbank', country: 'DE' },
          details: [{
            type: 'PAYMENT',
            date: Date.new(2025, 1, 1),
            country: 'DE',
            code: 'ABC',
            amount: { value: 100, currency: 'EUR' },
            information: ['Info line']
          }]
        }]
      )
      expect(txn.errors_on(:regulatory_reportings)).to be_empty
    end
  end

  describe 'schema_compatible? with LEI' do
    it 'rejects LEI for pain.001.001.03' do
      expect(SEPA::CreditTransferTransaction.new(agent_lei: SEPA::TestData::LEI))
        .not_to be_schema_compatible('pain.001.001.03')
    end

    it 'rejects LEI for pain.001.002.03' do
      expect(SEPA::CreditTransferTransaction.new(bic: SEPA::TestData::DD_TX_ALT_BIC, service_level: 'SEPA', agent_lei: SEPA::TestData::LEI))
        .not_to be_schema_compatible('pain.001.002.03')
    end

    it 'accepts LEI for pain.001.001.09' do
      expect(SEPA::CreditTransferTransaction.new(agent_lei: SEPA::TestData::LEI))
        .to be_schema_compatible('pain.001.001.09')
    end

    it 'accepts LEI for pain.001.001.13' do
      expect(SEPA::CreditTransferTransaction.new(agent_lei: SEPA::TestData::LEI))
        .to be_schema_compatible('pain.001.001.13')
    end
  end
end
