# frozen_string_literal: true

module SEPA
  module RegulatoryReportingCharset
    private

    def charset_regulatory_reportings(reportings, charset)
      return reportings unless reportings.is_a?(Array)

      reportings.map do |reporting|
        next reporting unless reporting.is_a?(Hash)

        reporting.merge(
          authority: charset_authority(reporting[:authority], charset),
          details: charset_details(reporting[:details], charset)
        ).compact
      end
    end

    def charset_authority(authority, charset)
      return authority unless authority.is_a?(Hash) && authority[:name]

      authority.merge(name: charset.text(authority[:name]))
    end

    def charset_details(details, charset)
      return details unless details.is_a?(Array)

      details.map do |detail|
        next detail unless detail.is_a?(Hash)

        detail.merge(
          type: charset.text(detail[:type]),
          type_proprietary: charset.text(detail[:type_proprietary]),
          information: charset_information(detail[:information], charset)
        ).compact
      end
    end

    def charset_information(information, charset)
      return charset.text(information) unless information.is_a?(Array)

      information.map { |entry| charset.text(entry) }
    end
  end
end
