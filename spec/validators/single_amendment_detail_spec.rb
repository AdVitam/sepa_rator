# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SEPA::Validators::SingleAmendmentDetail do
  let(:profile) { SEPA::Profiles::AT::SDD_08.with(validators: [described_class]) }
  let(:creditor) { SEPA::CreditorAccount.new(name: 'Old creditor', iban: SEPA::TestData::DEBTOR_IBAN, creditor_identifier: SEPA::TestData::CREDITOR_IDENTIFIER) }

  def add(attrs = {}, with_profile: profile)
    direct_debit_message(profile: with_profile).add_transaction(direct_debit_transaction(attrs))
  end

  it 'accepts a transaction without amendment' do
    expect { add({}) }.not_to raise_error
  end

  {
    original_mandate_id: 'OLD-MANDATE',
    original_debtor_account: SEPA::TestData::DEBTOR_IBAN,
    same_mandate_new_debtor_agent: true
  }.each do |field, value|
    it "accepts #{field} alone" do
      expect { add({ field => value }) }.not_to raise_error
    end
  end

  it 'accepts original_creditor_account alone' do
    expect { add({ original_creditor_account: creditor }) }.not_to raise_error
  end

  it 'rejects several amendment details and names them' do
    expect do
      add({ original_mandate_id: 'OLD-MANDATE', original_creditor_account: creditor })
    end.to raise_error(SEPA::ValidationError, /only one amendment detail.*original_mandate_id, original_creditor_account/)
  end

  it 'rejects the mutually exclusive debtor account and new debtor agent together' do
    expect do
      add({ original_debtor_account: SEPA::TestData::DEBTOR_IBAN, same_mandate_new_debtor_agent: true })
    end.to raise_error(SEPA::ValidationError, /original_debtor_account, same_mandate_new_debtor_agent/)
  end

  it 'ignores a false same_mandate_new_debtor_agent' do
    expect { add({ original_mandate_id: 'OLD-MANDATE', same_mandate_new_debtor_agent: false }) }.not_to raise_error
  end

  it 'is a no-op on profiles without a single-child AmdmntInfDtls' do
    expect do
      add({ original_mandate_id: 'OLD-MANDATE', original_creditor_account: creditor }, with_profile: SEPA::Profiles::EPC::SDD_08)
    end.not_to raise_error
  end

  it 'is a no-op on transactions without amendment fields' do
    ct = SEPA::CreditTransferTransaction.new(credit_transfer_transaction)
    expect { described_class.validate(ct, profile) }.not_to raise_error
  end
end
