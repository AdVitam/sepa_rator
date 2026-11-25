# frozen_string_literal: true

module SEPA
  ProfileFeatures = Data.define(
    :bic_tag,
    :wrap_date,
    :requires_bic,
    :org_bic_tag,
    :instr_for_dbtr_agt_format,
    # `:instruction3_code` (ISO enum) or `:external_code` (free 1-4 char, v13+)
    :instr_for_cdtr_agt_code_type,
    :regulatory_reporting_version,
    :charset,
    :min_amount,
    :requires_structured_address,
    :requires_country_code_on_address,
    # Element paths that must hold exactly one child (PSA XSD 1.1 asserts libxml2 cannot run)
    :single_child_paths,
    :extras
  ) do
    def self.default
      new(
        bic_tag: :BICFI,
        wrap_date: true,
        requires_bic: false,
        org_bic_tag: :AnyBIC,
        instr_for_dbtr_agt_format: :text,
        instr_for_cdtr_agt_code_type: :instruction3_code,
        regulatory_reporting_version: :v3,
        charset: Charset::ISO,
        min_amount: nil,
        requires_structured_address: false,
        requires_country_code_on_address: false,
        single_child_paths: [].freeze,
        extras: {}.freeze
      )
    end

    def [](key)
      return public_send(key) if respond_to?(key)
      return extras.fetch(key) if extras.key?(key)

      raise KeyError, "Unknown feature key: #{key.inspect}"
    end

    def merge(**overrides)
      extras_override = overrides.delete(:extras) || {}
      merged_extras = extras.merge(extras_override).freeze
      self.class.new(**to_h, **overrides, extras: merged_extras)
    end
  end

  module StageList
    module_function

    def merge(old, operation)
      return Array(operation).freeze if operation.is_a?(Array)

      case operation
      in { replace: klass, with: replacement }
        old.map { |stage| stage == klass ? replacement : stage }.freeze
      in { insert_after: klass, stage: stage }
        old.flat_map { |existing| existing == klass ? [existing, stage] : [existing] }.freeze
      in { insert_before: klass, stage: stage }
        old.flat_map { |existing| existing == klass ? [stage, existing] : [existing] }.freeze
      in { remove: klass }
        old.reject { |stage| stage == klass }.freeze
      else
        raise ArgumentError,
              "StageList.merge: unsupported operation #{operation.inspect}. " \
              'Expected an Array or one of: { replace:, with: }, { insert_after:, stage: }, ' \
              '{ insert_before:, stage: }, { remove: }'
      end
    end
  end

  PROFILE_FAMILIES = %i[credit_transfer direct_debit].freeze

  Profile = Data.define(
    :id,
    :family,
    :iso_schema,
    :xsd_path,
    :namespace,
    :features,
    :validators,
    :capabilities,
    :transaction_stages,
    :payment_info_stages,
    :group_header_stages,
    :accept_transaction
  ) do
    def initialize(**attrs)
      unless PROFILE_FAMILIES.include?(attrs[:family])
        raise ArgumentError,
              "Profile #{attrs[:id].inspect} has invalid family #{attrs[:family].inspect}; " \
              "expected one of #{PROFILE_FAMILIES.inspect}"
      end

      # Freeze collection fields so a caller cannot mutate a registered
      # profile's arrays under our feet. Individual stages/validators are
      # classes (already immutable by reference).
      %i[validators capabilities transaction_stages payment_info_stages group_header_stages]
        .each { |key| attrs[key] = attrs[key].dup.freeze unless attrs[key].frozen? }

      # Catch "forgot to point at a stage class" coquilles at registration
      # time instead of at XML build time.
      %i[transaction_stages payment_info_stages group_header_stages].each do |key|
        attrs[key].each do |stage|
          raise ArgumentError, "Profile #{attrs[:id].inspect} #{key} contains #{stage.inspect} which does not respond to .call" unless stage.respond_to?(:call)
        end
      end

      super
    end

    def supports?(capability)
      capabilities.include?(capability)
    end

    def single_child?(path)
      features.single_child_paths.include?(path)
    end

    def accepts?(transaction)
      accept_transaction.nil? || accept_transaction.call(transaction, self)
    end

    def with(**overrides)
      merged = overrides.each_with_object(to_h.dup) do |(key, value), acc|
        acc[key] = merge_field(key, acc[key], value)
      end
      self.class.new(**merged)
    end

    private

    def merge_field(key, old, value)
      case key
      when :features
        old.merge(**value)
      when :validators
        merge_list(old, value, unique: false)
      when :capabilities
        merge_list(old, value, unique: true)
      when :transaction_stages, :payment_info_stages, :group_header_stages
        StageList.merge(old, value)
      else
        value
      end
    end

    # Merge helper for the flat list fields `validators` and `capabilities`.
    # Stage lists use `StageList.merge` instead, which supports positional
    # operations (`insert_after:`, `replace:`/`with:`, `remove:`).
    #
    # Array = append (common case), `{ replace: [...] }` = drop the parent
    # list, `{ add: [...] }` = explicit append.
    def merge_list(old, value, unique:)
      combined =
        case value
        when Array
          old + value
        when Hash
          case value
          in { replace: new } then Array(new)
          in { add: new } then old + Array(new)
          else
            raise ArgumentError,
                  "merge_list: unsupported Hash operation #{value.inspect}. " \
                  'Expected `{ replace: [...] }` or `{ add: [...] }`.'
          end
        else
          raise ArgumentError,
                "merge_list: expected Array or Hash, got #{value.class}"
        end
      (unique ? combined.uniq : combined).freeze
    end
  end

  class ProfileRegistry
    @profiles = {}
    # Nested map: { family => { country_symbol_or_nil => { version_symbol => profile } } }
    @country_defaults = {}
    # Allow-list of SEPA-zone country codes accepted by `Message.new(country:)`.
    # Countries without a dedicated profile still fall back to the generic EPC
    # defaults, but a typo (e.g. `:fre`) raises `UnknownCountryError` instead
    # of silently using the fallback.
    @known_countries = Set.new

    class << self
      def register(profile, aliases: [])
        ([profile.id] + aliases.map(&:to_s)).each do |key|
          next unless @profiles.key?(key) && !@profiles[key].equal?(profile)

          raise ArgumentError, "A different profile is already registered under #{key.inspect}"
        end

        @profiles[profile.id] = profile
        aliases.each { |name| @profiles[name.to_s] = profile }
        profile
      end

      def [](profile_id)
        @profiles.fetch(profile_id.to_s) do
          raise ArgumentError, "Unknown profile: #{profile_id.inspect}"
        end
      end

      def all
        @profiles.values.uniq
      end

      # Register one or more country codes as valid inputs to
      # `Message.new(country:)`. Must be called from country_defaults.rb so
      # that the allow-list is populated before any Message is constructed.
      def register_countries(*codes)
        codes.each { |code| @known_countries << code }
      end

      def known_country?(code)
        code.nil? || @known_countries.include?(code)
      end

      # Register a (family, country, version) → profile mapping used by
      # `Message.new(country:, version:)` to resolve the recommended profile.
      def set_country_default(family:, country:, version:, profile:)
        unless profile.family == family
          raise ArgumentError,
                "set_country_default: profile #{profile.id.inspect} is for family " \
                "#{profile.family.inspect}, not #{family.inspect}"
        end

        @country_defaults[family] ||= {}
        @country_defaults[family][country] ||= {}
        if @country_defaults[family][country].key?(version) &&
           !@country_defaults[family][country][version].equal?(profile)
          raise ArgumentError,
                "set_country_default: (#{family.inspect}, #{country.inspect}, #{version.inspect}) " \
                "already maps to #{@country_defaults[family][country][version].id.inspect}"
        end

        @country_defaults[family][country][version] = profile
      end

      # Resolve a (family, country, version) triple to the recommended profile.
      # Falls back to the generic `country: nil` entry when the requested
      # country is a known SEPA country without a dedicated profile.
      #
      # @raise [ArgumentError] when the family is unknown
      # @raise [SEPA::UnknownCountryError] when the country is not in the
      #   SEPA allow-list (catches typos)
      # @raise [SEPA::UnsupportedVersionError] when the version is unknown for
      #   the resolved country
      def recommended(family:, country: nil, version: :latest)
        raise SEPA::UnknownCountryError.new(country: country, known_countries: @known_countries.to_a) unless known_country?(country)

        per_country = @country_defaults.fetch(family) do
          raise ArgumentError, "Unknown family: #{family.inspect}"
        end

        fallback_used = per_country[country].nil?
        versions = per_country[country] || per_country[nil]
        raise ArgumentError, "No default profiles registered for family=#{family.inspect}" unless versions

        versions.fetch(version) do
          raise SEPA::UnsupportedVersionError.new(
            country: country, version: version,
            available_versions: versions.keys,
            fallback_used: fallback_used
          )
        end
      end
    end
  end
end
