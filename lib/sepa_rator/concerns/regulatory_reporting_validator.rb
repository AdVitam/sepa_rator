# frozen_string_literal: true

module SEPA
  # Extracted validation logic for regulatory reporting fields on CreditTransferTransaction.
  # Keeps the transaction class under the Metrics/ClassLength limit.
  module RegulatoryReportingValidator
    REGULATORY_INDICATORS = %w[CRED DEBT BOTH].freeze
    COUNTRY_CODE_REGEX = /\A[A-Z]{2}\z/
    CURRENCY_CODE_REGEX = /\A[A-Z]{3}\z/

    private

    def validate_regulatory_reportings
      return unless regulatory_reportings

      unless regulatory_reportings.is_a?(Array)
        errors.add(:regulatory_reportings, 'must be an Array')
        return
      end

      errors.add(:regulatory_reportings, 'maximum 10 entries') if regulatory_reportings.length > 10

      regulatory_reportings.each_with_index do |reporting, i|
        unless reporting.is_a?(Hash)
          errors.add(:regulatory_reportings, "entry #{i} must be a Hash")
          next
        end
        if reporting[:indicator] && !REGULATORY_INDICATORS.include?(reporting[:indicator])
          errors.add(:regulatory_reportings, "entry #{i} indicator must be one of #{REGULATORY_INDICATORS.join(', ')}")
        end
        validate_regulatory_reporting_details(reporting, i)
      end
    end

    def validate_regulatory_reporting_details(reporting, entry_index)
      validate_regulatory_authority(reporting[:authority], entry_index)
      return unless reporting[:details]

      unless reporting[:details].is_a?(Array)
        errors.add(:regulatory_reportings, "entry #{entry_index} details must be an Array")
        return
      end

      reporting[:details].each_with_index do |detail, j|
        unless detail.is_a?(Hash)
          errors.add(:regulatory_reportings, "entry #{entry_index} detail #{j} must be a Hash")
          next
        end
        validate_regulatory_detail(detail, entry_index, j)
      end
    end

    def validate_regulatory_authority(authority, entry_index)
      return unless authority

      unless authority.is_a?(Hash)
        errors.add(:regulatory_reportings, "entry #{entry_index} authority must be a Hash")
        return
      end
      validate_authority_name(authority[:name], entry_index)
      validate_country_code(authority[:country], "entry #{entry_index} authority country")
    end

    def validate_authority_name(name, entry_index)
      return unless name && name.to_s.length > 140

      errors.add(:regulatory_reportings, "entry #{entry_index} authority name exceeds 140 characters")
    end

    def validate_regulatory_detail(detail, entry_idx, detail_idx)
      prefix = "entry #{entry_idx} detail #{detail_idx}"
      validate_regulatory_detail_text_fields(detail, prefix)
      validate_regulatory_detail_typed_fields(detail, prefix)
      validate_regulatory_detail_amount(detail[:amount], prefix)
      Array(detail[:information]).each_with_index do |inf, idx|
        errors.add(:regulatory_reportings, "#{prefix} information #{idx} exceeds 35 characters") if inf.to_s.length > 35
      end
    end

    def validate_regulatory_detail_text_fields(detail, prefix)
      errors.add(:regulatory_reportings, "#{prefix} code too long") if detail[:code] && detail[:code].to_s.length > 10
      errors.add(:regulatory_reportings, "#{prefix} type too long") if detail[:type] && detail[:type].to_s.length > 35
      errors.add(:regulatory_reportings, "#{prefix} type_proprietary too long") if detail[:type_proprietary] && detail[:type_proprietary].to_s.length > 35
    end

    def validate_regulatory_detail_typed_fields(detail, prefix)
      errors.add(:regulatory_reportings, "#{prefix} type and type_proprietary are mutually exclusive") if detail[:type] && detail[:type_proprietary]
      errors.add(:regulatory_reportings, "#{prefix} date must be a Date") if detail[:date] && !detail[:date].is_a?(Date)
      validate_country_code(detail[:country], "#{prefix} country")
    end

    def validate_regulatory_detail_amount(amount, prefix)
      return unless amount

      unless amount.is_a?(Hash) && amount[:value] && amount[:currency]
        errors.add(:regulatory_reportings, "#{prefix} amount must have :value and :currency")
        return
      end
      unless amount[:value].is_a?(Integer) || amount[:value].is_a?(Float) || amount[:value].is_a?(BigDecimal)
        errors.add(:regulatory_reportings, "#{prefix} amount value must be numeric")
      end
      errors.add(:regulatory_reportings, "#{prefix} amount currency invalid") unless amount[:currency].to_s.match?(CURRENCY_CODE_REGEX)
    end

    def validate_country_code(value, field_label)
      return unless value && !value.to_s.match?(COUNTRY_CODE_REGEX)

      errors.add(:regulatory_reportings, "#{field_label} must be a 2-letter code")
    end
  end
end
