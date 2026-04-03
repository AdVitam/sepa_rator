# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Converter do
  include SEPA::Converter::InstanceMethods

  describe :convert_text do
    it 'should convert special chars' do
      expect(convert_text('10€')).to eq('10E')
      expect(convert_text('info@bundesbank.de')).to eq('info(at)bundesbank.de')
      expect(convert_text('abc_def')).to eq('abc-def')
    end

    it 'should not change allowed special character' do
      expect(convert_text('üöäÜÖÄß')).to eq('üöäÜÖÄß')
    end

    it 'should accept French accented characters' do
      expect(convert_text('àâéèêëïîôùûüÿçœæ')).to eq('àâéèêëïîôùûüÿçœæ')
    end

    it 'should accept Spanish accented characters' do
      expect(convert_text('áéíóúñÑ')).to eq('áéíóúñÑ')
    end

    it 'should strip non-Latin characters (CJK, Arabic, Cyrillic)' do
      expect(convert_text('Test你好мирعربي')).to eq('Test')
    end

    it 'should convert & to +' do
      expect(convert_text('A&B')).to eq('A+B')
    end

    it 'should remove non-SEPA special characters' do
      expect(convert_text('*$%')).to eq('')
    end

    it 'should convert line breaks' do
      expect(convert_text("one\ntwo")).to eq('one two')
      expect(convert_text("one\ntwo\n")).to eq('one two')
      expect(convert_text("\none\ntwo\n")).to eq('one two')
      expect(convert_text("one\n\ntwo")).to eq('one two')
    end

    it 'should convert number' do
      expect(convert_text(1234)).to eq('1234')
    end

    it 'should remove invalid chars' do
      expect(convert_text('"=<>!')).to eq('')
    end

    it 'should not touch valid chars' do
      expect(convert_text("abc-ABC-0123- ':?,-(+.)/")).to eq("abc-ABC-0123- ':?,-(+.)/")
    end

    it 'should not touch nil' do
      expect(convert_text(nil)).to eq(nil)
    end

    context 'encoding handling' do
      it 'should handle ISO-8859-1 encoded strings' do
        iso_string = 'Stra\xDFe'.dup.force_encoding('ISO-8859-1')
        result = convert_text(iso_string)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result).to include('Stra')
      end

      it 'should replace invalid byte sequences' do
        invalid_string = "test\xFF\xFEdata".dup.force_encoding('UTF-8')
        result = convert_text(invalid_string)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result).to include('test')
        expect(result).to include('data')
      end
    end

    context 'XML injection protection' do
      it 'should strip HTML/XML tags' do
        expect(convert_text('<script>alert(1)</script>')).to eq('scriptalert(1)/script')
      end

      it 'should strip CDATA markers' do
        expect(convert_text('test]]><![CDATA[injected')).to eq('testCDATAinjected')
      end

      it 'should strip XML entity references' do
        expect(convert_text('a&#x0;b&#60;c')).to eq('a+x0b+60c')
      end

      it 'should strip null bytes' do
        expect(convert_text("test\x00injection")).to eq('testinjection')
      end
    end
  end

  describe :convert_decimal do
    it 'should convert Integer to BigDecimal' do
      expect(convert_decimal(42)).to eq(BigDecimal('42.00'))
    end

    it 'should convert Float to BigDecimal' do
      expect(convert_decimal(42.12)).to eq(BigDecimal('42.12'))
    end

    it 'should round' do
      expect(convert_decimal(1.345)).to eq(BigDecimal('1.35'))
    end

    it 'should not touch nil' do
      expect(convert_decimal(nil)).to eq(nil)
    end

    it 'should not convert zero value' do
      expect(convert_decimal(0)).to eq(nil)
    end

    it 'should not convert negative value' do
      expect(convert_decimal(-3)).to eq(nil)
    end

    it 'should not convert invalid value' do
      expect(convert_decimal('xyz')).to eq(nil)
      expect(convert_decimal('NaN')).to eq(nil)
      expect(convert_decimal('Infinity')).to eq(nil)
    end
  end
end
