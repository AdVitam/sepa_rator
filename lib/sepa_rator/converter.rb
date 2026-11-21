# frozen_string_literal: true

module SEPA
  module Converter
    KINDS = %i[text identifier code decimal].freeze

    def convert(*attributes, **options)
      to = options.fetch(:to)
      raise ArgumentError, "Converter '#{to}' does not exist!" unless KINDS.include?(to)

      include InstanceMethods

      converted_attributes[to]&.concat(attributes)
      attributes.each do |attribute|
        define_method "#{attribute}=" do |value|
          instance_variable_set("@#{attribute}", to == :decimal ? convert_decimal(value) : Charset.sanitize(value))
        end
      end
    end

    def text_attributes
      inherited_attributes(:text)
    end

    def identifier_attributes
      inherited_attributes(:identifier)
    end

    private

    def converted_attributes
      @converted_attributes ||= { text: [], identifier: [] }
    end

    def inherited_attributes(kind)
      parent = superclass.respond_to?(:text_attributes) ? superclass.public_send(:"#{kind}_attributes") : []
      (parent + converted_attributes[kind]).freeze
    end

    module InstanceMethods
      def convert_decimal(value)
        return unless value

        value = BigDecimal(value.to_s, exception: false)

        return unless value&.finite? && value.positive?

        value.round(2)
      end
    end
  end
end
