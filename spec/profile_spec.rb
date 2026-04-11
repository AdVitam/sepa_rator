# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profile do
  let(:stage_a) { Class.new }
  let(:stage_b) { Class.new }
  let(:stage_c) { Class.new }
  let(:validator_a) { Class.new }
  let(:validator_b) { Class.new }

  let(:base) do
    described_class.new(
      id: 'iso.pain.001.001.09',
      family: :credit_transfer,
      iso_schema: 'pain.001.001.09',
      xsd_path: 'iso/pain.001.001.09.xsd',
      namespace: 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.09',
      features: SEPA::ProfileFeatures.default,
      validators: [validator_a].freeze,
      capabilities: %i[uetr lei].freeze,
      transaction_stages: [stage_a, stage_b].freeze,
      payment_info_stages: [].freeze,
      group_header_stages: [].freeze,
      accept_transaction: nil
    )
  end

  describe '#supports?' do
    it 'returns true for registered capabilities' do
      expect(base.supports?(:uetr)).to be true
      expect(base.supports?(:lei)).to be true
    end

    it 'returns false for unknown capabilities' do
      expect(base.supports?(:mandate_related_info)).to be false
    end
  end

  describe '#accepts?' do
    it 'returns true when accept_transaction is nil' do
      expect(base.accepts?(double)).to be true
    end

    it 'delegates to accept_transaction lambda when present' do
      profile = base.with(accept_transaction: ->(txn, _p) { txn.currency == 'EUR' })
      eur = double(currency: 'EUR')
      usd = double(currency: 'USD')
      expect(profile.accepts?(eur)).to be true
      expect(profile.accepts?(usd)).to be false
    end
  end

  describe '#with' do
    it 'returns a new profile, leaving the original untouched' do
      derived = base.with(id: 'epc.sct.09')
      expect(derived.id).to eq 'epc.sct.09'
      expect(base.id).to eq 'iso.pain.001.001.09'
      expect(derived).not_to equal(base)
    end

    it 'merges features field-by-field via ProfileFeatures#merge' do
      derived = base.with(features: { regulatory_reporting_version: :v10 })
      expect(derived.features.regulatory_reporting_version).to eq :v10
      expect(derived.features.bic_tag).to eq base.features.bic_tag
    end

    it 'concatenates validators' do
      derived = base.with(validators: [validator_b])
      expect(derived.validators).to eq [validator_a, validator_b]
    end

    it 'concatenates capabilities and de-duplicates' do
      derived = base.with(capabilities: %i[lei mandate_related_info])
      expect(derived.capabilities).to contain_exactly(:uetr, :lei, :mandate_related_info)
    end

    it 'replaces a single stage via { replace:, with: }' do
      derived = base.with(transaction_stages: { replace: stage_a, with: stage_c })
      expect(derived.transaction_stages).to eq [stage_c, stage_b]
    end

    it 'inserts a stage after a given anchor' do
      derived = base.with(transaction_stages: { insert_after: stage_a, stage: stage_c })
      expect(derived.transaction_stages).to eq [stage_a, stage_c, stage_b]
    end

    it 'inserts a stage before a given anchor' do
      derived = base.with(transaction_stages: { insert_before: stage_b, stage: stage_c })
      expect(derived.transaction_stages).to eq [stage_a, stage_c, stage_b]
    end

    it 'removes a stage' do
      derived = base.with(transaction_stages: { remove: stage_a })
      expect(derived.transaction_stages).to eq [stage_b]
    end

    it 'replaces the full stage list when given an Array' do
      derived = base.with(transaction_stages: [stage_c])
      expect(derived.transaction_stages).to eq [stage_c]
    end

    it 'overrides scalar fields outright' do
      derived = base.with(xsd_path: 'dk/pain.001.001.09_AXZ_GBIC5.xsd', namespace: 'dk://foo')
      expect(derived.xsd_path).to eq 'dk/pain.001.001.09_AXZ_GBIC5.xsd'
      expect(derived.namespace).to eq 'dk://foo'
    end
  end
end

RSpec.describe SEPA::ProfileFeatures do
  describe '.default' do
    it 'returns sensible defaults for the generic ISO profile' do
      features = described_class.default
      expect(features.bic_tag).to eq :BICFI
      expect(features.wrap_date).to be true
      expect(features.charset).to eq :iso_latin
      expect(features.extras).to eq({})
    end
  end

  describe '#merge' do
    it 'overrides known fields' do
      merged = described_class.default.merge(regulatory_reporting_version: :v10)
      expect(merged.regulatory_reporting_version).to eq :v10
    end

    it 'deep-merges the extras hash' do
      original = described_class.default.merge(extras: { foo: 1 })
      merged = original.merge(extras: { bar: 2 })
      expect(merged.extras).to eq(foo: 1, bar: 2)
    end
  end

  describe '#[]' do
    it 'reads named fields' do
      expect(described_class.default[:bic_tag]).to eq :BICFI
    end

    it 'falls back to extras for unknown keys' do
      features = described_class.default.merge(extras: { custom: 'value' })
      expect(features[:custom]).to eq 'value'
    end
  end
end

RSpec.describe SEPA::ProfileRegistry do
  # Snapshot the registry state before each example and restore it afterwards
  # so these tests don't clobber the global profile catalog used by other specs.
  around do |example|
    saved = described_class.instance_variable_get(:@profiles).dup
    described_class.instance_variable_set(:@profiles, {})
    example.run
  ensure
    described_class.instance_variable_set(:@profiles, saved)
  end

  let(:profile) do
    SEPA::Profile.new(
      id: 'test.profile',
      family: :credit_transfer,
      iso_schema: 'pain.001.001.09',
      xsd_path: 'iso/pain.001.001.09.xsd',
      namespace: 'urn:test',
      features: SEPA::ProfileFeatures.default,
      validators: [].freeze,
      capabilities: [].freeze,
      transaction_stages: [].freeze,
      payment_info_stages: [].freeze,
      group_header_stages: [].freeze,
      accept_transaction: nil
    )
  end

  it 'registers a profile and retrieves it by id' do
    described_class.register(profile)
    expect(described_class['test.profile']).to equal(profile)
  end

  it 'supports aliases' do
    described_class.register(profile, aliases: %w[pain.001.001.09])
    expect(described_class['pain.001.001.09']).to equal(profile)
  end

  it 'raises ArgumentError for unknown ids' do
    expect { described_class['nope'] }.to raise_error(ArgumentError, /Unknown profile/)
  end

  it 'lists all registered profiles without duplicates' do
    described_class.register(profile, aliases: %w[alias1 alias2])
    expect(described_class.all).to contain_exactly(profile)
  end
end

RSpec.describe SEPA::StageList do
  let(:a) { :a }
  let(:b) { :b }
  let(:c) { :c }

  it 'replaces a stage' do
    expect(described_class.merge([a, b], { replace: a, with: c })).to eq [c, b]
  end

  it 'inserts after' do
    expect(described_class.merge([a, b], { insert_after: a, stage: c })).to eq [a, c, b]
  end

  it 'inserts before' do
    expect(described_class.merge([a, b], { insert_before: b, stage: c })).to eq [a, c, b]
  end

  it 'removes' do
    expect(described_class.merge([a, b], { remove: a })).to eq [b]
  end

  it 'replaces the whole list with an Array' do
    expect(described_class.merge([a, b], [c])).to eq [c]
  end
end
