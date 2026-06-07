# frozen_string_literal: true

require 'active_support/concern'

module SEPA
  module SchemaValidation
    extend ActiveSupport::Concern

    DEFAULT_SCHEMA_ROOT = File.expand_path('../../schema', __dir__).freeze
    # So missing-schema errors can name the companion gem to install.
    SCHEMA_GEMS = { 'at' => 'sepa_rator-at', 'dk' => 'sepa_rator-dk', 'sps' => 'sepa_rator-sps' }.freeze
    # Keyed by resolved absolute path: a root registered after a first
    # validation must not be shadowed by a stale entry.
    SCHEMA_CACHE = {} # rubocop:disable Style/MutableConstant -- intentional cache
    SCHEMA_CACHE_MUTEX = Mutex.new

    class << self
      def schema_roots
        @schema_roots ||= [DEFAULT_SCHEMA_ROOT]
      end

      def register_schema_root(path)
        expanded = File.expand_path(path)
        raise ArgumentError, "register_schema_root: #{expanded} is not a directory" unless File.directory?(expanded)

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
      path = resolve_xsd_path(profile)
      cached = SCHEMA_CACHE[path]
      return cached if cached

      SCHEMA_CACHE_MUTEX.synchronize do
        SCHEMA_CACHE[path] ||= read_xsd(profile, path)
      end
    end

    def resolve_xsd_path(profile)
      SchemaValidation.schema_roots
                      .map { |root| File.join(root, profile.xsd_path) }
                      .find { |candidate| File.file?(candidate) } ||
        raise_missing_schema!(profile)
    end

    def read_xsd(profile, path)
      # File.open (not File.read) so Nokogiri can resolve xs:include/xs:redefine
      # relative to the XSD file's directory (needed for AT/PSA schemas).
      File.open(path) { |f| Nokogiri::XML::Schema(f) }
    rescue Errno::ENOENT
      raise_missing_schema!(profile)
    end

    def raise_missing_schema!(profile)
      gem_name = SCHEMA_GEMS[profile.xsd_path.split('/').first]
      hint = gem_name ? " Add gem '#{gem_name}' to your Gemfile to validate profile #{profile.id}." : ''
      raise SEPA::Error,
            "[#{profile.id}] XSD file #{profile.xsd_path} not found " \
            "(searched roots: #{SchemaValidation.schema_roots.join(', ')}).#{hint}"
    end
  end
end
