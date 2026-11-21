# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Converter do
  include SEPA::Converter::InstanceMethods

  describe '.convert' do
    let(:model) do
      Class.new do
        extend SEPA::Converter

        attr_reader :label, :ref, :country, :amount

        convert :label, to: :text
        convert :ref, to: :identifier
        convert :country, to: :code
        convert :amount, to: :decimal
      end
    end

    it 'only sanitizes text, identifier and code setters' do
      instance = model.new
      instance.label = "José &\nCo\x00"
      instance.ref = "Réf_é\n1"
      instance.country = "fr\t"

      expect(instance.label).to eq('José & Co')
      expect(instance.ref).to eq('Réf_é 1')
      expect(instance.country).to eq('fr')
    end

    it 'keeps nil as nil' do
      instance = model.new
      instance.label = nil

      expect(instance.label).to be_nil
    end

    it 'converts decimals' do
      instance = model.new
      instance.amount = 1.345

      expect(instance.amount).to eq(BigDecimal('1.35'))
    end

    it 'raises for an unknown converter' do
      expect { Class.new { extend SEPA::Converter }.convert(:x, to: :unknown) }
        .to raise_error(ArgumentError, /does not exist/)
    end
  end

  describe :convert_decimal do
    it 'converts Integer to BigDecimal' do
      expect(convert_decimal(42)).to eq(BigDecimal('42.00'))
    end

    it 'converts Float to BigDecimal' do
      expect(convert_decimal(42.12)).to eq(BigDecimal('42.12'))
    end

    it 'rounds' do
      expect(convert_decimal(1.345)).to eq(BigDecimal('1.35'))
    end

    it 'does not touch nil' do
      expect(convert_decimal(nil)).to be_nil
    end

    it 'does not convert zero value' do
      expect(convert_decimal(0)).to be_nil
    end

    it 'does not convert negative value' do
      expect(convert_decimal(-3)).to be_nil
    end

    it 'does not convert invalid value' do
      expect(convert_decimal('xyz')).to be_nil
      expect(convert_decimal('NaN')).to be_nil
      expect(convert_decimal('Infinity')).to be_nil
    end
  end
end
