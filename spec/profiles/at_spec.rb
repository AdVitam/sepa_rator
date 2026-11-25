# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profiles::AT do
  describe 'SCT 09' do
    let(:profile) { described_class::SCT_09 }

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

    it 'uses the AT PSA XSD' do
      expect(profile.xsd_path).to eq 'at/pain.001.001.09.at.005.xsd'
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

    it 'converts texts with the AT charset' do
      xml = charset_credit_transfer_xml(profile, country_code: 'AT')

      expect(profile.features.charset).to eq SEPA::Charset::AT
      expect_charset_xml(xml, name: 'Jose Garcia & Co.', remittance: 'Cafe e', reference: 'Ref-1')
    end

    it 'generates valid XML against the AT PSA XSD' do
      sct = fresh_sct
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'DE', street_name: 'Hauptstrasse', building_number: '1',
                              town_name: 'Berlin', post_code: '10115'
                            )
                          ))
      expect(sct.to_xml).to validate_against('at/pain.001.001.09.at.005.xsd')
    end
  end

  describe 'SDD 08' do
    let(:profile) { described_class::SDD_08 }

    it 'declares the min_amount feature' do
      expect(profile.features.min_amount).to eq BigDecimal('0.01')
    end

    it 'uses the AT PSA XSD' do
      expect(profile.xsd_path).to eq 'at/pain.008.001.08.at.004.xsd'
    end

    it 'inherits structured-address enforcement from the AT layer' do
      sdd = direct_debit_message(profile: profile)
      address = SEPA::DebtorAddress.new(country_code: 'DE', address_line1: 'Hauptstrasse 1')
      expect do
        sdd.add_transaction(direct_debit_transaction(debtor_address: address))
      end.to raise_error(SEPA::ValidationError, /structured fields/)
    end

    it 'generates valid XML against the AT PSA XSD' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction(
                            debtor_address: SEPA::DebtorAddress.new(
                              country_code: 'DE', street_name: 'Hauptstrasse', building_number: '1',
                              town_name: 'Berlin', post_code: '10115'
                            )
                          ))
      expect(sdd.to_xml).to validate_against('at/pain.008.001.08.at.004.xsd')
    end
  end

  describe 'SCT 03 (legacy)' do
    let(:profile) { described_class::SCT_03 }

    it 'composes from EPC SCT 03' do
      expect(profile.iso_schema).to eq 'pain.001.001.03'
    end

    it 'uses the AT PSA XSD' do
      expect(profile.xsd_path).to eq 'at/pain.001.001.03.at.004.xsd'
    end

    it 'does not require structured addresses (v03 only supports Ctry + AdrLine)' do
      expect(profile.features.requires_structured_address).to be false
    end

    it 'generates valid XML against the AT PSA XSD' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction)
      expect(sct.to_xml).to validate_against('at/pain.001.001.03.at.004.xsd')
    end
  end

  describe 'SDD 02 (legacy)' do
    let(:profile) { described_class::SDD_02 }

    it 'uses the AT PSA XSD' do
      expect(profile.xsd_path).to eq 'at/pain.008.001.02.at.004.xsd'
    end

    it 'generates valid XML against the AT PSA XSD' do
      sdd = direct_debit_message(profile: profile)
      sdd.add_transaction(direct_debit_transaction)
      expect(sdd.to_xml).to validate_against('at/pain.008.001.02.at.004.xsd')
    end
  end

  describe 'SCT 13 (no AT-specific XSD, fallback to ISO)' do
    let(:profile) { described_class::SCT_13 }

    it 'falls back to the ISO baseline XSD' do
      expect(profile.xsd_path).to eq 'iso/pain.001.001.13.xsd'
    end

    it 'still enforces min_amount and structured addresses' do
      expect(profile.features.min_amount).to eq BigDecimal('0.01')
      expect(profile.features.requires_structured_address).to be true
    end

    it 'generates valid XML' do
      sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(
                              country_code: 'DE', street_name: 'Hauptstrasse', building_number: '1',
                              town_name: 'Berlin', post_code: '10115'
                            )
                          ))
      expect(sct.to_xml).to validate_against('iso/pain.001.001.13.xsd')
    end
  end

  describe 'SDD 12 (no AT-specific XSD, fallback to ISO)' do
    let(:profile) { described_class::SDD_12 }

    it 'falls back to the ISO baseline XSD' do
      expect(profile.xsd_path).to eq 'iso/pain.008.001.12.xsd'
    end
  end

  describe 'MinAmount shared validator' do
    it 'is the same class as Validators::DK::MinAmount (alias)' do
      expect(SEPA::Validators::DK::MinAmount).to equal(SEPA::Validators::MinAmount)
    end

    it 'rejects a transaction below the profile threshold' do
      profile = SEPA::Profiles::EPC::SCT_13.with(
        id: 'test.at_min_10', features: { min_amount: BigDecimal('10.00') }
      )
      txn = SEPA::CreditTransferTransaction.new(
        name: 'Supplier', iban: SEPA::TestData::CT_TX_IBAN, bic: SEPA::TestData::CT_TX_BIC,
        amount: BigDecimal('5.00'), reference: 'REF'
      )
      expect do
        SEPA::Validators::MinAmount.validate(txn, profile)
      end.to raise_error(SEPA::ValidationError, /amount 5\.00 is below the required minimum 10\.00/)
    end
  end

  describe 'country_defaults resolution' do
    it 'resolves country: :at, version: :latest to AT SCT_13' do
      sct = SEPA::CreditTransfer.new(country: :at, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_13)
    end

    it 'resolves country: :at, version: :v09 to AT SCT_09' do
      sct = SEPA::CreditTransfer.new(country: :at, version: :v09, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
      expect(sct.profile).to equal(described_class::SCT_09)
    end

    it 'resolves country: :at for direct debit to AT SDD_12' do
      sdd = SEPA::DirectDebit.new(country: :at, name: SEPA::TestData::CREDITOR_NAME,
                                  bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                  creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(sdd.profile).to equal(described_class::SDD_12)
    end
  end

  describe 'initiating party (PSA: exactly one element in InitgPty)' do
    def xml_doc(xml)
      Nokogiri::XML(xml).remove_namespaces!
    end

    def children_of(xml, xpath)
      xml_doc(xml).at_xpath(xpath).element_children.map(&:name)
    end

    def initiating_party_children(xml)
      children_of(xml, '//GrpHdr/InitgPty')
    end

    def at_sdd_08(attributes = {})
      sdd = direct_debit_message(profile: described_class::SDD_08, **attributes)
      sdd.add_transaction(direct_debit_transaction)
      sdd.to_xml
    end

    def at_sct_09(attributes = {})
      sct = SEPA::CreditTransfer.new(profile: described_class::SCT_09, name: SEPA::TestData::DEBTOR_NAME,
                                     bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                     **attributes)
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(country_code: 'AT', town_name: 'Wien')
                          ))
      sct.to_xml
    end

    it 'declares the rule on every AT profile' do
      [described_class::SCT_03, described_class::SCT_09, described_class::SCT_13,
       described_class::SDD_02, described_class::SDD_08, described_class::SDD_12].each do |profile|
        expect(profile.single_child?('GrpHdr/InitgPty')).to be(true), profile.id
      end
    end

    { described_class::SDD_08 => 'at/pain.008.001.08.at.004.xsd',
      described_class::SDD_02 => 'at/pain.008.001.02.at.004.xsd' }.each do |profile, xsd|
      it "writes only the name for #{profile.id} although the creditor identifier is set" do
        sdd = direct_debit_message(profile: profile)
        sdd.add_transaction(direct_debit_transaction)
        xml = sdd.to_xml

        expect(initiating_party_children(xml)).to eq(['Nm'])
        expect(xml_doc(xml).at_xpath('//CdtrSchmeId//Othr/Id').text).to eq(sdd.account.creditor_identifier)
        expect(xml).to satisfy_single_child_rules_of(profile)
        expect(xml).to validate_against(xsd)
      end
    end

    it 'writes only the BIC when the creditor sets an initiating party BIC' do
      xml = at_sdd_08(initiating_party_bic: 'RLNWATWWXXX')

      expect(initiating_party_children(xml)).to eq(['Id'])
      expect(children_of(xml, '//GrpHdr/InitgPty/Id/OrgId')).to eq(['AnyBIC'])
      expect(xml_doc(xml).at_xpath('//InitgPty//AnyBIC').text).to eq('RLNWATWWXXX')
      expect(xml_doc(xml).at_xpath('//CdtrSchmeId//Othr/Id').text).to eq(SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(xml).to satisfy_single_child_rules_of(described_class::SDD_08)
      expect(xml).to validate_against('at/pain.008.001.08.at.004.xsd')
    end

    it 'writes only the LEI when the creditor sets an initiating party LEI' do
      xml = at_sdd_08(initiating_party_lei: '529900T8BM49AURSDO55')

      expect(children_of(xml, '//GrpHdr/InitgPty/Id/OrgId')).to eq(['LEI'])
      expect(xml_doc(xml).at_xpath('//InitgPty//LEI').text).to eq('529900T8BM49AURSDO55')
      expect(xml).to satisfy_single_child_rules_of(described_class::SDD_08)
      expect(xml).to validate_against('at/pain.008.001.08.at.004.xsd')
    end

    it 'writes only the identifier when the debtor sets an initiating party identifier' do
      xml = at_sct_09(initiating_party_identifier: 'ACME-001')

      expect(initiating_party_children(xml)).to eq(['Id'])
      expect(children_of(xml, '//GrpHdr/InitgPty/Id/OrgId')).to eq(['Othr'])
      expect(xml_doc(xml).at_xpath('//InitgPty//Othr/Id').text).to eq('ACME-001')
      expect(xml).to satisfy_single_child_rules_of(described_class::SCT_09)
      expect(xml).to validate_against('at/pain.001.001.09.at.005.xsd')
    end

    it 'keeps name and id with the creditor identifier on profiles without the rule' do
      sdd = direct_debit_message(profile: SEPA::Profiles::EPC::SDD_08)
      sdd.add_transaction(direct_debit_transaction)
      xml = sdd.to_xml

      expect(initiating_party_children(xml)).to eq(%w[Nm Id])
      expect(xml_doc(xml).at_xpath('//InitgPty//Othr/Id').text).to eq(SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(xml).to validate_against('pain.008.001.08.xsd')
    end
  end

  describe 'original creditor scheme (PSA: exactly one element in OrgnlCdtrSchmeId)' do
    def amended_xml(original_creditor)
      sdd = direct_debit_message(profile: described_class::SDD_08)
      sdd.add_transaction(direct_debit_transaction(
                            original_creditor_account: SEPA::CreditorAccount.new(**original_creditor)
                          ))
      sdd.to_xml
    end

    def scheme_children(xml)
      Nokogiri::XML(xml).remove_namespaces!.at_xpath('//OrgnlCdtrSchmeId').element_children.map(&:name)
    end

    it 'writes only the id when the original creditor has a name and an identifier' do
      xml = amended_xml(name: 'Old Creditor', creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)

      expect(scheme_children(xml)).to eq(['Id'])
      expect(xml).to satisfy_single_child_rules_of(described_class::SDD_08)
      expect(xml).to validate_against('at/pain.008.001.08.at.004.xsd')
    end

    it 'writes only the name when the original creditor has no identifier' do
      xml = amended_xml(name: 'Old Creditor')

      expect(scheme_children(xml)).to eq(['Nm'])
      expect(xml).to satisfy_single_child_rules_of(described_class::SDD_08)
      expect(xml).to validate_against('at/pain.008.001.08.at.004.xsd')
    end
  end

  describe 'amendment details (PSA: exactly one element in AmdmntInfDtls)' do
    [described_class::SDD_08, described_class::SDD_12].each do |profile|
      it "rejects two amendment details under #{profile.id}" do
        sdd = direct_debit_message(profile: profile)

        expect do
          sdd.add_transaction(direct_debit_transaction(
                                original_mandate_id: 'OLD-MANDATE',
                                original_creditor_account: SEPA::CreditorAccount.new(
                                  name: 'Old Creditor', creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER
                                )
                              ))
        end.to raise_error(SEPA::ValidationError, /only one amendment detail/)
      end
    end
  end
end
