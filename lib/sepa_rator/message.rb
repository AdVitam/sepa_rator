# frozen_string_literal: true

module SEPA
  class Message
    include ActiveModel::Validations
    include SchemaValidation

    # Overridden by subclasses; used to resolve profiles via country/version hints.
    FAMILY = nil
    # Root element inside <Document>. Overridden by subclasses.
    XML_MAIN_TAG = nil

    attr_reader :account, :grouped_transactions, :profile, :initiation_source_name, :initiation_source_provider

    def initiation_source_name=(value)
      raise_unsupported_capability!('initiation_source_name', :initiation_source) if value && !profile.supports?(:initiation_source)

      @initiation_source_name = charset.text(value)
    end

    def initiation_source_provider=(value)
      @initiation_source_provider = charset.text(value)
    end

    validates_presence_of :transactions
    validates_length_of :initiation_source_name, within: 1..140, allow_nil: true
    validates_length_of :initiation_source_provider, within: 1..35, allow_nil: true
    validate do |record|
      record.errors.add(:account, record.account.errors.full_messages) unless record.account.valid?
    end

    class_attribute :account_class, :transaction_class, instance_writer: false

    # @param profile [SEPA::Profile, nil] explicit profile object. Mutually
    #   exclusive with `country:` and `version:`. Power-user path.
    # @param country [Symbol, nil] country code of **the bank that will receive
    #   and process this XML file** (not the beneficiary's bank). Resolves to
    #   the country-specific profile via {ProfileRegistry.recommended}. Falls
    #   back to the generic SEPA/EPC profile when the country has no dedicated
    #   variant registered.
    # @param version [Symbol] semantic version hint (`:latest`, `:v09`, `:v13`,
    #   …). Defaults to `:latest`.
    # @param account_options [Hash] attributes for the debtor/creditor account
    #   (`:name`, `:iban`, `:bic`, …).
    # @raise [ArgumentError] if `profile:` is mixed with `country:` / `version:`
    # @raise [SEPA::UnsupportedVersionError] if the requested version is not
    #   registered for the resolved country
    def initialize(country: nil, version: :latest, profile: nil, **account_options)
      @profile = resolve_profile(country: country, version: version, profile: profile)
      @grouped_transactions = {}
      @account = admit(account_class.new(account_options))
      validate_message_account_against_profile!
    end

    # Add a transaction to the message. The transaction is validated both
    # against its own ActiveModel rules and against the profile's
    # `accept_transaction` lambda + extra validators.
    #
    # @param options [Hash] transaction attributes
    # @raise [SEPA::ValidationError] if the transaction is invalid
    def add_transaction(options)
      transaction = admit(transaction_class.new(options))
      raise SEPA::ValidationError, transaction.errors.full_messages.join("\n") unless transaction.valid?

      validate_transaction_against_profile!(transaction)

      group = transaction_group(transaction)
      (@grouped_transactions[group] ||= []) << transaction
      @transactions = nil
    end

    # @return [Array<Transaction>] all transactions across all groups
    def transactions
      @transactions ||= grouped_transactions.values.flatten
    end

    # Generate the SEPA XML document using the profile provided at construction.
    #
    # @return [String] UTF-8 encoded XML
    # @raise [SEPA::ValidationError] if the message or account is invalid
    # @raise [SEPA::SchemaValidationError] if the generated XML fails XSD validation
    def to_xml
      # Fail-safe against post-insertion mutations of the account or
      # transactions (e.g. a caller flipping `currency` after adding).
      [@account, *transactions].each { |model| model.apply_charset(charset) }
      raise SEPA::ValidationError, errors.full_messages.join("\n") unless valid?

      validate_message_account_against_profile!
      transactions.each { |transaction| validate_transaction_against_profile!(transaction) }

      doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
        builder.Document(xml_namespace_attributes) do
          builder.__send__(self.class::XML_MAIN_TAG) do
            run_stages(profile.group_header_stages, builder)
            run_stages(profile.payment_info_stages, builder)
          end
        end
      end

      validate_final_document!(doc.doc, profile)
      doc.to_xml
    end

    # @param selected_transactions [Array<Transaction>] subset to sum (defaults to all)
    # @return [BigDecimal] total amount
    def amount_total(selected_transactions = transactions)
      selected_transactions.sum(&:amount)
    end

    def message_identification=(value)
      raise ArgumentError, 'message_identification must be a string!' unless value.is_a?(String)

      regex = %r{\A([A-Za-z0-9]|[+|?/\-:().,'\ ]){1,35}\z}
      raise ArgumentError, "message_identification does not match #{regex}!" unless value.match?(regex)

      @message_identification = value
    end

    def message_identification
      @message_identification ||= "MSG/#{SecureRandom.hex(14)}"
    end

    def creation_date_time=(value)
      raise ArgumentError, 'creation_date_time must be a string!' unless value.is_a?(String)

      regex = /[0-9]{4}-[0-9]{2,2}-[0-9]{2,2}(?:\s|T)[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}/
      raise ArgumentError, "creation_date_time does not match #{regex}!" unless value.match?(regex)

      @creation_date_time = value
    end

    def creation_date_time
      @creation_date_time ||= Time.now.iso8601
    end

    # Find the PmtInf ID for the batch containing a transaction with the given reference.
    def batch_id(transaction_reference)
      grouped_transactions.each do |group, transactions|
        return payment_information_identification(group) if transactions.any? { |t| t.reference == transaction_reference }
      end
      nil
    end

    def batches
      grouped_transactions.keys.map { |group| payment_information_identification(group) }
    end

    # Unique and consecutive identifier for a <PmtInf> block, derived from
    # `message_identification` + the group's position. Invoked by builder stages.
    def payment_information_identification(group)
      suffix = "/#{grouped_transactions.keys.index(group) + 1}"
      max_prefix_length = 35 - suffix.length
      "#{message_identification[0, max_prefix_length]}#{suffix}"
    end

    private

    def charset = profile.features.charset

    def admit(model) = model.detach_nested_models(@nested_copies ||= {}.compare_by_identity).apply_charset(charset)

    # Single entry point for validating a transaction against the message's
    # profile. Called both from `add_transaction` (at insertion) and from
    # `to_xml` (as a fail-safe against post-insertion mutations).
    def validate_transaction_against_profile!(transaction)
      validate_creditor_account_override!(transaction.creditor_account) if transaction.respond_to?(:creditor_account) && transaction.creditor_account
      assert_capabilities!(transaction, 'transaction')

      raise SEPA::ValidationError, "Transaction not compatible with profile #{profile.id}" unless transaction.compatible_with?(profile)

      validate_transaction_addresses_against_profile!(transaction)
      run_profile_validators(transaction)
    end

    def validate_message_account_against_profile!
      validate_account_against_profile!(@account, 'account')
      return unless profile.features.exclusive_initiating_party && @account.initiating_party_identifiers.length > 1

      raise SEPA::ValidationError,
            "[#{profile.id}] InitgPty/Id holds a single identifier: set only one of " \
            'initiating_party_bic, initiating_party_lei or initiating_party_identifier'
    end

    # `InitgPty` is built from the message account only.
    def validate_creditor_account_override!(account)
      validate_account_against_profile!(account, 'creditor_account')
      return if account.initiating_party_identifiers.empty?

      raise SEPA::ValidationError, "[#{profile.id}] creditor_account.initiating_party_* is ignored: set it on the message account instead"
    end

    # Shared by the message account and the direct debit `creditor_account` override.
    def validate_account_against_profile!(account, label)
      raise SEPA::ValidationError, "[#{profile.id}] #{label} is missing the required BIC" if profile.features.requires_bic && (account.bic.nil? || account.bic.empty?)

      assert_capabilities!(account, label)
      assert_address_format!(account.address, "#{label}.address")
      assert_address_has_country_code!(account.address, "#{label}.address")
    end

    def assert_capabilities!(model, label)
      field, capability = model.capability_violation(profile)
      raise_unsupported_capability!("#{label}.#{field}", capability) if field
    end

    def raise_unsupported_capability!(field, capability)
      raise SEPA::ValidationError, "[#{profile.id}] #{field} requires capability :#{capability}, not supported by this profile"
    end

    # Transaction-level addresses (`creditor_address`, `debtor_address`) are
    # serialised in `PmtInf/*/PstlAdr` and must satisfy the same structured
    # requirement as the message account when the profile mandates it.
    def validate_transaction_addresses_against_profile!(transaction)
      assert_address_format!(transaction.creditor_address, 'creditor_address') if transaction.respond_to?(:creditor_address)
      assert_address_format!(transaction.debtor_address, 'debtor_address') if transaction.respond_to?(:debtor_address)
      return unless profile.features.requires_country_code_on_address

      assert_address_has_country_code!(transaction.creditor_address, 'creditor_address') if transaction.respond_to?(:creditor_address)
      assert_address_has_country_code!(transaction.debtor_address, 'debtor_address') if transaction.respond_to?(:debtor_address)
    end

    def assert_address_format!(address, label)
      return if address.nil?

      if profile.features.requires_structured_address && !address.structured?
        raise SEPA::ValidationError, "[#{profile.id}] #{label} must use structured fields (StrtNm, PstCd, TwnNm, …), not AdrLine"
      end
      return if address.lines_only? || profile.supports?(:structured_address)

      raise SEPA::ValidationError,
            "[#{profile.id}] #{label} requires capability :structured_address, not supported by this profile: set only country_code and address lines"
    end

    def assert_address_has_country_code!(address, label)
      return unless profile.features.requires_country_code_on_address
      return if address.nil?
      return if address.country_code && !address.country_code.empty?

      raise SEPA::ValidationError,
            "[#{profile.id}] #{label} must include a country code (Ctry)"
    end

    # Resolves the (country, version, profile) triple to a single Profile.
    # Passing `profile:` bypasses the country/version lookup entirely; the
    # two are mutually exclusive.
    def resolve_profile(country:, version:, profile:)
      return ProfileRegistry.recommended(family: self.class::FAMILY, country: country, version: version) unless profile

      raise ArgumentError, 'pass either `profile:` or `country:`/`version:`, not both' if country || version != :latest
      raise ArgumentError, "expected SEPA::Profile, got #{profile.class}" unless profile.is_a?(Profile)
      raise ArgumentError, "profile #{profile.id} is for #{profile.family}, not #{self.class::FAMILY}" unless profile.family == self.class::FAMILY

      profile
    end

    def run_stages(stages, builder)
      ctx = Builders::Context.new(
        message: self,
        profile: profile,
        builder: builder,
        transaction: nil,
        group: nil
      )
      stages.each { |stage| stage.call(ctx) }
    end

    def xml_namespace_attributes
      {
        xmlns: profile.namespace,
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation': "#{profile.namespace} #{File.basename(profile.xsd_path)}"
      }
    end

    def run_profile_validators(transaction)
      profile.validators.each do |validator|
        validator.validate(transaction, profile)
      end
    end

    # @abstract Subclasses return a grouping key (Data struct) used to batch
    #   transactions into separate PmtInf blocks.
    def transaction_group(transaction)
      transaction
    end
  end
end
