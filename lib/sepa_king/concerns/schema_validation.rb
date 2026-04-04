# frozen_string_literal: true

module SEPA
  module SchemaValidation
    extend ActiveSupport::Concern

    SCHEMA_DIR = File.expand_path('../../schema', __dir__).freeze
    SCHEMA_CACHE_MUTEX = Mutex.new

    class_methods do
      def schema_cache
        @schema_cache ||= {}
      end
    end

    private

    def validate_final_document!(document, schema_name)
      xsd = self.class.schema_cache[schema_name] || begin
        schema = Nokogiri::XML::Schema(File.read("#{SCHEMA_DIR}/#{schema_name}.xsd"))
        SCHEMA_CACHE_MUTEX.synchronize { self.class.schema_cache[schema_name] ||= schema }
      end

      errors = xsd.validate(document).map(&:message)
      raise SEPA::SchemaValidationError, "Incompatible with schema #{schema_name}: #{errors.join(', ')}" if errors.any?
    end
  end
end
