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
      end.to raise_error(SEPA::ValidationError, /must use structured fields/)
    end

    it 'accepts a transaction whose creditor address uses structured fields' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'FR', street_name: 'rue de Rivoli',
                                          town_name: 'Paris', post_code: '75001')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.not_to raise_error
    end

    it 'rejects a mixed address that has both structured fields and AdrLine' do
      sct = fresh_sct
      mixed = SEPA::CreditorAddress.new(
        country_code: 'FR', street_name: 'rue de Rivoli', town_name: 'Paris',
        post_code: '75001', address_line1: 'c/o John Doe'
      )
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: mixed))
      end.to raise_error(SEPA::ValidationError, /must use structured fields/)
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

    context 'account-level address' do
      it 'rejects an AdrLine-only account address at construction' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(country_code: 'FR',
                                       address_line1: '1 rue de Rivoli',
                                       address_line2: '75001 Paris')
          )
        end.to raise_error(SEPA::ValidationError, /account\.address must use structured fields/)
      end

      it 'accepts a structured account address' do
        expect do
          SEPA::CreditTransfer.new(
            profile: profile, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(country_code: 'FR', street_name: 'rue de Rivoli',
                                       post_code: '75001', town_name: 'Paris')
          )
        end.not_to raise_error
      end

      it 'accepts an AdrLine-only address when the profile does not require structured fields' do
        expect do
          SEPA::CreditTransfer.new(
            profile: SEPA::Profiles::ISO::SCT_09, name: SEPA::TestData::DEBTOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
            address: SEPA::Address.new(country_code: 'FR', address_line1: '1 rue de Rivoli')
          )
        end.not_to raise_error
      end
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
      end.to raise_error(SEPA::ValidationError, /must use structured fields/)
    end

    it 'accepts a structured debtor address' do
      sdd = fresh_sdd
      address = SEPA::DebtorAddress.new(country_code: 'FR', street_name: 'rue de Rivoli',
                                        town_name: 'Paris', post_code: '75001')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.not_to raise_error
    end

    it 'rejects an AdrLine-only address on a per-transaction creditor_account override' do
      sdd = fresh_sdd
      unstructured_creditor = SEPA::CreditorAccount.new(
        name: 'Other Creditor', bic: 'RABONL2U', iban: 'NL08RABO0135742099',
        creditor_identifier: 'NL53ZZZ091734220000',
        address: SEPA::CreditorAddress.new(country_code: 'NL',
                                           address_line1: '1 Herengracht', address_line2: '1017 Amsterdam')
      )
      expect do
        sdd.add_transaction(direct_debit_transaction(creditor_account: unstructured_creditor))
      end.to raise_error(SEPA::ValidationError, /creditor_account\.address must use structured fields/)
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
