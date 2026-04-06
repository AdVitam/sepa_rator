# frozen_string_literal: true

module SEPA
  module SchemaValidation
    SCHEMA_DIR = File.expand_path('../../schema', __dir__).freeze
    SCHEMA_CACHE_MUTEX = Mutex.new

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def schema_cache
        @schema_cache ||= {}
      end
    end

    private

    def validate_final_document!(document, schema_name)
      raise ArgumentError, "Unknown schema: #{schema_name}" unless SCHEMA_FEATURES.key?(schema_name)

      xsd = self.class.schema_cache[schema_name]
      unless xsd
        SCHEMA_CACHE_MUTEX.synchronize do
          xsd = self.class.schema_cache[schema_name] ||=
            Nokogiri::XML::Schema(File.read("#{SCHEMA_DIR}/#{schema_name}.xsd"))
        end
      end

      validation_errors = xsd.validate(document)
      return if validation_errors.empty?

      sanitized = validation_errors.map { |e| e.message.gsub(/'[^']{20,}'/, "'[REDACTED]'") }
      raise SEPA::SchemaValidationError.new(
        "Incompatible with schema #{schema_name}: #{sanitized.join(', ')}",
        validation_errors.map(&:message)
      )
    end
  end
end
