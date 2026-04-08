# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DebtorAccount do
  it 'initializes a new account' do
    expect(
      SEPA::DebtorAccount.new(name: SEPA::TestData::CREDITOR_NAME,
                              bic: SEPA::TestData::DEBTOR_BIC,
                              iban: SEPA::TestData::DEBTOR_IBAN)
    ).to be_valid
  end

  describe :agent_lei do
    it 'accepts valid LEI' do
      expect(SEPA::DebtorAccount).to accept(nil, SEPA::TestData::LEI, for: :agent_lei)
    end

    it 'does not accept invalid LEI' do
      expect(SEPA::DebtorAccount).not_to accept('invalid', 'short', for: :agent_lei)
    end
  end

  describe :initiating_party_lei do
    it 'accepts valid LEI' do
      expect(SEPA::DebtorAccount).to accept(nil, SEPA::TestData::LEI, for: :initiating_party_lei)
    end

    it 'does not accept invalid LEI' do
      expect(SEPA::DebtorAccount).not_to accept('invalid', 'short', for: :initiating_party_lei)
    end
  end

  describe :initiating_party_bic do
    it 'accepts valid BIC' do
      expect(SEPA::DebtorAccount).to accept(nil, 'DEUTDEFF', 'DEUTDEFF500', for: :initiating_party_bic)
    end

    it 'does not accept invalid BIC' do
      expect(SEPA::DebtorAccount).not_to accept('invalid', '', for: :initiating_party_bic)
    end
  end

  describe :initiating_party_identifier do
    it 'accepts valid values up to 256 characters' do
      expect(SEPA::DebtorAccount).to accept(nil, 'DE98ZZZ09999999999', 'X' * 256, for: :initiating_party_identifier)
    end

    it 'does not accept values exceeding 256 characters' do
      expect(SEPA::DebtorAccount).not_to accept('', 'X' * 257, for: :initiating_party_identifier)
    end
  end
end
