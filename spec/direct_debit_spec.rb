# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DirectDebit do
  let(:message_id_regex) { %r{MSG/[0-9a-f]{28}} }

  let(:sdd_02) { SEPA::Profiles::ISO::SDD_02 }
  let(:sdd_08) { SEPA::Profiles::ISO::SDD_08 }
  let(:sdd_12) { SEPA::Profiles::ISO::SDD_12 }
  let(:sdd_epc_002_02) { SEPA::Profiles::ISO::SDD_EPC_002_02 }
  let(:sdd_epc_003_02) { SEPA::Profiles::ISO::SDD_EPC_003_02 }

  describe :new do
    it 'defaults to the generic EPC SDD profile when no profile/country is given' do
      sdd = SEPA::DirectDebit.new(name: SEPA::TestData::CREDITOR_NAME, iban: SEPA::TestData::DEBTOR_IBAN,
                                  bic: SEPA::TestData::DEBTOR_BIC,
                                  creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      expect(sdd.profile).to equal(SEPA::Profiles::EPC::SDD_12)
    end

    it 'rejects a CreditTransfer profile' do
      expect do
        SEPA::DirectDebit.new(profile: SEPA::Profiles::ISO::SCT_03, name: 'x',
                              iban: SEPA::TestData::DEBTOR_IBAN, bic: SEPA::TestData::DEBTOR_BIC,
                              creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER)
      end.to raise_error(ArgumentError, /credit_transfer/)
    end
  end

  describe :add_transaction do
    it 'adds valid transactions' do
      sdd = direct_debit_message
      3.times { sdd.add_transaction(direct_debit_transaction) }
      expect(sdd.transactions.size).to eq(3)
    end

    it 'fails for invalid transaction' do
      expect { direct_debit_message.add_transaction(name: '') }.to raise_error(SEPA::ValidationError)
    end
  end

  describe :batch_id do
    let(:sdd) { direct_debit_message }

    it 'returns the id of the batch where the given transaction belongs (1 batch)' do
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE'))
      expect(sdd.batch_id('EXAMPLE REFERENCE')).to match(%r{#{message_id_regex}/1})
    end

    it 'returns the id of the batch where the given transaction belongs (2 batches)' do
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 1'))
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 2',
                                                   requested_date: Date.today.next.next))
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 3'))

      expect(sdd.batch_id('EXAMPLE REFERENCE 1')).to match(%r{#{message_id_regex}/1})
      expect(sdd.batch_id('EXAMPLE REFERENCE 2')).to match(%r{#{message_id_regex}/2})
      expect(sdd.batch_id('EXAMPLE REFERENCE 3')).to match(%r{#{message_id_regex}/1})
    end
  end

  describe :batches do
    it 'returns an array of batch ids in the sepa message' do
      sdd = direct_debit_message
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 1'))
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 2',
                                                   requested_date: Date.today.next.next))
      sdd.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 3'))

      expect(sdd.batches.size).to eq(2)
      expect(sdd.batches[0]).to match(%r{#{message_id_regex}/[0-9]+})
      expect(sdd.batches[1]).to match(%r{#{message_id_regex}/[0-9]+})
    end
  end

  describe :to_xml do
    context 'for invalid creditor' do
      it 'fails' do
        expect do
          SEPA::DirectDebit.new(profile: sdd_02, name: '',
                                iban: SEPA::TestData::DEBTOR_IBAN, bic: SEPA::TestData::DEBTOR_BIC,
                                creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER).to_xml
        end.to raise_error(SEPA::Error, /Name is too short/)
      end
    end

    context 'with debtor address using AdrLine (IBAN-only)' do
      let(:setup) do
        sda = SEPA::DebtorAddress.new(country_code: 'CH', address_line1: 'Mustergasse 123',
                                      address_line2: '1234 Musterstadt')
        ->(sdd) { sdd.add_transaction(direct_debit_transaction_alt(debtor_address: sda)) }
      end

      %i[sdd_epc_003_02 sdd_08 sdd_12].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_dd(profile, bic: nil, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end
    end

    context 'with debtor address using structured fields' do
      let(:setup) do
        sda = SEPA::DebtorAddress.new(country_code: 'CH', street_name: 'Mustergasse', building_number: '123',
                                      post_code: '1234', town_name: 'Musterstadt')
        ->(sdd) { sdd.add_transaction(direct_debit_transaction_alt(debtor_address: sda)) }
      end

      %i[sdd_02 sdd_08 sdd_12].each do |profile_key|
        it "validates against #{profile_key}" do
          profile = send(profile_key)
          expect(build_dd(profile, bic: nil, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
        end
      end
    end

    context 'for valid creditor' do
      context 'without BIC (IBAN-only)' do
        let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction_alt) } }

        %i[sdd_epc_003_02 sdd_02 sdd_08 sdd_12].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_dd(profile, bic: nil, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'fails for pain.008.002.02 (requires BIC)' do
          expect { build_dd(sdd_epc_002_02, bic: nil, &setup).to_xml }
            .to raise_error(SEPA::ValidationError, /Account missing required BIC/)
        end
      end

      context 'with BIC' do
        let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction_alt) } }

        %i[sdd_02 sdd_epc_002_02 sdd_epc_003_02 sdd_08 sdd_12].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end
      end

      context 'XML structure for pain.008.001.08' do
        subject(:xml) do
          sdd = build_dd(sdd_08)
          sdd.add_transaction(direct_debit_transaction_alt)
          sdd.to_xml
        end

        it 'uses BICFI instead of BIC for creditor agent' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BICFI',
                                  SEPA::TestData::DEBTOR_BIC)
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'uses BICFI instead of BIC for debtor agent' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/BICFI',
                                  SEPA::TestData::DD_TX_ALT_BIC)
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'does not wrap ReqdColltnDt in Dt' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt')
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt/Dt')
        end

        it 'uses correct namespace' do
          expect(xml).to include('urn:iso:std:iso:20022:tech:xsd:pain.008.001.08')
        end
      end

      context 'XML structure for pain.008.001.12' do
        subject(:xml) do
          sdd = build_dd(sdd_12)
          sdd.add_transaction(direct_debit_transaction_alt)
          sdd.to_xml
        end

        it 'uses BICFI' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BICFI',
                                  SEPA::TestData::DEBTOR_BIC)
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'uses correct namespace' do
          expect(xml).to include('urn:iso:std:iso:20022:tech:xsd:pain.008.001.12')
        end
      end

      context 'without requested_date given' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction_alt)
          sdd.add_transaction(name: 'Meier & Schulze oHG',
                              iban: 'DE68210501700012345678',
                              amount: 750.00,
                              reference: 'XYZ/2013-08-ABO/6789',
                              remittance_information: 'Vielen Dank für Ihren Einkauf!',
                              mandate_id: 'K-08-2010-42123',
                              mandate_date_of_signature: Date.new(2010, 7, 25))
          sdd.to_xml
        end

        it 'creates valid XML file' do
          expect(xml).to validate_against('pain.008.001.02.xsd')
        end

        it 'has creditor identifier' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/GrpHdr/InitgPty/Id/OrgId/Othr/Id',
                                  SEPA::TestData::CREDITOR_IDENTIFIER)
        end

        it 'contains <PmtInfId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtInfId', %r{#{message_id_regex}/1})
        end

        it 'contains <ReqdColltnDt>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'contains <PmtMtd>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtMtd', 'DD')
        end

        it 'contains <BtchBookg>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/BtchBookg', 'true')
        end

        it 'contains <NbOfTxs>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/NbOfTxs', '2')
        end

        it 'contains <CtrlSum>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CtrlSum', '789.99')
        end

        it 'contains <Cdtr>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/Nm', SEPA::TestData::CREDITOR_NAME)
        end

        it 'contains <CdtrAcct>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAcct/Id/IBAN', SEPA::TestData::DEBTOR_IBAN)
        end

        it 'contains <CdtrAgt>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC',
                                  SEPA::TestData::DEBTOR_BIC)
        end

        it 'contains <CdtrSchmeId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrSchmeId/Id/PrvtId/Othr/Id',
                                  SEPA::TestData::CREDITOR_IDENTIFIER)
        end

        it 'contains <EndToEndId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/PmtId/EndToEndId',
                                  'XYZ/2013-08-ABO/12345')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/PmtId/EndToEndId',
                                  'XYZ/2013-08-ABO/6789')
        end

        it 'contains <InstdAmt>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/InstdAmt', '39.99')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/InstdAmt', '750.00')
        end

        it 'contains <MndtId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/MndtId',
                                  'K-02-2011-12345')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/MndtId',
                                  'K-08-2010-42123')
        end

        it 'contains <DtOfSgntr>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/DtOfSgntr',
                                  '2011-01-25')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/DtOfSgntr',
                                  '2010-07-25')
        end

        it 'contains <DbtrAgt>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DbtrAgt/FinInstnId/BIC',
                                  SEPA::TestData::DD_TX_ALT_BIC)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DbtrAgt/FinInstnId/Othr/Id',
                                  'NOTPROVIDED')
        end

        it 'contains <Dbtr>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/Dbtr/Nm',
                                  'Zahlemann + Söhne GbR')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/Dbtr/Nm', 'Meier + Schulze oHG')
        end

        it 'contains <DbtrAcct>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DbtrAcct/Id/IBAN',
                                  SEPA::TestData::DD_TX_ALT_IBAN)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DbtrAcct/Id/IBAN',
                                  'DE68210501700012345678')
        end

        it 'contains <RmtInf>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/RmtInf/Ustrd',
                                  'Unsere Rechnung vom 10.08.2013')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/RmtInf/Ustrd',
                                  'Vielen Dank für Ihren Einkauf')
        end
      end

      context 'with different requested_date given' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2))
          sdd.to_xml
        end

        it 'contains two payment_informations with <ReqdColltnDt>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/ReqdColltnDt', (Date.today + 2).iso8601)
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end

        it 'contains two payment_informations with different <PmtInfId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtInfId', %r{#{message_id_regex}/1})
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtInfId', %r{#{message_id_regex}/2})
        end
      end

      context 'with different local_instrument given' do
        subject do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(local_instrument: 'CORE'))
          sdd.add_transaction(direct_debit_transaction.merge(local_instrument: 'B2B'))
          sdd
        end

        it 'has errors' do
          expect(subject.errors_on(:base).size).to eq(1)
        end

        it 'raises error on XML generation' do
          expect { subject.to_xml }
            .to raise_error(SEPA::Error, /CORE, COR1 AND B2B must not be mixed in one message/)
        end
      end

      context 'with different sequence_type given' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'OOFF'))
          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'FRST'))
          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'FRST'))
          sdd.to_xml
        end

        it 'contains two payment_informations with <SeqTp>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtTpInf/SeqTp', 'OOFF')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtTpInf/SeqTp', 'FRST')
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end
      end

      context 'with different batch_booking given' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: false))
          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: true))
          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: true))
          sdd.to_xml
        end

        it 'contains two payment_informations with <BtchBookg>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/BtchBookg', 'false')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/BtchBookg', 'true')
          expect(xml).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end
      end

      context 'with transactions containing different group criteria' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1, sequence_type: 'OOFF',
                                                             amount: 1))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1, sequence_type: 'FNAL',
                                                             amount: 2))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2, sequence_type: 'OOFF',
                                                             amount: 4))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2, sequence_type: 'FNAL',
                                                             amount: 8))
          sdd.to_xml
        end

        it 'contains multiple payment_informations' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtTpInf/SeqTp', 'OOFF')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtTpInf/SeqTp', 'FNAL')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/ReqdColltnDt', (Date.today + 2).iso8601)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/PmtTpInf/SeqTp', 'OOFF')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/ReqdColltnDt', (Date.today + 2).iso8601)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/PmtTpInf/SeqTp', 'FNAL')
        end

        it 'has multiple control sums' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/CtrlSum', '1.00')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/CtrlSum', '2.00')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/CtrlSum', '4.00')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/CtrlSum', '8.00')
        end
      end

      context 'with transactions containing different creditor_account' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction)
          sdd.add_transaction(direct_debit_transaction.merge(creditor_account: SEPA::CreditorAccount.new(
            name: 'Creditor Inc.',
            bic: 'RABONL2U',
            iban: 'NL08RABO0135742099',
            creditor_identifier: 'NL53ZZZ091734220000'
          )))
          sdd.to_xml
        end

        it 'contains two payment_informations with <Cdtr>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/Cdtr/Nm', SEPA::TestData::CREDITOR_NAME)
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/Cdtr/Nm', 'Creditor Inc.')
        end
      end

      context 'with mandate amendments' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(original_debtor_account: 'NL08RABO0135742099'))
          sdd.add_transaction(direct_debit_transaction.merge(same_mandate_new_debtor_agent: true))
          sdd.add_transaction(direct_debit_transaction.merge(original_creditor_account: SEPA::CreditorAccount.new(
            creditor_identifier: 'NL53ZZZ091734220000', name: 'Creditor Inc.'
          )))
          sdd.to_xml
        end

        it 'includes amendment indicator' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInd',
                                  'true')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/AmdmntInd',
                                  'true')
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInd',
                                  'true')
        end

        it 'includes amendment information details' do
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAcct/Id/IBAN',
            'NL08RABO0135742099'
          )
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAgt/FinInstnId/Othr/Id',
            'SMNDA'
          )
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlCdtrSchmeId/Nm',
            'Creditor Inc.'
          )
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlCdtrSchmeId/Id/PrvtId/Othr/Id',
            'NL53ZZZ091734220000'
          )
        end
      end

      context 'with original_mandate_id amendment (F9)' do
        let(:setup) do
          ->(sdd) { sdd.add_transaction(direct_debit_transaction.merge(original_mandate_id: 'OLD-MANDATE-123')) }
        end

        %i[sdd_02 sdd_08 sdd_12 sdd_epc_002_02].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'includes OrgnlMndtId in amendment details' do
          xml = build_dd(sdd_02, &setup).to_xml
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInd',
                                  'true')
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlMndtId',
            'OLD-MANDATE-123'
          )
        end
      end

      context 'with original_mandate_id combined with other amendments' do
        let(:setup) do
          lambda do |sdd|
            sdd.add_transaction(direct_debit_transaction.merge(
                                  original_mandate_id: 'OLD-42',
                                  original_debtor_account: 'NL08RABO0135742099'
                                ))
          end
        end

        it 'validates against pain.008.001.02' do
          expect(build_dd(sdd_02, &setup).to_xml).to validate_against('pain.008.001.02.xsd')
        end

        it 'includes both OrgnlMndtId and OrgnlDbtrAcct' do
          xml = build_dd(sdd_02, &setup).to_xml
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlMndtId',
            'OLD-42'
          )
          expect(xml).to have_xml(
            '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAcct/Id/IBAN',
            'NL08RABO0135742099'
          )
        end
      end

      context 'with creditor address on account (F2)' do
        let(:account_attrs) { { address: SEPA::Address.new(country_code: 'DE', town_name: 'Berlin', post_code: '10115') } }
        let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction) } }

        %i[sdd_02 sdd_08 sdd_12].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_dd(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'contains creditor PstlAdr' do
          expect(build_dd(sdd_02, account_attrs, &setup).to_xml)
            .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/PstlAdr/TwnNm', 'Berlin')
        end
      end

      context 'with charge_bearer SHAR on transaction (F4)' do
        let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction.merge(charge_bearer: 'SHAR')) } }

        %i[sdd_02 sdd_08].each do |profile_key|
          it "validates against #{profile_key}" do
            profile = send(profile_key)
            expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
          end
        end

        it 'contains ChrgBr with SHAR' do
          expect(build_dd(sdd_02, &setup).to_xml)
            .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ChrgBr', 'SHAR')
        end
      end

      context 'with charge_bearer SLEV (default behavior)' do
        it 'defaults to SLEV' do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction)
          expect(sdd.to_xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ChrgBr', 'SLEV')
        end
      end

      context 'with instruction given' do
        subject(:xml) do
          sdd = build_dd(sdd_02)
          sdd.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC'))
          sdd.to_xml
        end

        it 'creates valid XML file' do
          expect(xml).to validate_against('pain.008.001.02.xsd')
        end

        it 'contains <InstrId>' do
          expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/PmtId/InstrId', '1234/ABC')
        end
      end

      context 'with large message identification' do
        it 'truncates the payment identification to 35 characters' do
          sdd = build_dd(sdd_02)
          sdd.message_identification = 'A' * 35
          sdd.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC'))
          expect { sdd.to_xml }.not_to raise_error
        end
      end

      context 'with a different currency given' do
        let(:setup) do
          ->(sdd) { sdd.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC', currency: 'SEK')) }
        end

        it 'validates against pain.008.001.02' do
          expect(build_dd(sdd_02, &setup).to_xml).to validate_against('pain.008.001.02.xsd')
        end

        it 'has a SEK Ccy' do
          doc = Nokogiri::XML(build_dd(sdd_02, &setup).to_xml)
          doc.remove_namespaces!
          nodes = doc.xpath('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/InstdAmt')
          expect(nodes.length).to be(1)
          expect(nodes.first.attribute('Ccy').value).to eql('SEK')
        end
      end
    end

    context 'xml_schema_header' do
      [
        [:sdd_02, 'pain.008.001.02'],
        [:sdd_08, 'pain.008.001.08'],
        [:sdd_12, 'pain.008.001.12'],
        [:sdd_epc_003_02, 'pain.008.003.02']
      ].each do |profile_key, format|
        context "when profile is #{format}" do
          it 'returns correct header' do
            profile = send(profile_key)
            sdd = build_dd(profile, bic: nil)
            sdd.add_transaction(direct_debit_transaction_alt)
            expected = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
                       "<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:#{format}\" " \
                       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
                       "xsi:schemaLocation=\"urn:iso:std:iso:20022:tech:xsd:#{format} #{format}.xsd\">\n"
            expect(sdd.to_xml).to start_with(expected)
          end
        end
      end
    end
  end

  describe 'PostalAddress24 fields' do
    let(:setup) do
      lambda do |sdd|
        sdd.add_transaction(direct_debit_transaction(
                              debtor_address: SEPA::DebtorAddress.new(
                                country_code: 'DE', street_name: 'Hauptstrasse', building_name: 'Tower A',
                                floor: '3', post_code: '10115', town_name: 'Berlin'
                              )
                            ))
      end
    end

    it 'validates against pain.008.001.08' do
      expect(build_dd(sdd_08, &setup).to_xml).to validate_against('pain.008.001.08.xsd')
    end

    it 'contains BldgNm element' do
      expect(build_dd(sdd_08, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/PstlAdr/BldgNm', 'Tower A')
    end
  end

  describe 'PostalAddress27 fields' do
    let(:setup) do
      lambda do |sdd|
        sdd.add_transaction(direct_debit_transaction(
                              debtor_address: SEPA::DebtorAddress.new(
                                country_code: 'DE', street_name: 'Hauptstrasse',
                                care_of: 'c/o Max Mustermann', unit_number: '4B',
                                post_code: '10115', town_name: 'Berlin'
                              )
                            ))
      end
    end

    it 'validates against pain.008.001.12' do
      expect(build_dd(sdd_12, &setup).to_xml).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains CareOf element' do
      expect(build_dd(sdd_12, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/PstlAdr/CareOf', 'c/o Max Mustermann')
    end
  end

  describe 'InstrPrty' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(instruction_priority: 'HIGH')) } }

    %i[sdd_02 sdd_08].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains InstrPrty element' do
      expect(build_dd(sdd_02, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtTpInf/InstrPrty', 'HIGH')
    end
  end

  describe 'UETR' do
    let(:setup) do
      ->(sdd) { sdd.add_transaction(direct_debit_transaction(uetr: '550e8400-e29b-41d4-a716-446655440000')) }
    end

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains UETR element' do
      expect(build_dd(sdd_08, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/PmtId/UETR',
                     '550e8400-e29b-41d4-a716-446655440000')
    end

    it 'is rejected at add_transaction time for pain.008.001.02' do
      expect { build_dd(sdd_02, &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
    end
  end

  describe 'RPRE sequence type' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(sequence_type: 'RPRE')) } }

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains RPRE in SeqTp' do
      expect(build_dd(sdd_08, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtTpInf/SeqTp', 'RPRE')
    end
  end

  describe 'purpose_code' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(purpose_code: 'SALA')) } }

    %i[sdd_02 sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains Purp element' do
      expect(build_dd(sdd_02, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Purp/Cd', 'SALA')
    end
  end

  describe 'ultimate_debtor_name' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(ultimate_debtor_name: 'Ultimate Debtor GmbH')) } }

    %i[sdd_02 sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains UltmtDbtr element' do
      expect(build_dd(sdd_02, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/UltmtDbtr/Nm', 'Ultimate Debtor GmbH')
    end
  end

  describe 'ultimate_creditor_name' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(ultimate_creditor_name: 'Ultimate Creditor AG')) } }

    %i[sdd_02 sdd_08].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains UltmtCdtr element' do
      expect(build_dd(sdd_02, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/UltmtCdtr/Nm', 'Ultimate Creditor AG')
    end
  end

  describe 'structured_remittance_information' do
    let(:setup) do
      lambda do |sdd|
        sdd.add_transaction(direct_debit_transaction(
                              remittance_information: nil,
                              structured_remittance_information: 'RF712348231'
                            ))
      end
    end

    it 'validates against pain.008.001.02' do
      expect(build_dd(sdd_02, &setup).to_xml).to validate_against('pain.008.001.02.xsd')
    end

    it 'contains Strd/CdtrRefInf structure' do
      xml = build_dd(sdd_02, &setup).to_xml
      expect(xml).to have_xml(
        '//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Cd', 'SCOR'
      )
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/RmtInf/Strd/CdtrRefInf/Ref',
                              'RF712348231')
    end
  end

  describe 'LEI on creditor agent (CdtrAgt)' do
    let(:account_attrs) { { agent_lei: SEPA::TestData::LEI } }
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction) } }

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains LEI in CdtrAgt/FinInstnId' do
      expect(build_dd(sdd_08, account_attrs, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
    end
  end

  describe 'LEI on debtor agent (DbtrAgt)' do
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction(agent_lei: SEPA::TestData::LEI)) } }

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains LEI in DbtrAgt/FinInstnId' do
      expect(build_dd(sdd_08, &setup).to_xml)
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
    end

    it 'is rejected at add_transaction time for pain.008.001.02' do
      expect { build_dd(sdd_02, &setup) }.to raise_error(SEPA::ValidationError, /not compatible/)
    end
  end

  describe 'ContactDetails on Cdtr' do
    let(:account_attrs) do
      { contact_details: SEPA::ContactDetails.new(name: 'Creditor Contact', phone_number: '+49-30123456') }
    end
    let(:setup) { ->(sdd) { sdd.add_transaction(direct_debit_transaction) } }

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains CtctDtls in Cdtr' do
      xml = build_dd(sdd_08, account_attrs, &setup).to_xml
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/Nm', 'Creditor Contact')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/PhneNb', '+49-30123456')
    end
  end

  describe 'ContactDetails on Dbtr (debtor_contact_details)' do
    let(:setup) do
      lambda do |sdd|
        sdd.add_transaction(direct_debit_transaction(
                              debtor_contact_details: SEPA::ContactDetails.new(
                                name: 'Debtor Contact', email_address: 'debtor@example.com'
                              )
                            ))
      end
    end

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains CtctDtls in Dbtr' do
      xml = build_dd(sdd_08, &setup).to_xml
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/Nm', 'Debtor Contact')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/EmailAdr',
                              'debtor@example.com')
    end
  end

  describe 'LEI and ContactDetails combined' do
    let(:account_attrs) do
      { agent_lei: SEPA::TestData::LEI,
        contact_details: SEPA::ContactDetails.new(name: 'Admin') }
    end
    let(:setup) do
      lambda do |sdd|
        sdd.add_transaction(direct_debit_transaction(
                              agent_lei: SEPA::TestData::LEI_ALT,
                              debtor_contact_details: SEPA::ContactDetails.new(name: 'Debtor Admin')
                            ))
      end
    end

    %i[sdd_08 sdd_12].each do |profile_key|
      it "validates against #{profile_key}" do
        profile = send(profile_key)
        expect(build_dd(profile, account_attrs, &setup).to_xml).to validate_against("#{profile.iso_schema}.xsd")
      end
    end

    it 'contains LEI and ContactDetails in correct locations' do
      xml = build_dd(sdd_12, account_attrs, &setup).to_xml
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/Nm', 'Admin')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/LEI',
                              SEPA::TestData::LEI_ALT)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/Nm', 'Debtor Admin')
    end
  end
end
