# frozen_string_literal: true

require 'active_support/concern'

module SEPA
  module SchemaValidation
    extend ActiveSupport::Concern

    DEFAULT_SCHEMA_ROOT = File.expand_path('../../schema', __dir__).freeze
    # Country-specific XSDs live in companion gems; maps an xsd_path prefix
    # to the gem that ships it, for actionable missing-schema errors.
    SCHEMA_GEMS = { 'at' => 'sepa_rator-at', 'dk' => 'sepa_rator-dk', 'sps' => 'sepa_rator-sps' }.freeze
    # Eagerly-initialised module-level XSD cache, shared across every
    # class that includes SchemaValidation. Keyed by `profile.xsd_path`
    # so two profiles that share an ISO schema name but point to
    # different XSD files (e.g. the ISO baseline and the DK GBIC5
    # variant) never share a cache entry.
    SCHEMA_CACHE = {} # rubocop:disable Style/MutableConstant -- intentional cache
    SCHEMA_CACHE_MUTEX = Mutex.new

    class << self
      def schema_roots
        @schema_roots ||= [DEFAULT_SCHEMA_ROOT]
      end

      def register_schema_root(path)
        expanded = File.expand_path(path)
        schema_roots.unshift(expanded) unless schema_roots.include?(expanded)
      end
    end

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
      path = SchemaValidation.schema_roots
                             .map { |root| File.join(root, profile.xsd_path) }
                             .find { |candidate| File.exist?(candidate) }
      raise_missing_schema!(profile) unless path

      # File.open (not File.read) so Nokogiri can resolve xs:include/xs:redefine
      # relative to the XSD file's directory (needed for AT/PSA schemas).
      File.open(path) { |f| Nokogiri::XML::Schema(f) }
    rescue Errno::ENOENT
      raise_missing_schema!(profile)
    end

    def raise_missing_schema!(profile)
      gem_name = SCHEMA_GEMS[profile.xsd_path.split('/').first]
      hint = if gem_name
               "Add gem '#{gem_name}' to your Gemfile to validate profile #{profile.id}."
             else
               "Searched roots: #{SchemaValidation.schema_roots.join(', ')}."
             end
      raise SEPA::Error, "[#{profile.id}] XSD file #{profile.xsd_path} not found. #{hint}"
    end
  end
end
