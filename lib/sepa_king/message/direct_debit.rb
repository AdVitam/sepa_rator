# frozen_string_literal: true

module SEPA
  DirectDebitGroup = Data.define(:requested_date, :local_instrument, :sequence_type, :batch_booking, :account, :instruction_priority)

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
      DirectDebitGroup.new(
        requested_date: transaction.requested_date,
        local_instrument: transaction.local_instrument,
        sequence_type: transaction.sequence_type,
        batch_booking: transaction.batch_booking,
        account: transaction.creditor_account || account,
        instruction_priority: transaction.instruction_priority
      )
    end

    def build_payment_informations(builder, schema_name)
      grouped_transactions.each do |group, transactions|
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('DD')
          builder.BtchBookg(group.batch_booking)
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum(format_amount(amount_total(transactions)))
          build_payment_type_information(builder, group)
          build_creditor_info(builder, group, schema_name)
          build_creditor_scheme_identification(builder, group)

          transactions.each { |transaction| build_transaction(builder, transaction, schema_name) }
        end
      end
    end

    def build_payment_type_information(builder, group)
      builder.PmtTpInf do
        builder.InstrPrty(group.instruction_priority) if group.instruction_priority
        builder.SvcLvl do
          builder.Cd('SEPA')
        end
        builder.LclInstrm do
          builder.Cd(group.local_instrument)
        end
        builder.SeqTp(group.sequence_type)
      end
    end

    def build_creditor_info(builder, group, schema_name)
      builder.ReqdColltnDt(group.requested_date.iso8601)
      builder.Cdtr do
        builder.Nm(group.account.name)
      end
      build_iban_account(builder, :CdtrAcct, group.account.iban)
      builder.CdtrAgt do
        build_agent_bic(builder, group.account.bic, schema_name)
      end
      builder.ChrgBr('SLEV')
    end

    def build_creditor_scheme_identification(builder, group)
      builder.CdtrSchmeId do
        builder.Id do
          builder.PrvtId do
            builder.Othr do
              builder.Id(group.account.creditor_identifier)
              builder.SchmeNm do
                builder.Prtry('SEPA')
              end
            end
          end
        end
      end
    end

    def build_amendment_informations(builder, transaction)
      builder.AmdmntInd(true)
      builder.AmdmntInfDtls do
        if transaction.original_debtor_account
          build_iban_account(builder, :OrgnlDbtrAcct, transaction.original_debtor_account)
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
        build_payment_identification(builder, transaction)
        builder.InstdAmt(format_amount(transaction.amount), Ccy: transaction.currency)
        builder.DrctDbtTx do
          builder.MndtRltdInf do
            builder.MndtId(transaction.mandate_id)
            builder.DtOfSgntr(transaction.mandate_date_of_signature.iso8601)
            build_amendment_informations(builder, transaction) if transaction.amendment_informations?
          end
        end
        builder.DbtrAgt do
          build_agent_bic(builder, transaction.bic, schema_name)
        end
        builder.Dbtr do
          builder.Nm(transaction.name)
          build_postal_address(builder, transaction.debtor_address) if transaction.debtor_address
        end
        build_iban_account(builder, :DbtrAcct, transaction.iban)
        build_remittance_information(builder, transaction)
      end
    end
  end
end
