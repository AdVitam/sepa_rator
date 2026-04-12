# frozen_string_literal: true

require 'active_support/concern'

module SEPA
  module SchemaValidation
    extend ActiveSupport::Concern

    SCHEMA_DIR = File.expand_path('../../schema', __dir__).freeze
    # Eagerly-initialised module-level XSD cache, shared across every
    # class that includes SchemaValidation. Keyed by `profile.xsd_path`
    # so two profiles that share an ISO schema name but point to
    # different XSD files (e.g. the ISO baseline and the DK GBIC5
    # variant) never share a cache entry.
    SCHEMA_CACHE = {} # rubocop:disable Style/MutableConstant -- intentional cache
    SCHEMA_CACHE_MUTEX = Mutex.new

    private

    def validate_final_document!(document, profile)
      xsd = load_xsd(profile)

      validation_errors = xsd.validate(document)
      return if validation_errors.empty?

      sanitized = validation_errors.map { |e| e.message.gsub(/'[^']{20,}'/, "'[REDACTED]'") }
      raise SEPA::SchemaValidationError.new(
        "Incompatible with profile #{profile.id}: #{sanitized.join(', ')}",
        validation_errors.map(&:message)
      )
    end

    def load_xsd(profile)
      cache_key = profile.xsd_path
      cached = SCHEMA_CACHE[cache_key]
      return cached if cached

      SCHEMA_CACHE_MUTEX.synchronize do
        SCHEMA_CACHE[cache_key] ||= read_xsd(profile)
      end
    end

    def read_xsd(profile)
      path = File.join(SCHEMA_DIR, profile.xsd_path)
      # File.open (not File.read) so Nokogiri can resolve xs:include/xs:redefine
      # relative to the XSD file's directory (needed for AT/PSA schemas).
      File.open(path) { |f| Nokogiri::XML::Schema(f) }
    rescue Errno::ENOENT => e
      raise SEPA::Error,
            "[#{profile.id}] XSD file not found at #{path} (xsd_path=#{profile.xsd_path.inspect}): #{e.message}"
    end
  end
end
