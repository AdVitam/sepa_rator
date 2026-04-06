# frozen_string_literal: true

module SEPA
  PAIN_008_001_02 = 'pain.008.001.02'
  PAIN_008_001_08 = 'pain.008.001.08'
  PAIN_008_001_12 = 'pain.008.001.12'
  PAIN_008_002_02 = 'pain.008.002.02'
  PAIN_008_003_02 = 'pain.008.003.02'
  PAIN_001_001_03 = 'pain.001.001.03'
  PAIN_001_001_09 = 'pain.001.001.09'
  PAIN_001_001_13 = 'pain.001.001.13'
  PAIN_001_002_03 = 'pain.001.002.03'
  PAIN_001_003_03 = 'pain.001.003.03'
  PAIN_001_001_03_CH_02 = 'pain.001.001.03.ch.02'

  SCHEMA_FEATURES = {
    PAIN_001_001_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_001_001_09 => { bic_tag: :BICFI, wrap_date: true,  swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_001_001_13 => { bic_tag: :BICFI, wrap_date: true,  swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :structured, regulatory_reporting_version: :v10 },
    PAIN_001_002_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: true,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_001_003_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_001_001_03_CH_02 => { bic_tag: :BIC, wrap_date: false, swiss: true, requires_bic: false,
                               instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_008_001_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_008_001_08 => { bic_tag: :BICFI, wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_008_001_12 => { bic_tag: :BICFI, wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_008_002_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: true,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 },
    PAIN_008_003_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false,
                         instr_for_dbtr_agt_format: :text, regulatory_reporting_version: :v3 }
  }.each_value(&:freeze).freeze

  # Element order follows PostalAddress27 XSD sequence (the superset).
  # Fields absent in older schemas are rejected by XSD validation.
  POSTAL_ADDRESS_FIELDS = [
    %i[CareOf care_of],
    %i[Dept department],
    %i[SubDept sub_department],
    %i[StrtNm street_name],
    %i[BldgNb building_number],
    %i[BldgNm building_name],
    %i[Flr floor],
    %i[UnitNb unit_number],
    %i[PstBx post_box],
    %i[Room room],
    %i[PstCd post_code],
    %i[TwnNm town_name],
    %i[TwnLctnNm town_location_name],
    %i[DstrctNm district_name],
    %i[CtrySubDvsn country_sub_division],
    %i[Ctry country_code],
    %i[AdrLine address_line1],
    %i[AdrLine address_line2]
  ].freeze

  class Message
    include ActiveModel::Validations
    include SchemaValidation
    include XmlBuilder

    attr_reader :account, :grouped_transactions
    attr_accessor :initiation_source_name, :initiation_source_provider

    INITN_SRC_SCHEMAS = [PAIN_001_001_13].freeze

    validates_presence_of :transactions
    validates_length_of :initiation_source_name, within: 1..140, allow_nil: true
    validates_length_of :initiation_source_provider, within: 1..35, allow_nil: true
    validate do |record|
      record.errors.add(:account, record.account.errors.full_messages) unless record.account.valid?
    end

    class_attribute :account_class, :transaction_class, :xml_main_tag, :known_schemas, instance_writer: false

    # @param account_options [Hash] attributes for the debtor/creditor account (:name, :iban, :bic)
    def initialize(account_options = {})
      @grouped_transactions = {}
      @account = account_class.new(account_options)
    end

    # Add a transaction to the message. The transaction is validated immediately.
    # @param options [Hash] transaction attributes (see {Transaction} subclasses for valid keys)
    # @raise [SEPA::ValidationError] if the transaction is invalid
    def add_transaction(options)
      transaction = transaction_class.new(options)
      raise SEPA::ValidationError, transaction.errors.full_messages.join("\n") unless transaction.valid?

      group = transaction_group(transaction)
      @grouped_transactions[group] ||= []
      @grouped_transactions[group] << transaction
      @transactions = nil
    end

    # @return [Array<Transaction>] all transactions across all groups
    def transactions
      @transactions ||= grouped_transactions.values.flatten
    end

    # Generate the SEPA XML document for the given schema.
    # @param schema_name [String] one of {known_schemas} (defaults to the first)
    # @return [String] UTF-8 encoded XML
    # @raise [SEPA::ValidationError] if the message or account is invalid
    # @raise [SEPA::SchemaValidationError] if transactions are incompatible or XML fails XSD validation
    def to_xml(schema_name = known_schemas.first)
      raise SEPA::ValidationError, errors.full_messages.join("\n") unless valid?
      raise SEPA::SchemaValidationError, "Incompatible with schema #{schema_name}!" unless schema_compatible?(schema_name)

      xml_builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
        builder.Document(xml_schema(schema_name)) do
          builder.__send__(xml_main_tag) do
            build_group_header(builder, schema_name)
            build_payment_informations(builder, schema_name)
          end
        end
      end

      validate_final_document!(xml_builder.doc, schema_name)
      xml_builder.to_xml
    end

    # @param selected_transactions [Array<Transaction>] subset to sum (defaults to all)
    # @return [BigDecimal] total amount
    def amount_total(selected_transactions = transactions)
      selected_transactions.sum(&:amount)
    end

    # Check if all transactions are compatible with the given schema.
    # @param schema_name [String] one of {known_schemas}
    # @return [Boolean]
    # @raise [ArgumentError] if the schema is unknown
    def schema_compatible?(schema_name)
      raise ArgumentError, "Schema #{schema_name} is unknown!" unless known_schemas.include?(schema_name)

      features = schema_features(schema_name)
      return false if features[:requires_bic] && (account.bic.nil? || account.bic.empty?)
      return false if @initiation_source_name && !INITN_SRC_SCHEMAS.include?(schema_name)

      transactions.all? { |t| t.schema_compatible?(schema_name) }
    end

    # Set unique identifier for the message (max 35 chars, alphanumeric + punctuation).
    # Validates and assigns immediately (fail-fast) rather than deferring to ActiveModel,
    # because this field has a lazy default and must always be in a valid state once assigned.
    # @param value [String] unique message ID (1-35 chars)
    # @raise [ArgumentError] if value is not a valid string
    def message_identification=(value)
      raise ArgumentError, 'message_identification must be a string!' unless value.is_a?(String)

      regex = %r{\A([A-Za-z0-9]|[+|?/\-:().,'\ ]){1,35}\z}
      raise ArgumentError, "message_identification does not match #{regex}!" unless value.match?(regex)

      @message_identification = value
    end

    # @return [String] unique message identifier (auto-generated if not set)
    def message_identification
      @message_identification ||= "MSG/#{SecureRandom.hex(14)}"
    end

    # Set creation date time for the message (ISO 8601 format).
    # Validates and assigns immediately (fail-fast) rather than deferring to ActiveModel,
    # because this field has a lazy default and must always be in a valid state once assigned.
    # @note Rabobank (NL) only accepts the strict format YYYY-MM-DDTHH:MM:SS
    # @param value [String] ISO 8601 datetime
    # @raise [ArgumentError] if value does not match the expected format
    def creation_date_time=(value)
      raise ArgumentError, 'creation_date_time must be a string!' unless value.is_a?(String)

      regex = /[0-9]{4}-[0-9]{2,2}-[0-9]{2,2}(?:\s|T)[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}/
      raise ArgumentError, "creation_date_time does not match #{regex}!" unless value.match?(regex)

      @creation_date_time = value
    end

    # @return [String] ISO 8601 creation datetime (auto-generated if not set)
    def creation_date_time
      @creation_date_time ||= Time.now.iso8601
    end

    # Find the PmtInf ID for the batch containing a transaction with the given reference.
    # @param transaction_reference [String] the transaction's EndToEndId reference
    # @return [String, nil] the payment information identification, or nil if not found
    def batch_id(transaction_reference)
      grouped_transactions.each do |group, transactions|
        return payment_information_identification(group) if transactions.any? { |transaction| transaction.reference == transaction_reference }
      end
      nil
    end

    # @return [Array<String>] list of all PmtInf IDs in the message
    def batches
      grouped_transactions.keys.map { |group| payment_information_identification(group) }
    end

    private

    def schema_features(schema_name)
      SCHEMA_FEATURES.fetch(schema_name) { raise ArgumentError, "Schema #{schema_name} is unknown!" }
    end

    # @return {Hash<Symbol=>String>} xml schema information used in output xml
    def xml_schema(schema_name)
      if schema_features(schema_name)[:swiss]
        {
          xmlns: 'http://www.six-interbank-clearing.com/de/pain.001.001.03.ch.02.xsd',
          'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation': 'http://www.six-interbank-clearing.com/de/pain.001.001.03.ch.02.xsd  pain.001.001.03.ch.02.xsd'
        }
      else
        {
          xmlns: "urn:iso:std:iso:20022:tech:xsd:#{schema_name}",
          'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation': "urn:iso:std:iso:20022:tech:xsd:#{schema_name} #{schema_name}.xsd"
        }
      end
    end

    def build_group_header(builder, schema_name)
      builder.GrpHdr do
        builder.MsgId(message_identification)
        builder.CreDtTm(creation_date_time)
        builder.NbOfTxs(transactions.length)
        builder.CtrlSum(format_amount(amount_total))
        builder.InitgPty do
          builder.Nm(account.name)
          account.initiating_party_id(builder)
        end
        build_initiation_source(builder, schema_name)
      end
    end

    # Unique and consecutive identifier (used for the <PmntInf> blocks)
    def payment_information_identification(group)
      suffix = "/#{grouped_transactions.keys.index(group) + 1}"
      max_prefix_length = 35 - suffix.length
      "#{message_identification[0, max_prefix_length]}#{suffix}"
    end

    # Returns a key to determine the group to which the transaction belongs
    def transaction_group(transaction)
      transaction
    end

    def build_initiation_source(builder, schema_name)
      return unless INITN_SRC_SCHEMAS.include?(schema_name) && @initiation_source_name

      builder.InitnSrc do
        builder.Nm(@initiation_source_name)
        builder.Prvdr(@initiation_source_provider) if @initiation_source_provider
      end
    end
  end
end
