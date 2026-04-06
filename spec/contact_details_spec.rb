# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::ContactDetails do
  describe :initialize do
    it 'creates valid contact details with basic fields' do
      cd = SEPA::ContactDetails.new(
        name: 'John Doe',
        phone_number: '+49123456789',
        email_address: 'john@example.com'
      )
      expect(cd).to be_valid
    end

    it 'creates valid contact details with all fields' do
      cd = SEPA::ContactDetails.new(
        name_prefix: 'MIST',
        name: 'John Doe',
        phone_number: '+49123456789',
        mobile_number: '+49170123456',
        fax_number: '+49987654321',
        url_address: 'https://example.com',
        email_address: 'john@example.com',
        email_purpose: 'BUSI',
        job_title: 'CFO',
        responsibility: 'Payments',
        department: 'Finance',
        other_contacts: [{ channel_type: 'SKPE', id: 'john.doe' }],
        preferred_method: 'MAIL'
      )
      expect(cd).to be_valid
    end

    it 'is valid with no fields set' do
      cd = SEPA::ContactDetails.new
      expect(cd).to be_valid
    end
  end

  describe :name_prefix do
    it 'accepts valid name prefixes' do
      expect(SEPA::ContactDetails).to accept('DOCT', 'MADM', 'MISS', 'MIST', 'MIKS', for: :name_prefix)
    end

    it 'accepts nil' do
      expect(SEPA::ContactDetails).to accept(nil, for: :name_prefix)
    end

    it 'does not accept invalid name prefix' do
      expect(SEPA::ContactDetails).not_to accept('MR', 'PROF', 'invalid', for: :name_prefix)
    end
  end

  describe :name do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'John Doe', 'X' * 140, for: :name)
    end

    it 'does not accept values exceeding 140 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 141, for: :name)
    end
  end

  describe :phone_number do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, '+49123456789', 'X' * 30, for: :phone_number)
    end

    it 'does not accept values exceeding 30 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 31, for: :phone_number)
    end
  end

  describe :mobile_number do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, '+49170123456', 'X' * 30, for: :mobile_number)
    end

    it 'does not accept values exceeding 30 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 31, for: :mobile_number)
    end
  end

  describe :fax_number do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, '+49987654321', 'X' * 30, for: :fax_number)
    end

    it 'does not accept values exceeding 30 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 31, for: :fax_number)
    end
  end

  describe :url_address do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'https://example.com', 'X' * 2048, for: :url_address)
    end

    it 'does not accept values exceeding 2048 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 2049, for: :url_address)
    end
  end

  describe :email_address do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'user@example.com', 'X' * 2048, for: :email_address)
    end

    it 'does not accept values exceeding 2048 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 2049, for: :email_address)
    end
  end

  describe :email_purpose do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'BUSI', 'X' * 35, for: :email_purpose)
    end

    it 'does not accept values exceeding 35 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 36, for: :email_purpose)
    end
  end

  describe :job_title do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'CFO', 'X' * 35, for: :job_title)
    end

    it 'does not accept values exceeding 35 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 36, for: :job_title)
    end
  end

  describe :responsibility do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'Payments', 'X' * 35, for: :responsibility)
    end

    it 'does not accept values exceeding 35 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 36, for: :responsibility)
    end
  end

  describe :department do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'Finance', 'X' * 70, for: :department)
    end

    it 'does not accept values exceeding 70 characters' do
      expect(SEPA::ContactDetails).not_to accept('X' * 71, for: :department)
    end
  end

  describe :preferred_method do
    it 'accepts valid values' do
      expect(SEPA::ContactDetails).to accept(nil, 'LETT', 'MAIL', 'PHON', 'FAXX', 'CELL', 'ONLI', for: :preferred_method)
    end

    it 'does not accept invalid values' do
      expect(SEPA::ContactDetails).not_to accept('SMS', 'EMAIL', 'invalid', for: :preferred_method)
    end
  end

  describe :other_contacts do
    it 'accepts valid other_contacts' do
      cd = SEPA::ContactDetails.new(other_contacts: [{ channel_type: 'SKPE', id: 'user123' }])
      expect(cd).to be_valid
    end

    it 'accepts other_contacts without id' do
      cd = SEPA::ContactDetails.new(other_contacts: [{ channel_type: 'SKPE' }])
      expect(cd).to be_valid
    end

    it 'does not accept non-Array' do
      cd = SEPA::ContactDetails.new(other_contacts: 'invalid')
      expect(cd).not_to be_valid
      expect(cd.errors[:other_contacts]).to include('must be an Array')
    end

    it 'does not accept entry without channel_type' do
      cd = SEPA::ContactDetails.new(other_contacts: [{ id: 'user123' }])
      expect(cd).not_to be_valid
      expect(cd.errors[:other_contacts].first).to match(/entry 0 must have :channel_type/)
    end

    it 'does not accept channel_type exceeding 4 characters' do
      cd = SEPA::ContactDetails.new(other_contacts: [{ channel_type: 'ABCDE' }])
      expect(cd).not_to be_valid
      expect(cd.errors[:other_contacts].first).to match(/channel_type exceeds 4 characters/)
    end

    it 'does not accept id exceeding 128 characters' do
      cd = SEPA::ContactDetails.new(other_contacts: [{ channel_type: 'SKPE', id: 'X' * 129 }])
      expect(cd).not_to be_valid
      expect(cd.errors[:other_contacts].first).to match(/id exceeds 128 characters/)
    end

    it 'validates multiple entries independently' do
      cd = SEPA::ContactDetails.new(other_contacts: [
                                      { channel_type: 'SKPE', id: 'valid' },
                                      { channel_type: 'ABCDE' }
                                    ])
      expect(cd).not_to be_valid
      expect(cd.errors[:other_contacts].size).to eq(1)
    end
  end
end
