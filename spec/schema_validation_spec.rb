# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe SEPA::SchemaValidation do
  subject(:validator) { Class.new { include SEPA::SchemaValidation }.new }

  around do |example|
    original_roots = described_class.schema_roots.dup
    example.run
  ensure
    described_class.schema_roots.replace(original_roots)
  end

  def stub_profile(xsd_path)
    instance_double(SEPA::Profile, id: 'test.profile', xsd_path: xsd_path)
  end

  describe '.register_schema_root' do
    it 'prepends the expanded path to the schema roots' do
      Dir.mktmpdir do |dir|
        described_class.register_schema_root("#{dir}/.")

        expect(described_class.schema_roots.first).to eq(dir)
      end
    end

    it 'does not register the same root twice, even non-normalized' do
      Dir.mktmpdir do |dir|
        expect do
          described_class.register_schema_root(dir)
          described_class.register_schema_root("#{dir}/.")
        end.to change { described_class.schema_roots.size }.by(1)
      end
    end

    it 'rejects a path that is not a directory' do
      expect { described_class.register_schema_root('/nonexistent/schemas') }
        .to raise_error(ArgumentError, %r{/nonexistent/schemas is not a directory})
    end

    it 'is exposed as SEPA.register_schema_root' do
      Dir.mktmpdir do |dir|
        SEPA.register_schema_root(dir)

        expect(described_class.schema_roots).to include(dir)
      end
    end

    SEPA::SchemaValidation::SCHEMA_GEMS.each_key do |prefix|
      it "is called by the #{prefix} entry file required in spec_helper" do
        root = File.expand_path("../sepa_rator-#{prefix}/lib/schema", __dir__)

        expect(described_class.schema_roots).to include(root)
      end
    end
  end

  describe '#load_xsd' do
    it 'resolves an XSD from a registered root' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'custom'))
        FileUtils.cp(
          File.join(described_class::DEFAULT_SCHEMA_ROOT, 'iso/pain.001.001.09.xsd'),
          File.join(dir, 'custom/pain.001.001.09.xsd')
        )
        described_class.register_schema_root(dir)

        xsd = validator.send(:load_xsd, stub_profile('custom/pain.001.001.09.xsd'))

        expect(xsd).to be_a(Nokogiri::XML::Schema)
      end
    end

    it 'lets a registered root shadow the default root' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'iso'))
        FileUtils.cp(
          File.join(described_class::DEFAULT_SCHEMA_ROOT, 'iso/pain.001.001.09.xsd'),
          File.join(dir, 'iso/pain.001.001.09.xsd')
        )
        described_class.register_schema_root(dir)

        path = validator.send(:resolve_xsd_path, stub_profile('iso/pain.001.001.09.xsd'))

        expect(path).to eq(File.join(dir, 'iso/pain.001.001.09.xsd'))
      end
    end

    described_class::SCHEMA_GEMS.each do |prefix, gem_name|
      it "raises an actionable error naming #{gem_name} when a #{prefix}/ XSD is missing" do
        described_class.schema_roots.replace([described_class::DEFAULT_SCHEMA_ROOT])

        expect { validator.send(:load_xsd, stub_profile("#{prefix}/missing.xsd")) }
          .to raise_error(
            SEPA::Error,
            /searched roots: .*schema.*Add gem '#{gem_name}' to your Gemfile to validate profile test\.profile/
          )
      end
    end

    it 'lists the searched roots when no companion gem matches the prefix' do
      expect { validator.send(:load_xsd, stub_profile('nowhere/missing.xsd')) }
        .to raise_error(SEPA::Error, /not found \(searched roots: .*schema.*\)\.\z/)
    end
  end

  describe 'single-child rules' do
    def ct_xml(paths)
      profile = SEPA::Profiles::ISO::SCT_09.with(features: { single_child_paths: paths })
      sct = credit_transfer_message(profile: profile)
      sct.add_transaction(credit_transfer_transaction)
      sct.to_xml
    end

    it 'raises when an element with several children is listed' do
      expect { ct_xml(%w[GrpHdr]) }
        .to raise_error(SEPA::SchemaValidationError, %r{#{SEPA::Profiles::ISO::SCT_09.id}.*Document/CstmrCdtTrfInitn/GrpHdr})
    end

    it 'checks every listed path, not only the first' do
      expect { ct_xml(%w[GrpHdr/InitgPty GrpHdr]) }
        .to raise_error(SEPA::SchemaValidationError, %r{required in Document/CstmrCdtTrfInitn/GrpHdr\z})
    end

    it 'raises when a listed element has no child' do
      expect { ct_xml(%w[GrpHdr/MsgId]) }
        .to raise_error(SEPA::SchemaValidationError, %r{CstmrCdtTrfInitn/GrpHdr/MsgId})
    end

    it 'accepts a document where every listed element has exactly one child' do
      xml = ct_xml(%w[GrpHdr/InitgPty])

      expect(xml).to satisfy_single_child_rules_of(
        SEPA::Profiles::ISO::SCT_09.with(features: { single_child_paths: %w[GrpHdr/InitgPty] })
      )
    end

    it 'does not check profiles without rules' do
      sdd = direct_debit_message(profile: SEPA::Profiles::EPC::SDD_08)
      sdd.add_transaction(direct_debit_transaction)

      expect { sdd.to_xml }.not_to raise_error
    end
  end
end
