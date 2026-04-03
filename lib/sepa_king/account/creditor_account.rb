# frozen_string_literal: true

module SEPA
  class CreditorAccount < Account
    attr_accessor :creditor_identifier

    validates_with CreditorIdentifierValidator, message: 'is invalid'
  end
end
