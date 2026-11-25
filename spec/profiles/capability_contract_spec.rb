# frozen_string_literal: true

require 'spec_helper'

# Every profile must either serialise an optional element into XSD-valid XML
# or reject it before generation with a precise error, never in between.
RSpec.describe SEPA::Profile, '#supports?' do
  contact = -> { SEPA::ContactDetails.new(name: 'Jane Doe', phone_number: '+43-1234567') }
  structured = { country_code: 'AT', street_name: 'Hauptstrasse', building_number: '1', post_code: '1010', town_name: 'Wien' }.freeze

  scenarios = [
    { field: 'account.initiating_party_lei', capability: :lei,
      account: -> { { initiating_party_lei: SEPA::TestData::LEI } } },
    { field: 'account.agent_lei', capability: :agent_lei,
      account: -> { { agent_lei: SEPA::TestData::LEI } } },
    { field: 'transaction.agent_lei', capability: :agent_lei,
      transaction: -> { { agent_lei: SEPA::TestData::LEI } } },
    { field: 'account.contact_details', capability: :contact_details,
      account: -> { { contact_details: contact.call } } },
    { field: 'transaction.creditor_contact_details', capability: :contact_details, family: :credit_transfer,
      transaction: -> { { creditor_contact_details: contact.call } } },
    { field: 'transaction.debtor_contact_details', capability: :contact_details, family: :direct_debit,
      transaction: -> { { debtor_contact_details: contact.call } } },
    { field: 'account.address', capability: :account_address,
      account: -> { { address: :address } } },
    { field: 'creditor_address', capability: :structured_address, family: :credit_transfer,
      transaction: -> { { creditor_address: SEPA::CreditorAddress.new(**structured) } } },
    { field: 'debtor_address', capability: :structured_address, family: :direct_debit,
      transaction: -> { { debtor_address: SEPA::DebtorAddress.new(**structured) } } }
  ].freeze

  def account_address(profile)
    klass = profile.family == :credit_transfer ? SEPA::DebtorAddress : SEPA::CreditorAddress
    if profile.features.requires_structured_address
      klass.new(country_code: 'AT', street_name: 'Hauptstrasse', building_number: '1',
                post_code: '1010', town_name: 'Wien')
    else
      klass.new(country_code: 'AT', address_line1: 'Hauptstrasse 1', address_line2: '1010 Wien')
    end
  end

  def message_with(profile, scenario)
    account = scenario.fetch(:account, -> { {} }).call
                      .transform_values { |value| value == :address ? account_address(profile) : value }
    transaction = scenario.fetch(:transaction, -> { {} }).call
    if profile.family == :credit_transfer
      build_ct(profile, account) { |sct| sct.add_transaction(credit_transfer_transaction(transaction)) }
    else
      build_dd(profile, account) { |sdd| sdd.add_transaction(direct_debit_transaction(transaction)) }
    end
  end

  profiles = SEPA::ProfileRegistry.all.select { |profile| profile.id.match?(/\A(iso|epc|cfonb|nl|gb|at|dk|sps)\./) }

  profiles.each do |profile|
    context profile.id do
      scenarios.each do |scenario|
        next if scenario[:family] && scenario[:family] != profile.family

        if profile.supports?(scenario[:capability])
          it "serialises #{scenario[:field]} into XSD-valid XML" do
            expect { message_with(profile, scenario).to_xml }.not_to raise_error
          end
        else
          it "rejects #{scenario[:field]} before generation" do
            expect { message_with(profile, scenario) }
              .to raise_error(SEPA::ValidationError, /#{Regexp.escape(scenario[:field])} requires capability :#{scenario[:capability]}/)
          end
        end
      end
    end
  end
end
