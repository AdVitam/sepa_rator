# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::CreditorAccount do
  it 'initializes a new account' do
    expect(
      SEPA::CreditorAccount.new(name: 'Gläubiger GmbH',
                                bic: 'BANKDEFFXXX',
                                iban: 'DE87200500001234567890',
                                creditor_identifier: 'DE98ZZZ09999999999')
    ).to be_valid
  end

  describe :creditor_identifier do
    it 'accepts valid value' do
      expect(SEPA::CreditorAccount).to accept('DE98ZZZ09999999999', 'AT88ZZZ00000000001', 'IT66ZZZA1B2C3D4E5F6G7H8', 'NL42ZZZ123456780001', 'FR72ZZZ123456', for: :creditor_identifier)
    end

    it 'does not accept invalid value' do
      expect(SEPA::CreditorAccount).not_to accept('', 'invalid', 'DE98ZZZ099999999990', 'DEAAAAAAAAAAAAAAAA', for: :creditor_identifier)
    end
  end
end
