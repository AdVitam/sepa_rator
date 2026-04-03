# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DebtorAddress do
  it 'should initialize a new address' do
    expect(
      SEPA::DebtorAddress.new(country_code: 'CH',
                              address_line1: 'Mustergasse 123',
                              address_line2: '12345 Musterstadt')
    ).to be_valid
  end

  it 'should accept PostalAddress24 fields' do
    expect(
      SEPA::DebtorAddress.new(
        country_code: 'DE',
        street_name: 'Hauptstrasse',
        building_number: '42',
        building_name: 'Tower A',
        floor: '3',
        post_box: '1234',
        room: '301',
        post_code: '10115',
        town_name: 'Berlin',
        town_location_name: 'Mitte',
        district_name: 'Berlin-Mitte',
        country_sub_division: 'BE',
        department: 'Finance',
        sub_department: 'Accounts'
      )
    ).to be_valid
  end

  it 'should accept PostalAddress27 fields' do
    expect(
      SEPA::DebtorAddress.new(
        country_code: 'DE',
        street_name: 'Hauptstrasse',
        care_of: 'c/o Max Mustermann',
        unit_number: '4B'
      )
    ).to be_valid
  end

  it 'should reject too-long field values' do
    expect(SEPA::DebtorAddress.new(country_code: 'DE', care_of: 'X' * 141)).not_to be_valid
    expect(SEPA::DebtorAddress.new(country_code: 'DE', building_name: 'X' * 141)).not_to be_valid
    expect(SEPA::DebtorAddress.new(country_code: 'DE', unit_number: 'X' * 17)).not_to be_valid
    expect(SEPA::DebtorAddress.new(country_code: 'DE', department: 'X' * 71)).not_to be_valid
    expect(SEPA::DebtorAddress.new(country_code: 'DE', country_sub_division: 'X' * 36)).not_to be_valid
  end
end
