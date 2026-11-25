# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA do
  # At 10:05 UTC only UTC+14 (Kiritimati) has reached 2026-11-25, so any other system zone works
  let(:now) { Time.utc(2026, 11, 24, 10, 5) }
  let(:local_date) { Date.new(2026, 11, 25) }

  around do |example|
    zone = Time.zone
    travel_to(now) { example.run }
  ensure
    Time.zone = zone
  end

  context 'with an application time zone ahead of UTC' do
    before { Time.zone = 'Pacific/Kiritimati' }

    it 'accepts a mandate signed on the local date' do
      transaction = SEPA::DirectDebitTransaction.new(direct_debit_transaction(mandate_date_of_signature: local_date))
      expect(transaction.errors_on(:mandate_date_of_signature)).to be_empty
    end

    it 'validates the credit transfer requested date against the local date' do
      expect(SEPA::CreditTransferTransaction).to accept(local_date, for: :requested_date)
      expect(SEPA::CreditTransferTransaction).not_to accept(local_date.prev_day, for: :requested_date)
    end

    it 'requires the direct debit requested date to be after the local date' do
      expect(SEPA::DirectDebitTransaction).to accept(local_date.next, for: :requested_date)
      expect(SEPA::DirectDebitTransaction).not_to accept(local_date, for: :requested_date)
    end
  end

  context 'without an application time zone' do
    before { Time.zone = nil }

    it 'rejects a mandate signed on the local date as being in the future' do
      transaction = SEPA::DirectDebitTransaction.new(direct_debit_transaction(mandate_date_of_signature: local_date))
      expect(transaction.errors_on(:mandate_date_of_signature)).to include('is in the future')
    end
  end
end
