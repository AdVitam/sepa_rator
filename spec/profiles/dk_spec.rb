# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::DK do
  describe 'SCT 09 GBIC5' do
    let(:profile) { described_class::SCT_09_GBIC5 }

    def fresh_sct
      SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                               bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
    end

    it 'composes from EPC SCT 09' do
      expect(profile.iso_schema).to eq 'pain.001.001.09'
      expect(profile.transaction_stages).to eq(SEPA::Profiles::EPC::SCT_09.transaction_stages)
    end

    it 'declares a minimum amount of 0.01' do
      expect(profile.features.min_amount).to eq BigDecimal('0.01')
    end

    it 'requires structured addresses' do
      expect(profile.features.requires_structured_address).to be true
    end

    it 'rejects a zero-amount transaction (ISO floor, caught before DK validator)' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(amount: 0))
      end.to raise_error(SEPA::ValidationError)
    end

    it 'accepts a transaction at the minimum threshold' do
      sct = fresh_sct
      expect do
        sct.add_transaction(credit_transfer_transaction(amount: BigDecimal('0.01')))
      end.not_to raise_error
    end

    it 'rejects an AdrLine-only creditor address' do
      sct = fresh_sct
      address = SEPA::CreditorAddress.new(country_code: 'DE',
                                          address_line1: 'Hauptstrasse 1',
                                          address_line2: '10115 Berlin')
      expect do
        sct.add_transaction(credit_transfer_transaction(creditor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'generates valid XML' do
      sct = fresh_sct
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'DE', street_name: 'Hauptstrasse', building_number: '1',
                              town_name: 'Berlin', post_code: '10115'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.09.xsd')
    end
  end

  describe 'SDD 08 GBIC5' do
    let(:profile) { described_class::SDD_08_GBIC5 }

    it 'declares the min_amount feature' do
      expect(profile.features.min_amount).to eq BigDecimal('0.01')
    end

    it 'inherits structured-address enforcement from the DK layer' do
      sdd = direct_debit_message(profile: profile)
      address = SEPA::DebtorAddress.new(country_code: 'DE', address_line1: 'Hauptstrasse 1')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end
  end

  describe 'MinAmount validator direct test' do
    # Synthesises a profile with a 10.00 minimum so we can exercise the
    # rejection path (the real DK threshold of 0.01 is below the 2-decimal
    # precision floor of SEPA amounts and is caught by the ISO `> 0` rule).
    let(:profile) do
      SEPA::Profiles::EPC::SCT_13.with(
        id: 'test.min_amount_10',
        features: { min_amount: BigDecimal('10.00') }
      )
    end

    it 'rejects a transaction below the profile threshold' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Supplier', iban: SEPA::TestData::CT_TX_IBAN, bic: SEPA::TestData::CT_TX_BIC,
        amount: BigDecimal('5.00'), reference: 'REF'
      )
      expect do
        SEPA::Validators::DK::MinAmount.validate(txn, profile)
      end.to raise_error(SEPA::ValidationError, /amount 5\.00 is below the required minimum 10\.00/)
    end

    it 'accepts a transaction at the profile threshold' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Supplier', iban: SEPA::TestData::CT_TX_IBAN, bic: SEPA::TestData::CT_TX_BIC,
        amount: BigDecimal('10.00'), reference: 'REF'
      )
      expect { SEPA::Validators::DK::MinAmount.validate(txn, profile) }.not_to raise_error
    end

    it 'is a no-op when the profile has no min_amount set' do
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Supplier', iban: SEPA::TestData::CT_TX_IBAN, bic: SEPA::TestData::CT_TX_BIC,
        amount: BigDecimal('0.01'), reference: 'REF'
      )
      expect do
        SEPA::Validators::DK::MinAmount.validate(txn, SEPA::Profiles::EPC::SCT_13)
      end.not_to raise_error
    end
  end

  describe 'country_defaults resolution' do
    it 'resolves country: :de, version: :latest to DK SCT_13_GBIC5' do
      sct = SEPA::CreditTransfer.new(country: :de, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_13_GBIC5)
    end

    it 'resolves country: :de, version: :v09 to DK SCT_09_GBIC5' do
      sct = SEPA::CreditTransfer.new(country: :de, version: :v09, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_09_GBIC5)
    end

    it 'resolves country: :de for direct debit to DK SDD_12_GBIC5' do
      sdd = SEPA::DirectDebit.new(country: :de, name: SEPA::TestData::CREDITOR_NAME,
                                  bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                  creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(sdd.profile).to equal(described_class::SDD_12_GBIC5)
    end
  end
end
