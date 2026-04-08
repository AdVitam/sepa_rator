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
    it 'accepts missing options' do
      expect do
        SEPA::CreditTransfer.new
      end.not_to raise_error
    end
  end

  describe :add_transaction do
    it 'adds valid transactions' do
      3.times do
        credit_transfer.add_transaction(credit_transfer_transaction)
      end

      expect(credit_transfer.transactions.size).to eq(3)
    end

    it 'fails for invalid transaction' do
      expect do
        credit_transfer.add_transaction name: ''
      end.to raise_error(SEPA::ValidationError)
    end
  end

  describe :to_xml do
    context 'for invalid debtor' do
      it 'fails' do
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

      it 'validates against pain.001.003.03' do
        expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
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

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
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

        it 'validates against pain.001.003.03' do
          expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
        end

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
        end

        it 'validates against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        context 'with CHF as currency' do
          let(:currency) { 'CHF' }

          it 'validates against pain.001.001.03.ch.02' do
            expect(subject.to_xml(SEPA::PAIN_001_001_03_CH_02)).to validate_against('pain.001.001.03.ch.02.xsd')
          end
        end

        it 'fails for pain.001.002.03' do
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

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'validates against pain.001.002.03' do
          expect(subject.to_xml('pain.001.002.03')).to validate_against('pain.001.002.03.xsd')
        end

        it 'validates against pain.001.003.03' do
          expect(subject.to_xml('pain.001.003.03')).to validate_against('pain.001.003.03.xsd')
        end

        it 'validates against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
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

        it 'uses BICFI instead of BIC for debtor agent' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'uses BICFI instead of BIC for creditor agent' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BICFI', 'PBNKDEFF370')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/BIC')
        end

        it 'wraps ReqdExctnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'uses correct namespace' do
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

        it 'uses BICFI instead of BIC' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC')
        end

        it 'wraps ReqdExctnDt in Dt' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt/Dt')
        end

        it 'uses correct namespace' do
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

        it 'creates valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'has message_identification' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/MsgId', message_id_regex)
        end

        it 'contains <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtInfId', %r{#{message_id_regex}/1})
        end

        it 'contains <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'contains <PmtMtd>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtMtd', 'TRF')
        end

        it 'contains <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/BtchBookg', 'true')
        end

        it 'contains <NbOfTxs>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/NbOfTxs', '2')
        end

        it 'contains <CtrlSum>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CtrlSum', '161.50')
        end

        it 'contains <Dbtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/Nm', 'Schuldner GmbH')
        end

        it 'contains <DbtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAcct/Id/IBAN', 'DE87200500001234567890')
        end

        it 'contains <DbtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC', 'BANKDEFFXXX')
        end

        it 'contains <EndToEndId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/EndToEndId', 'XYZ-1234/123')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/PmtId/EndToEndId', 'XYZ-5678/456')
        end

        it 'contains <Amt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt', '102.50')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Amt/InstdAmt', '59.00')
        end

        it 'contains <CdtrAgt> for every BIC given' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/BIC', 'PBNKDEFF370')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAgt')
        end

        it 'contains <Cdtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Cdtr/Nm', 'Telekomiker AG')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Cdtr/Nm', 'Amazonas GmbH')
        end

        it 'contains <CdtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/IBAN', 'DE37112589611964645802')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAcct/Id/IBAN', 'DE27793589132923472195')
        end

        it 'contains <RmtInf>' do
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

        it 'contains two payment_informations with <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 2).iso8601)

          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end

        it 'contains two payment_informations with different <PmtInfId>' do
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

        it 'contains two payment_informations with <BtchBookg>' do
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

        it 'contains multiple payment_informations' do
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

        it 'has multiple control sums' do
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

        it 'creates valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'contains CtgyPurp with INST' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/CtgyPurp/Cd', 'INST')
        end

        it 'contains SvcLvl SEPA' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA')
        end

        it 'validates against pain.001.001.09' do
          expect(credit_transfer.tap do |sct|
            sct.add_transaction credit_transfer_transaction.merge(category_purpose: 'INST')
          end.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
          expect(credit_transfer.tap do |sct|
            sct.add_transaction credit_transfer_transaction.merge(category_purpose: 'INST')
          end.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end
      end

      context 'with debtor address on account (F1)' do
        subject do
          credit_transfer_with_address.add_transaction(credit_transfer_transaction)
          credit_transfer_with_address
        end

        let(:credit_transfer_with_address) do
          SEPA::CreditTransfer.new(
            name: 'Schuldner GmbH',
            bic: 'BANKDEFFXXX',
            iban: 'DE87200500001234567890',
            address: SEPA::Address.new(country_code: 'DE', town_name: 'Berlin', post_code: '10115', street_name: 'Hauptstrasse')
          )
        end

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'validates against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        it 'contains debtor PstlAdr' do
          expect(subject.to_xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/PstlAdr/TwnNm', 'Berlin')
        end

        it 'contains debtor street name' do
          expect(subject.to_xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/PstlAdr/StrtNm', 'Hauptstrasse')
        end
      end

      context 'with charge_bearer on transaction (F3)' do
        subject do
          sct = credit_transfer
          sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'SHAR', service_level: nil))
          sct
        end

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'validates against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        it 'contains ChrgBr with SHAR' do
          expect(subject.to_xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'SHAR')
        end

        it 'fails for EPC schema pain.001.002.03' do
          expect { subject.to_xml(SEPA::PAIN_001_002_03) }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'fails for EPC schema pain.001.003.03' do
          expect { subject.to_xml(SEPA::PAIN_001_003_03) }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context 'with charge_bearer DEBT' do
        subject do
          sct = credit_transfer
          sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'DEBT', service_level: nil))
          sct
        end

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'contains ChrgBr with DEBT' do
          expect(subject.to_xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'DEBT')
        end
      end

      context 'with charge_bearer SLEV on EPC schema' do
        subject do
          sct = credit_transfer
          sct.add_transaction(credit_transfer_transaction.merge(charge_bearer: 'SLEV'))
          sct
        end

        it 'validates against pain.001.002.03' do
          expect(subject.to_xml(SEPA::PAIN_001_002_03)).to validate_against('pain.001.002.03.xsd')
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

        it 'creates valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'contains <InstrId>' do
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

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'has a CHF Ccy' do
          doc = Nokogiri::XML(subject.to_xml('pain.001.001.03'))
          doc.remove_namespaces!

          nodes = doc.xpath('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt')
          expect(nodes.length).to be(1)
          expect(nodes.first.attribute('Ccy').value).to eql('CHF')
        end

        it 'fails for pain.001.002.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_002_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'fails for pain.001.003.03' do
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

        it 'validates against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'validates against pain.001.001.09' do
          expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
        end

        it 'validates against pain.001.001.13' do
          expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
        end

        it 'fails for pain.001.002.03' do
          expect do
            subject.to_xml(SEPA::PAIN_001_002_03)
          end.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'validates against pain.001.003.03' do
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

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
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

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
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

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
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

        it 'returns correct header' do
          expect(subject).to start_with(xml_header)
        end
      end
    end

    context 'with potentially malicious input' do
      it 'generates valid XML with injection attempts in name' do
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

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'contains BldgNm element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/BldgNm', 'Tower A')
      end

      it 'contains DstrctNm element' do
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

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains CareOf element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/PstlAdr/CareOf', 'c/o Max Mustermann')
      end

      it 'contains UnitNb element' do
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

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'contains InstrPrty element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/InstrPrty', 'HIGH')
      end

      it 'places InstrPrty before SvcLvl' do
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

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains UETR element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/PmtId/UETR', '550e8400-e29b-41d4-a716-446655440000')
      end

      it 'fails for pain.001.001.03' do
        expect { subject.to_xml(SEPA::PAIN_001_001_03) }.to raise_error(SEPA::SchemaValidationError, /Incompatible/)
      end
    end

    context 'with purpose_code' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(purpose_code: 'SALA')
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains Purp element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Purp/Cd', 'SALA')
      end
    end

    context 'with ultimate_creditor_name' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(ultimate_creditor_name: 'Ultimate Corp')
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains UltmtCdtr element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/UltmtCdtr/Nm', 'Ultimate Corp')
      end
    end

    context 'with ultimate_debtor_name' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(ultimate_debtor_name: 'Original Debtor GmbH')
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains UltmtDbtr element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/UltmtDbtr/Nm', 'Original Debtor GmbH')
      end
    end

    context 'with initiating_party_identifier' do
      subject do
        sct = SEPA::CreditTransfer.new(name: 'Schuldner GmbH',
                                       bic: 'BANKDEFFXXX',
                                       iban: 'DE87200500001234567890',
                                       initiating_party_identifier: 'DE98ZZZ09999999999')
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains InitgPty/Id element' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/Id', 'DE98ZZZ09999999999')
      end
    end

    context 'with URGP service level' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(service_level: 'URGP')
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains SvcLvl with URGP' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03))
          .to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/SvcLvl/Cd', 'URGP')
      end
    end

    context 'with structured_remittance_information' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          remittance_information: nil,
          structured_remittance_information: 'RF712348231'
        )
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains Strd/CdtrRefInf structure' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Cd', 'SCOR')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Ref', 'RF712348231')
      end
    end

    context 'with creditor without BIC' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(bic: nil)
        sct
      end

      it 'does not emit NOTPROVIDED for creditor agent' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        notprovided = doc.at_xpath('//CdtTrfTxInf/CdtrAgt/FinInstnId/Othr/Id')
        expect(notprovided).to be_nil
      end

      it 'does not emit CdtrAgt at all' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        cdtr_agt = doc.at_xpath('//CdtTrfTxInf/CdtrAgt')
        expect(cdtr_agt).to be_nil
      end
    end

    context 'with InitnSrc (v13 only)' do
      subject do
        sct = credit_transfer
        sct.initiation_source_name = 'MyApp'
        sct.initiation_source_provider = 'Advitam'
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains InitnSrc element in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitnSrc/Nm', 'MyApp')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitnSrc/Prvdr', 'Advitam')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with InstrForDbtrAgt at PmtInf level (v09/v13)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(debtor_agent_instruction: 'Please process urgently')
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains InstrForDbtrAgt in PmtInf' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/InstrForDbtrAgt', 'Please process urgently')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with MndtRltdInf (v13 only)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          credit_transfer_mandate_id: 'MNDT-2024-001',
          credit_transfer_mandate_date_of_signature: Date.new(2024, 1, 15),
          credit_transfer_mandate_frequency: 'MNTH'
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains MndtRltdInf elements in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/MndtId', 'MNDT-2024-001')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/DtOfSgntr', '2024-01-15')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/MndtRltdInf/Frqcy/Tp', 'MNTH')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end

      it 'is incompatible with v09' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
      end
    end

    context 'with InstrForCdtrAgt' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          instructions_for_creditor_agent: [{ code: 'HOLD', instruction_info: 'Hold for pickup' }]
        )
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains InstrForCdtrAgt elements' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForCdtrAgt/Cd', 'HOLD')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForCdtrAgt/InstrInf', 'Hold for pickup')
      end
    end

    context 'with InstrForDbtrAgt at transaction level (v03/v09 text)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(instruction_for_debtor_agent: 'Urgent transfer')
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'emits plain text InstrForDbtrAgt for v03' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt', 'Urgent transfer')
      end
    end

    context 'with InstrForDbtrAgt at transaction level (v13 structured)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          instruction_for_debtor_agent: 'Please process',
          instruction_for_debtor_agent_code: 'URGP'
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'emits structured InstrForDbtrAgt for v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt/Cd', 'URGP')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/InstrForDbtrAgt/InstrInf', 'Please process')
      end

      it 'is incompatible with v03 due to code' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with RegulatoryReporting (v03)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          regulatory_reportings: [{ indicator: 'CRED', details: [{ code: 'ABC', information: ['Some info'] }] }]
        )
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'uses Cd tag in v03' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/DbtCdtRptgInd', 'CRED')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Cd', 'ABC')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Inf', 'Some info')
      end
    end

    context 'with RegulatoryReporting (v13)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          regulatory_reportings: [{ indicator: 'CRED', details: [{ code: 'ABC', information: ['Some info'] }] }]
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'uses RptgCd tag in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/DbtCdtRptgInd', 'CRED')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/RptgCd', 'ABC')
      end
    end

    context 'with enhanced RemittanceInformation' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          remittance_information: nil,
          structured_remittance_information: 'RF712348231',
          structured_remittance_reference_type: 'SCOR',
          structured_remittance_issuer: 'Bank GmbH',
          additional_remittance_information: ['Invoice 2024-001']
        )
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains Issr and AddtlRmtInf' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/CdtrRefInf/Tp/Issr', 'Bank GmbH')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RmtInf/Strd/AddtlRmtInf', 'Invoice 2024-001')
      end
    end

    context 'with all new features combined (v13)' do
      subject do
        sct = credit_transfer
        sct.initiation_source_name = 'MyApp'
        sct.add_transaction credit_transfer_transaction(
          debtor_agent_instruction: 'Process urgently',
          credit_transfer_mandate_id: 'MNDT-001',
          credit_transfer_mandate_date_of_signature: Date.new(2024, 6, 1),
          instructions_for_creditor_agent: [{ code: 'HOLD' }],
          instruction_for_debtor_agent: 'Note for agent',
          instruction_for_debtor_agent_code: 'URGP',
          regulatory_reportings: [{ indicator: 'CRED', details: [{ code: 'XYZ' }] }]
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end
    end

    context 'with LEI on debtor agent (DbtrAgt)' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          agent_lei: '529900T8BM49AURSDO55'
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains LEI in DbtrAgt/FinInstnId' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/LEI', '529900T8BM49AURSDO55')
      end

      it 'places LEI after BICFI in DbtrAgt' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml.index('BICFI')).to be < xml.index('LEI')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with LEI on creditor agent (CdtrAgt)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(agent_lei: '529900T8BM49AURSDO55')
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains LEI in CdtrAgt/FinInstnId' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI', '529900T8BM49AURSDO55')
      end

      it 'emits CdtrAgt even without BIC when LEI is present' do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(bic: nil, agent_lei: '529900T8BM49AURSDO55')
        xml = sct.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI', '529900T8BM49AURSDO55')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with LEI in InitgPty OrgId' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          initiating_party_lei: '529900T8BM49AURSDO55'
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains LEI in InitgPty/Id/OrgId' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/LEI', '529900T8BM49AURSDO55')
      end

      it 'is incompatible with v03' do
        expect(subject).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      end
    end

    context 'with BICOrBEI in InitgPty OrgId (v03)' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          initiating_party_bic: 'DEUTDEFF'
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains BICOrBEI in InitgPty/Id/OrgId' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/BICOrBEI', 'DEUTDEFF')
      end
    end

    context 'with AnyBIC in InitgPty OrgId (v09/v13)' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          initiating_party_bic: 'DEUTDEFF'
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains AnyBIC in InitgPty/Id/OrgId for v09' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/AnyBIC', 'DEUTDEFF')
      end

      it 'does not contain BICOrBEI in v09' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        expect(doc.at_xpath('//InitgPty/Id/OrgId/BICOrBEI')).to be_nil
      end
    end

    context 'with AnyBIC and LEI in InitgPty OrgId (v09)' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          initiating_party_bic: 'DEUTDEFF',
          initiating_party_lei: '529900T8BM49AURSDO55'
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'places AnyBIC before LEI in OrgId' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml.index('AnyBIC')).to be < xml.index('LEI')
      end
    end

    context 'with ContactDetails on InitgPty' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          contact_details: SEPA::ContactDetails.new(name: 'John Doe', phone_number: '+49-123456789')
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains CtctDtls in InitgPty' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/Nm', 'John Doe')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/PhneNb', '+49-123456789')
      end
    end

    context 'with ContactDetails on Dbtr' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          contact_details: SEPA::ContactDetails.new(name: 'Jane Smith', email_address: 'jane@example.com')
        )
        sct.add_transaction credit_transfer_transaction
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'contains CtctDtls in Dbtr' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/Nm', 'Jane Smith')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/EmailAdr', 'jane@example.com')
      end
    end

    context 'with ContactDetails on Cdtr (creditor_contact_details)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          creditor_contact_details: SEPA::ContactDetails.new(name: 'Creditor Contact', phone_number: '+49-30123456')
        )
        sct
      end

      it 'validates against pain.001.001.09' do
        expect(subject.to_xml(SEPA::PAIN_001_001_09)).to validate_against('pain.001.001.09.xsd')
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains CtctDtls in Cdtr' do
        xml = subject.to_xml(SEPA::PAIN_001_001_09)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/Nm', 'Creditor Contact')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/PhneNb', '+49-30123456')
      end
    end

    context 'with RegulatoryReporting with authority, type, date, country, amount (v03)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
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
        )
        sct
      end

      it 'validates against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end

      it 'contains Authrty element' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Authrty/Nm', 'Bundesbank')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Authrty/Ctry', 'DE')
      end

      it 'contains Tp as plain text in v03' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp', 'PAYMENT')
      end

      it 'contains Dt element' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Dt', '2025-06-15')
      end

      it 'contains Ctry element in detail' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Ctry', 'DE')
      end

      it 'contains Amt element' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Amt', '102.50')
      end

      it 'follows correct XSD element order (Tp, Dt, Ctry, Cd, Amt, Inf)' do
        xml = subject.to_xml(SEPA::PAIN_001_001_03)
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
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          regulatory_reportings: [{
            indicator: 'CRED',
            authority: { name: 'Bundesbank', country: 'DE' },
            details: [{
              type: 'PYMT',
              date: Date.new(2025, 6, 15),
              country: 'DE',
              code: 'ABC',
              amount: { value: 102.50, currency: 'EUR' },
              information: ['Transfer info']
            }]
          }]
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'wraps Tp in structured Cd element in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp/Cd', 'PYMT')
      end

      it 'uses RptgCd instead of Cd in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/RptgCd', 'ABC')
      end
    end

    context 'with RegulatoryReporting with type_proprietary (v13)' do
      subject do
        sct = credit_transfer
        sct.add_transaction credit_transfer_transaction(
          regulatory_reportings: [{
            indicator: 'DEBT',
            details: [{ type_proprietary: 'CUSTOM_TYPE', code: 'XYZ' }]
          }]
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'uses Prtry inside Tp in v13' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/RgltryRptg/Dtls/Tp/Prtry', 'CUSTOM_TYPE')
      end
    end

    context 'with all new features combined including LEI and ContactDetails (v13)' do
      subject do
        sct = SEPA::CreditTransfer.new(
          name: 'Schuldner GmbH',
          bic: 'BANKDEFFXXX',
          iban: 'DE87200500001234567890',
          agent_lei: '529900T8BM49AURSDO55',
          initiating_party_lei: 'ABCDEFGHIJKLMNOPQR30',
          initiating_party_bic: 'DEUTDEFF',
          contact_details: SEPA::ContactDetails.new(name: 'Admin', phone_number: '+49-30000000')
        )
        sct.initiation_source_name = 'MyApp'
        sct.add_transaction credit_transfer_transaction(
          agent_lei: '529900ABCDEFGHIJKL19',
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
        )
        sct
      end

      it 'validates against pain.001.001.13' do
        expect(subject.to_xml(SEPA::PAIN_001_001_13)).to validate_against('pain.001.001.13.xsd')
      end

      it 'contains LEI in multiple locations' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/LEI', 'ABCDEFGHIJKLMNOPQR30')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/AnyBIC', 'DEUTDEFF')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/LEI', '529900T8BM49AURSDO55')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/CdtrAgt/FinInstnId/LEI', '529900ABCDEFGHIJKL19')
      end

      it 'contains ContactDetails in multiple locations' do
        xml = subject.to_xml(SEPA::PAIN_001_001_13)
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/CtctDtls/Nm', 'Admin')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/CtctDtls/Nm', 'Admin')
        expect(xml).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf/Cdtr/CtctDtls/Nm', 'Creditor Admin')
      end
    end
  end
end
