# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DebtorAccount do
  it 'initializes a new account' do
    expect(
      SEPA::DebtorAccount.new(name: 'Gläubiger GmbH',
                              bic: 'BANKDEFFXXX',
                              iban: 'DE87200500001234567890')
    ).to be_valid
  end
end
