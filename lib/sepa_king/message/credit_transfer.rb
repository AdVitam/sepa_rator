# frozen_string_literal: true

module SEPA
  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [PAIN_001_001_03, PAIN_001_001_03_CH_02, PAIN_001_001_09, PAIN_001_001_13, PAIN_001_003_03, PAIN_001_002_03]

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        batch_booking: transaction.batch_booking,
        service_level: transaction.service_level,
        category_purpose: transaction.category_purpose }
    end

    def build_payment_informations(builder, schema_name)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group[:batch_booking])
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum('%.2f' % amount_total(transactions))
          if group[:service_level] || group[:category_purpose]
            builder.PmtTpInf do
              if group[:service_level]
                builder.SvcLvl do
                  builder.Cd(group[:service_level])
                end
              end
              if group[:category_purpose]
                builder.CtgyPurp do
                  builder.Cd(group[:category_purpose])
                end
              end
            end
          end
          if [PAIN_001_001_09, PAIN_001_001_13].include?(schema_name)
            builder.ReqdExctnDt do
              builder.Dt(group[:requested_date].iso8601)
            end
          else
            builder.ReqdExctnDt(group[:requested_date].iso8601)
          end
          builder.Dbtr do
            builder.Nm(account.name)
          end
          builder.DbtrAcct do
            builder.Id do
              builder.IBAN(account.iban)
            end
          end
          builder.DbtrAgt do
            builder.FinInstnId do
              if account.bic
                if [PAIN_001_001_09, PAIN_001_001_13].include?(schema_name)
                  builder.BICFI(account.bic)
                else
                  builder.BIC(account.bic)
                end
              elsif schema_name != PAIN_001_001_03_CH_02
                builder.Othr do
                  builder.Id('NOTPROVIDED')
                end
              end
            end
          end
          builder.ChrgBr('SLEV') if group[:service_level]

          transactions.each do |transaction|
            build_transaction(builder, transaction, schema_name)
          end
        end
      end
    end

    def build_transaction(builder, transaction, schema_name)
      builder.CdtTrfTxInf do
        builder.PmtId do
          builder.InstrId(transaction.instruction) if transaction.instruction.present?
          builder.EndToEndId(transaction.reference)
        end
        builder.Amt do
          builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        end
        if transaction.bic
          builder.CdtrAgt do
            builder.FinInstnId do
              if [PAIN_001_001_09, PAIN_001_001_13].include?(schema_name)
                builder.BICFI(transaction.bic)
              else
                builder.BIC(transaction.bic)
              end
            end
          end
        end
        builder.Cdtr do
          builder.Nm(transaction.name)
          build_postal_address(builder, transaction.creditor_address) if transaction.creditor_address
        end
        builder.CdtrAcct do
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
