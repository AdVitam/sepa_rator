# frozen_string_literal: true

module SEPA
  class DirectDebit < Message
    self.account_class = CreditorAccount
    self.transaction_class = DirectDebitTransaction
    self.xml_main_tag = 'CstmrDrctDbtInitn'
    self.known_schemas = [PAIN_008_001_02, PAIN_008_001_08, PAIN_008_001_12, PAIN_008_003_02, PAIN_008_002_02]

    validate do |record|
      errors.add(:base, 'CORE, COR1 AND B2B must not be mixed in one message!') if record.transactions.map(&:local_instrument).uniq.size > 1
    end

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        local_instrument: transaction.local_instrument,
        sequence_type: transaction.sequence_type,
        batch_booking: transaction.batch_booking,
        account: transaction.creditor_account || account }
    end

    def build_payment_informations(builder, schema_name)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('DD')
          builder.BtchBookg(group[:batch_booking])
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum('%.2f' % amount_total(transactions))
          builder.PmtTpInf do
            builder.SvcLvl do
              builder.Cd('SEPA')
            end
            builder.LclInstrm do
              builder.Cd(group[:local_instrument])
            end
            builder.SeqTp(group[:sequence_type])
          end
          builder.ReqdColltnDt(group[:requested_date].iso8601)
          builder.Cdtr do
            builder.Nm(group[:account].name)
          end
          builder.CdtrAcct do
            builder.Id do
              builder.IBAN(group[:account].iban)
            end
          end
          builder.CdtrAgt do
            builder.FinInstnId do
              if group[:account].bic
                if [PAIN_008_001_08, PAIN_008_001_12].include?(schema_name)
                  builder.BICFI(group[:account].bic)
                else
                  builder.BIC(group[:account].bic)
                end
              else
                builder.Othr do
                  builder.Id('NOTPROVIDED')
                end
              end
            end
          end
          builder.ChrgBr('SLEV')
          builder.CdtrSchmeId do
            builder.Id do
              builder.PrvtId do
                builder.Othr do
                  builder.Id(group[:account].creditor_identifier)
                  builder.SchmeNm do
                    builder.Prtry('SEPA')
                  end
                end
              end
            end
          end

          transactions.each do |transaction|
            build_transaction(builder, transaction, schema_name)
          end
        end
      end
    end

    def build_amendment_informations(builder, transaction)
      builder.AmdmntInd(true)
      builder.AmdmntInfDtls do
        if transaction.original_debtor_account
          builder.OrgnlDbtrAcct do
            builder.Id do
              builder.IBAN(transaction.original_debtor_account)
            end
          end
        elsif transaction.same_mandate_new_debtor_agent
          builder.OrgnlDbtrAgt do
            builder.FinInstnId do
              builder.Othr do
                builder.Id('SMNDA')
              end
            end
          end
        end
        if transaction.original_creditor_account
          builder.OrgnlCdtrSchmeId do
            builder.Nm(transaction.original_creditor_account.name) if transaction.original_creditor_account.name
            if transaction.original_creditor_account.creditor_identifier
              builder.Id do
                builder.PrvtId do
                  builder.Othr do
                    builder.Id(transaction.original_creditor_account.creditor_identifier)
                    builder.SchmeNm do
                      builder.Prtry('SEPA')
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def build_transaction(builder, transaction, schema_name)
      builder.DrctDbtTxInf do
        builder.PmtId do
          builder.InstrId(transaction.instruction) if transaction.instruction.present?
          builder.EndToEndId(transaction.reference)
        end
        builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        builder.DrctDbtTx do
          builder.MndtRltdInf do
            builder.MndtId(transaction.mandate_id)
            builder.DtOfSgntr(transaction.mandate_date_of_signature.iso8601)
            build_amendment_informations(builder, transaction) if transaction.amendment_informations?
          end
        end
        builder.DbtrAgt do
          builder.FinInstnId do
            if transaction.bic
              if [PAIN_008_001_08, PAIN_008_001_12].include?(schema_name)
                builder.BICFI(transaction.bic)
              else
                builder.BIC(transaction.bic)
              end
            else
              builder.Othr do
                builder.Id('NOTPROVIDED')
              end
            end
          end
        end
        builder.Dbtr do
          builder.Nm(transaction.name)
          build_postal_address(builder, transaction.debtor_address) if transaction.debtor_address
        end
        builder.DbtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        if transaction.remittance_information || transaction.structured_remittance_information
          builder.RmtInf do
            if transaction.structured_remittance_information
              builder.Strd do
                builder.CdtrRefInf do
                  builder.Tp do
                    builder.CdOrPrtry do
                      builder.Cd('SCOR')
                    end
                  end
                  builder.Ref(transaction.structured_remittance_information)
                end
              end
            else
              builder.Ustrd(transaction.remittance_information)
            end
          end
        end
      end
    end
  end
end
