# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::DirectDebit do
  let(:message_id_regex) { %r{MSG/[0-9a-f]{28}} }

  let(:direct_debit) { direct_debit_message }

  describe :new do
    it 'accepts missing options' do
      expect do
        SEPA::DirectDebit.new
      end.not_to raise_error
    end
  end

  describe :add_transaction do
    it 'adds valid transactions' do
      3.times do
        direct_debit.add_transaction(direct_debit_transaction)
      end

      expect(direct_debit.transactions.size).to eq(3)
    end

    it 'fails for invalid transaction' do
      expect do
        direct_debit.add_transaction name: ''
      end.to raise_error(SEPA::ValidationError)
    end
  end

  describe :batch_id do
    it 'returns the id of the batch where the given transactions belongs to (1 batch)' do
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE'))

      expect(direct_debit.batch_id('EXAMPLE REFERENCE')).to match(%r{#{message_id_regex}/1})
    end

    it 'returns the id of the batch where the given transactions belongs to (2 batches)' do
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 1'))
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 2', requested_date: Date.today.next.next))
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 3'))

      expect(direct_debit.batch_id('EXAMPLE REFERENCE 1')).to match(%r{#{message_id_regex}/1})
      expect(direct_debit.batch_id('EXAMPLE REFERENCE 2')).to match(%r{#{message_id_regex}/2})
      expect(direct_debit.batch_id('EXAMPLE REFERENCE 3')).to match(%r{#{message_id_regex}/1})
    end
  end

  describe :batches do
    it 'returns an array of batch ids in the sepa message' do
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 1'))
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 2', requested_date: Date.today.next.next))
      direct_debit.add_transaction(direct_debit_transaction(reference: 'EXAMPLE REFERENCE 3'))

      expect(direct_debit.batches.size).to eq(2)
      expect(direct_debit.batches[0]).to match(%r{#{message_id_regex}/[0-9]+})
      expect(direct_debit.batches[1]).to match(%r{#{message_id_regex}/[0-9]+})
    end
  end

  describe :to_xml do
    context 'for invalid creditor' do
      it 'fails' do
        expect do
          SEPA::DirectDebit.new.to_xml
        end.to raise_error(SEPA::Error, /Name is too short/)
      end
    end

    context 'setting debtor address with adrline' do
      subject do
        sdd = direct_debit_message(bic: nil)

        sda = SEPA::DebtorAddress.new country_code: 'CH',
                                      address_line1: 'Mustergasse 123',
                                      address_line2: '1234 Musterstadt'

        sdd.add_transaction(direct_debit_transaction_alt(debtor_address: sda))

        sdd
      end

      it 'validates against pain.008.003.02' do
        expect(subject.to_xml(SEPA::PAIN_008_003_02)).to validate_against('pain.008.003.02.xsd')
      end

      it 'validates against pain.008.001.08' do
        expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
      end

      it 'validates against pain.008.001.12' do
        expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
      end
    end

    context 'setting debtor address with structured fields' do
      subject do
        sdd = direct_debit_message(bic: nil)

        sda = SEPA::DebtorAddress.new country_code: 'CH',
                                      street_name: 'Mustergasse',
                                      building_number: '123',
                                      post_code: '1234',
                                      town_name: 'Musterstadt'

        sdd.add_transaction(direct_debit_transaction_alt(debtor_address: sda))

        sdd
      end

      it 'validates against pain.008.001.02' do
        expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
      end

      it 'validates against pain.008.001.08' do
        expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
      end

      it 'validates against pain.008.001.12' do
        expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
      end
    end

    context 'for valid creditor' do
      context 'without BIC (IBAN-only)' do
        subject do
          sdd = direct_debit_message(bic: nil)

          sdd.add_transaction(direct_debit_transaction_alt)

          sdd
        end

        it 'validates against pain.008.003.02' do
          expect(subject.to_xml(SEPA::PAIN_008_003_02)).to validate_against('pain.008.003.02.xsd')
        end

        it 'fails for pain.008.002.02' do
          expect do
            subject.to_xml(SEPA::PAIN_008_002_02)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'validates against pain.008.001.12' do
          expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
        end
      end

      context 'with BIC' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction_alt)

          sdd
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.002.02' do
          expect(subject.to_xml(SEPA::PAIN_008_002_02)).to validate_against('pain.008.002.02.xsd')
        end

        it 'validates against pain.008.003.02' do
          expect(subject.to_xml(SEPA::PAIN_008_003_02)).to validate_against('pain.008.003.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'validates against pain.008.001.12' do
          expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
        end
      end

      context 'XML structure for pain.008.001.08' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction_alt)

          sdd.to_xml(SEPA::PAIN_008_001_08)
        end

        it 'uses BICFI instead of BIC for creditor agent' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BICFI', SEPA::TestData::DEBTOR_BIC)
          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'uses BICFI instead of BIC for debtor agent' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/BICFI', SEPA::TestData::DD_TX_ALT_BIC)
          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'does not wrap ReqdColltnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt')
          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt/Dt')
        end

        it 'uses correct namespace' do
          expect(subject).to include('urn:iso:std:iso:20022:tech:xsd:pain.008.001.08')
        end
      end

      context 'XML structure for pain.008.001.12' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction_alt)

          sdd.to_xml(SEPA::PAIN_008_001_12)
        end

        it 'uses BICFI instead of BIC' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BICFI', SEPA::TestData::DEBTOR_BIC)
          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'does not wrap ReqdColltnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt')
          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt/Dt')
        end

        it 'uses correct namespace' do
          expect(subject).to include('urn:iso:std:iso:20022:tech:xsd:pain.008.001.12')
        end
      end

      context 'with BIC and debtor address' do
        subject do
          sdd = direct_debit

          sda = SEPA::DebtorAddress.new(
            country_code: 'CH',
            address_line1: 'Mustergasse 123',
            address_line2: '1234 Musterstadt'
          )

          sdd.add_transaction(direct_debit_transaction_alt(debtor_address: sda))

          sdd
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.002.02' do
          expect(subject.to_xml(SEPA::PAIN_008_002_02)).to validate_against('pain.008.002.02.xsd')
        end

        it 'validates against pain.008.003.02' do
          expect(subject.to_xml(SEPA::PAIN_008_003_02)).to validate_against('pain.008.003.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'validates against pain.008.001.12' do
          expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
        end
      end

      context 'without requested_date given' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction_alt)

          sdd.add_transaction name: 'Meier & Schulze oHG',
                              iban: 'DE68210501700012345678',
                              amount: 750.00,
                              reference: 'XYZ/2013-08-ABO/6789',
                              remittance_information: 'Vielen Dank für Ihren Einkauf!',
                              mandate_id: 'K-08-2010-42123',
                              mandate_date_of_signature: Date.new(2010, 7, 25)

          sdd.to_xml
        end

        it 'creates valid XML file' do
          expect(subject).to validate_against('pain.008.001.02.xsd')
        end

        it 'has creditor identifier' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/GrpHdr/InitgPty/Id/OrgId/Othr/Id', direct_debit.account.creditor_identifier)
        end

        it 'contains <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtInfId', %r{#{message_id_regex}/1})
        end

        it 'contains <ReqdColltnDt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ReqdColltnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'contains <PmtMtd>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtMtd', 'DD')
        end

        it 'contains <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/BtchBookg', 'true')
        end

        it 'contains <NbOfTxs>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/NbOfTxs', '2')
        end

        it 'contains <CtrlSum>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CtrlSum', '789.99')
        end

        it 'contains <Cdtr>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/Nm', SEPA::TestData::CREDITOR_NAME)
        end

        it 'contains <CdtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAcct/Id/IBAN', SEPA::TestData::DEBTOR_IBAN)
        end

        it 'contains <CdtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/BIC', SEPA::TestData::DEBTOR_BIC)
        end

        it 'contains <CdtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrSchmeId/Id/PrvtId/Othr/Id', SEPA::TestData::CREDITOR_IDENTIFIER)
        end

        it 'contains <EndToEndId>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/PmtId/EndToEndId', 'XYZ/2013-08-ABO/12345')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/PmtId/EndToEndId', 'XYZ/2013-08-ABO/6789')
        end

        it 'contains <InstdAmt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/InstdAmt', '39.99')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/InstdAmt', '750.00')
        end

        it 'contains <MndtId>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/MndtId', 'K-02-2011-12345')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/MndtId', 'K-08-2010-42123')
        end

        it 'contains <DtOfSgntr>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/DtOfSgntr', '2011-01-25')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/DtOfSgntr', '2010-07-25')
        end

        it 'contains <DbtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DbtrAgt/FinInstnId/BIC', SEPA::TestData::DD_TX_ALT_BIC)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DbtrAgt/FinInstnId/Othr/Id', 'NOTPROVIDED')
        end

        it 'contains <Dbtr>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/Dbtr/Nm', 'Zahlemann + Söhne GbR')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/Dbtr/Nm', 'Meier + Schulze oHG')
        end

        it 'contains <DbtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DbtrAcct/Id/IBAN', SEPA::TestData::DD_TX_ALT_IBAN)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DbtrAcct/Id/IBAN', 'DE68210501700012345678')
        end

        it 'contains <RmtInf>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/RmtInf/Ustrd', 'Unsere Rechnung vom 10.08.2013')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/RmtInf/Ustrd', 'Vielen Dank für Ihren Einkauf')
        end
      end

      context 'with different requested_date given' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2))

          sdd.to_xml
        end

        it 'contains two payment_informations with <ReqdColltnDt>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/ReqdColltnDt', (Date.today + 2).iso8601)

          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end

        it 'contains two payment_informations with different <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtInfId', %r{#{message_id_regex}/1})
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtInfId', %r{#{message_id_regex}/2})
        end
      end

      context 'with different local_instrument given' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(local_instrument: 'CORE'))
          sdd.add_transaction(direct_debit_transaction.merge(local_instrument: 'B2B'))

          sdd
        end

        it 'has errors' do
          expect(subject.errors_on(:base).size).to eq(1)
        end

        it 'raises error on XML generation' do
          expect do
            subject.to_xml
          end.to raise_error(SEPA::Error, /CORE, COR1 AND B2B must not be mixed in one message/)
        end
      end

      context 'with different sequence_type given' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'OOFF'))
          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'FRST'))
          sdd.add_transaction(direct_debit_transaction.merge(sequence_type: 'FRST'))

          sdd.to_xml
        end

        it 'contains two payment_informations with <LclInstrm>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtTpInf/SeqTp', 'OOFF')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtTpInf/SeqTp', 'FRST')

          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end
      end

      context 'with different batch_booking given' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: false))
          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: true))
          sdd.add_transaction(direct_debit_transaction.merge(batch_booking: true))

          sdd.to_xml
        end

        it 'contains two payment_informations with <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/BtchBookg', 'false')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/BtchBookg', 'true')

          expect(subject).not_to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]')
        end
      end

      context 'with transactions containing different group criteria' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1, sequence_type: 'OOFF', amount: 1))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 1, sequence_type: 'FNAL', amount: 2))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2, sequence_type: 'OOFF', amount: 4))
          sdd.add_transaction(direct_debit_transaction.merge(requested_date: Date.today + 2, sequence_type: 'FNAL', amount: 8))

          sdd.to_xml
        end

        it 'contains multiple payment_informations' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/PmtTpInf/SeqTp', 'OOFF')

          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/ReqdColltnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/PmtTpInf/SeqTp', 'FNAL')

          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/ReqdColltnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/PmtTpInf/SeqTp', 'OOFF')

          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/ReqdColltnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/PmtTpInf/SeqTp', 'FNAL')
        end

        it 'has multiple control sums' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/CtrlSum', '1.00')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/CtrlSum', '2.00')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[3]/CtrlSum', '4.00')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[4]/CtrlSum', '8.00')
        end
      end

      context 'with transactions containing different creditor_account' do
        subject do
          sdd = direct_debit

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
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[1]/Cdtr/Nm', SEPA::TestData::CREDITOR_NAME)
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf[2]/Cdtr/Nm', 'Creditor Inc.')
        end
      end

      context 'with mandate amendments' do
        subject do
          sdd = direct_debit

          sdd.add_transaction(direct_debit_transaction.merge(original_debtor_account: 'NL08RABO0135742099'))
          sdd.add_transaction(direct_debit_transaction.merge(same_mandate_new_debtor_agent: true))
          sdd.add_transaction(direct_debit_transaction.merge(original_creditor_account: SEPA::CreditorAccount.new(creditor_identifier: 'NL53ZZZ091734220000', name: 'Creditor Inc.')))
          sdd.to_xml
        end

        it 'includes amendment indicator' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInd', 'true')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/AmdmntInd', 'true')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInd', 'true')
        end

        it 'includes amendment information details' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAcct/Id/IBAN', 'NL08RABO0135742099')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[2]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAgt/FinInstnId/Othr/Id', 'SMNDA')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlCdtrSchmeId/Nm', 'Creditor Inc.')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[3]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlCdtrSchmeId/Id/PrvtId/Othr/Id', 'NL53ZZZ091734220000')
        end
      end

      context 'with original_mandate_id amendment (F9)' do
        subject do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(original_mandate_id: 'OLD-MANDATE-123'))
          sdd.to_xml
        end

        it 'validates against pain.008.001.02' do
          expect(subject).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(original_mandate_id: 'OLD-MANDATE-123'))
          expect(sdd.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'validates against pain.008.001.12' do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(original_mandate_id: 'OLD-MANDATE-123'))
          expect(sdd.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
        end

        it 'validates against pain.008.002.02' do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(original_mandate_id: 'OLD-MANDATE-123'))
          expect(sdd.to_xml(SEPA::PAIN_008_002_02)).to validate_against('pain.008.002.02.xsd')
        end

        it 'includes OrgnlMndtId in amendment details' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInd', 'true')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlMndtId', 'OLD-MANDATE-123')
        end
      end

      context 'with original_mandate_id combined with other amendments' do
        subject do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(
                                original_mandate_id: 'OLD-42',
                                original_debtor_account: 'NL08RABO0135742099'
                              ))
          sdd.to_xml
        end

        it 'validates against pain.008.001.02' do
          expect(subject).to validate_against('pain.008.001.02.xsd')
        end

        it 'includes both OrgnlMndtId and OrgnlDbtrAcct' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlMndtId', 'OLD-42')
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/DrctDbtTx/MndtRltdInf/AmdmntInfDtls/OrgnlDbtrAcct/Id/IBAN', 'NL08RABO0135742099')
        end
      end

      context 'with creditor address on account (F2)' do
        subject do
          direct_debit_with_address.add_transaction(direct_debit_transaction)
          direct_debit_with_address
        end

        let(:direct_debit_with_address) do
          SEPA::DirectDebit.new(
            name: SEPA::TestData::CREDITOR_NAME,
            bic: SEPA::TestData::DEBTOR_BIC,
            iban: SEPA::TestData::DEBTOR_IBAN,
            creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER,
            address: SEPA::Address.new(country_code: 'DE', town_name: 'Berlin', post_code: '10115')
          )
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml('pain.008.001.02')).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'validates against pain.008.001.12' do
          expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
        end

        it 'contains creditor PstlAdr' do
          expect(subject.to_xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/PstlAdr/TwnNm', 'Berlin')
        end
      end

      context 'with charge_bearer on transaction (F4)' do
        subject do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction.merge(charge_bearer: 'SHAR'))
          sdd
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml('pain.008.001.02')).to validate_against('pain.008.001.02.xsd')
        end

        it 'validates against pain.008.001.08' do
          expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
        end

        it 'contains ChrgBr with SHAR' do
          expect(subject.to_xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ChrgBr', 'SHAR')
        end

        it 'fails for EPC schema pain.008.002.02' do
          expect { subject.to_xml(SEPA::PAIN_008_002_02) }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context 'with charge_bearer SLEV (default behavior)' do
        subject do
          sdd = direct_debit
          sdd.add_transaction(direct_debit_transaction)
          sdd.to_xml
        end

        it 'defaults to SLEV' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/ChrgBr', 'SLEV')
        end
      end

      context 'with instruction given' do
        subject do
          sct = direct_debit

          sct.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC'))

          sct.to_xml
        end

        it 'creates valid XML file' do
          expect(subject).to validate_against('pain.008.001.02.xsd')
        end

        it 'contains <InstrId>' do
          expect(subject).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/PmtId/InstrId', '1234/ABC')
        end
      end

      context 'with large message identification' do
        subject do
          sct = direct_debit
          sct.message_identification = 'A' * 35
          sct.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC'))
          sct
        end

        it 'truncates the payment identification to 35 characters' do
          expect { subject.to_xml }.not_to raise_error
        end
      end

      context 'with a different currency given' do
        subject do
          sct = direct_debit

          sct.add_transaction(direct_debit_transaction.merge(instruction: '1234/ABC', currency: 'SEK'))

          sct
        end

        it 'validates against pain.008.001.02' do
          expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
        end

        it 'has a CHF Ccy' do
          doc = Nokogiri::XML(subject.to_xml('pain.008.001.02'))
          doc.remove_namespaces!

          nodes = doc.xpath('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf[1]/InstdAmt')
          expect(nodes.length).to be(1)
          expect(nodes.first.attribute('Ccy').value).to eql('SEK')
        end

        it 'fails for pain.008.002.02' do
          expect do
            subject.to_xml(SEPA::PAIN_008_002_02)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'fails for pain.008.003.02' do
          expect do
            subject.to_xml(SEPA::PAIN_008_003_02)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end
    end

    context 'xml_schema_header' do
      subject { sepa_direct_debit.to_xml(format) }

      let(:sepa_direct_debit) do
        SEPA::DirectDebit.new name: SEPA::TestData::CREDITOR_NAME,
                              iban: SEPA::TestData::DEBTOR_IBAN,
                              creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER
      end

      let(:xml_header) do
        '<?xml version="1.0" encoding="UTF-8"?>' \
          "\n<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:#{format}\" " \
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
          "xsi:schemaLocation=\"urn:iso:std:iso:20022:tech:xsd:#{format} #{format}.xsd\">\n"
      end

      let(:transaction) { direct_debit_transaction_alt }

      before do
        sepa_direct_debit.add_transaction transaction
      end

      context "when format is #{SEPA::PAIN_008_001_02}" do
        let(:format) { SEPA::PAIN_008_001_02 }

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_008_002_02}" do
        let(:format) { SEPA::PAIN_008_002_02 }
        let(:sepa_direct_debit) do
          direct_debit_message(bic: SEPA::TestData::DD_TX_ALT_BIC)
        end
        let(:transaction) do
          direct_debit_transaction_alt(
            debtor_address: SEPA::DebtorAddress.new(
              country_code: 'CH',
              address_line1: 'Mustergasse 123',
              address_line2: '1234 Musterstadt'
            )
          )
        end

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_008_003_02}" do
        let(:format) { SEPA::PAIN_008_003_02 }

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
        end
      end
    end
  end

  describe 'PostalAddress24 fields' do
    subject do
      sdd = direct_debit

      sdd.add_transaction direct_debit_transaction(
        debtor_address: SEPA::DebtorAddress.new(
          country_code: 'DE',
          street_name: 'Hauptstrasse',
          building_name: 'Tower A',
          floor: '3',
          post_code: '10115',
          town_name: 'Berlin'
        )
      )
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'contains BldgNm element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/PstlAdr/BldgNm', 'Tower A')
    end
  end

  describe 'PostalAddress27 fields' do
    subject do
      sdd = direct_debit

      sdd.add_transaction direct_debit_transaction(
        debtor_address: SEPA::DebtorAddress.new(
          country_code: 'DE',
          street_name: 'Hauptstrasse',
          care_of: 'c/o Max Mustermann',
          unit_number: '4B',
          post_code: '10115',
          town_name: 'Berlin'
        )
      )
      sdd
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains CareOf element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/PstlAdr/CareOf', 'c/o Max Mustermann')
    end
  end

  describe 'InstrPrty' do
    subject do
      sdd = direct_debit

      sdd.add_transaction direct_debit_transaction(instruction_priority: 'HIGH')
      sdd
    end

    it 'validates against pain.008.001.02' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'contains InstrPrty element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtTpInf/InstrPrty', 'HIGH')
    end

    it 'fails for pain.008.002.02' do
      expect { subject.to_xml(SEPA::PAIN_008_002_02) }.to raise_error(SEPA::SchemaValidationError, /Incompatible/)
    end
  end

  describe 'UETR' do
    subject do
      sdd = direct_debit

      sdd.add_transaction direct_debit_transaction(uetr: '550e8400-e29b-41d4-a716-446655440000')
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains UETR element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/PmtId/UETR', '550e8400-e29b-41d4-a716-446655440000')
    end

    it 'fails for pain.008.001.02' do
      expect { subject.to_xml(SEPA::PAIN_008_001_02) }.to raise_error(SEPA::SchemaValidationError, /Incompatible/)
    end
  end

  describe 'RPRE sequence type' do
    subject do
      sdd = direct_debit

      sdd.add_transaction direct_debit_transaction(sequence_type: 'RPRE')
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains RPRE in SeqTp' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/PmtTpInf/SeqTp', 'RPRE')
    end

    it 'fails for pain.008.001.02' do
      expect { subject.to_xml(SEPA::PAIN_008_001_02) }.to raise_error(SEPA::SchemaValidationError, /Incompatible/)
    end
  end

  describe 'purpose_code' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(purpose_code: 'SALA')
      sdd
    end

    it 'validates against pain.008.001.02' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains Purp element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Purp/Cd', 'SALA')
    end
  end

  describe 'ultimate_debtor_name' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(ultimate_debtor_name: 'Ultimate Debtor GmbH')
      sdd
    end

    it 'validates against pain.008.001.02' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains UltmtDbtr element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/UltmtDbtr/Nm', 'Ultimate Debtor GmbH')
    end
  end

  describe 'ultimate_creditor_name' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(ultimate_creditor_name: 'Ultimate Creditor AG')
      sdd
    end

    it 'validates against pain.008.001.02' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'contains UltmtCdtr element' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02))
        .to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/UltmtCdtr/Nm', 'Ultimate Creditor AG')
    end
  end

  describe 'structured_remittance_information' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(
        remittance_information: nil,
        structured_remittance_information: 'RF712348231'
      )
      sdd
    end

    it 'validates against pain.008.001.02' do
      expect(subject.to_xml(SEPA::PAIN_008_001_02)).to validate_against('pain.008.001.02.xsd')
    end

    it 'contains Strd/CdtrRefInf structure' do
      xml = subject.to_xml(SEPA::PAIN_008_001_02)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Cd', 'SCOR')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/RmtInf/Strd/CdtrRefInf/Ref', 'RF712348231')
    end
  end

  describe 'LEI on creditor agent (CdtrAgt)' do
    subject do
      sdd = SEPA::DirectDebit.new(
        name: SEPA::TestData::CREDITOR_NAME,
        bic: SEPA::TestData::DEBTOR_BIC,
        iban: SEPA::TestData::DEBTOR_IBAN,
        creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER,
        agent_lei: SEPA::TestData::LEI
      )
      sdd.add_transaction direct_debit_transaction
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains LEI in CdtrAgt/FinInstnId' do
      xml = subject.to_xml(SEPA::PAIN_008_001_08)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
    end

    it 'is incompatible with v02' do
      expect(subject).not_to be_schema_compatible(SEPA::PAIN_008_001_02)
    end
  end

  describe 'LEI on debtor agent (DbtrAgt)' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(agent_lei: SEPA::TestData::LEI)
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains LEI in DbtrAgt/FinInstnId' do
      xml = subject.to_xml(SEPA::PAIN_008_001_08)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
    end

    it 'is incompatible with v02' do
      expect(subject).not_to be_schema_compatible(SEPA::PAIN_008_001_02)
    end
  end

  describe 'ContactDetails on Cdtr' do
    subject do
      sdd = SEPA::DirectDebit.new(
        name: SEPA::TestData::CREDITOR_NAME,
        bic: SEPA::TestData::DEBTOR_BIC,
        iban: SEPA::TestData::DEBTOR_IBAN,
        creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER,
        contact_details: SEPA::ContactDetails.new(name: 'Creditor Contact', phone_number: '+49-30123456')
      )
      sdd.add_transaction direct_debit_transaction
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains CtctDtls in Cdtr' do
      xml = subject.to_xml(SEPA::PAIN_008_001_08)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/Nm', 'Creditor Contact')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/PhneNb', '+49-30123456')
    end
  end

  describe 'ContactDetails on Dbtr (debtor_contact_details)' do
    subject do
      sdd = direct_debit
      sdd.add_transaction direct_debit_transaction(
        debtor_contact_details: SEPA::ContactDetails.new(name: 'Debtor Contact', email_address: 'debtor@example.com')
      )
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains CtctDtls in Dbtr' do
      xml = subject.to_xml(SEPA::PAIN_008_001_08)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/Nm', 'Debtor Contact')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/EmailAdr', 'debtor@example.com')
    end
  end

  describe 'LEI and ContactDetails combined' do
    subject do
      sdd = SEPA::DirectDebit.new(
        name: SEPA::TestData::CREDITOR_NAME,
        bic: SEPA::TestData::DEBTOR_BIC,
        iban: SEPA::TestData::DEBTOR_IBAN,
        creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER,
        agent_lei: SEPA::TestData::LEI,
        contact_details: SEPA::ContactDetails.new(name: 'Admin')
      )
      sdd.add_transaction direct_debit_transaction(
        agent_lei: SEPA::TestData::LEI_ALT,
        debtor_contact_details: SEPA::ContactDetails.new(name: 'Debtor Admin')
      )
      sdd
    end

    it 'validates against pain.008.001.08' do
      expect(subject.to_xml(SEPA::PAIN_008_001_08)).to validate_against('pain.008.001.08.xsd')
    end

    it 'validates against pain.008.001.12' do
      expect(subject.to_xml(SEPA::PAIN_008_001_12)).to validate_against('pain.008.001.12.xsd')
    end

    it 'contains LEI and ContactDetails in correct locations' do
      xml = subject.to_xml(SEPA::PAIN_008_001_12)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/CdtrAgt/FinInstnId/LEI', SEPA::TestData::LEI)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/Cdtr/CtctDtls/Nm', 'Admin')
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/DbtrAgt/FinInstnId/LEI', SEPA::TestData::LEI_ALT)
      expect(xml).to have_xml('//Document/CstmrDrctDbtInitn/PmtInf/DrctDbtTxInf/Dbtr/CtctDtls/Nm', 'Debtor Admin')
    end
  end
end
