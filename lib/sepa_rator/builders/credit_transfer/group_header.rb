# frozen_string_literal: true

module SEPA
  module Builders
    module CreditTransfer
      # Distinct from the DirectDebit variant because pain.001.001.13 adds `InitnSrc`.
      class GroupHeader < Stage
        def call
          builder.GrpHdr do
            builder.MsgId(message.message_identification)
            builder.CreDtTm(message.creation_date_time)
            builder.NbOfTxs(message.transactions.length)
            builder.CtrlSum(XmlBuilder.format_amount(message.amount_total))
            builder.InitgPty do
              builder.Nm(message.account.name)
              message.account.initiating_party_id(builder, profile)
              XmlBuilder.build_contact_details(builder, message.account.contact_details)
            end
            build_initiation_source
          end
        end

        private

        def build_initiation_source
          return unless message.initiation_source_name

          builder.InitnSrc do
            builder.Nm(message.initiation_source_name)
            builder.Prvdr(message.initiation_source_provider) if message.initiation_source_provider
          end
        end
      end
    end
  end
end
