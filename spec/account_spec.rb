# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Account do
  describe :new do
    it 'does not accept unknown keys' do
      expect do
        SEPA::Account.new foo: 'bar'
      end.to raise_error(ActiveModel::UnknownAttributeError)
    end
  end

  describe :name do
    it 'accepts valid value' do
      expect(SEPA::Account).to accept('Gläubiger GmbH', 'Zahlemann & Söhne GbR', 'X' * 70, for: :name)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Account).not_to accept(nil, '', 'X' * 71, for: :name)
    end
  end

  describe :iban do
    it 'accepts valid value' do
      expect(SEPA::Account).to accept('DE21500500009876543210', 'PL61109010140000071219812874', for: :iban)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Account).not_to accept(nil, '', 'invalid', for: :iban)
    end
  end

  describe :bic do
    it 'accepts valid value' do
      expect(SEPA::Account).to accept('DEUTDEFF', 'DEUTDEFF500', SEPA::TestData::DD_TX_ALT_BIC, for: :bic)
    end

    it 'does not accept invalid value' do
      expect(SEPA::Account).not_to accept('', 'invalid', for: :bic)
    end
  end

  describe :address do
    it 'accepts a valid address' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC,
        address: SEPA::Address.new(country_code: 'DE', town_name: 'Berlin', post_code: '10115')
      )
      expect(account).to be_valid
    end

    it 'accepts nil address' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC
      )
      expect(account).to be_valid
    end

    it 'propagates address validation errors' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC,
        address: SEPA::Address.new(country_code: 'INVALID')
      )
      expect(account).not_to be_valid
      expect(account.errors[:address]).not_to be_empty
    end
  end

  describe :agent_lei do
    it 'accepts valid LEI' do
      expect(SEPA::Account).to accept(nil, SEPA::TestData::LEI, for: :agent_lei)
    end

    it 'does not accept invalid LEI' do
      expect(SEPA::Account).not_to accept('invalid', 'short', '529900t8bm49aursdo55', for: :agent_lei)
    end
  end

  describe :contact_details do
    it 'accepts valid contact details' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC,
        contact_details: SEPA::ContactDetails.new(name: 'John Doe', phone_number: '+49123456789')
      )
      expect(account).to be_valid
    end

    it 'accepts nil contact details' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC
      )
      expect(account).to be_valid
    end

    it 'propagates contact details validation errors' do
      account = SEPA::Account.new(
        name: 'Test GmbH',
        iban: SEPA::TestData::DEBTOR_IBAN,
        bic: SEPA::TestData::DEBTOR_BIC,
        contact_details: SEPA::ContactDetails.new(name_prefix: 'INVALID')
      )
      expect(account).not_to be_valid
      expect(account.errors[:contact_details]).not_to be_empty
    end
  end
end
