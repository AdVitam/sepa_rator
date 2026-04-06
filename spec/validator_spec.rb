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
end

RSpec.describe SEPA::BICValidator do
  it 'accepts valid BICs' do
    expect(BICValidatable).to accept('DEUTDEDBDUE', 'DUSSDEDDXXX', for: %i[bic custom_bic])
  end

  it 'does not accept an invalid BIC' do
    expect(BICValidatable).not_to accept('', 'GENODE61HR', 'DEUTDEDBDUEDEUTDEDBDUE', for: %i[bic custom_bic])
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
