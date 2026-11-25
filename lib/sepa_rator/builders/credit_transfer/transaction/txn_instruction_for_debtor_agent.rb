# frozen_string_literal: true

module SEPA
  module Builders
    module CreditTransfer
      module Transaction
        # Transaction-level InstrForDbtrAgt. Serialized as plain text in older
        # schemas and as a structured {Cd, InstrInf} block in pain.001.001.13.
        class TxnInstructionForDebtorAgent < Stage
          def call
            return unless transaction.instruction_for_debtor_agent || transaction.instruction_for_debtor_agent_code

            case profile.features.instr_for_dbtr_agt_format
            when :structured
              builder.InstrForDbtrAgt do
                builder.Cd(transaction.instruction_for_debtor_agent_code) if transaction.instruction_for_debtor_agent_code
                builder.InstrInf(transaction.instruction_for_debtor_agent) if transaction.instruction_for_debtor_agent
              end
            when :text
              # `instruction_for_debtor_agent_code` is rejected upstream by
              # `CreditTransferTransaction#instr_for_dbtr_agt_code_compatible?`
              # when the profile uses :text format, so a bare code without
              # text is unreachable here.
              builder.InstrForDbtrAgt(transaction.instruction_for_debtor_agent) if transaction.instruction_for_debtor_agent
            else
              raise ArgumentError,
                    "Unknown instr_for_dbtr_agt_format: #{profile.features.instr_for_dbtr_agt_format.inspect}"
            end
          end
        end
      end
    end
  end
end
