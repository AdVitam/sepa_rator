# frozen_string_literal: true

module SEPA
  class IBANValidator < ActiveModel::Validator
    # IBAN2007Identifier (taken from schema)
    REGEX = /\A[A-Z]{2,2}[0-9]{2,2}[a-zA-Z0-9]{1,30}\z/

    def validate(record)
      field_name = options[:field_name] || :iban
      value = record.public_send(field_name).to_s

      return if IBANTools::IBAN.valid?(value) && value.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  class BICValidator < ActiveModel::Validator
    # AnyBICIdentifier (pain.001.001.03 and earlier schemas)
    V03_REGEX = /\A[A-Z]{6,6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3,3}){0,1}\z/
    # BICFIDec2014Identifier (pain.001.001.09 / .13 and pain.008.001.08 / .12)
    V09_REGEX = /\A[A-Z0-9]{4,4}[A-Z]{2,2}[A-Z0-9]{2,2}([A-Z0-9]{3,3}){0,1}\z/

    REGEX = V03_REGEX

    def validate(record)
      field_name = options[:field_name] || :bic
      value = record.public_send(field_name)

      return unless value
      return if value.to_s.match?(V03_REGEX) || value.to_s.match?(V09_REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  class CreditorIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A
      [a-zA-Z]{2}                 # ISO country code
      [0-9]{2}                    # Check digits
      [A-Za-z0-9]{3}              # Creditor business code
      [A-Za-z0-9+?/:().,'-]{1,28} # National identifier
    \z}x

    def validate(record)
      field_name = options[:field_name] || :creditor_identifier
      value = record.public_send(field_name)

      return if valid?(value)

      record.errors.add(field_name, :invalid, message: options[:message])
    end

    def valid?(creditor_identifier)
      return false unless creditor_identifier.to_s.match?(REGEX)

      # In Germany, the identifier has to be exactly 18 chars long
      return false if creditor_identifier[0..1].match?(/DE/i) && creditor_identifier.length != 18

      # Verify mod-97 check digit (ISO 7064)
      # Structure: CC DD BBB NNNN...
      # CC = country code, DD = check digits, BBB = business code (skipped), N = national id
      # Strip non-alphanumeric chars from national id before check (the spec allows +?/:().,'-
      # but they are ignored for mod-97 computation)
      check_base = creditor_identifier[0..3] + creditor_identifier[7..].gsub(/[^A-Za-z0-9]/, '')
      rearranged = check_base[4..] + check_base[0..3]
      numeric = rearranged.gsub(/[A-Z]/i) { |c| c.upcase.ord - 55 }
      numeric.to_i % 97 == 1
    end
  end

  class MandateIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A[A-Za-z0-9 +?/:().,'-]{1,35}\z}

    def validate(record)
      field_name = options[:field_name] || :mandate_id
      value = record.public_send(field_name)

      return if value.to_s.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end
end
