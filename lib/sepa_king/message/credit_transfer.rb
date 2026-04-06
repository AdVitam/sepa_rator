# frozen_string_literal: true

module SEPA
  CreditTransferGroup = Data.define(:requested_date, :batch_booking, :service_level, :category_purpose,
                                    :instruction_priority, :charge_bearer, :debtor_agent_instruction)

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
        instruction_priority: transaction.instruction_priority,
        charge_bearer: transaction.charge_bearer || (transaction.service_level ? 'SLEV' : nil),
        debtor_agent_instruction: transaction.debtor_agent_instruction
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
          build_pmtinf_debtor_agent_instruction(builder, group, schema_name)
          builder.ChrgBr(group.charge_bearer) if group.charge_bearer

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
        build_postal_address(builder, account.address) if account.address
      end
      build_iban_account(builder, :DbtrAcct, account.iban)
      builder.DbtrAgt do
        build_agent_bic(builder, account.bic, schema_name,
                        fallback: !schema_features(schema_name)[:swiss])
      end
    end

    # InstrForDbtrAgt at PmtInf level (v09/v13 only, Max140Text)
    def build_pmtinf_debtor_agent_instruction(builder, group, schema_name)
      return unless CreditTransferTransaction::PMTINF_INSTR_SCHEMAS.include?(schema_name) && group.debtor_agent_instruction

      builder.InstrForDbtrAgt(group.debtor_agent_instruction)
    end

    # XSD element order: PmtId > Amt > [MndtRltdInf v13] > [UltmtDbtr] > [CdtrAgt] > [Cdtr] >
    #   [CdtrAcct] > [UltmtCdtr] > [InstrForCdtrAgt] > [InstrForDbtrAgt] > [Purp] > [RgltryRptg] > [RmtInf]
    def build_transaction(builder, transaction, schema_name)
      builder.CdtTrfTxInf do
        build_payment_identification(builder, transaction)
        builder.Amt do
          builder.InstdAmt(format_amount(transaction.amount), Ccy: transaction.currency)
        end
        build_credit_transfer_mandate(builder, transaction, schema_name)
        build_ultimate_party(builder, :UltmtDbtr, transaction.ultimate_debtor_name)
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
        build_ultimate_party(builder, :UltmtCdtr, transaction.ultimate_creditor_name)
        build_instructions_for_creditor_agent(builder, transaction)
        build_txn_instruction_for_debtor_agent(builder, transaction, schema_name)
        build_purpose(builder, transaction.purpose_code)
        build_regulatory_reportings(builder, transaction, schema_name)
        build_remittance_information(builder, transaction)
      end
    end

    # MndtRltdInf — CreditTransferMandateData1 (v13 only)
    def build_credit_transfer_mandate(builder, transaction, schema_name)
      return unless CreditTransferTransaction::MNDT_RLTD_INF_SCHEMAS.include?(schema_name) && transaction.credit_transfer_mandate?

      builder.MndtRltdInf do
        builder.MndtId(transaction.credit_transfer_mandate_id) if transaction.credit_transfer_mandate_id
        builder.DtOfSgntr(transaction.credit_transfer_mandate_date_of_signature.iso8601) if transaction.credit_transfer_mandate_date_of_signature
        builder.Frqcy { builder.Tp(transaction.credit_transfer_mandate_frequency) } if transaction.credit_transfer_mandate_frequency
      end
    end

    # InstrForCdtrAgt — unbounded, same XML structure for all versions
    def build_instructions_for_creditor_agent(builder, transaction)
      return unless transaction.instructions_for_creditor_agent

      transaction.instructions_for_creditor_agent.each do |instr|
        builder.InstrForCdtrAgt do
          builder.Cd(instr[:code]) if instr[:code]
          builder.InstrInf(instr[:instruction_info]) if instr[:instruction_info]
        end
      end
    end

    # InstrForDbtrAgt at transaction level — text (v03/v09) or structured (v13)
    def build_txn_instruction_for_debtor_agent(builder, transaction, schema_name)
      return unless transaction.instruction_for_debtor_agent || transaction.instruction_for_debtor_agent_code

      if schema_features(schema_name)[:instr_for_dbtr_agt_format] == :structured
        builder.InstrForDbtrAgt do
          builder.Cd(transaction.instruction_for_debtor_agent_code) if transaction.instruction_for_debtor_agent_code
          builder.InstrInf(transaction.instruction_for_debtor_agent) if transaction.instruction_for_debtor_agent
        end
      elsif transaction.instruction_for_debtor_agent
        builder.InstrForDbtrAgt(transaction.instruction_for_debtor_agent)
      end
    end

    # RgltryRptg — RegulatoryReporting3 (v03/v09) or RegulatoryReporting10 (v13)
    def build_regulatory_reportings(builder, transaction, schema_name)
      return unless transaction.regulatory_reportings

      transaction.regulatory_reportings.each do |reporting|
        builder.RgltryRptg do
          builder.DbtCdtRptgInd(reporting[:indicator]) if reporting[:indicator]
          reporting[:details]&.each do |detail|
            builder.Dtls do
              code_tag = schema_features(schema_name)[:regulatory_reporting_version] == :v10 ? :RptgCd : :Cd
              builder.__send__(code_tag, detail[:code]) if detail[:code]
              Array(detail[:information]).each { |inf| builder.Inf(inf) }
            end
          end
        end
      end
    end
  end
end
