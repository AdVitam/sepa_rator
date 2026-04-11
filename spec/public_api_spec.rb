# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Public API: country / version / profile' do
  let(:account_attrs) do
    { name: SEPA::TestData::DEBTOR_NAME, bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN }
  end
  let(:creditor_attrs) do
    { name: SEPA::TestData::CREDITOR_NAME, bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
      creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER }
  end

  describe 'Level 0 — no profile, no country (generic SEPA default)' do
    it 'resolves CreditTransfer to EPC SCT latest' do
      sct = SEPA::CreditTransfer.new(**account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::EPC::SCT_13)
    end

    it 'resolves DirectDebit to EPC SDD latest' do
      sdd = SEPA::DirectDebit.new(**creditor_attrs)
      expect(sdd.profile).to equal(SEPA::Profiles::EPC::SDD_12)
    end
  end

  describe 'Level 1 — country hint' do
    it 'resolves country: :fr to CFONB for CreditTransfer' do
      sct = SEPA::CreditTransfer.new(country: :fr, **account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::CFONB::SCT_13)
    end

    it 'resolves country: :fr to CFONB for DirectDebit' do
      sdd = SEPA::DirectDebit.new(country: :fr, **creditor_attrs)
      expect(sdd.profile).to equal(SEPA::Profiles::CFONB::SDD_12)
    end

    it 'falls back to generic EPC for a country without dedicated profiles' do
      sct = SEPA::CreditTransfer.new(country: :it, **account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::EPC::SCT_13)
    end
  end

  describe 'Level 2 — country + version' do
    it 'resolves country: :fr, version: :v09 to CFONB SCT_09' do
      sct = SEPA::CreditTransfer.new(country: :fr, version: :v09, **account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::CFONB::SCT_09)
    end

    it 'resolves country: nil, version: :v09 to EPC SCT_09' do
      sct = SEPA::CreditTransfer.new(version: :v09, **account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::EPC::SCT_09)
    end

    it 'raises UnsupportedVersionError with the list of available versions' do
      err = nil
      begin
        SEPA::CreditTransfer.new(country: :fr, version: :v42, **account_attrs)
      rescue SEPA::UnsupportedVersionError => e
        err = e
      end
      expect(err).not_to be_nil
      expect(err.country).to eq :fr
      expect(err.version).to eq :v42
      expect(err.available_versions).to include(:latest, :v09, :v13)
    end
  end

  describe 'Level 3 — explicit profile' do
    it 'accepts a Profile constant directly' do
      sct = SEPA::CreditTransfer.new(profile: SEPA::Profiles::ISO::SCT_03, **account_attrs)
      expect(sct.profile).to equal(SEPA::Profiles::ISO::SCT_03)
    end

    it 'raises when profile is combined with country' do
      expect do
        SEPA::CreditTransfer.new(profile: SEPA::Profiles::ISO::SCT_03, country: :fr, **account_attrs)
      end.to raise_error(ArgumentError, /either `profile:` or `country:`/)
    end

    it 'raises when profile is combined with a non-default version' do
      expect do
        SEPA::CreditTransfer.new(profile: SEPA::Profiles::ISO::SCT_03, version: :v09, **account_attrs)
      end.to raise_error(ArgumentError, /either `profile:` or `country:`/)
    end

    it 'raises when the explicit profile belongs to the wrong family' do
      expect do
        SEPA::CreditTransfer.new(profile: SEPA::Profiles::EPC::SDD_08, **account_attrs)
      end.to raise_error(ArgumentError, /direct_debit/)
    end

    it 'raises when the explicit profile is not a SEPA::Profile' do
      expect do
        SEPA::CreditTransfer.new(profile: 'pain.001.001.09', **account_attrs)
      end.to raise_error(ArgumentError, /expected SEPA::Profile/)
    end
  end

  describe 'end-to-end: French company paying an Italian supplier' do
    it 'uses CFONB (bank is French) but accepts an IT beneficiary IBAN' do
      sct = SEPA::CreditTransfer.new(country: :fr, version: :v09, **account_attrs)
      sct.add_transaction(credit_transfer_transaction(
                            iban: 'IT60X0542811101000000123456',
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'IT', street_name: 'Via Roma',
                              town_name: 'Milano', post_code: '20121'
                            )
                          ))
      expect(sct.to_xml).to validate_against('pain.001.001.09.xsd')
    end
  end
end
