# frozen_string_literal: true

module SEPA
  module Builders
    module DirectDebit
      class GroupHeader < Stage
        def call
          builder.GrpHdr do
            builder.MsgId(message.message_identification)
            builder.CreDtTm(message.creation_date_time)
            builder.NbOfTxs(message.transactions.length)
            builder.CtrlSum(XmlBuilder.format_amount(message.amount_total))
            XmlBuilder.build_initiating_party(builder, message.account, profile)
          end
        end
      end
    end
  end
end
