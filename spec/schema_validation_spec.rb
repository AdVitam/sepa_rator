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

    it 'does not register the same root twice' do
      Dir.mktmpdir do |dir|
        expect do
          2.times { described_class.register_schema_root(dir) }
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
end
