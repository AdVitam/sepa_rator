# frozen_string_literal: true

module SEPA
  module Builders
    module CreditTransfer
      class PaymentInformation < Stage
        def call
          message.grouped_transactions.each do |group, transactions|
            builder.PmtInf do
              emit_header(group, transactions)
              emit_payment_type_information(group)
              emit_requested_execution_date(group)
              emit_debtor_info
              emit_pmtinf_debtor_agent_instruction(group)
              builder.ChrgBr(group.charge_bearer) if group.charge_bearer

              transactions.each { |transaction| emit_transaction(transaction, group) }
            end
          end
        end

        private

        def emit_header(group, transactions)
          builder.PmtInfId(message.payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group.batch_booking)
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum(XmlBuilder.format_amount(message.amount_total(transactions)))
        end

        def emit_payment_type_information(group)
          return unless group.service_level || group.category_purpose || group.instruction_priority

          builder.PmtTpInf do
            builder.InstrPrty(group.instruction_priority) if group.instruction_priority
            builder.SvcLvl { builder.Cd(group.service_level) } if group.service_level
            builder.CtgyPurp { builder.Cd(group.category_purpose) } if group.category_purpose
          end
        end

        def emit_requested_execution_date(group)
          if profile.features.wrap_date
            builder.ReqdExctnDt { builder.Dt(group.requested_date.iso8601) }
          else
            builder.ReqdExctnDt(group.requested_date.iso8601)
          end
        end

        def emit_debtor_info
          account = message.account
          builder.Dbtr do
            builder.Nm(account.name)
            XmlBuilder.build_postal_address(builder, account.address)
            XmlBuilder.build_contact_details(builder, account.contact_details)
          end
          XmlBuilder.build_iban_account(builder, :DbtrAcct, account.iban)
          builder.DbtrAgt do
            XmlBuilder.build_agent_bic(builder, account.bic, profile, fallback: true, lei: account.agent_lei)
          end
        end

        def emit_pmtinf_debtor_agent_instruction(group)
          return unless group.debtor_agent_instruction

          builder.InstrForDbtrAgt(group.debtor_agent_instruction)
        end

        def emit_transaction(transaction, group)
          txn_context = Context.new(
            message: message,
            profile: profile,
            builder: builder,
            transaction: transaction,
            group: group
          )
          builder.CdtTrfTxInf do
            profile.transaction_stages.each { |stage| stage.call(txn_context) }
          end
        end
      end
    end
  end
end
