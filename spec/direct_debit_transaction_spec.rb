# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DirectDebitTransaction do
  describe :initialize do
    it 'should create a valid transaction' do
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
      it 'should succeed' do
        expect(SEPA::DirectDebitTransaction.new({})).to be_schema_compatible('pain.008.003.02')
      end

      it 'should fail for invalid attributes' do
        expect(SEPA::DirectDebitTransaction.new(currency: 'CHF')).not_to be_schema_compatible('pain.008.003.02')
      end

      it 'should reject RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).not_to be_schema_compatible('pain.008.003.02')
      end
    end

    context 'for pain.008.002.02' do
      it 'should succeed for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE')).to be_schema_compatible('pain.008.002.02')
      end

      it 'should fail for invalid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).not_to be_schema_compatible('pain.008.002.02')
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'COR1')).not_to be_schema_compatible('pain.008.002.02')
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).not_to be_schema_compatible('pain.008.002.02')
      end

      it 'should reject RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', sequence_type: 'RPRE'))
          .not_to be_schema_compatible('pain.008.002.02')
      end
    end

    context 'for pain.008.001.02' do
      it 'should succeed for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.02')
      end

      it 'should reject RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).not_to be_schema_compatible('pain.008.001.02')
      end
    end

    context 'for pain.008.001.08' do
      it 'should succeed for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.08')
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).to be_schema_compatible('pain.008.001.08')
      end

      it 'should accept RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).to be_schema_compatible('pain.008.001.08')
      end

      it 'should accept UETR' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.008.001.08')
      end
    end

    context 'for pain.008.001.12' do
      it 'should succeed for valid attributes' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', currency: 'CHF')).to be_schema_compatible('pain.008.001.12')
        expect(SEPA::DirectDebitTransaction.new(bic: nil)).to be_schema_compatible('pain.008.001.12')
      end

      it 'should accept RPRE sequence type' do
        expect(SEPA::DirectDebitTransaction.new(sequence_type: 'RPRE')).to be_schema_compatible('pain.008.001.12')
      end

      it 'should accept UETR' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .to be_schema_compatible('pain.008.001.12')
      end
    end

    context 'UETR schema compatibility' do
      it 'should reject UETR for pain.008.001.02' do
        expect(SEPA::DirectDebitTransaction.new(uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.008.001.02')
      end

      it 'should reject UETR for pain.008.002.02' do
        expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', uetr: '550e8400-e29b-41d4-a716-446655440000'))
          .not_to be_schema_compatible('pain.008.002.02')
      end
    end
  end

  context 'Instruction Priority' do
    it 'should allow valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, 'HIGH', 'NORM', for: :instruction_priority)
    end

    it 'should not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept('', 'LOW', 'high', for: :instruction_priority)
    end
  end

  describe 'InstrPrty schema compatibility' do
    it 'should reject for pain.008.002.02' do
      expect(SEPA::DirectDebitTransaction.new(bic: 'SPUEDE2UXXX', local_instrument: 'CORE', instruction_priority: 'HIGH'))
        .not_to be_schema_compatible('pain.008.002.02')
    end

    it 'should reject for pain.008.003.02' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .not_to be_schema_compatible('pain.008.003.02')
    end

    it 'should accept for pain.008.001.02' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .to be_schema_compatible('pain.008.001.02')
    end

    it 'should accept for pain.008.001.08' do
      expect(SEPA::DirectDebitTransaction.new(instruction_priority: 'HIGH'))
        .to be_schema_compatible('pain.008.001.08')
    end
  end

  context 'Mandate Date of Signature' do
    around(:each) { |example| travel_to(Time.new(2025, 6, 15, 12, 0, 0)) { example.run } }

    it 'should accept valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(Date.today, Date.today - 1, for: :mandate_date_of_signature)
    end

    it 'should not accept invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept(nil, '2010-12-01', Date.today + 1, for: :mandate_date_of_signature)
    end
  end

  context 'Requested date' do
    around(:each) { |example| travel_to(Time.new(2025, 6, 15, 12, 0, 0)) { example.run } }

    it 'should allow valid value' do
      expect(SEPA::DirectDebitTransaction).to accept(nil, Date.new(1999, 1, 1), Date.today.next, Date.today + 2, for: :requested_date)
    end

    it 'should not allow invalid value' do
      expect(SEPA::DirectDebitTransaction).not_to accept(Date.new(1995, 12, 21), Date.today - 1, Date.today, for: :requested_date)
    end
  end
end
