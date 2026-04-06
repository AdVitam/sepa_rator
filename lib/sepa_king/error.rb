# frozen_string_literal: true

module SEPA
  class Error < RuntimeError; end
  class ValidationError < Error; end

  class SchemaValidationError < Error
    attr_reader :validation_errors

    def initialize(message, validation_errors = [])
      @validation_errors = validation_errors
      super(message)
    end
  end
end
