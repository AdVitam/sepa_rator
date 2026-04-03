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
    PAIN_001_001_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false },
    PAIN_001_001_09 => { bic_tag: :BICFI, wrap_date: true,  swiss: false, requires_bic: false },
    PAIN_001_001_13 => { bic_tag: :BICFI, wrap_date: true,  swiss: false, requires_bic: false },
    PAIN_001_002_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: true },
    PAIN_001_003_03 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false },
    PAIN_001_001_03_CH_02 => { bic_tag: :BIC, wrap_date: false, swiss: true, requires_bic: false },
    PAIN_008_001_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false },
    PAIN_008_001_08 => { bic_tag: :BICFI, wrap_date: false, swiss: false, requires_bic: false },
    PAIN_008_001_12 => { bic_tag: :BICFI, wrap_date: false, swiss: false, requires_bic: false },
    PAIN_008_002_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: true },
    PAIN_008_003_02 => { bic_tag: :BIC,   wrap_date: false, swiss: false, requires_bic: false }
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

    attr_reader :account, :grouped_transactions

    validates_presence_of :transactions
    validate do |record|
      record.errors.add(:account, record.account.errors.full_messages) unless record.account.valid?
    end

    class_attribute :account_class, :transaction_class, :xml_main_tag, :known_schemas

    def initialize(account_options = {})
      @grouped_transactions = {}
      @account = account_class.new(account_options)
    end

    def add_transaction(options)
      transaction = transaction_class.new(options)
      raise SEPA::ValidationError, transaction.errors.full_messages.join("\n") unless transaction.valid?

      group = transaction_group(transaction)
      @grouped_transactions[group] ||= []
      @grouped_transactions[group] << transaction
      @transactions = nil
    end

    def transactions
      @transactions ||= grouped_transactions.values.flatten
    end

    # @return [String] xml
    def to_xml(schema_name = known_schemas.first)
      raise SEPA::ValidationError, errors.full_messages.join("\n") unless valid?
      raise SEPA::SchemaValidationError, "Incompatible with schema #{schema_name}!" unless schema_compatible?(schema_name)

      xml_builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
        builder.Document(xml_schema(schema_name)) do
          builder.__send__(xml_main_tag) do
            build_group_header(builder)
            build_payment_informations(builder, schema_name)
          end
        end
      end

      validate_final_document!(xml_builder.doc, schema_name)
      xml_builder.to_xml
    end

    def amount_total(selected_transactions = transactions)
      selected_transactions.sum(&:amount)
    end

    def schema_compatible?(schema_name)
      raise ArgumentError, "Schema #{schema_name} is unknown!" unless known_schemas.include?(schema_name)

      features = schema_features(schema_name)
      return false if features[:requires_bic] && account.bic.blank?

      transactions.all? { |t| t.schema_compatible?(schema_name) }
    end

    # Set unique identifer for the message
    def message_identification=(value)
      raise ArgumentError, 'message_identification must be a string!' unless value.is_a?(String)

      regex = %r{\A([A-Za-z0-9]|[+|?/\-:().,'\ ]){1,35}\z}
      raise ArgumentError, "message_identification does not match #{regex}!" unless value.match?(regex)

      @message_identification = value
    end

    # Get unique identifer for the message (with fallback to a random string)
    def message_identification
      @message_identification ||= "SEPA-KING/#{SecureRandom.hex(11)}"
    end

    # Set creation date time for the message
    # p.s. Rabobank in the Netherlands only accepts the more restricted format [0-9]{4}[-][0-9]{2,2}[-][0-9]{2,2}[T][0-9]{2,2}[:][0-9]{2,2}[:][0-9]{2,2}
    def creation_date_time=(value)
      raise ArgumentError, 'creation_date_time must be a string!' unless value.is_a?(String)

      regex = /[0-9]{4}-[0-9]{2,2}-[0-9]{2,2}(?:\s|T)[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}/
      raise ArgumentError, "creation_date_time does not match #{regex}!" unless value.match?(regex)

      @creation_date_time = value
    end

    # Get creation date time for the message (with fallback to Time.now.iso8601)
    def creation_date_time
      @creation_date_time ||= Time.now.iso8601
    end

    # Returns the id of the batch to which the given transaction belongs
    # Identified based upon the reference of the transaction
    def batch_id(transaction_reference)
      grouped_transactions.each do |group, transactions|
        return payment_information_identification(group) if transactions.any? { |transaction| transaction.reference == transaction_reference }
      end
      nil
    end

    def batches
      grouped_transactions.keys.map { |group| payment_information_identification(group) }
    end

    def self.schema_cache
      @schema_cache ||= {}
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

    def build_group_header(builder)
      builder.GrpHdr do
        builder.MsgId(message_identification)
        builder.CreDtTm(creation_date_time)
        builder.NbOfTxs(transactions.length)
        builder.CtrlSum(format_amount(amount_total))
        builder.InitgPty do
          builder.Nm(account.name)
          account.initiating_party_id(builder)
        end
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

    def build_postal_address(builder, address)
      builder.PstlAdr do
        POSTAL_ADDRESS_FIELDS.each do |xml_tag, attr|
          value = address.public_send(attr)
          builder.__send__(xml_tag, value) if value
        end
      end
    end

    def build_agent_bic(builder, bic, schema_name, fallback: true)
      builder.FinInstnId do
        if bic
          builder.__send__(schema_features(schema_name)[:bic_tag], bic)
        elsif fallback
          builder.Othr do
            builder.Id('NOTPROVIDED')
          end
        end
      end
    end

    def build_remittance_information(builder, transaction)
      return unless transaction.remittance_information || transaction.structured_remittance_information

      builder.RmtInf do
        if transaction.structured_remittance_information
          builder.Strd do
            builder.CdtrRefInf do
              builder.Tp do
                builder.CdOrPrtry do
                  builder.Cd('SCOR')
                end
              end
              builder.Ref(transaction.structured_remittance_information)
            end
          end
        else
          builder.Ustrd(transaction.remittance_information)
        end
      end
    end

    def format_amount(value)
      format('%.2f', value)
    end

    def validate_final_document!(document, schema_name)
      xsd = self.class.schema_cache[schema_name] ||= Nokogiri::XML::Schema(
        File.read(File.expand_path("../../lib/schema/#{schema_name}.xsd", __dir__))
      )
      errors = xsd.validate(document).map(&:message)
      raise SEPA::SchemaValidationError, "Incompatible with schema #{schema_name}: #{errors.join(', ')}" if errors.any?
    end
  end
end
