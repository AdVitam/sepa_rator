# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::GB do
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

    it 'uses the ISO baseline XSD (no UK-specific XSD)' do
      expect(profile.xsd_path).to eq 'iso/pain.001.001.09.xsd'
    end

    it 'requires structured addresses' do
      expect(profile.features.requires_structured_address).to be true
    end

    it 'requires country code on addresses' do
      expect(profile.features.requires_country_code_on_address).to be true
    end

    # ── Currency acceptance ──────────────────────────────────────

    it 'accepts EUR transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'EUR'))
      end.not_to raise_error
    end

    it 'accepts GBP transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil))
      end.not_to raise_error
    end

    it 'rejects CHF transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'CHF', service_level: nil))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects USD transactions' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'USD', service_level: nil))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    # ── EUR-specific rules (SEPA) ────────────────────────────────

    it 'rejects URGP service level for EUR (SEPA requires SvcLvl=SEPA)' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'EUR', service_level: 'URGP'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects SHAR charge bearer for EUR' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'EUR', charge_bearer: 'SHAR'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    # ── GBP-specific rules (CHAPS) ───────────────────────────────

    it 'allows SHAR charge bearer for GBP' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil,
                                                        charge_bearer: 'SHAR'))
      end.not_to raise_error
    end

    it 'allows DEBT charge bearer for GBP' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil,
                                                        charge_bearer: 'DEBT'))
      end.not_to raise_error
    end

    it 'allows CRED charge bearer for GBP' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil,
                                                        charge_bearer: 'CRED'))
      end.not_to raise_error
    end

    it 'allows URGP service level for GBP' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: 'URGP'))
      end.not_to raise_error
    end

    it 'rejects service_level SEPA for GBP' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: 'SEPA'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    # ── Address enforcement ──────────────────────────────────────

    it 'rejects an AdrLine-only creditor address' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'GB',
                                          address_line1: '10 Downing Street',
                                          address_line2: 'London SW1A 2AA')
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil,
                                                        creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'rejects a structured address without country code' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(street_name: 'Downing Street', building_number: '10',
                                          post_code: 'SW1A 2AA', town_name: 'London')
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil,
                                                        creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /[Cc]ountry code/)
    end

    it 'accepts a structured address with country code' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(
                              currency: 'GBP', service_level: nil,
                              creditor_address: SEPA::CreditorAddress.new(
                                country_code: 'GB', street_name: 'Downing Street', building_number: '10',
                                post_code: 'SW1A 2AA', town_name: 'London'
                              )
                            ))
      end.not_to raise_error
    end

    # ── XSD validation ───────────────────────────────────────────

    it 'generates valid XML against the ISO v09 XSD' do
      sct = fresh_sct
      sct.add_transaction(credit_transfer_transaction(
                            currency: 'GBP', service_level: nil,
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'GB', street_name: 'Downing Street', building_number: '10',
                              town_name: 'London', post_code: 'SW1A 2AA'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.09.xsd')
    end

    # ── Account-level address ────────────────────────────────────

    context 'account-level address' do
      it 'rejects an account address without country code' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(street_name: 'Downing Street',
                                       post_code: 'SW1A 2AA', town_name: 'London')
          )
        end.to raise_error(SEPA::ValidationError, /[Cc]ountry code/)
      end

      it 'accepts a structured account address with country code' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(country_code: 'GB', street_name: 'Downing Street',
                                       post_code: 'SW1A 2AA', town_name: 'London')
          )
        end.not_to raise_error
      end
    end
  end

  # ── SCT 03 ───────────────────────────────────────────────────

  describe 'SCT 03' do
    let(:profile) { described_class::SCT_03 }

    it 'composes from ISO SCT 03' do
      expect(profile.iso_schema).to eq 'pain.001.001.03'
    end

    it 'accepts GBP transactions' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect do
        sct.add_transaction(credit_transfer_transaction(currency: 'GBP', service_level: nil))
      end.not_to raise_error
    end

    it 'generates valid XML against the ISO v03 XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction)
      expect(sct.to_xml).to validate_against('pain.001.001.03.xsd')
    end
  end

  # ── SCT 13 ───────────────────────────────────────────────────

  describe 'SCT 13' do
    let(:profile) { described_class::SCT_13 }

    it 'composes from ISO SCT 13' do
      expect(profile.iso_schema).to eq 'pain.001.001.13'
    end

    it 'generates valid XML against the ISO v13 XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction(
                            currency: 'GBP', service_level: nil,
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'GB', street_name: 'Downing Street', building_number: '10',
                              town_name: 'London', post_code: 'SW1A 2AA'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.13.xsd')
    end
  end

  # ── SDD 08 ───────────────────────────────────────────────────

  describe 'SDD 08' do
    let(:profile) { described_class::SDD_08 }

    it 'composes from ISO SDD 08' do
      expect(profile.iso_schema).to eq 'pain.008.001.08'
    end

    it 'requires structured addresses' do
      sdd = direct_debit_message(profile: profile)
      address = SEPA::DebtorAddress.new(country_code: 'GB', address_line1: '10 Downing Street')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'rejects GBP direct debits (Bacs is out of scope)' do
      sdd = direct_debit_message(profile: profile)
      expect do
        sdd.add_transaction(direct_debit_transaction(currency: 'GBP'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'accepts EUR direct debits' do
      sdd = direct_debit_message(profile: profile)
      expect do
        sdd.add_transaction(direct_debit_transaction(currency: 'EUR'))
      end.not_to raise_error
    end

    it 'generates valid XML' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction(
                            debtor_address: SEPA::DebtorAddress.new(
                              country_code: 'GB', street_name: 'Downing Street', building_number: '10',
                              town_name: 'London', post_code: 'SW1A 2AA'
                            )
                          ))
      expect(sdd.to_xml).to validate_against('pain.008.001.08.xsd')
    end
  end

  # ── SDD 02 ───────────────────────────────────────────────────

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

  # ── Profile registration ───────────────────────────────────────

  describe 'profile ids' do
    it 'registers all GB profiles in the registry' do
      expect(SEPA::ProfileRegistry['gb.sct.03']).to equal(described_class::SCT_03)
      expect(SEPA::ProfileRegistry['gb.sct.09']).to equal(described_class::SCT_09)
      expect(SEPA::ProfileRegistry['gb.sct.13']).to equal(described_class::SCT_13)
      expect(SEPA::ProfileRegistry['gb.sdd.02']).to equal(described_class::SDD_02)
      expect(SEPA::ProfileRegistry['gb.sdd.08']).to equal(described_class::SDD_08)
      expect(SEPA::ProfileRegistry['gb.sdd.12']).to equal(described_class::SDD_12)
    end
  end

  # ── Country defaults ───────────────────────────────────────────

  describe 'country_defaults resolution' do
    it 'resolves country: :gb, version: :latest to GB SCT_13' do
      sct = SEPA::CreditTransfer.new(country: :gb, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_13)
    end

    it 'resolves country: :gb, version: :v09 to GB SCT_09' do
      sct = SEPA::CreditTransfer.new(country: :gb, version: :v09, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_09)
    end

    it 'resolves country: :gb, version: :v03 to GB SCT_03' do
      sct = SEPA::CreditTransfer.new(country: :gb, version: :v03, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_03)
    end

    it 'resolves country: :gb for direct debit to GB SDD_12' do
      sdd = SEPA::DirectDebit.new(country: :gb, name: SEPA::TestData::CREDITOR_NAME,
                                  bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                  creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(sdd.profile).to equal(described_class::SDD_12)
    end
  end
end
