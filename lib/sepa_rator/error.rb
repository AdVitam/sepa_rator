# frozen_string_literal: true

module SEPA
  class Error < RuntimeError; end
  class ValidationError < Error; end

  # Raised when `Message.new(country:, version:)` is called with a version the
  # requested country doesn't support. Carries the list of available versions
  # so callers can recover or surface a helpful message.
  class UnsupportedVersionError < Error
    attr_reader :country, :version, :available_versions

    def initialize(country:, version:, available_versions:)
      @country = country
      @version = version
      @available_versions = available_versions
      super("Version #{version.inspect} not supported for country=#{country.inspect}. " \
            "Available: #{available_versions.inspect}")
    end
  end

  class SchemaValidationError < Error
    attr_reader :validation_errors

    def initialize(message, validation_errors = [])
      @validation_errors = validation_errors
      super(message)
    end
  end
end
