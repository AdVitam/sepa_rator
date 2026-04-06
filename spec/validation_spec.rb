# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Credit Transfer Initiation' do
  it 'validates example file' do
    expect(File.read('spec/examples/pain.001.002.03.xml')).to validate_against('pain.001.002.03.xsd')
    expect(File.read('spec/examples/pain.001.003.03.xml')).to validate_against('pain.001.003.03.xsd')
    expect(File.read('spec/examples/pain.001.001.09.xml')).to validate_against('pain.001.001.09.xsd')
    expect(File.read('spec/examples/pain.001.001.13.xml')).to validate_against('pain.001.001.13.xsd')
  end

  it 'does not validate dummy string' do
    expect('foo').not_to validate_against('pain.001.002.03.xsd')
    expect('foo').not_to validate_against('pain.001.003.03.xsd')
    expect('foo').not_to validate_against('pain.001.001.09.xsd')
    expect('foo').not_to validate_against('pain.001.001.13.xsd')
  end
end

RSpec.describe 'Direct Debit Initiation' do
  it 'validates example file' do
    expect(File.read('spec/examples/pain.008.002.02.xml')).to validate_against('pain.008.002.02.xsd')
    expect(File.read('spec/examples/pain.008.003.02.xml')).to validate_against('pain.008.003.02.xsd')
    expect(File.read('spec/examples/pain.008.001.08.xml')).to validate_against('pain.008.001.08.xsd')
    expect(File.read('spec/examples/pain.008.001.12.xml')).to validate_against('pain.008.001.12.xsd')
  end

  it 'does not validate dummy string' do
    expect('foo').not_to validate_against('pain.008.002.02.xsd')
    expect('foo').not_to validate_against('pain.008.003.02.xsd')
    expect('foo').not_to validate_against('pain.008.001.08.xsd')
    expect('foo').not_to validate_against('pain.008.001.12.xsd')
  end
end
