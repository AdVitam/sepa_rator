# frozen_string_literal: true

CHARSET_PERSON = 'José García & Co.'

def charset_credit_transfer_xml(profile, country_code: 'DE')
  sct = SEPA::CreditTransfer.new(profile: profile, name: CHARSET_PERSON,
                                 bic: SEPA::TestData::DEBTOR_BIC, iban: SEPA::TestData::DEBTOR_IBAN)
  sct.add_transaction(credit_transfer_transaction(
                        name: CHARSET_PERSON, reference: 'Réf-1', remittance_information: 'Café é',
                        creditor_address: SEPA::CreditorAddress.new(
                          country_code: country_code, street_name: 'Hauptstrasse', building_number: '1',
                          town_name: 'Berlin', post_code: '10115'
                        )
                      ))
  sct.to_xml
end

def expect_charset_xml(xml, name:, remittance:, reference:)
  base = '//Document/CstmrCdtTrfInitn/PmtInf'
  expect(xml).to have_xml("#{base}/Dbtr/Nm", name)
  expect(xml).to have_xml("#{base}/CdtTrfTxInf/Cdtr/Nm", name)
  expect(xml).to have_xml("#{base}/CdtTrfTxInf/RmtInf/Ustrd", remittance)
  expect(xml).to have_xml("#{base}/CdtTrfTxInf/PmtId/EndToEndId", reference)
end
