# frozen_string_literal: true

require 'spec_helper'

IBANValidatable = Class.new do
  include ActiveModel::Model

  attr_accessor :iban, :iban_the_terrible

  validates_with SEPA::IBANValidator, message: '%<value>s seems wrong'
  validates_with SEPA::IBANValidator, field_name: :iban_the_terrible
end

BICValidatable = Class.new do
  include ActiveModel::Model

  attr_accessor :bic, :custom_bic

  validates_with SEPA::BICValidator, message: '%<value>s seems wrong'
  validates_with SEPA::BICValidator, field_name: :custom_bic
end

CreditorIdentifierValidatable = Class.new do
  include ActiveModel::Model

  attr_accessor :creditor_identifier, :crid

  validates_with SEPA::CreditorIdentifierValidator, message: '%<value>s seems wrong'
  validates_with SEPA::CreditorIdentifierValidator, field_name: :crid
end

MandateIdentifierValidatable = Class.new do
  include ActiveModel::Model

  attr_accessor :mandate_id, :mid

  validates_with SEPA::MandateIdentifierValidator, message: '%<value>s seems wrong'
  validates_with SEPA::MandateIdentifierValidator, field_name: :mid
end

LEIValidatable = Class.new do
  include ActiveModel::Model

  attr_accessor :lei, :custom_lei

  validates_with SEPA::LEIValidator, message: '%<value>s seems wrong'
  validates_with SEPA::LEIValidator, field_name: :custom_lei
end

RSpec.describe SEPA::IBANValidator do
  it 'accepts valid IBAN' do
    expect(IBANValidatable).to accept('DE21500500009876543210', 'DE87200500001234567890',
                                      for: %i[iban iban_the_terrible])
  end

  it 'does not accept an invalid IBAN' do
    expect(IBANValidatable).not_to accept('', 'xxx',                     # Oviously no IBAN
                                          'DE22500500009876543210',      # wrong checksum
                                          'DE2150050000987654321',       # too short
                                          'de87200500001234567890',      # downcase characters
                                          'DE87 2005 0000 1234 5678 90', # spaces included
                                          for: %i[iban iban_the_terrible])
  end

  it 'customizes error message' do
    v = IBANValidatable.new(iban: 'xxx')
    v.valid?
    expect(v.errors[:iban]).to eq(['xxx seems wrong'])
  end

  it 'provides a detailed error message with field names by default' do
    v = IBANValidatable.new(iban_the_terrible: 'DE22500500009876543210')
    v.valid?
    expect(v.errors[:iban_the_terrible].first).to match(/\Ais invalid \(\w+ .+\)\z/)
  end

  it 'provides a specific message for lowercase or spaced IBANs' do
    v = IBANValidatable.new(iban_the_terrible: 'de87200500001234567890')
    v.valid?
    expect(v.errors[:iban_the_terrible]).to eq(['is invalid (must be uppercase with no spaces)'])
  end
end

RSpec.describe SEPA::BICValidator do
  it 'accepts valid v03 BICs (AnyBICIdentifier)' do
    expect(BICValidatable).to accept('DEUTDEDBDUE', 'DUSSDEDDXXX', for: %i[bic custom_bic])
  end

  it 'accepts valid v09/v13 BICs (BICFIDec2014Identifier) with digits in first positions' do
    expect(BICValidatable).to accept('1234DEFFXXX', 'AB12FR00', for: %i[bic custom_bic])
  end

  it 'does not accept an invalid BIC' do
    expect(BICValidatable).not_to accept('', 'GENODE61HR', 'DEUTDEDBDUEDEUTDEDBDUE',
                                         '12345678', # country code positions not letters
                                         for: %i[bic custom_bic])
  end

  it 'customizes error message' do
    v = BICValidatable.new(bic: 'xxx')
    v.valid?
    expect(v.errors[:bic]).to eq(['xxx seems wrong'])
  end
end

RSpec.describe SEPA::CreditorIdentifierValidator do
  it 'accepts valid creditor_identifier' do
    expect(CreditorIdentifierValidatable).to accept(
      'DE98ZZZ09999999999',
      'CH1312300000012345',
      'SE41ZZZ1234567890',
      'PL18ZZZ0123456789',
      'NO38ZZZ123456785',
      'HU74111A12345676',
      'BG07ZZZ100064095',
      'AT88ZZZ00000000001',
      'FR72ZZZ123456',
      'NL42ZZZ123456780001',
      for: %i[creditor_identifier crid]
    )
  end

  it 'does not accept an invalid creditor_identifier' do
    expect(CreditorIdentifierValidatable).not_to accept(
      '',
      'xxx',
      'DE98ZZZ099999999990',
      'DE98---09999999999',
      for: %i[creditor_identifier crid]
    )
  end

  it 'customizes error message' do
    v = CreditorIdentifierValidatable.new(creditor_identifier: 'xxx')
    v.valid?
    expect(v.errors[:creditor_identifier]).to eq(['xxx seems wrong'])
  end
end

RSpec.describe SEPA::MandateIdentifierValidator do
  it 'accepts valid mandate_identifier' do
    expect(MandateIdentifierValidatable).to accept('XYZ-123', "+?/-:().,'", 'X' * 35, for: %i[mandate_id mid])
  end

  it 'does not accept an invalid mandate_identifier' do
    expect(MandateIdentifierValidatable).not_to accept(nil, '', 'X' * 36, '#/*', 'Ümläüt', for: %i[mandate_id mid])
  end

  it 'customizes error message' do
    v = MandateIdentifierValidatable.new(mandate_id: '*** 123')
    v.valid?
    expect(v.errors[:mandate_id]).to eq(['*** 123 seems wrong'])
  end
end

RSpec.describe SEPA::LEIValidator do
  it 'accepts valid LEI' do
    expect(LEIValidatable).to accept('529900T8BM49AURSDO55', 'ABCDEFGHIJKLMNOPQR30', '7ZW8GROSS5KVJYZ6MU86',
                                     for: %i[lei custom_lei])
  end

  it 'accepts nil (LEI is optional)' do
    expect(LEIValidatable).to accept(nil, for: %i[lei custom_lei])
  end

  it 'does not accept an invalid LEI' do
    expect(LEIValidatable).not_to accept('',                        # empty
                                         'xxx',                     # too short
                                         '529900T8BM49AURSDO5',    # 19 chars (too short)
                                         '529900T8BM49AURSDO555',  # 21 chars (too long)
                                         '529900t8bm49aursdo55',   # lowercase letters
                                         '529900T8BM49AURSDO5A',   # last 2 must be digits
                                         '529900T8BM49AURSDO56',   # wrong checksum
                                         for: %i[lei custom_lei])
  end

  it 'customizes error message' do
    v = LEIValidatable.new(lei: 'xxx')
    v.valid?
    expect(v.errors[:lei]).to eq(['xxx seems wrong'])
  end
end

RSpec.describe SEPA, '.mod97_valid?' do
  it 'returns true for valid checksums' do
    expect(SEPA.mod97_valid?('529900T8BM49AURSDO55')).to be true            # valid LEI
    expect(SEPA.mod97_valid?('09999999999DE98')).to be true                 # rearranged creditor id
  end

  it 'returns false for invalid checksums' do
    expect(SEPA.mod97_valid?('529900T8BM49AURSDO56')).to be false
    expect(SEPA.mod97_valid?('AAAA')).to be false
  end
end

RSpec.describe SEPA::IBANValidator, '.valid_iban?' do
  it 'returns true for valid IBANs' do
    expect(SEPA::IBANValidator.valid_iban?('DE87200500001234567890')).to be true
  end

  it 'returns false for invalid IBANs' do
    expect(SEPA::IBANValidator.valid_iban?('DE22500500009876543210')).to be false
  end

  it 'returns false for lowercase IBANs' do
    expect(SEPA::IBANValidator.valid_iban?('de87200500001234567890')).to be false
  end

  it 'returns false for spaced IBANs' do
    expect(SEPA::IBANValidator.valid_iban?('DE87 2005 0000 1234 5678 90')).to be false
  end
end
