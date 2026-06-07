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
      described_class.register_schema_root('/tmp/extra_schemas/.')

      expect(described_class.schema_roots.first).to eq('/tmp/extra_schemas')
    end

    it 'does not register the same root twice' do
      expect do
        2.times { described_class.register_schema_root('/tmp/extra_schemas') }
      end.to change { described_class.schema_roots.size }.by(1)
    end

    it 'is exposed as SEPA.register_schema_root' do
      SEPA.register_schema_root('/tmp/extra_schemas')

      expect(described_class.schema_roots).to include('/tmp/extra_schemas')
    end
  end

  describe '#read_xsd' do
    it 'resolves an XSD from a registered root' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'custom'))
        FileUtils.cp(
          File.join(described_class::DEFAULT_SCHEMA_ROOT, 'iso/pain.001.001.09.xsd'),
          File.join(dir, 'custom/pain.001.001.09.xsd')
        )
        described_class.register_schema_root(dir)

        xsd = validator.send(:read_xsd, stub_profile('custom/pain.001.001.09.xsd'))

        expect(xsd).to be_a(Nokogiri::XML::Schema)
      end
    end

    it 'raises an actionable error naming the companion gem when its XSD is missing' do
      described_class.schema_roots.replace([described_class::DEFAULT_SCHEMA_ROOT])

      expect { validator.send(:read_xsd, stub_profile('at/missing.xsd')) }
        .to raise_error(SEPA::Error, /Add gem 'sepa_rator-at' to your Gemfile to validate profile test\.profile/)
    end

    it 'lists the searched roots when no companion gem matches the prefix' do
      expect { validator.send(:read_xsd, stub_profile('nowhere/missing.xsd')) }
        .to raise_error(SEPA::Error, /Searched roots: .*schema/)
    end
  end
end
