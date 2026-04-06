# frozen_string_literal: true

module SEPA
  class Transaction
    include ActiveModel::Validations
    include AttributeInitializer
    extend Converter

    # DSL to declare and validate address fields on subclasses (ISP-compliant).
    # Each subclass declares only the address it actually uses.
    def self.validates_address(*fields)
      fields.each do |field|
        attr_accessor field

        validate do |t|
          address = t.public_send(field)
          next unless address && !address.valid?

          address.errors.each { |error| t.errors.add(field, error.full_message) }
        end
      end
    end

    # Convention SEPA: 1999-01-01 signifies "execute as soon as possible" (ASAP).
    # When no specific date is requested, this sentinel value tells the bank
    # to process the payment at the earliest opportunity.
    DEFAULT_REQUESTED_DATE = Date.new(1999, 1, 1).freeze

    attr_accessor :name,
                  :iban,
                  :bic,
                  :amount,
                  :instruction,
                  :reference,
                  :remittance_information,
                  :requested_date,
                  :batch_booking,
                  :currency,
                  :structured_remittance_information,
                  :structured_remittance_reference_type,
                  :structured_remittance_issuer,
                  :additional_remittance_information,
                  :uetr,
                  :instruction_priority,
                  :purpose_code,
                  :ultimate_debtor_name,
                  :ultimate_creditor_name

    convert :name, :instruction, :reference, :remittance_information, :structured_remittance_information,
            :structured_remittance_reference_type, :structured_remittance_issuer,
            :purpose_code, :ultimate_debtor_name, :ultimate_creditor_name, to: :text
    convert :amount, to: :decimal

    validates_length_of :name, within: 1..70
    validates_format_of :currency, with: /\A[A-Z]{3}\z/
    validates_inclusion_of :instruction_priority, in: %w[HIGH NORM], allow_nil: true
    validates_length_of :instruction, within: 1..35, allow_nil: true
    validates_length_of :reference, within: 1..35, allow_nil: true
    validates_length_of :remittance_information, within: 1..140, allow_nil: true
    validates_length_of :structured_remittance_information, within: 1..35, allow_nil: true
    validates_length_of :structured_remittance_reference_type, within: 1..4, allow_nil: true
    validates_length_of :structured_remittance_issuer, within: 1..35, allow_nil: true
    validates_length_of :purpose_code, within: 1..4, allow_nil: true
    validates_length_of :ultimate_debtor_name, within: 1..70, allow_nil: true
    validates_length_of :ultimate_creditor_name, within: 1..70, allow_nil: true
    validates_numericality_of :amount, greater_than: 0, less_than_or_equal_to: 999_999_999.99
    validates_presence_of :requested_date

    UETR_REGEX = /\A[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}\z/
    validates_format_of :uetr, with: UETR_REGEX, allow_nil: true
    validates_inclusion_of :batch_booking, in: [true, false]
    validates_with BICValidator, IBANValidator, message: 'is invalid'

    validate do |t|
      if t.remittance_information && (t.structured_remittance_information || t.additional_remittance_information)
        t.errors.add(:base, 'remittance_information and structured remittance fields are mutually exclusive')
      end

      next unless t.additional_remittance_information

      unless t.additional_remittance_information.is_a?(Array) && t.additional_remittance_information.length <= 3
        t.errors.add(:additional_remittance_information, 'must be an Array with at most 3 items')
        next
      end

      t.additional_remittance_information.each_with_index do |info, i|
        t.errors.add(:additional_remittance_information, "entry #{i} exceeds 140 characters") if info.to_s.length > 140
      end
    end

    def initialize(attributes = {})
      super
      self.requested_date ||= DEFAULT_REQUESTED_DATE
      self.reference ||= 'NOTPROVIDED'
      self.batch_booking = true if batch_booking.nil?
      self.currency ||= 'EUR'
    end

    protected

    # NOTE: This validation only checks that the date is not in the past.
    # It does NOT validate against the TARGET2 business calendar (weekends, holidays).
    # Callers should ensure the requested date falls on a TARGET2 business day.
    def validate_requested_date_after(min_requested_date)
      return unless requested_date.is_a?(Date)

      return unless requested_date != DEFAULT_REQUESTED_DATE && requested_date < min_requested_date

      errors.add(:requested_date, "must be greater or equal to #{min_requested_date}, or nil")
    end
  end
end
