# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Charset do
  let(:issue_example) { 'José García & Co.' }

  describe '.sanitize' do
    it 'does not touch nil' do
      expect(described_class.sanitize(nil)).to be_nil
    end

    it 'converts non-string values to a string' do
      expect(described_class.sanitize(1234)).to eq('1234')
    end

    it 'returns an equal string for already valid ASCII' do
      expect(described_class.sanitize("abc-ABC-0123- ':?,-(+.)/")).to eq("abc-ABC-0123- ':?,-(+.)/")
    end

    it 'keeps any Unicode text' do
      expect(described_class.sanitize('José 你好 мир')).to eq('José 你好 мир')
    end

    it 'collapses newlines and tabs to one space and strips' do
      expect(described_class.sanitize("\none\n\ntwo\tthree\n")).to eq('one two three')
    end

    it 'removes NUL and C0 control characters' do
      expect(described_class.sanitize("test\x00in\x01jection")).to eq('testinjection')
    end

    it 'removes invalid UTF-8 bytes' do
      result = described_class.sanitize((+"abc\xFF").force_encoding('UTF-8'))

      expect(result).to eq('abc')
      expect(result).to be_valid_encoding
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it 'transcodes ISO-8859-1 input' do
      result = described_class.sanitize((+"Stra\xDFe").force_encoding('ISO-8859-1'))

      expect(result).to eq('Straße')
      expect(result.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe 'constants' do
    it 'are frozen with distinct Symbol ids' do
      charsets = [described_class::ISO, described_class::EPC, described_class::DK,
                  described_class::AT, described_class::SPS]

      expect(charsets).to all(be_frozen)
      expect(charsets.map(&:id)).to all(be_a(Symbol))
      expect(charsets.map(&:id).uniq.size).to eq(charsets.size)
    end
  end

  describe 'ISO' do
    subject(:charset) { described_class::ISO }

    it 'keeps any Unicode' do
      expect(charset.text(issue_example)).to eq(issue_example)
      expect(charset.text('10€ info@x.de a_b 你好 "=<>!')).to eq('10€ info@x.de a_b 你好 "=<>!')
    end

    it 'sanitizes like Charset.sanitize' do
      expect(charset.text("one\ntwo\x00")).to eq('one two')
      expect(charset.identifier("Réf_é\n1")).to eq('Réf_é 1')
    end

    it 'does not restrict identifiers' do
      expect(charset.identifier('Réf_é ü&')).to eq('Réf_é ü&')
    end

    it 'does not touch nil' do
      expect(charset.text(nil)).to be_nil
      expect(charset.identifier(nil)).to be_nil
    end

    it 'leaves markup characters to the XML builder' do
      expect(charset.text('<script>alert(1)</script>')).to eq('<script>alert(1)</script>')
      expect(charset.text('test]]><![CDATA[injected')).to eq('test]]><![CDATA[injected')
      expect(charset.text('a&#x0;b&#60;c')).to eq('a&#x0;b&#60;c')
    end

    it 'strips NUL bytes' do
      expect(charset.text("test\x00injection")).to eq('testinjection')
    end
  end

  describe 'EPC' do
    subject(:charset) { described_class::EPC }

    it 'transliterates and rewrites the issue example' do
      expect(charset.text(issue_example)).to eq('Jose Garcia + Co.')
    end

    it 'keeps the EPC character set' do
      expect(charset.text("abc-ABC-0123- ':?,-(+.)/")).to eq("abc-ABC-0123- ':?,-(+.)/")
    end

    it 'replaces special characters (EPC best practices)' do
      expect(charset.text('10€')).to eq('10E')
      expect(charset.text('info@bundesbank.de')).to eq('info(at)bundesbank.de')
      expect(charset.text('abc_def')).to eq('abc-def')
      expect(charset.text('A&B')).to eq('A+B')
    end

    it 'transliterates letters one to one' do
      expect(charset.text('Straße Æ Œuvre Łódź')).to eq('Strase A Ouvre Lodz')
      expect(charset.text('àâéèêëïîôùûüÿçœæ')).to eq('aaeeeeiiouuuycoa')
      expect(charset.text('áéíóúñÑ')).to eq('aeiounN')
      expect(charset.text('üöäÜÖÄß')).to eq('uoaUOAs')
    end

    it 'drops characters without transliteration' do
      expect(charset.text('Test你好мирعربي')).to eq('Test')
      expect(charset.text('"=<>!')).to eq('')
      expect(charset.text('*$%')).to eq('')
    end

    it 'sanitizes before filtering' do
      expect(charset.text("one\ntwo\n")).to eq('one two')
      expect(charset.text(1234)).to eq('1234')
      expect(charset.text(nil)).to be_nil
    end

    it 'strips markup characters' do
      expect(charset.text('<script>alert(1)</script>')).to eq('scriptalert(1)/script')
      expect(charset.text('test]]><![CDATA[injected')).to eq('testCDATAinjected')
      expect(charset.text('a&#x0;b&#60;c')).to eq('a+x0b+60c')
      expect(charset.text("test\x00injection")).to eq('testinjection')
    end

    it 'never produces characters outside the set' do
      expect(charset.text('Ünï©ödé ™ ǅ ƒ "=<>!*$%@_&€ 你好')).to match(%r{\A[A-Za-z0-9 /\-?:().,'+]*\z})
    end

    it 'applies RestrictedIdentificationSEPA1 to identifiers' do
      expect(charset.identifier('Réf_é ü&')).to eq('Ref-e u+')
      expect(charset.identifier(nil)).to be_nil
    end
  end

  describe 'DK' do
    subject(:charset) { described_class::DK }

    it 'keeps the ampersand and transliterates accents' do
      expect(charset.text(issue_example)).to eq('Jose Garcia & Co.')
    end

    it 'keeps the Danish/German extension characters' do
      expect(charset.text('üöäÜÖÄß*$%')).to eq('üöäÜÖÄß*$%')
    end

    it 'still replaces characters outside the set' do
      expect(charset.text('10€ info@bundesbank.de abc_def')).to eq('10E info(at)bundesbank.de abc-def')
      expect(charset.text('"=<>!')).to eq('')
    end

    it 'strips markup characters but keeps the ampersand' do
      expect(charset.text('<script>alert(1)</script>')).to eq('scriptalert(1)/script')
      expect(charset.text('a&#x0;b&#60;c')).to eq('a&x0b&60c')
    end

    it 'applies RestrictedIdentificationSEPA1 to identifiers' do
      expect(charset.identifier('Réf_é ü&')).to eq('Ref-e u+')
      expect(charset.identifier(nil)).to be_nil
    end
  end

  describe 'AT' do
    subject(:charset) { described_class::AT }

    it 'keeps the ampersand and transliterates accents' do
      expect(charset.text(issue_example)).to eq('Jose Garcia & Co.')
    end

    it 'keeps characters of the Austrian XSD set' do
      expect(charset.text('äöüßÄÖÜ a@b_c 10€ §%!=#~;*{}[]\\°^><"|$')).to eq('äöüßÄÖÜ a@b_c 10€ §%!=#~;*{}[]\\°^><"|$')
    end

    it 'drops characters outside the set' do
      expect(charset.text('Test你好')).to eq('Test')
    end

    it 'applies RestrictedIdentificationSEPA1 to identifiers' do
      expect(charset.identifier('Réf_é ü&')).to eq('Ref-e u+')
      expect(charset.identifier(nil)).to be_nil
    end
  end

  describe 'SPS' do
    subject(:charset) { described_class::SPS }

    it 'keeps the Swiss set unchanged' do
      expect(charset.text(issue_example)).to eq(issue_example)
      expect(charset.text('Łódź € Ș ț "=<>!@_*$%')).to eq('Łódź € Ș ț "=<>!@_*$%')
    end

    it 'drops characters outside the set' do
      expect(charset.text('Test你好')).to eq('Test')
    end

    it 'never produces characters outside the set' do
      expect(charset.text('Aǅ ƒ ǆ 你好 ™ ‰ é €')).to match(/\A[ -~ -ſȘ-ț€]*\z/)
    end

    it 'applies RestrictedIdentificationSEPA1 to identifiers' do
      expect(charset.identifier('Réf_é ü&')).to eq('Ref-e u+')
      expect(charset.identifier(nil)).to be_nil
    end
  end
end
