# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::CreditTransfer do
  let(:message_id_regex) { %r{MSG/[0-9a-f]{28}} }
  let(:credit_transfer) do
    SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                             bic: 'BANKDEFFXXX',
                             iban: 'DE87200500001234567890'
  end

  describe :new do
    it 'should accept missing options' do
      expect do
        SEPA::CreditTransfer.new
      end.to_not raise_error
    end
  end

  describe :add_transaction do
    it 'should add valid transactions' do
      3.times do
        credit_transfer.add_transaction(credit_transfer_transaction)
      end

      expect(credit_transfer.transactions.size).to eq(3)
    end

    it 'should fail for invalid transaction' do
      expect do
        credit_transfer.add_transaction name: ''
      end.to raise_error(SEPA::ValidationError)
    end
  end

  describe :to_xml do
    context 'for invalid debtor' do
      it 'should fail' do
        expect do
          SEPA::CreditTransfer.new.to_xml
        end.to raise_error(SEPA::Error, /Name is too short/)
      end
    end

    context 'setting creditor address with adrline' do
      subject do
        sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                       iban: 'DE87200500001234567890'

        sca = SEPA::CreditorAddress.new country_code: 'CH',
                                        address_line1: 'Mustergasse 123',
                                        address_line2: '1234 Musterstadt'

        sct.add_transaction name: 'Telekomiker AG',
                            bic: 'PBNKDEFF370',
                            iban: 'DE37112589611964645802',
                            amount: 102.50,
                            reference: 'XYZ-1234/123',
                            remittance_information: 'Rechnung vom 22.08.2013',
                            creditor_address: sca

        sct
      end

      it 'should validate against pain.001.003.03' do
        expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
      end

      it 'should validate against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'should validate against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end
    end

    context 'setting creditor address with structured fields' do
      subject do
        sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                       iban: 'DE87200500001234567890',
                                       bic: 'BANKDEFFXXX'

        sca = SEPA::CreditorAddress.new country_code: 'CH',
                                        street_name: 'Mustergasse',
                                        building_number: '123',
                                        post_code: '1234',
                                        town_name: 'Musterstadt'

        sct.add_transaction name: 'Telekomiker AG',
                            bic: 'PBNKDEFF370',
                            iban: 'DE37112589611964645802',
                            amount: 102.50,
                            reference: 'XYZ-1234/123',
                            remittance_information: 'Rechnung vom 22.08.2013',
                            creditor_address: sca

        sct
      end

      it 'should validate against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'should validate against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'should validate against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end
    end

    context 'for valid debtor' do
      context 'without BIC (IBAN-only)' do
        subject do
          sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                         iban: 'DE87200500001234567890'

          sct.add_transaction name: 'Telekomiker AG',
                              bic: 'PBNKDEFF370',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              currency: currency,
                              reference: 'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct
        end

        let(:currency) { nil }

        it 'should validate against pain.001.003.03' do
          expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
        end

        it 'should validate against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'should validate against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        context 'with CHF as currency' do
          let(:currency) { 'CHF' }

          it 'should validate against pain.001.001.03.ch.02' do
            expect(subject.to_xml(SEPA::PAIN_001_001_03_CH_02)).to validate_against('pain.001.001.03.ch.02.xsd')
          end
        end

        it 'should fail for pain.001.002.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_002_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context 'with BIC' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              bic: 'PBNKDEFF370',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              reference: 'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'should validate against pain.001.002.03' do
          expect(subject.to_xml('pain.001.002.03')).to validate_against('pain.001.002.03.xsd')
        end

        it 'should validate against pain.001.003.03' do
          expect(subject.to_xml('pain.001.003.03')).to validate_against('pain.001.003.03.xsd')
        end

        it 'should validate against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'should validate against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end
      end

      context 'XML structure for pain.001.001.09' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              bic: 'PBNKDEFF370',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              reference: 'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct.to_xml(SEPA::PAIN_001_001_09)
        end

        it 'should use BICFI instead of BIC for debtor agent' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'should use BICFI instead of BIC for creditor agent' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BICFI', 'PBNKDEFF370')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'should wrap ReqdExctnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'should use correct namespace' do
          expect(subject).to include('urn:iso:std:iso:20022:tech:xsd:pain.001.001.09')
        end
      end

      context 'XML structure for pain.001.001.13' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              bic: 'PBNKDEFF370',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              reference: 'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct.to_xml(SEPA::PAIN_001_001_13)
        end

        it 'should use BICFI instead of BIC' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'should wrap ReqdExctnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'should use correct namespace' do
          expect(subject).to include('urn:iso:std:iso:20022:tech:xsd:pain.001.001.13')
        end
      end

      context 'without requested_date given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              bic: 'PBNKDEFF370',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              reference: 'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct.add_transaction name: 'Amazonas GmbH',
                              iban: 'DE27793589132923472195',
                              amount: 59.00,
                              reference: 'XYZ-5678/456',
                              remittance_information: 'Rechnung vom 21.08.2013'

          sct.to_xml
        end

        it 'should create valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should have message_identification' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/MsgId', message_id_regex)
        end

        it 'should contain <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtInfId', %r{#{message_id_regex}/1})
        end

        it 'should contain <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'should contain <PmtMtd>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtMtd', 'TRF')
        end

        it 'should contain <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/BtchBookg', 'true')
        end

        it 'should contain <NbOfTxs>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/NbOfTxs', '2')
        end

        it 'should contain <CtrlSum>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CtrlSum', '161.50')
        end

        it 'should contain <Dbtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/Nm', 'Schuldner GmbH')
        end

        it 'should contain <DbtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAcct/Id/IBAN', 'DE87200500001234567890')
        end

        it 'should contain <DbtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC', 'BANKDEFFXXX')
        end

        it 'should contain <EndToEndId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/EndToEndId', 'XYZ-1234/123')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/PmtId/EndToEndId', 'XYZ-5678/456')
        end

        it 'should contain <Amt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt', '102.50')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Amt/InstdAmt', '59.00')
        end

        it 'should contain <CdtrAgt> for every BIC given' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/BIC', 'PBNKDEFF370')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAgt')
        end

        it 'should contain <Cdtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Cdtr/Nm', 'Telekomiker AG')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Cdtr/Nm', 'Amazonas GmbH')
        end

        it 'should contain <CdtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/IBAN', 'DE37112589611964645802')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAcct/Id/IBAN', 'DE27793589132923472195')
        end

        it 'should contain <RmtInf>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Ustrd', 'Rechnung vom 22.08.2013')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/RmtInf/Ustrd', 'Rechnung vom 21.08.2013')
        end
      end

      context 'with different requested_date given' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2))

          sct.to_xml
        end

        it 'should contain two payment_informations with <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 2).iso8601)

          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end

        it 'should contain two payment_informations with different <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/PmtInfId', %r{#{message_id_regex}/1})
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/PmtInfId', %r{#{message_id_regex}/2})
        end
      end

      context 'with different batch_booking given' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: false))
          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: true))
          sct.add_transaction(credit_transfer_transaction.merge(batch_booking: true))

          sct.to_xml
        end

        it 'should contain two payment_informations with <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')

          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end
      end

      context 'with transactions containing different group criteria' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1, batch_booking: false, amount: 1))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 1, batch_booking: true,  amount: 2))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: false, amount: 4))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: true,  amount: 8))
          sct.add_transaction(credit_transfer_transaction.merge(requested_date: Date.today + 2, batch_booking: true, category_purpose: 'SALA', amount: 6))

          sct.to_xml
        end

        it 'should contain multiple payment_informations' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/BtchBookg', 'false')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/BtchBookg', 'true')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/PmtTpInf/CtgyPurp/Cd', 'SALA')
        end

        it 'should have multiple control sums' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/CtrlSum', '1.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/CtrlSum', '2.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/CtrlSum', '4.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/CtrlSum', '8.00')
        end
      end

      context 'with INST category purpose (SCT Inst)' do
        subject do
          sct = credit_transfer

          sct.add_transaction credit_transfer_transaction.merge(category_purpose: 'INST')

          sct.to_xml
        end

        it 'should create valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should contain CtgyPurp with INST' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/CtgyPurp/Cd', 'INST')
        end

        it 'should contain SvcLvl SEPA' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA')
        end

        it 'should validate against pain.001.001.09' do
          expect(credit_transfer.tap do |sct|
            sct.add_transaction credit_transfer_transaction.merge(category_purpose: 'INST')
          end.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'should validate against pain.001.001.13' do
          expect(credit_transfer.tap do |sct|
            sct.add_transaction credit_transfer_transaction.merge(category_purpose: 'INST')
          end.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end
      end

      context 'with instruction given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              iban: 'DE37112589611964645802',
                              amount: 102.50,
                              instruction: '1234/ABC'

          sct.to_xml
        end

        it 'should create valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should contain <InstrId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/InstrId', '1234/ABC')
        end
      end

      context 'with a different currency given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              iban: 'DE37112589611964645802',
                              bic: 'PBNKDEFF370',
                              amount: 102.50,
                              currency: 'CHF'

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'should have a CHF Ccy' do
          doc = Nokogiri::XML(subject.to_xml('pain.001.001.03'))
          doc.remove_namespaces!

          nodes = doc.xpath('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt')
          expect(nodes.length).to eql(1)
          expect(nodes.first.attribute('Ccy').value).to eql('CHF')
        end

        it 'should fail for pain.001.002.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_002_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'should fail for pain.001.003.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_003_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context 'with a transaction without a bic' do
        subject do
          sct = credit_transfer

          sct.add_transaction name: 'Telekomiker AG',
                              iban: 'DE37112589611964645802',
                              amount: 102.50

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'should validate against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'should validate against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        it 'should fail for pain.001.002.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_002_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'should validate against pain.001.003.03' do
          expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
        end
      end
    end

    context 'xml_schema_header' do
      subject { credit_transfer.to_xml(format) }

      let(:xml_header) do
        '<?xml version="1.0" encoding="UTF-8"?>' \
          "\n<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:#{format}\" " \
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
          "xsi:schemaLocation=\"urn:iso:std:iso:20022:tech:xsd:#{format} #{format}.xsd\">\n"
      end

      let(:transaction) do
        {
          name: 'Telekomiker AG',
          iban: 'DE37112589611964645802',
          bic: 'PBNKDEFF370',
          amount: 102.50,
          currency: 'CHF'
        }
      end

      before do
        credit_transfer.add_transaction transaction
      end

      context "when format is #{SEPA::PAIN_001_001_03}" do
        let(:format) { SEPA::PAIN_001_001_03 }

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_002_03}" do
        let(:format) { SEPA::PAIN_001_002_03 }
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            bic: 'PBNKDEFF370',
            iban: 'DE37112589611964645802',
            amount: 102.50,
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_003_03}" do
        let(:format) { SEPA::PAIN_001_003_03 }
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            bic: 'PBNKDEFF370',
            iban: 'DE37112589611964645802',
            amount: 102.50,
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_001_03_CH_02}" do
        let(:format) { SEPA::PAIN_001_001_03_CH_02 }
        let(:credit_transfer) do
          SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                   iban: 'CH5481230000001998736',
                                   bic: 'RAIFCH22'
        end
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE62007620110623852957',
            amount: 102.50,
            currency: 'CHF',
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        let(:xml_header) do
          '<?xml version="1.0" encoding="UTF-8"?>' \
            "\n<Document xmlns=\"http://www.six-interbank-clearing.com/de/#{format}.xsd\" " \
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
            "xsi:schemaLocation=\"http://www.six-interbank-clearing.com/de/#{format}.xsd  #{format}.xsd\">\n"
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end
    end

    context 'with potentially malicious input' do
      it 'should generate valid XML with injection attempts in name' do
        sct = SEPA::CreditTransfer.new(name: 'Legitimate Business', iban: 'DE87200500001234567890', bic: 'BANKDEFFXXX')
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
      subject do
        sct = credit_transfer

        sct.add_transaction credit_transfer_transaction(
          creditor_address: SEPA::CreditorAddress.new(
            country_code: 'DE',
            street_name: 'Hauptstrasse',
            building_number: '42',
            building_name: 'Tower A',
            floor: '3',
            post_code: '10115',
            town_name: 'Berlin',
            district_name: 'Berlin-Mitte'
          )
        )
        sct
      end

      it 'should validate against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'should contain BldgNm element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/BldgNm', 'Tower A')
      end

      it 'should contain DstrctNm element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/DstrctNm', 'Berlin-Mitte')
      end
    end

    context 'with PostalAddress27 fields' do
      subject do
        sct = credit_transfer

        sct.add_transaction credit_transfer_transaction(
          creditor_address: SEPA::CreditorAddress.new(
            country_code: 'DE',
            street_name: 'Hauptstrasse',
            care_of: 'c/o Max Mustermann',
            unit_number: '4B',
            post_code: '10115',
            town_name: 'Berlin'
          )
        )
        sct
      end

      it 'should validate against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'should contain CareOf element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/CareOf', 'c/o Max Mustermann')
      end

      it 'should contain UnitNb element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/UnitNb', '4B')
      end
    end

    context 'with InstrPrty' do
      subject do
        sct = credit_transfer

        sct.add_transaction credit_transfer_transaction(instruction_priority: 'HIGH')
        sct
      end

      it 'should validate against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'should validate against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'should contain InstrPrty element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/InstrPrty', 'HIGH')
      end

      it 'should place InstrPrty before SvcLvl' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml.index('InstrPrty')).to be < xml.index('SvcLvl')
      end
    end

    context 'with UETR' do
      subject do
        sct = credit_transfer

        sct.add_transaction credit_transfer_transaction(uetr: '550e8400-e29b-41d4-a716-446655440000')
        sct
      end

      it 'should validate against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'should validate against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'should contain UETR element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/PmtId/UETR', '550e8400-e29b-41d4-a716-446655440000')
      end

      it 'should fail for pain.001.001.03' do
        expect { subject.to_xml(SEPA::PAIN_001_001_03) }.to raise_error(SEPA::SchemaValidationError, /Incompatible/)
      end
    end
  end
end
