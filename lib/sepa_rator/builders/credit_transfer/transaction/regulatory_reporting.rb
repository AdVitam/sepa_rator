# frozen_string_literal: true

module SEPA
  module Builders
    module CreditTransfer
      module Transaction
        # RgltryRptg — RegulatoryReporting3 (v3) or RegulatoryReporting10 (v10).
        # Version is driven by `profile.features.regulatory_reporting_version`.
        class RegulatoryReporting < Stage
          def call
            return unless transaction.regulatory_reportings

            version = profile.features.regulatory_reporting_version

            transaction.regulatory_reportings.each do |reporting|
              builder.RgltryRptg do
                builder.DbtCdtRptgInd(reporting[:indicator]) if reporting[:indicator]
                build_authority(reporting[:authority])
                reporting[:details]&.each do |detail|
                  builder.Dtls { build_detail(detail, version) }
                end
              end
            end
          end

          private

          def build_authority(authority)
            return unless authority

            builder.Authrty do
              builder.Nm(authority[:name]) if authority[:name]
              builder.Ctry(authority[:country]) if authority[:country]
            end
          end

          def build_detail(detail, version)
            # XSD sequence: Tp → Dt → Ctry → Cd/RptgCd → Amt → Inf
            build_detail_type(detail, version)
            builder.Dt(detail[:date].iso8601) if detail[:date]
            builder.Ctry(detail[:country]) if detail[:country]
            builder.__send__(code_tag_for(version), detail[:code]) if detail[:code]
            build_detail_amount(detail[:amount])
            Array(detail[:information]).each { |inf| builder.Inf(inf) }
          end

          def code_tag_for(version)
            case version
            when :v10 then :RptgCd
            when :v3 then :Cd
            else raise ArgumentError, "Unknown regulatory_reporting_version: #{version.inspect}"
            end
          end

          def build_detail_type(detail, version)
            return unless detail[:type] || detail[:type_proprietary]

            case version
            when :v10
              builder.Tp do
                detail[:type_proprietary] ? builder.Prtry(detail[:type_proprietary]) : builder.Cd(detail[:type])
              end
            when :v3
              # `type_proprietary` is rejected upstream by
              # CreditTransferTransaction#regulatory_reportings_compatible?.
              builder.Tp(detail[:type]) if detail[:type]
            else
              raise ArgumentError, "Unknown regulatory_reporting_version: #{version.inspect}"
            end
          end

          # ActiveOrHistoricCurrencyAndAmount allows up to 5 fractional digits
          # (unlike payment amounts at 2).
          def build_detail_amount(amount)
            return unless amount

            decimal = BigDecimal(amount[:value].to_s).truncate(5)
            frac_digits = [decimal.to_s('F').split('.').last&.length.to_i, 2].max
            value = format("%.#{frac_digits}f", decimal)
            builder.Amt(value, Ccy: amount[:currency])
          end
        end
      end
    end
  end
end
