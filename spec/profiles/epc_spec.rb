# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::EPC do
  describe 'Credit Transfer (SCT)' do
    let(:profile) { described_class::SCT_09 }

    it 'inherits the ISO SCT 09 stages, features and XSD path' do
      expect(profile.iso_schema).to eq 'pain.001.001.09'
      expect(profile.xsd_path).to eq 'iso/pain.001.001.09.xsd'
      expect(profile.transaction_stages).to eq(SEPA::Profiles::ISO::SCT_09.transaction_stages)
    end

    it 'accepts an EUR transaction with default (SEPA) service level' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect { sct.add_transaction(credit_transfer_transaction) }.not_to raise_error
    end

    it 'rejects non-EUR transactions at add_transaction time' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect { sct.add_transaction(credit_transfer_transaction(currency: 'CHF')) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects URGP service level' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect { sct.add_transaction(credit_transfer_transaction(service_level: 'URGP')) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects non-SLEV charge bearer' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect { sct.add_transaction(credit_transfer_transaction(charge_bearer: 'SHAR', service_level: nil)) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'generates valid XML against the ISO v09 XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction)
      expect(sct.to_xml).to validate_against('pain.001.001.09.xsd')
    end
  end

  describe 'Direct Debit (SDD)' do
    let(:profile) { described_class::SDD_08 }

    it 'accepts a valid EUR CORE direct debit' do
      sdd = direct_debit_message(profile: profile)
      expect { sdd.add_transaction(direct_debit_transaction) }.not_to raise_error
    end

    it 'rejects non-EUR direct debits' do
      sdd = direct_debit_message(profile: profile)
      expect { sdd.add_transaction(direct_debit_transaction(currency: 'CHF')) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'rejects non-SLEV charge bearer' do
      sdd = direct_debit_message(profile: profile)
      expect { sdd.add_transaction(direct_debit_transaction(charge_bearer: 'SHAR')) }
        .to raise_error(SEPA::ValidationError, /not compatible/)
    end

    it 'accepts B2B local instrument' do
      sdd = direct_debit_message(profile: profile)
      expect { sdd.add_transaction(direct_debit_transaction(local_instrument: 'B2B')) }.not_to raise_error
    end

    it 'generates valid XML against the ISO v08 XSD' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction)
      expect(sdd.to_xml).to validate_against('pain.008.001.08.xsd')
    end
  end
end
