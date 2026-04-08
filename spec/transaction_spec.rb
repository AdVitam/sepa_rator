# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Transaction do
  describe :new do
    it 'has default for reference' do
      expect(SEPA::Transaction.new.reference).to eq('NOTPROVIDED')
    end

    it 'has default for requested_date' do
      expect(SEPA::Transaction.new.requested_date).to eq(Date.new(1999, 1, 1))
    end

    it 'has default for batch_booking' do
      expect(SEPA::Transaction.new.batch_booking).to be(true)
    end
  end

  context 'Name' do
    it 'accepts valid value' do
      expect(SEPA::Transaction).to accept('Manfred Mustermann III.', 'Zahlemann & Söhne GbR', 'X' * 70, for: :name)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Transaction).not_to accept(nil, '', 'X' * 71, for: :name)
    end
  end

  context 'IBAN' do
    it 'accepts valid value' do
      expect(SEPA::Transaction).to accept('DE21500500009876543210', 'PL61109010140000071219812874', for: :iban)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Transaction).not_to accept(nil, '', 'invalid', for: :iban)
    end
  end

  context 'BIC' do
    it 'accepts valid value' do
      expect(SEPA::Transaction).to accept('DEUTDEFF', 'DEUTDEFF500', 'SPUEDE2UXXX', for: :bic)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Transaction).not_to accept('', 'invalid', for: :bic)
    end
  end

  context 'Amount' do
    it 'accepts valid value' do
      expect(SEPA::Transaction).to accept(0.01, 1, 100, 100.00, 99.99, 999_999_999.99, BigDecimal('10'), '42', '42.51', '42.512', 1.23456, for: :amount)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Transaction).not_to accept(nil, 0, -3, 'xz', 1_000_000_000, for: :amount)
    end
  end

  context 'Reference' do
    it 'accepts valid value' do
      expect(SEPA::Transaction).to accept(nil, 'ABC-1234/78.0', 'X' * 35, for: :reference)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Transaction).not_to accept('', 'X' * 36, for: :reference)
    end
  end

  context 'Remittance information' do
    it 'allows valid value' do
      expect(SEPA::Transaction).to accept(nil, 'Bonus', 'X' * 140, for: :remittance_information)
    end

    it 'does not allow invalid value' do
      expect(SEPA::Transaction).not_to accept('', 'X' * 141, for: :remittance_information)
    end
  end

  context 'Currency' do
    it 'allows valid values' do
      expect(SEPA::Transaction).to accept('EUR', 'CHF', 'SEK', for: :currency)
    end

    it 'does not allow invalid values' do
      expect(SEPA::Transaction).not_to accept('', 'EURO', 'ABCDEF', for: :currency)
    end
  end

  context 'Unknown attributes' do
    it 'raises ActiveModel::UnknownAttributeError for unknown attribute' do
      expect { SEPA::Transaction.new(nonexistent_attr: 'value') }.to raise_error(ActiveModel::UnknownAttributeError)
    end

    it 'accepts valid attributes' do
      expect { SEPA::Transaction.new(name: 'Test', iban: 'DE21500500009876543210', bic: 'SPUEDE2UXXX', amount: 100) }.not_to raise_error
    end
  end

  context 'UETR' do
    it 'accepts valid UUIDv4' do
      expect(SEPA::Transaction).to accept(nil, '550e8400-e29b-41d4-a716-446655440000', for: :uetr)
    end

    it 'does not accept invalid UETR' do
      expect(SEPA::Transaction).not_to accept(
        '',
        'not-a-uuid',
        '550e8400-e29b-31d4-a716-446655440000', # v3, not v4
        '550E8400-E29B-41D4-A716-446655440000', # uppercase
        for: :uetr
      )
    end
  end
end
