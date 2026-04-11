# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::CFONB do
  describe 'SCT 09' do
    let(:profile) { described_class::SCT_09 }

    def fresh_sct
      SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                               bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
    end

    it 'composes from EPC SCT 09 (same XSD, same stages)' do
      expect(profile.xsd_path).to eq 'iso/pain.001.001.09.xsd'
      expect(profile.iso_schema).to eq 'pain.001.001.09'
      expect(profile.transaction_stages).to eq(SEPA::Profiles::EPC::SCT_09.transaction_stages)
    end

    it 'sets the requires_structured_address feature' do
      expect(profile.features.requires_structured_address).to be true
    end

    it 'rejects a transaction whose creditor address only uses AdrLine' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'FR',
                                          address_line1: 'rue de Rivoli',
                                          address_line2: '75001 Paris')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields.*CFONB/)
    end

    it 'accepts a transaction whose creditor address uses structured fields' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'FR', street_name: 'rue de Rivoli',
                                          town_name: 'Paris', post_code: '75001')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.not_to raise_error
    end

    it 'accepts a transaction without any address' do
      sct = fresh_sct
      expect { sct.add_transaction(credit_transfer_transaction) }.not_to raise_error
    end

    it 'still enforces EPC rules (non-EUR rejected)' do
      sct = fresh_sct
      expect { sct.add_transaction(credit_transfer_transaction(currency: 'CHF')) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'generates valid XML against the ISO v09 XSD' do
      sct = fresh_sct
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'FR', street_name: 'rue de Rivoli',
                              town_name: 'Paris', post_code: '75001'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.09.xsd')
    end
  end

  describe 'SDD 08' do
    let(:profile) { described_class::SDD_08 }

    def fresh_sdd
      direct_debit_message(profile: profile)
    end

    it 'rejects a debtor address using only AdrLine' do
      sdd = fresh_sdd
      address = SEPA::DebtorAddress.new(country_code: 'FR', address_line1: 'rue de Rivoli',
                                        address_line2: '75001 Paris')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields.*CFONB/)
    end

    it 'accepts a structured debtor address' do
      sdd = fresh_sdd
      address = SEPA::DebtorAddress.new(country_code: 'FR', street_name: 'rue de Rivoli',
                                        town_name: 'Paris', post_code: '75001')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.not_to raise_error
    end
  end

  describe 'profile ids' do
    it 'registers all CFONB profiles in the registry' do
      expect(SEPA::ProfileRegistry['cfonb.sct.09']).to equal(described_class::SCT_09)
      expect(SEPA::ProfileRegistry['cfonb.sct.13']).to equal(described_class::SCT_13)
      expect(SEPA::ProfileRegistry['cfonb.sdd.08']).to equal(described_class::SDD_08)
      expect(SEPA::ProfileRegistry['cfonb.sdd.12']).to equal(described_class::SDD_12)
    end
  end
end
