# frozen_string_literal: true

module SEPA
  module XmlBuilder
    private

    def build_postal_address(builder, address)
      builder.PstlAdr do
        POSTAL_ADDRESS_FIELDS.each do |xml_tag, attr|
          value = address.public_send(attr)
          builder.__send__(xml_tag, value) if value
        end
      end
    end

    def build_agent_bic(builder, bic, schema_name, fallback: true)
      builder.FinInstnId do
        if bic
          builder.__send__(schema_features(schema_name)[:bic_tag], bic)
        elsif fallback
          builder.Othr do
            builder.Id('NOTPROVIDED')
          end
        end
      end
    end

    def build_remittance_information(builder, transaction)
      has_structured = transaction.structured_remittance_information || transaction.additional_remittance_information
      return unless transaction.remittance_information || has_structured

      builder.RmtInf do
        if has_structured
          builder.Strd do
            build_creditor_reference_information(builder, transaction) if transaction.structured_remittance_information
            Array(transaction.additional_remittance_information).each { |info| builder.AddtlRmtInf(info) }
          end
        else
          builder.Ustrd(transaction.remittance_information)
        end
      end
    end

    def build_creditor_reference_information(builder, transaction)
      builder.CdtrRefInf do
        ref_type = transaction.structured_remittance_reference_type || 'SCOR'
        builder.Tp do
          builder.CdOrPrtry { builder.Cd(ref_type) }
          builder.Issr(transaction.structured_remittance_issuer) if transaction.structured_remittance_issuer
        end
        builder.Ref(transaction.structured_remittance_information)
      end
    end

    def build_ultimate_party(builder, tag, name)
      return unless name

      builder.__send__(tag) { builder.Nm(name) }
    end

    def build_purpose(builder, purpose_code)
      return unless purpose_code

      builder.Purp { builder.Cd(purpose_code) }
    end

    def build_payment_identification(builder, transaction)
      builder.PmtId do
        builder.InstrId(transaction.instruction) if transaction.instruction && !transaction.instruction.empty?
        builder.EndToEndId(transaction.reference)
        builder.UETR(transaction.uetr) if transaction.uetr && !transaction.uetr.empty?
      end
    end

    def build_iban_account(builder, tag, iban)
      builder.__send__(tag) do
        builder.Id do
          builder.IBAN(iban)
        end
      end
    end

    def format_amount(value)
      format('%.2f', value)
    end
  end
end
