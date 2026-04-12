# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::SPS do
  describe 'SCT 09' do
    let(:profile) { described_class::SCT_09 }

    def fresh_sct(**overrides)
      SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                               bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                               **overrides)
    end

    it 'composes from ISO SCT 09 (not EPC)' do
      expect(profile.iso_schema).to eq 'pain.001.001.09'
      expect(profile.transaction_stages).to eq(SEPA::Profiles::ISO::SCT_09.transaction_stages)
    end

    it 'uses the Swiss XSD' do
      expect(profile.xsd_path).to eq 'sps/pain.001.001.09.ch.03.xsd'
    end

    it 'requires structured addresses' do
      expect(profile.features.requires_structured_address).to be true
    end

    it 'requires country code on addresses' do
      expect(profile.features.requires_country_code_on_address).to be true
    end

    it 'accepts EUR transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'EUR'))
      end.not_to raise_error
    end

    it 'accepts CHF transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'CHF', service_level: nil))
      end.not_to raise_error
    end

    it 'rejects GBP transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects SHAR charge bearer' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(charge_bearer: 'SHAR'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects an AdrLine-only creditor address' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'CH',
                                          address_line1: 'Musterstrasse 123',
                                          address_line2: '1234 Musterstadt')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'rejects a structured address without country code' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(street_name: 'Musterstrasse', building_number: '123',
                                          post_code: '1234', town_name: 'Musterstadt')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /[Cc]ountry code/)
    end

    it 'accepts a structured address with country code' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(
                              creditor_address: SEPA::CreditorAddress.new(
                                country_code: 'CH', street_name: 'Musterstrasse', building_number: '123',
                                post_code: '1234', town_name: 'Musterstadt'
                              )
                            ))
      end.not_to raise_error
    end

    it 'generates valid XML against the Swiss XSD' do
      sct = fresh_sct
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'CH', street_name: 'Musterstrasse', building_number: '123',
                              town_name: 'Musterstadt', post_code: '1234'
                            )
                          ))
      expect(sct.to_xml).to validate_against('sps/pain.001.001.09.ch.03.xsd')
    end

    context 'account-level address' do
      it 'rejects an account address without country code' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(street_name: 'Musterstrasse',
                                       post_code: '1234', town_name: 'Musterstadt')
          )
        end.to raise_error(SEPA::ValidationError, /[Cc]ountry code/)
      end

      it 'accepts a structured account address with country code' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(country_code: 'CH', street_name: 'Musterstrasse',
                                       post_code: '1234', town_name: 'Musterstadt')
          )
        end.not_to raise_error
      end
    end
  end

  describe 'SCT 03' do
    let(:profile) { described_class::SCT_03 }

    it 'composes from ISO SCT 03' do
      expect(profile.iso_schema).to eq 'pain.001.001.03'
    end

    it 'accepts CHF transactions' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'CHF', service_level: nil))
      end.not_to raise_error
    end

    it 'generates valid XML against the ISO v03 XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction)
      expect(sct.to_xml).to validate_against('pain.001.001.03.xsd')
    end
  end

  describe 'SCT 13' do
    let(:profile) { described_class::SCT_13 }

    it 'composes from ISO SCT 13' do
      expect(profile.iso_schema).to eq 'pain.001.001.13'
    end

    it 'generates valid XML against the ISO v13 XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'CH', street_name: 'Musterstrasse', building_number: '123',
                              town_name: 'Musterstadt', post_code: '1234'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.13.xsd')
    end
  end

  describe 'SDD 08' do
    let(:profile) { described_class::SDD_08 }

    it 'composes from ISO SDD 08' do
      expect(profile.iso_schema).to eq 'pain.008.001.08'
    end

    it 'requires structured addresses' do
      sdd = direct_debit_message(profile: profile)
      address = SEPA::DebtorAddress.new(country_code: 'CH', address_line1: 'Musterstrasse 1')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'rejects CHF direct debits (SEPA SDD is EUR-only)' do
      sdd = direct_debit_message(profile: profile)
      expect do
        sdd.add_transaction(direct_debit_transaction(currency: 'CHF'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'generates valid XML' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction(
                            debtor_address: SEPA::DebtorAddress.new(
                              country_code: 'CH', street_name: 'Musterstrasse', building_number: '1',
                              town_name: 'Bern', post_code: '3001'
                            )
                          ))
      expect(sdd.to_xml).to validate_against('pain.008.001.08.xsd')
    end
  end

  describe 'SDD 02' do
    let(:profile) { described_class::SDD_02 }

    it 'composes from ISO SDD 02' do
      expect(profile.iso_schema).to eq 'pain.008.001.02'
    end

    it 'generates valid XML against the ISO v02 XSD' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction)
      expect(sdd.to_xml).to validate_against('pain.008.001.02.xsd')
    end
  end

  describe 'profile ids' do
    it 'registers all SPS profiles in the registry' do
      expect(SEPA::ProfileRegistry['sps.sct.03']).to equal(described_class::SCT_03)
      expect(SEPA::ProfileRegistry['sps.sct.09']).to equal(described_class::SCT_09)
      expect(SEPA::ProfileRegistry['sps.sct.13']).to equal(described_class::SCT_13)
      expect(SEPA::ProfileRegistry['sps.sdd.02']).to equal(described_class::SDD_02)
      expect(SEPA::ProfileRegistry['sps.sdd.08']).to equal(described_class::SDD_08)
      expect(SEPA::ProfileRegistry['sps.sdd.12']).to equal(described_class::SDD_12)
    end
  end

  describe 'country_defaults resolution' do
    it 'resolves country: :ch, version: :latest to SPS SCT_13' do
      sct = SEPA::CreditTransfer.new(country: :ch, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_13)
    end

    it 'resolves country: :ch, version: :v09 to SPS SCT_09' do
      sct = SEPA::CreditTransfer.new(country: :ch, version: :v09, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_09)
    end

    it 'resolves country: :ch, version: :v03 to SPS SCT_03' do
      sct = SEPA::CreditTransfer.new(country: :ch, version: :v03, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_03)
    end

    it 'resolves country: :ch for direct debit to SPS SDD_12' do
      sdd = SEPA::DirectDebit.new(country: :ch, name: SEPA::TestData::CREDITOR_NAME,
                                  bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                  creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(sdd.profile).to equal(described_class::SDD_12)
    end
  end
end
