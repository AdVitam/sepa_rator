# frozen_string_literal: true

module SEPA
  module Builders
    module CreditTransfer
      module Transaction
        class InstructionsForCreditorAgent < Stage
          def call
            return unless transaction.instructions_for_creditor_agent

            transaction.instructions_for_creditor_agent.each do |instr|
              builder.InstrForCdtrAgt do
                builder.Cd(instr[:code]) if instr[:code]
                builder.InstrInf(instr[:instruction_info]) if instr[:instruction_info]
              end
            end
          end
        end
      end
    end
  end
end
