# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DirectDebitTransaction do
  describe :initialize do
    it 'creates a valid transaction' do
      expect(
        SEPA::DirectDebitTransaction.new(name: 'Zahlemann & Söhne Gbr',
                                         bic: 'SPUEDE2UXXX',
                                         iban: 'DE21500500009876543210',
                                         amount: 39.99,
                                         reference: 'XYZ-1234/123',
                                         remittance_information: 'Vielen Dank für Ihren Einkauf!',
                                         mandate_id: 'K-02-2011-12345',
                                         mandate_date_of_signature: Date.new(2011, 1, 25))
      ).to be_valid
    end
  end

  describe :schema_compatible? do
    context 'for pain.008.003.02' do
      it 'succeeds' do
        expect(SEPA::DirectDebitTransaction.new({})).to be_schema_compatible('pain.008.003.02')
      end

      it 'fails for invalid attributes' do
        expect(SEPA::DirectDebitTransaction.new(currency: 'CHF')).not_to be_schema_compatible('pain.008.003.02')
      end

      it 'rejects RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).not_to be_schema_compatible('pain.008.003.02')
      end
    end

    context 'for pain.008.002.02' do
      it 'succeeds for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE')).to be_schema_compatible('pain.008.002.02')
      end

      it 'fails for invalid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).not_to be_schema_compatible('pain.008.002.02')
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'COR1')).not_to be_schema_compatible('pain.008.002.02')
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).not_to be_schema_compatible('pain.008.002.02')
      end

      it 'rejects RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', sequence_type: 'RPRE'))
          .not_to be_schema_compatible('pain.008.002.02')
      end
    end

    context 'for pain.008.001.02' do
      it 'succeeds for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.02')
      end

      it 'rejects RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).not_to be_schema_compatible('pain.008.001.02')
      end
    end

    context 'for pain.008.001.08' do
      it 'succeeds for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.08')
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).to be_schema_compatible('pain.008.001.08')
      end

      it 'accepts RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).to be_schema_compatible('pain.008.001.08')
      end

      it 'accepts UETR' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.008.001.08')
      end
    end

    context 'for pain.008.001.12' do
      it 'succeeds for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.12')
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).to be_schema_compatible('pain.008.001.12')
      end

      it 'accepts RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).to be_schema_compatible('pain.008.001.12')
      end

      it 'accepts UETR' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.008.001.12')
      end
    end

    context 'UETR schema compatibility' do
      it 'rejects UETR for pain.008.001.02' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.008.001.02')
      end

      it 'rejects UETR for pain.008.002.02' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.008.002.02')
      end
    end
  end

  context 'Debtor Address' do
    it 'accepts valid address_line' do
      expect(SEPA::DirectDebitTransaction).to accept(SEPA::DebtorAddress.new(
                                                       country_code: 'CH',
                                                       address_line1: 'Musterstrasse 123',
                                                       address_line2: '1234 Musterstadt'
                                                     ), for: :debtor_address)
    end

    it 'accepts valid structured address' do
      expect(SEPA::DirectDebitTransaction).to accept(SEPA::DebtorAddress.new(
                                                       country_code: 'CH',
                                                       street_name: 'Mustergasse',
                                                       building_number: '123',
                                                       post_code: '1234',
                                                       town_name: 'Musterstadt'
                                                     ), for: :debtor_address)
    end
  end

  context 'Creditor Account' do
    it 'propagates errors from invalid creditor_account' do
      invalid_account = SEPA::CreditorAccount.new(name: '', iban: 'INVALID')
      transaction = SEPA::DirectDebitTransaction.new(
        direct_debit_transaction(creditor_account: invalid_account)
      )

      expect(transaction).not_to be_valid
      expect(transaction.errors[:creditor_account]).not_to be_empty
    end
  end

  context 'Original Debtor Account' do
    it 'accepts valid IBAN' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'DE21500500009876543210', for: :original_debtor_account)
    end

    it 'does not accept invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('INVALID', 'XX00000000',
                                                         'de21500500009876543210', # lowercase
                                                         'DE21 5005 0000 9876 5432 10', # spaces
                                                         for: :original_debtor_account)
    end
  end

  context 'Charge Bearer' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'DEBT', 'CRED', 'SHAR', 'SLEV', for: :charge_bearer)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'INVALID', 'slev', for: :charge_bearer)
    end
  end

  context 'Charge Bearer schema compatibility' do
    it 'rejects non-SLEV for pain.008.002.02' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', charge_bearer: 'SHAR'))
        .not_to be_schema_compatible('pain.008.002.02')
    end

    it 'rejects non-SLEV for pain.008.003.02' do
      expect(SEPA::DirectDebitTransaction.new(charge_bearer: 'DEBT'))
        .not_to be_schema_compatible('pain.008.003.02')
    end

    it 'accepts SLEV for pain.008.002.02' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', charge_bearer: 'SLEV'))
        .to be_schema_compatible('pain.008.002.02')
    end

    it 'accepts any for pain.008.001.02' do
      expect(SEPA::DirectDebitTransaction.new(charge_bearer: 'SHAR'))
        .to be_schema_compatible('pain.008.001.02')
    end

    it 'accepts any for pain.008.001.08' do
      expect(SEPA::DirectDebitTransaction.new(charge_bearer: 'DEBT'))
        .to be_schema_compatible('pain.008.001.08')
    end

    it 'accepts nil for EPC schemas' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', charge_bearer: nil))
        .to be_schema_compatible('pain.008.002.02')
    end
  end

  context 'Original Mandate ID' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'OLD-MANDATE-123', 'X' * 35, for: :original_mandate_id)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'X' * 36, '!@#$%', for: :original_mandate_id)
    end
  end

  context 'Instruction Priority' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'HIGH', 'NORM', for: :instruction_priority)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'LOW', 'high', for: :instruction_priority)
    end
  end

  describe 'InstrPrty schema compatibility' do
    it 'rejects for pain.008.002.02' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', instruction_priority: 'HIGH'))
        .not_to be_schema_compatible('pain.008.002.02')
    end

    it 'rejects for pain.008.003.02' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .not_to be_schema_compatible('pain.008.003.02')
    end

    it 'accepts for pain.008.001.02' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .to be_schema_compatible('pain.008.001.02')
    end

    it 'accepts for pain.008.001.08' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .to be_schema_compatible('pain.008.001.08')
    end
  end

  context 'Mandate Date of Signature' do
    around { |example| travel_to(Time.new(2025, 6, 15, 12, 0, 0)) { example.run } }

    it 'accepts valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(Date.today, Date.today - 1, for: :mandate_date_of_signature)
    end

    it 'does not accept invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept(nil, '2010-12-01', Date.today + 1, for: :mandate_date_of_signature)
    end
  end

  context 'Purpose Code' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'SALA', 'PENS', 'X' * 4, for: :purpose_code)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'X' * 5, for: :purpose_code)
    end
  end

  context 'Ultimate Debtor Name' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'Ultimate Debtor', 'X' * 70, for: :ultimate_debtor_name)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'X' * 71, for: :ultimate_debtor_name)
    end
  end

  context 'Ultimate Creditor Name' do
    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'Ultimate Creditor', 'X' * 70, for: :ultimate_creditor_name)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'X' * 71, for: :ultimate_creditor_name)
    end
  end

  context 'Requested date' do
    around { |example| travel_to(Time.new(2025, 6, 15, 12, 0, 0)) { example.run } }

    it 'allows valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, Date.new(1999, 1, 1), Date.today.next, Date.today + 2, for: :requested_date)
    end

    it 'does not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept(Date.new(1995, 12, 21), Date.today - 1, Date.today, for: :requested_date)
    end
  end

  context 'Agent LEI' do
    it 'allows valid LEI' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, '529900T8BM49AURSDO55', for: :agent_lei)
    end

    it 'does not allow invalid LEI' do
      expect(SEPA::DirectDebitTransaction).not_to accept('invalid', 'short', for: :agent_lei)
    end
  end

  context 'Debtor Contact Details' do
    it 'accepts valid contact details' do
      txn = SEPA::DirectDebitTransaction.new(
        name: 'Test GmbH',
        iban: 'DE21500500009876543210',
        bic: 'SPUEDE2UXXX',
        amount: 39.99,
        mandate_id: 'K-02-2011-12345',
        mandate_date_of_signature: Date.new(2011, 1, 25),
        debtor_contact_details: SEPA::ContactDetails.new(name: 'John Doe')
      )
      expect(txn.errors_on(:debtor_contact_details)).to be_empty
    end

    it 'propagates contact details validation errors' do
      txn = SEPA::DirectDebitTransaction.new(
        name: 'Test GmbH',
        iban: 'DE21500500009876543210',
        bic: 'SPUEDE2UXXX',
        amount: 39.99,
        mandate_id: 'K-02-2011-12345',
        mandate_date_of_signature: Date.new(2011, 1, 25),
        debtor_contact_details: SEPA::ContactDetails.new(name_prefix: 'INVALID')
      )
      expect(txn.errors_on(:debtor_contact_details)).not_to be_empty
    end
  end

  describe 'schema_compatible? with LEI' do
    it 'rejects LEI for pain.008.001.02' do
      expect(SEPA::DirectDebitTransaction.new(agent_lei: '529900T8BM49AURSDO55'))
        .not_to be_schema_compatible('pain.008.001.02')
    end

    it 'rejects LEI for pain.008.002.02' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', agent_lei: '529900T8BM49AURSDO55'))
        .not_to be_schema_compatible('pain.008.002.02')
    end

    it 'accepts LEI for pain.008.001.08' do
      expect(SEPA::DirectDebitTransaction.new(agent_lei: '529900T8BM49AURSDO55'))
        .to be_schema_compatible('pain.008.001.08')
    end

    it 'accepts LEI for pain.008.001.12' do
      expect(SEPA::DirectDebitTransaction.new(agent_lei: '529900T8BM49AURSDO55'))
        .to be_schema_compatible('pain.008.001.12')
    end
  end
end
