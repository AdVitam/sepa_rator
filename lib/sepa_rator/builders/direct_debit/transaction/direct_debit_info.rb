# frozen_string_literal: true

module SEPA
  module Builders
    module DirectDebit
      module Transaction
        class DirectDebitInfo < Stage
          def call
            builder.DrctDbtTx do
              builder.MndtRltdInf do
                builder.MndtId(transaction.mandate_id)
                builder.DtOfSgntr(transaction.mandate_date_of_signature.iso8601)
                build_amendment_informations if transaction.amendment_informations?
              end
            end
          end

          private

          def build_amendment_informations
            builder.AmdmntInd(true)
            builder.AmdmntInfDtls do
              builder.OrgnlMndtId(transaction.original_mandate_id) if transaction.original_mandate_id
              build_original_debtor
              build_original_creditor_scheme if transaction.original_creditor_account
            end
          end

          def build_original_debtor
            if transaction.original_debtor_account
              XmlBuilder.build_iban_account(builder, :OrgnlDbtrAcct, transaction.original_debtor_account)
            elsif transaction.same_mandate_new_debtor_agent
              builder.OrgnlDbtrAgt do
                builder.FinInstnId do
                  builder.Othr { builder.Id('SMNDA') }
                end
              end
            end
          end

          def build_original_creditor_scheme
            original = transaction.original_creditor_account
            builder.OrgnlCdtrSchmeId do
              builder.Nm(original.name) if original.name
              next unless original.creditor_identifier

              builder.Id do
                builder.PrvtId do
                  builder.Othr do
                    builder.Id(original.creditor_identifier)
                    builder.SchmeNm { builder.Prtry('SEPA') }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
