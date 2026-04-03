# frozen_string_literal: true

module SEPA
  class Account
    include ActiveModel::Validations
    extend Converter

    attr_accessor :name, :iban, :bic

    convert :name, to: :text

    validates_length_of :name, within: 1..70
    validates_with BICValidator, IBANValidator, message: 'is invalid'

    def initialize(attributes = {})
      attributes.each do |name, value|
        setter = "#{name}="
        raise ArgumentError, "Unknown attribute: #{name}" unless respond_to?(setter)

        public_send(setter, value)
      end
    end

    def initiating_party_id(builder); end
  end
end
