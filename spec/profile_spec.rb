# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Profile do
  # Fake stages must respond to .call to satisfy the profile's
  # registration-time shape check.
  def self.fake_stage(name)
    Class.new do
      define_singleton_method(:call) { |_ctx| nil }
      define_singleton_method(:inspect) { "FakeStage(#{name})" }
    end
  end
  let(:stage_a) { self.class.fake_stage(:a) }
  let(:stage_b) { self.class.fake_stage(:b) }
  let(:stage_c) { self.class.fake_stage(:c) }
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

    it 'concatenates capabilities and de-duplicates when given a raw Array' do
      derived = base.with(capabilities: %i[lei mandate_related_info])
      expect(derived.capabilities).to contain_exactly(:uetr, :lei, :mandate_related_info)
    end

    it 'drops parent capabilities when given `{ replace: [...] }`' do
      derived = base.with(capabilities: { replace: [].freeze })
      expect(derived.capabilities).to be_empty
    end

    it 'appends capabilities when given `{ add: [...] }`' do
      derived = base.with(capabilities: { add: %i[mandate_related_info] })
      expect(derived.capabilities).to contain_exactly(:uetr, :lei, :mandate_related_info)
    end

    it 'supports the same replace/add operators for validators' do
      validator_c = Class.new
      expect(base.with(validators: { replace: [validator_c] }).validators).to eq [validator_c]
      expect(base.with(validators: { add: [validator_c] }).validators).to eq [validator_a, validator_c]
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

    it 'raises on an unknown stage-list operation instead of a cryptic pattern error' do
      expect { base.with(transaction_stages: { replaces: stage_a, with: stage_c }) }
        .to raise_error(ArgumentError, /unsupported operation/)
    end

    it 'raises on an unknown list Hash operation for capabilities' do
      expect { base.with(capabilities: { replaced: %i[lei] }) }
        .to raise_error(ArgumentError, /unsupported Hash operation/)
    end

    it 'raises on a non-Array, non-Hash list value' do
      expect { base.with(capabilities: :uetr) }
        .to raise_error(ArgumentError, /expected Array or Hash/)
    end
  end

  describe '.new validation' do
    it 'rejects an invalid family symbol' do
      expect do
        described_class.new(
          id: 'bad', family: :cross_border, iso_schema: 'x', xsd_path: 'x', namespace: 'x',
          features: SEPA::ProfileFeatures.default, validators: [].freeze, capabilities: [].freeze,
          transaction_stages: [].freeze, payment_info_stages: [].freeze,
          group_header_stages: [].freeze, accept_transaction: nil
        )
      end.to raise_error(ArgumentError, /invalid family :cross_border/)
    end

    it 'rejects a stage list entry that does not respond to .call' do
      bogus_stage = Object.new
      expect do
        described_class.new(
          id: 'bad', family: :credit_transfer, iso_schema: 'x', xsd_path: 'x', namespace: 'x',
          features: SEPA::ProfileFeatures.default, validators: [].freeze, capabilities: [].freeze,
          transaction_stages: [bogus_stage].freeze, payment_info_stages: [].freeze,
          group_header_stages: [].freeze, accept_transaction: nil
        )
      end.to raise_error(ArgumentError, /transaction_stages contains .* which does not respond to \.call/)
    end
  end
end

RSpec.describe SEPA::ProfileFeatures do
  describe '.default' do
    it 'returns sensible defaults for the generic ISO profile' do
      features = described_class.default
      expect(features.bic_tag).to eq :BICFI
      expect(features.wrap_date).to be true
      expect(features.charset).to eq SEPA::Charset::ISO
      expect(features.extras).to eq({})
    end

    it 'defaults instr_for_cdtr_agt_code_type to the ISO Instruction3Code enum' do
      expect(described_class.default.instr_for_cdtr_agt_code_type).to eq :instruction3_code
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

  it 'is idempotent when the same Profile object is registered twice' do
    described_class.register(profile)
    expect { described_class.register(profile) }.not_to raise_error
  end

  it 'raises when a different profile is registered under an existing id' do
    described_class.register(profile)
    duplicate = profile.with(namespace: 'urn:other')
    expect { described_class.register(duplicate) }
      .to raise_error(ArgumentError, /already registered/)
  end

  it 'raises when an alias collides with a different profile' do
    described_class.register(profile, aliases: %w[shortcut])
    other = profile.with(id: 'test.other')
    expect { described_class.register(other, aliases: %w[shortcut]) }
      .to raise_error(ArgumentError, /already registered under "shortcut"/)
  end

  describe '.set_country_default' do
    let(:dd_profile) do
      SEPA::Profile.new(
        id: 'test.dd', family: :direct_debit, iso_schema: 'pain.008.001.08',
        xsd_path: 'iso/pain.008.001.08.xsd', namespace: 'urn:test',
        features: SEPA::ProfileFeatures.default, validators: [].freeze,
        capabilities: [].freeze, transaction_stages: [].freeze,
        payment_info_stages: [].freeze, group_header_stages: [].freeze,
        accept_transaction: nil
      )
    end

    it 'raises when the profile family does not match the requested family' do
      expect do
        described_class.set_country_default(family: :credit_transfer, country: :xx,
                                            version: :latest, profile: dd_profile)
      end.to raise_error(ArgumentError, /profile "test\.dd" is for family :direct_debit, not :credit_transfer/)
    end
  end

  describe '.recommended' do
    # Save/restore the two registry maps this describe block mutates.
    around do |example|
      saved_defaults = described_class.instance_variable_get(:@country_defaults)
      saved_known = described_class.instance_variable_get(:@known_countries)
      example.run
    ensure
      described_class.instance_variable_set(:@country_defaults, saved_defaults)
      described_class.instance_variable_set(:@known_countries, saved_known)
    end

    it 'raises ArgumentError for an unknown family' do
      expect do
        SEPA::ProfileRegistry.recommended(family: :cross_border, country: :fr)
      end.to raise_error(ArgumentError, /Unknown family: :cross_border/)
    end

    it 'raises ArgumentError when the family has no default profiles registered at all' do
      # Synthetic defaults: only :credit_transfer is populated, :fr has an
      # entry, but no :nil fallback. Querying country :xx (in the
      # allow-list but not in the per-country hash) falls through to nil
      # which is also absent → "No default profiles registered".
      described_class.instance_variable_set(
        :@country_defaults, credit_transfer: { fr: { latest: :dummy } }
      )
      described_class.instance_variable_set(:@known_countries, Set.new(%i[fr xx]))

      expect do
        SEPA::ProfileRegistry.recommended(family: :credit_transfer, country: :xx)
      end.to raise_error(ArgumentError, /No default profiles registered for family=:credit_transfer/)
    end
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

  it 'raises on a typoed operation key' do
    expect { described_class.merge([a, b], { replaces: a, with: c }) }
      .to raise_error(ArgumentError, /unsupported operation/)
  end

  it 'replaces the whole list with an Array' do
    expect(described_class.merge([a, b], [c])).to eq [c]
  end
end

RSpec.describe SEPA::ProfileRegistry, '.all' do
  let(:charset_by_prefix) do
    {
      'iso.pain.001.002' => SEPA::Charset::EPC, 'iso.pain.001.003' => SEPA::Charset::EPC,
      'iso.pain.008.002' => SEPA::Charset::EPC, 'iso.pain.008.003' => SEPA::Charset::EPC,
      'iso.' => SEPA::Charset::ISO, 'epc.' => SEPA::Charset::EPC, 'cfonb.' => SEPA::Charset::EPC,
      'nl.' => SEPA::Charset::EPC, 'gb.' => SEPA::Charset::EPC, 'dk.' => SEPA::Charset::DK,
      'at.' => SEPA::Charset::AT, 'sps.' => SEPA::Charset::SPS
    }
  end

  it 'gives every registered profile the charset of its family' do
    profiles = described_class.all
    expect(profiles.size).to be > 40

    profiles.each do |profile|
      expected = charset_by_prefix.find { |prefix, _| profile.id.start_with?(prefix) }&.last

      expect(profile.features.charset).to eq(expected), "#{profile.id} uses #{profile.features.charset.id}"
    end
  end
end
