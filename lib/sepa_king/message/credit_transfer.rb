# frozen_string_literal: true

module SEPA
  CreditTransferGroup = Data.define(:requested_date, :batch_booking, :service_level, :category_purpose, :instruction_priority)

  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [PAIN_001_001_03, PAIN_001_001_03_CH_02, PAIN_001_001_09, PAIN_001_001_13, PAIN_001_003_03, PAIN_001_002_03]

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      CreditTransferGroup.new(
        requested_date: transaction.requested_date,
        batch_booking: transaction.batch_booking,
        service_level: transaction.service_level,
        category_purpose: transaction.category_purpose,
        instruction_priority: transaction.instruction_priority
      )
    end

    def build_payment_informations(builder, schema_name)
      grouped_transactions.each do |group, transactions|
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group.batch_booking)
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum(format_amount(amount_total(transactions)))
          build_payment_type_information(builder, group)
          build_requested_execution_date(builder, group, schema_name)
          build_debtor_info(builder, schema_name)
          builder.ChrgBr('SLEV') if group.service_level

          transactions.each { |transaction| build_transaction(builder, transaction, schema_name) }
        end
      end
    end

    def build_payment_type_information(builder, group)
      return unless group.service_level || group.category_purpose || group.instruction_priority

      builder.PmtTpInf do
        builder.InstrPrty(group.instruction_priority) if group.instruction_priority
        if group.service_level
          builder.SvcLvl do
            builder.Cd(group.service_level)
          end
        end
        if group.category_purpose
          builder.CtgyPurp do
            builder.Cd(group.category_purpose)
          end
        end
      end
    end

    def build_requested_execution_date(builder, group, schema_name)
      if schema_features(schema_name)[:wrap_date]
        builder.ReqdExctnDt do
          builder.Dt(group.requested_date.iso8601)
        end
      else
        builder.ReqdExctnDt(group.requested_date.iso8601)
      end
    end

    def build_debtor_info(builder, schema_name)
      builder.Dbtr do
        builder.Nm(account.name)
      end
      build_iban_account(builder, :DbtrAcct, account.iban)
      builder.DbtrAgt do
        build_agent_bic(builder, account.bic, schema_name,
                        fallback: !schema_features(schema_name)[:swiss])
      end
    end

    def build_transaction(builder, transaction, schema_name)
      builder.CdtTrfTxInf do
        build_payment_identification(builder, transaction)
        builder.Amt do
          builder.InstdAmt(format_amount(transaction.amount), Ccy: transaction.currency)
        end
        if transaction.bic
          builder.CdtrAgt do
            build_agent_bic(builder, transaction.bic, schema_name, fallback: false)
          end
        end
        builder.Cdtr do
          builder.Nm(transaction.name)
          build_postal_address(builder, transaction.creditor_address) if transaction.creditor_address
        end
        build_iban_account(builder, :CdtrAcct, transaction.iban)
        build_remittance_information(builder, transaction)
      end
    end
  end
end
