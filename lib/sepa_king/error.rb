# frozen_string_literal: true

module SEPA
  class Error < RuntimeError; end
  class ValidationError < Error; end
  class SchemaValidationError < Error; end
end
