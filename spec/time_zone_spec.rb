# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/time/zones'

RSpec.describe SEPA, '.today' do
  around do |example|
    zone = Time.zone
    Time.zone = 'Pacific/Kiritimati' # UTC+14: already tomorrow almost everywhere
    example.run
  ensure
    Time.zone = zone
  end

  it 'uses the application time zone' do
    travel_to(Time.utc(2026, 11, 24, 12, 0)) do
      expect(described_class.today).to eq(Date.new(2026, 11, 25))
    end
  end

  it "accepts a mandate signed today in the application's time zone" do
    travel_to(Time.utc(2026, 11, 24, 12, 0)) do
      today = Time.zone.today
      transaction = SEPA::DirectDebitTransaction.new(
        direct_debit_transaction(mandate_date_of_signature: today, requested_date: today + 2)
      )
      expect(transaction.errors_on(:mandate_date_of_signature)).to be_empty
    end
  end

  it 'falls back to the system date without ActiveSupport time zones' do
    allow(Date).to receive(:respond_to?).and_call_original
    allow(Date).to receive(:respond_to?).with(:current).and_return(false)
    expect(described_class.today).to eq(Date.today)
  end
end
