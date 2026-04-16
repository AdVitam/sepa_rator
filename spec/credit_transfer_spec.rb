# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::CreditTransfer do
  let(:message_id_regex) { %r{MSG/[0-9a-f]{28}} }

  # Shorthand constants for the ISO profiles exercised throughout this spec.
  # Note that specs that need a specific variant instantiate a fresh message
  # via `build_ct(profile)` — the principle is one instance = one profile.
  let(:sct_03) { SEPA::Profiles::ISO::SCT_03 }
  let(:sct_09) { SEPA::Profiles::ISO::SCT_09 }
  let(:sct_13) { SEPA::Profiles::ISO::SCT_13 }
  let(:sct_epc_002_03) { SEPA::Profiles::ISO::SCT_EPC_002_03 }
  let(:sct_epc_003_03) { SEPA::Profiles::ISO::SCT_EPC_003_03 }

  describe :new do
    it 'defaults to the generic EPC SCT profile when no profile/country is given' do
      sct = SEPA::CreditTransfer.new(name: SEPA::TestData::DEBTOR_NAME, iban: SEPA::TestData::DEBTOR_IBAN,
                                     bic: SEPA::TestData::DEBTOR_BIC)
      expect(sct.profile).to equal(SEPA::Profiles::EPC::SCT_13)
    end

    it 'rejects a DirectDebit profile' do
      expect do
        SEPA::CreditTransfer.new(profile: SEPA::Profiles::ISO::SDD_02, name: 'x', iban: SEPA::TestData::DEBTOR_IBAN,
                                 bic: SEPA::TestData::DEBTOR_BIC)
      end.to raise_error(ArgumentError, /direct_debit/)
    end

    context 'account-vs-profile validation' do
      it 'rejects an account with agent_lei on a non-LEI profile' do
        expect do
          SEPA::CreditTransfer.new(profile: sct_03, name: SEPA::TestData::DEBTOR_NAME,
                                   bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                   agent_lei: SEPA::TestData::LEI)
        end.to raise_error(SEPA::ValidationError, /agent_lei.*does not support LEI/)
      end

      it 'rejects an account with initiating_party_lei on a non-LEI profile' do
        expect do
          SEPA::CreditTransfer.new(profile: sct_03, name: SEPA::TestData::DEBTOR_NAME,
                                   bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                   initiating_party_lei: SEPA::TestData::LEI)
        end.to raise_error(SEPA::ValidationError, /initiating_party_lei.*does not support LEI/)
      end

      it 'accepts agent_lei on a LEI-capable profile (v09)' do
        expect do
          SEPA::CreditTransfer.new(profile: sct_09, name: SEPA::TestData::DEBTOR_NAME,
                                   bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN,
                                   agent_lei: SEPA::TestData::LEI)
        end.not_to raise_error
      end
    end
  end

  describe :add_transaction do
    it 'adds valid transactions' do
      sct = credit_transfer_message
      3.times { sct.add_transaction(credit_transfer_transaction) }
      expect(sct.transactions.size).to eq(3)
    end

    it 'fails for invalid transaction' do
      expect do
        credit_transfer_message.add_transaction(name: '')
      end.to raise_error(SEPA::ValidationError)
    end

    it 'rejects a transaction requiring a capability the profile does not advertise' do
      sct = build_ct(sct_03) # no :uetr capability
      expect do
        sct.add_transaction(credit_transfer_transaction(uetr: '550e8400-e29b-41d4-a716-446655440000'))
      end.to raise_error(SEPA::ValidationError, /not compatible/)
    end
  end

  describe :to_xml do
    context 'for invalid debtor' do
      it 'fails' do
        expect do
          SEPA::CreditTransfer.new(profile: sct_03, name: '', iban: SEPA::TestData::DEBTOR_IBAN,
                                   bic: SEPA::TestData::DEBTOR_BIC).to_xml
        end.to raise_error(SEPA::Error, /Name is too short/)
      end
    end

    context 'profile re-validation on mutated state (fail-safe)' do
      it 'catches a post-insertion mutation that breaks EPC currency rule' do
        sct = SEPA::CreditTransfer.new(
          profile: SEPA::Profiles::EPC::SCT_13, name: SEPA::TestData::DEBTOR_NAME,
          bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN
        )
        sct.add_transaction(credit_transfer_transaction)
        sct.transactions.first.currency = 'CHF'
        expect { sct.to_xml }.to raise_error(SEPA::ValidationError, /not compatible/)
      end

      it 'catches an account field mutated to an incompatible value' do
        sct = SEPA::CreditTransfer.new(profile: sct_03, name: SEPA::TestData::DEBTOR_NAME,
                                       bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
        sct.add_transaction(credit_transfer_transaction)
        sct.account.agent_lei = SEPA::TestData::LEI
        expect { sct.to_xml }.to raise_error(SEPA::ValidationError, /does not support LEI/)
      end
    end

    context 'with creditor address using AdrLine (IBAN-only transfer)' do
      let(:setup) do
        sca = SEPA::CreditorAddress.new(
          country_code: 'CH',
          address_line1: 'Mustergasse 123',
          address_line2: '1234 Musterstadt'
        )
        ->(sct) { sct.add_transaction(credit_transfer_transaction(creditor_address: sca)) }
      end

      [%i[sct_epc_003_03 pain.001.003.03], %i[sct_09 pain.001.001.09], %i[sct_13 pain.001.001.13]].each do |profile_key, schema|
        it "validates against #{schema}" do
          profile = send(profile_key)
          xml = build_ct(profile, bic: nil, &setup).to_xml
          expect(xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end
    end

    context 'with creditor address using structured fields' do
      let(:setup) do
        sca = SEPA::CreditorAddress.new(
          country_code: 'CH',
          street_name: 'Mustergasse',
          building_number: '123',
          post_code: '1234',
          town_name: 'Musterstadt'
        )
        ->(sct) { sct.add_transaction(credit_transfer_transaction(creditor_address: sca)) }
      end

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end
    end

    context 'for valid debtor' do
      context 'without BIC (IBAN-only)' do
        let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

        %i[sct_epc_003_03 sct_03 sct_09 sct_13].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, bic: nil, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'fails at construction for pain.001.002.03 (requires BIC)' do
          expect { build_ct(sct_epc_002_03, bic: nil, &setup) }
            .to raise_error(SEPA::ValidationError, /missing the required BIC/)
        end
      end

      context 'with BIC' do
        let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

        %i[sct_03 sct_epc_002_03 sct_epc_003_03 sct_09 sct_13].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end
      end

      context 'XML structure for pain.001.001.09' do
        subject(:xml) do
          sct = build_ct(sct_09)
          sct.add_transaction(credit_transfer_transaction)
          sct.to_xml
        end

        it 'uses BICFI instead of BIC for debtor agent' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', SEPA::TestData::DEBTOR_BIC)
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'uses BICFI instead of BIC for creditor agent' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BICFI',
                                  SEPA::TestData::CT_TX_BIC)
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'wraps ReqdExctnDt in Dt' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'uses correct namespace' do
          expect(xml).to include('urn:iso:std:iso:20022:tech:xsd:pain.001.001.09')
        end
      end

      context 'XML structure for pain.001.001.13' do
        subject(:xml) do
          sct = build_ct(sct_13)
          sct.add_transaction(credit_transfer_transaction)
          sct.to_xml
        end

        it 'uses BICFI' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', SEPA::TestData::DEBTOR_BIC)
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'wraps ReqdExctnDt in Dt' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'uses correct namespace' do
          expect(xml).to include('urn:iso:std:iso:20022:tech:xsd:pain.001.001.13')
        end
      end

      context 'without requested_date given' do
        subject(:xml) do
          sct = build_ct(sct_03)
          sct.add_transaction(credit_transfer_transaction)
          sct.add_transaction(name: 'Amazonas GmbH',
                              iban: 'DE27793589132923472195',
                              amount: 59.00,
                              reference: 'XYZ-5678/456',
                              remittance_information: 'Rechnung vom 21.08.2013')
          sct.to_xml
        end

        it 'creates valid XML file' do
          expect(xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'has message_identification' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/MsgId', message_id_regex)
        end

        it 'contains <PmtInfId>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtInfId', %r{#{message_id_regex}/1})
        end

        it 'contains <ReqdExctnDt>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'contains <PmtMtd>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtMtd', 'TRF')
        end

        it 'contains <BtchBookg>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/BtchBookg', 'true')
        end

        it 'contains <NbOfTxs>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/NbOfTxs', '2')
        end

        it 'contains <CtrlSum>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CtrlSum', '161.50')
        end

        it 'contains <Dbtr>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/Nm', SEPA::TestData::DEBTOR_NAME)
        end

        it 'contains <DbtrAcct>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAcct/Id/IBAN', SEPA::TestData::DEBTOR_IBAN)
        end

        it 'contains <DbtrAgt>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC', SEPA::TestData::DEBTOR_BIC)
        end

        it 'contains <EndToEndId>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/EndToEndId', 'XYZ-1234/123')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/PmtId/EndToEndId', 'XYZ-5678/456')
        end

        it 'contains <Amt>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt', '102.50')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Amt/InstdAmt', '59.00')
        end

        it 'contains <CdtrAgt> for every BIC given' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/BIC',
                                  SEPA::TestData::CT_TX_BIC)
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAgt')
        end

        it 'contains <Cdtr>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Cdtr/Nm', SEPA::TestData::CT_TX_NAME)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Cdtr/Nm', 'Amazonas GmbH')
        end

        it 'contains <CdtrAcct>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/IBAN',
                                  SEPA::TestData::CT_TX_IBAN)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAcct/Id/IBAN',
                                  'DE27793589132923472195')
        end

        it 'contains <RmtInf>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Ustrd',
                                  'Rechnung vom 22.08.2013')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/RmtInf/Ustrd',
                                  'Rechnung vom 21.08.2013')
        end
      end

      context 'with different requested_date given' do
        subject(:xml) do
          sct = build_ct(sct_03)
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2))
          sct.to_xml
        end

        it 'contains two payment_informations with <ReqdExctnDt>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end

        it 'contains two payment_informations with different <PmtInfId>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/PmtInfId', %r{#{message_id_regex}/1})
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/PmtInfId', %r{#{message_id_regex}/2})
        end
      end

      context 'with different batch_booking given' do
        subject(:xml) do
          sct = build_ct(sct_03)
          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: false))
          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: true))
          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: true))
          sct.to_xml
        end

        it 'contains two payment_informations with <BtchBookg>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')
          expect(xml).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end
      end

      context 'with transactions containing different group criteria' do
        subject(:xml) do
          sct = build_ct(sct_03)
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1, batch_booking: false, amount: 1))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1, batch_booking: true, amount: 2))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: false, amount: 4))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: true, amount: 8))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: true,
                                                                category_purpose: 'SALA', amount: 6))
          sct.to_xml
        end

        it 'contains multiple payment_informations' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/BtchBookg', 'false')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/BtchBookg', 'true')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/PmtTpInf/CtgyPurp/Cd', 'SALA')
        end

        it 'has multiple control sums' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/CtrlSum', '1.00')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/CtrlSum', '2.00')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/CtrlSum', '4.00')
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/CtrlSum', '8.00')
        end
      end

      context 'with INST category purpose (SCT Inst)' do
        let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction.merge(category_purpose: 'INST')) } }

        it 'contains CtgyPurp with INST' do
          expect(build_ct(sct_03, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/CtgyPurp/Cd', 'INST')
        end

        it 'contains SvcLvl SEPA' do
          expect(build_ct(sct_03, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA')
        end

        %i[sct_03 sct_09 sct_13].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end
      end

      context 'with debtor address on account (F1)' do
        let(:account_attrs) do
          {
            address: SEPA::Address.new(country_code: 'DE', town_name: 'Berlin', post_code: '10115',
                                       street_name: 'Hauptstrasse')
          }
        end
        let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

        %i[sct_03 sct_09 sct_13].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'contains debtor PstlAdr' do
          expect(build_ct(sct_03, account_attrs, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/PstlAdr/TwnNm', 'Berlin')
        end

        it 'contains debtor street name' do
          expect(build_ct(sct_03, account_attrs, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/PstlAdr/StrtNm', 'Hauptstrasse')
        end
      end

      context 'with charge_bearer SHAR on transaction (F3)' do
        let(:setup) do
          ->(sct) { sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'SHAR', service_level: nil)) }
        end

        %i[sct_03 sct_09 sct_13].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'contains ChrgBr with SHAR' do
          expect(build_ct(sct_03, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'SHAR')
        end
      end

      context 'with charge_bearer DEBT' do
        let(:setup) do
          ->(sct) { sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'DEBT', service_level: nil)) }
        end

        it 'validates against pain.001.001.03' do
          expect(build_ct(sct_03, &setup).to_xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'contains ChrgBr with DEBT' do
          expect(build_ct(sct_03, &setup).to_xml)
            .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'DEBT')
        end
      end

      context 'with charge_bearer SLEV on EPC schema' do
        let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'SLEV')) } }

        it 'validates against pain.001.002.03' do
          expect(build_ct(sct_epc_002_03, &setup).to_xml).to validate_against('pain.001.002.03.xsd')
        end
      end

      context 'with instruction given' do
        subject(:xml) do
          sct = build_ct(sct_03)
          sct.add_transaction(name: SEPA::TestData::CT_TX_NAME, iban: SEPA::TestData::CT_TX_IBAN,
                              amount: 102.50, instruction: '1234/ABC')
          sct.to_xml
        end

        it 'creates valid XML file' do
          expect(xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'contains <InstrId>' do
          expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/InstrId', '1234/ABC')
        end
      end

      context 'with a different currency given' do
        let(:setup) do
          lambda do |sct|
            sct.add_transaction(name: SEPA::TestData::CT_TX_NAME, iban: SEPA::TestData::CT_TX_IBAN,
                                bic: SEPA::TestData::CT_TX_BIC, amount: 102.50, currency: 'CHF')
          end
        end

        it 'validates against pain.001.001.03' do
          expect(build_ct(sct_03, &setup).to_xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'has a CHF Ccy' do
          doc = Nokogiri::XML(build_ct(sct_03, &setup).to_xml)
          doc.remove_namespaces!
          nodes = doc.xpath('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt')
          expect(nodes.length).to be(1)
          expect(nodes.first.attribute('Ccy').value).to eql('CHF')
        end
      end

      context 'with a transaction without a bic' do
        let(:setup) do
          lambda do |sct|
            sct.add_transaction(name: SEPA::TestData::CT_TX_NAME, iban: SEPA::TestData::CT_TX_IBAN, amount: 102.50)
          end
        end

        %i[sct_03 sct_09 sct_13 sct_epc_003_03].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end
      end
    end

    context 'xml_schema_header' do
      [
        [:sct_03, 'pain.001.001.03'],
        [:sct_09, 'pain.001.001.09'],
        [:sct_13, 'pain.001.001.13'],
        [:sct_epc_002_03, 'pain.001.002.03'],
        [:sct_epc_003_03, 'pain.001.003.03']
      ].each do |profile_key, format|
        context "when profile is #{format}" do
          it 'returns correct header' do
            profile = send(profile_key)
            sct = build_ct(profile)
            sct.add_transaction(name: SEPA::TestData::CT_TX_NAME, iban: SEPA::TestData::CT_TX_IBAN,
                                bic: SEPA::TestData::CT_TX_BIC, amount: 102.50)
            expected = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
                       "<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:#{format}\" " \
                       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
                       "xsi:schemaLocation=\"urn:iso:std:iso:20022:tech:xsd:#{format} #{format}.xsd\">\n"
            expect(sct.to_xml).to start_with(expected)
          end
        end
      end

      it 'derives schemaLocation from File.basename(profile.xsd_path), not iso_schema' do
        # Building the attribute directly so we don't need a real XSD file on
        # disk. The real-world case is a DK GBIC5 profile whose xsd_path is
        # `dk/pain.001.001.09_AXZ_GBIC5.xsd` — the header must advertise that
        # filename, not `pain.001.001.09.xsd`.
        profile = SEPA::Profiles::ISO::SCT_09.with(
          id: 'test.dk.sct.09.gbic5',
          xsd_path: 'dk/pain.001.001.09_AXZ_GBIC5.xsd'
        )
        sct = SEPA::CreditTransfer.new(profile: profile, name: SEPA::TestData::DEBTOR_NAME,
                                       bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
        attrs = sct.send(:xml_namespace_attributes)
        expect(attrs[:'xsi:schemaLocation'])
          .to eq('urn:iso:std:iso:20022:tech:xsd:pain.001.001.09 pain.001.001.09_AXZ_GBIC5.xsd')
      end
    end

    context 'with potentially malicious input' do
      it 'generates valid XML with injection attempts in name' do
        sct = SEPA::CreditTransfer.new(profile: sct_03, name: 'Legitimate Business',
                                       iban: SEPA::TestData::DEBTOR_IBAN, bic: SEPA::TestData::DEBTOR_BIC)
        sct.add_transaction(
          name: '<script>alert("xss")</script>',
          iban: 'DE21500500009876543210',
          bic: 'SPUEDE2UXXX',
          amount: 100.00,
          remittance_information: ']]><Injected>data</Injected>'
        )
        expect(sct.to_xml).to validate_against('pain.001.001.03.xsd')
      end
    end

    context 'with PostalAddress24 fields' do
      let(:setup) do
        address = SEPA::CreditorAddress.new(
          country_code: 'DE', street_name: 'Hauptstrasse', building_number: '42',
          building_name: 'Tower A', floor: '3', post_code: '10115',
          town_name: 'Berlin', district_name: 'Berlin-Mitte'
        )
        ->(sct) { sct.add_transaction(credit_transfer_transaction(creditor_address: address)) }
      end

      it 'validates against pain.001.001.09' do
        expect(build_ct(sct_09, &setup).to_xml).to validate_against('pain.001.001.09.xsd')
      end

      it 'contains BldgNm element' do
        expect(build_ct(sct_09, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/BldgNm', 'Tower A')
      end

      it 'contains DstrctNm element' do
        expect(build_ct(sct_09, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/DstrctNm', 'Berlin-Mitte')
      end
    end

    context 'with PostalAddress27 fields' do
      let(:setup) do
        address = SEPA::CreditorAddress.new(
          country_code: 'DE', street_name: 'Hauptstrasse',
          care_of: 'c/o Max Mustermann', unit_number: '4B',
          post_code: '10115', town_name: 'Berlin'
        )
        ->(sct) { sct.add_transaction(credit_transfer_transaction(creditor_address: address)) }
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains CareOf element' do
        expect(build_ct(sct_13, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/CareOf', 'c/o Max Mustermann')
      end

      it 'contains UnitNb element' do
        expect(build_ct(sct_13, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/UnitNb', '4B')
      end
    end

    context 'with InstrPrty' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(instruction_priority: 'HIGH')) } }

      %i[sct_03 sct_09].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains InstrPrty element' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/InstrPrty', 'HIGH')
      end

      it 'places InstrPrty before SvcLvl' do
        xml = build_ct(sct_03, &setup).to_xml
        expect(xml.index('InstrPrty')).to be < xml.index('SvcLvl')
      end
    end

    context 'with UETR' do
      let(:setup) do
        ->(sct) { sct.add_transaction(credit_transfer_transaction(uetr: '550e8400-e29b-41d4-a716-446655440000')) }
      end

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains UETR element' do
        expect(build_ct(sct_09, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/PmtId/UETR',
                       '550e8400-e29b-41d4-a716-446655440000')
      end

      it 'is rejected by pain.001.001.03 at add_transaction time' do
        expect { build_ct(sct_03, &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
      end
    end

    context 'with purpose_code' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(purpose_code: 'SALA')) } }

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains Purp element' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Purp/Cd', 'SALA')
      end
    end

    context 'with ultimate_creditor_name' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(ultimate_creditor_name: 'Ultimate Corp')) } }

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains UltmtCdtr element' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/UltmtCdtr/Nm', 'Ultimate Corp')
      end
    end

    context 'with ultimate_debtor_name' do
      let(:setup) do
        ->(sct) { sct.add_transaction(credit_transfer_transaction(ultimate_debtor_name: 'Original Debtor GmbH')) }
      end

      it 'validates against pain.001.001.03' do
        expect(build_ct(sct_03, &setup).to_xml).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains UltmtDbtr element' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/UltmtDbtr/Nm', 'Original Debtor GmbH')
      end
    end

    context 'with initiating_party_identifier' do
      let(:account_attrs) { { initiating_party_identifier: SEPA::TestData::CREDITOR_IDENTIFIER } }
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains InitgPty/Id element' do
        expect(build_ct(sct_03, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/Id',
                       SEPA::TestData::CREDITOR_IDENTIFIER)
      end
    end

    context 'with initiating_party_scheme' do
      let(:account_attrs) do
        { initiating_party_identifier: SEPA::TestData::CREDITOR_IDENTIFIER, initiating_party_scheme: 'SIREN' }
      end
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains SchmeNm/Prtry element' do
        expect(build_ct(sct_13, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/SchmeNm/Prtry', 'SIREN')
      end

      it 'omits SchmeNm when scheme is nil' do
        attrs = { initiating_party_identifier: SEPA::TestData::CREDITOR_IDENTIFIER }
        expect(build_ct(sct_13, attrs, &setup).to_xml)
          .not_to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/SchmeNm')
      end
    end

    context 'with URGP service level' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(service_level: 'URGP')) } }

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains SvcLvl with URGP' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/SvcLvl/Cd', 'URGP')
      end
    end

    context 'with structured_remittance_information' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                remittance_information: nil,
                                structured_remittance_information: 'RF712348231'
                              ))
        end
      end

      it 'validates against pain.001.001.03' do
        expect(build_ct(sct_03, &setup).to_xml).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains Strd/CdtrRefInf structure' do
        xml = build_ct(sct_03, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Cd',
                                'SCOR')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Ref',
                                'RF712348231')
      end
    end

    context 'with creditor without BIC' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(bic: nil)) } }

      it 'does not emit NOTPROVIDED for creditor agent' do
        doc = Nokogiri::XML(build_ct(sct_03, &setup).to_xml)
        doc.remove_namespaces!
        expect(doc.at_xpath('//CdtTrfTxInf/CdtrAgt/FinInstnId/Othr/Id')).to be_nil
      end

      it 'does not emit CdtrAgt at all' do
        doc = Nokogiri::XML(build_ct(sct_03, &setup).to_xml)
        doc.remove_namespaces!
        expect(doc.at_xpath('//CdtTrfTxInf/CdtrAgt')).to be_nil
      end
    end

    context 'with InitnSrc (v13 only)' do
      let(:setup) do
        lambda do |sct|
          sct.initiation_source_name = 'MyApp'
          sct.initiation_source_provider = 'Advitam'
          sct.add_transaction(credit_transfer_transaction)
        end
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains InitnSrc element in v13' do
        xml = build_ct(sct_13, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitnSrc/Nm', 'MyApp')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitnSrc/Prvdr', 'Advitam')
      end

      it 'is rejected at assignment for v03 (InitnSrc is v13-only)' do
        expect { build_ct(sct_03, &setup) }
          .to raise_error(SEPA::ValidationError, /initiation_source_name.*does not support InitnSrc/)
      end
    end

    context 'with InstrForDbtrAgt at PmtInf level (v09/v13)' do
      let(:setup) do
        ->(sct) { sct.add_transaction(credit_transfer_transaction(debtor_agent_instruction: 'Please process urgently')) }
      end

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains InstrForDbtrAgt in PmtInf' do
        expect(build_ct(sct_09, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/InstrForDbtrAgt', 'Please process urgently')
      end

      it 'is rejected at add_transaction time for v03' do
        expect { build_ct(sct_03, &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
      end
    end

    context 'with MndtRltdInf (v13 only)' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                credit_transfer_mandate_id: 'MNDT-2024-001',
                                credit_transfer_mandate_date_of_signature: Date.new(2024, 1, 15),
                                credit_transfer_mandate_frequency: 'MNTH'
                              ))
        end
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains MndtRltdInf elements in v13' do
        xml = build_ct(sct_13, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/MndtId', 'MNDT-2024-001')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/DtOfSgntr', '2024-01-15')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/Frqcy/Tp', 'MNTH')
      end

      %i[sct_03 sct_09].each do |profile_key|
        it "is rejected at add_transaction time for #{profile_key}" do
          expect { build_ct(send(profile_key), &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
        end
      end
    end

    context 'with InstrForCdtrAgt' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                instructions_for_creditor_agent: [{ code: 'HOLD', instruction_info: 'Hold for pickup' }]
                              ))
        end
      end

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains InstrForCdtrAgt elements' do
        xml = build_ct(sct_03, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForCdtrAgt/Cd', 'HOLD')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForCdtrAgt/InstrInf',
                                'Hold for pickup')
      end
    end

    context 'with InstrForDbtrAgt at transaction level (v03/v09 text)' do
      let(:setup) do
        ->(sct) { sct.add_transaction(credit_transfer_transaction(instruction_for_debtor_agent: 'Urgent transfer')) }
      end

      %i[sct_03 sct_09].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'emits plain text InstrForDbtrAgt for v03' do
        expect(build_ct(sct_03, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt', 'Urgent transfer')
      end
    end

    context 'with InstrForDbtrAgt at transaction level (v13 structured)' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                instruction_for_debtor_agent: 'Please process',
                                instruction_for_debtor_agent_code: 'URGP'
                              ))
        end
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'emits structured InstrForDbtrAgt for v13' do
        xml = build_ct(sct_13, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt/Cd', 'URGP')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt/InstrInf',
                                'Please process')
      end

      it 'is rejected at add_transaction time for v03' do
        expect { build_ct(sct_03, &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
      end
    end

    context 'with RegulatoryReporting' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                regulatory_reportings: [{ indicator: 'CRED',
                                                          details: [{ code: 'ABC', information: ['Some info'] }] }]
                              ))
        end
      end

      it 'uses Cd tag in v03' do
        xml = build_ct(sct_03, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/DbtCdtRptgInd', 'CRED')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Cd', 'ABC')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Inf', 'Some info')
      end

      it 'uses RptgCd tag in v13' do
        xml = build_ct(sct_13, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/DbtCdtRptgInd', 'CRED')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/RptgCd', 'ABC')
      end
    end

    context 'with RegulatoryReporting with authority, type, date, country, amount (v03)' do
      subject(:xml) { build_ct(sct_03, &setup).to_xml }

      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                regulatory_reportings: [{
                                  indicator: 'CRED',
                                  authority: { name: 'Bundesbank', country: 'DE' },
                                  details: [{
                                    type: 'PAYMENT',
                                    date: Date.new(2025, 6, 15),
                                    country: 'DE',
                                    code: 'ABC',
                                    amount: { value: 102.50, currency: 'EUR' },
                                    information: ['Transfer info']
                                  }]
                                }]
                              ))
        end
      end

      it 'validates against pain.001.001.03' do
        expect(xml).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains Authrty element' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Authrty/Nm', 'Bundesbank')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Authrty/Ctry', 'DE')
      end

      it 'contains Tp as plain text in v03' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp', 'PAYMENT')
      end

      it 'contains Dt element' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Dt', '2025-06-15')
      end

      it 'contains Ctry element in detail' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Ctry', 'DE')
      end

      it 'contains Amt element' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Amt', '102.50')
      end

      it 'follows correct XSD element order (Tp, Dt, Ctry, Cd, Amt, Inf)' do
        dtls_pos = xml.index('<Dtls>')
        tp_pos = xml.index('<Tp>PAYMENT</Tp>', dtls_pos)
        dt_pos = xml.index('<Dt>2025-06-15</Dt>', dtls_pos)
        ctry_pos = xml.index('<Ctry>DE</Ctry>', dtls_pos)
        cd_pos = xml.index('<Cd>ABC</Cd>', dtls_pos)
        amt_pos = xml.index('<Amt', dtls_pos)
        inf_pos = xml.index('<Inf>Transfer info</Inf>', dtls_pos)
        expect(tp_pos).to be < dt_pos
        expect(dt_pos).to be < ctry_pos
        expect(ctry_pos).to be < cd_pos
        expect(cd_pos).to be < amt_pos
        expect(amt_pos).to be < inf_pos
      end
    end

    context 'with RegulatoryReporting with structured type (v13)' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                regulatory_reportings: [{
                                  indicator: 'CRED',
                                  authority: { name: 'Bundesbank', country: 'DE' },
                                  details: [{ type: 'PYMT', date: Date.new(2025, 6, 15), country: 'DE', code: 'ABC',
                                              amount: { value: 102.50, currency: 'EUR' },
                                              information: ['Transfer info'] }]
                                }]
                              ))
        end
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'wraps Tp in structured Cd element in v13' do
        expect(build_ct(sct_13, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp/Cd', 'PYMT')
      end

      it 'uses RptgCd instead of Cd in v13' do
        expect(build_ct(sct_13, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/RptgCd', 'ABC')
      end
    end

    context 'with RegulatoryReporting with type_proprietary (v13)' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                regulatory_reportings: [{
                                  indicator: 'DEBT',
                                  details: [{ type_proprietary: 'CUSTOM_TYPE', code: 'XYZ' }]
                                }]
                              ))
        end
      end

      it 'validates against pain.001.001.13' do
        expect(build_ct(sct_13, &setup).to_xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'uses Prtry inside Tp in v13' do
        expect(build_ct(sct_13, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp/Prtry', 'CUSTOM_TYPE')
      end
    end

    context 'with enhanced RemittanceInformation' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                remittance_information: nil,
                                structured_remittance_information: 'RF712348231',
                                structured_remittance_reference_type: 'SCOR',
                                structured_remittance_issuer: 'Bank GmbH',
                                additional_remittance_information: ['Invoice 2024-001']
                              ))
        end
      end

      %i[sct_03 sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains Issr and AddtlRmtInf' do
        xml = build_ct(sct_03, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Tp/Issr',
                                'Bank GmbH')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/AddtlRmtInf',
                                'Invoice 2024-001')
      end
    end

    context 'with LEI on debtor agent (DbtrAgt)' do
      let(:account_attrs) { { agent_lei: SEPA::TestData::LEI } }
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains LEI in DbtrAgt/FinInstnId' do
        expect(build_ct(sct_09, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
      end

      it 'places LEI after BICFI in DbtrAgt' do
        xml = build_ct(sct_09, account_attrs, &setup).to_xml
        expect(xml.index('BICFI')).to be < xml.index('LEI')
      end

      it 'rejects an account with agent_lei for a v03 profile at construction' do
        # agent_lei is a LEI-capability field; v03 profiles do not advertise :lei,
        # so constructing the Message must fail immediately.
        expect { build_ct(sct_03, account_attrs) }
          .to raise_error(SEPA::ValidationError, /agent_lei.*does not support LEI/)
      end
    end

    context 'with LEI on creditor agent (CdtrAgt)' do
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction(agent_lei: SEPA::TestData::LEI)) } }

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains LEI in CdtrAgt/FinInstnId' do
        expect(build_ct(sct_09, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
      end

      it 'emits CdtrAgt even without BIC when LEI is present' do
        sct = build_ct(sct_09)
        sct.add_transaction(credit_transfer_transaction(bic: nil, agent_lei: SEPA::TestData::LEI))
        expect(sct.to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
      end
    end

    context 'with LEI in InitgPty OrgId' do
      let(:account_attrs) { { initiating_party_lei: SEPA::TestData::LEI } }
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains LEI in InitgPty/Id/OrgId' do
        expect(build_ct(sct_09, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/LEI', SEPA::TestData::LEI)
      end
    end

    context 'with BICOrBEI in InitgPty OrgId (v03)' do
      let(:account_attrs) { { initiating_party_bic: 'DEUTDEFF' } }
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      it 'validates against pain.001.001.03' do
        expect(build_ct(sct_03, account_attrs, &setup).to_xml).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains BICOrBEI in InitgPty/Id/OrgId' do
        expect(build_ct(sct_03, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/BICOrBEI', 'DEUTDEFF')
      end
    end

    context 'with AnyBIC in InitgPty OrgId (v09/v13)' do
      let(:account_attrs) { { initiating_party_bic: 'DEUTDEFF' } }
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains AnyBIC in InitgPty/Id/OrgId for v09' do
        expect(build_ct(sct_09, account_attrs, &setup).to_xml)
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/AnyBIC', 'DEUTDEFF')
      end

      it 'does not contain BICOrBEI in v09' do
        doc = Nokogiri::XML(build_ct(sct_09, account_attrs, &setup).to_xml)
        doc.remove_namespaces!
        expect(doc.at_xpath('//InitgPty/Id/OrgId/BICOrBEI')).to be_nil
      end
    end

    context 'with AnyBIC and LEI in InitgPty OrgId (v09)' do
      let(:account_attrs) do
        { initiating_party_bic: 'DEUTDEFF', initiating_party_lei: SEPA::TestData::LEI }
      end
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      it 'validates against pain.001.001.09' do
        expect(build_ct(sct_09, account_attrs, &setup).to_xml).to validate_against('pain.001.001.09.xsd')
      end

      it 'places AnyBIC before LEI in OrgId' do
        xml = build_ct(sct_09, account_attrs, &setup).to_xml
        expect(xml.index('AnyBIC')).to be < xml.index('LEI')
      end
    end

    context 'with ContactDetails on InitgPty' do
      let(:account_attrs) do
        { contact_details: SEPA::ContactDetails.new(name: 'John Doe', phone_number: '+49-123456789') }
      end
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains CtctDtls in InitgPty' do
        xml = build_ct(sct_09, account_attrs, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/Nm', 'John Doe')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/PhneNb', '+49-123456789')
      end
    end

    context 'with ContactDetails on Dbtr' do
      let(:account_attrs) do
        { contact_details: SEPA::ContactDetails.new(name: 'Jane Smith', email_address: 'jane@example.com') }
      end
      let(:setup) { ->(sct) { sct.add_transaction(credit_transfer_transaction) } }

      it 'validates against pain.001.001.09' do
        expect(build_ct(sct_09, account_attrs, &setup).to_xml).to validate_against('pain.001.001.09.xsd')
      end

      it 'contains CtctDtls in Dbtr' do
        xml = build_ct(sct_09, account_attrs, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/Nm', 'Jane Smith')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/EmailAdr', 'jane@example.com')
      end
    end

    context 'with ContactDetails on Cdtr (creditor_contact_details)' do
      let(:setup) do
        lambda do |sct|
          sct.add_transaction(credit_transfer_transaction(
                                creditor_contact_details: SEPA::ContactDetails.new(
                                  name: 'Creditor Contact', phone_number: '+49-30123456'
                                )
                              ))
        end
      end

      %i[sct_09 sct_13].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_ct(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end

      it 'contains CtctDtls in Cdtr' do
        xml = build_ct(sct_09, &setup).to_xml
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/Nm', 'Creditor Contact')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/PhneNb', '+49-30123456')
      end
    end

    context 'with all new features combined including LEI and ContactDetails (v13)' do
      subject(:xml) do
        sct = SEPA::CreditTransfer.new(
          profile: sct_13,
          name: SEPA::TestData::DEBTOR_NAME,
          bic: SEPA::TestData::DEBTOR_BIC,
          iban: SEPA::TestData::DEBTOR_IBAN,
          agent_lei: SEPA::TestData::LEI,
          initiating_party_lei: SEPA::TestData::LEI_ALT2,
          initiating_party_bic: 'DEUTDEFF',
          contact_details: SEPA::ContactDetails.new(name: 'Admin', phone_number: '+49-30000000')
        )
        sct.initiation_source_name = 'MyApp'
        sct.add_transaction(credit_transfer_transaction(
                              agent_lei: SEPA::TestData::LEI_ALT,
                              debtor_agent_instruction: 'Process urgently',
                              credit_transfer_mandate_id: 'MNDT-001',
                              credit_transfer_mandate_date_of_signature: Date.new(2024, 6, 1),
                              instructions_for_creditor_agent: [{ code: 'HOLD' }],
                              instruction_for_debtor_agent: 'Note for agent',
                              instruction_for_debtor_agent_code: 'URGP',
                              regulatory_reportings: [{
                                indicator: 'CRED',
                                authority: { name: 'Bundesbank', country: 'DE' },
                                details: [{ type: 'PYMT', date: Date.new(2025, 1, 1), country: 'DE', code: 'XYZ',
                                            amount: { value: 50, currency: 'EUR' } }]
                              }],
                              creditor_contact_details: SEPA::ContactDetails.new(name: 'Creditor Admin')
                            ))
        sct.to_xml
      end

      it 'validates against pain.001.001.13' do
        expect(xml).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains LEI in multiple locations' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/LEI', SEPA::TestData::LEI_ALT2)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/AnyBIC', 'DEUTDEFF')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI',
                                SEPA::TestData::LEI_ALT)
      end

      it 'contains ContactDetails in multiple locations' do
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/Nm', 'Admin')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/Nm', 'Admin')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/Nm', 'Creditor Admin')
      end
    end
  end
end
