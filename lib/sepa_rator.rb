# frozen_string_literal: true

require 'active_model'
require 'bigdecimal'
require 'nokogiri'
require 'ibandit'

require 'sepa_rator/error'
require 'sepa_rator/profile'
require 'sepa_rator/builders/stage'
require 'sepa_rator/converter'
require 'sepa_rator/validator'
require 'sepa_rator/nested_model_validator'
require 'sepa_rator/concerns/schema_validation'
require 'sepa_rator/concerns/xml_builder'
require 'sepa_rator/concerns/regulatory_reporting_validator'
require 'sepa_rator/account'
require 'sepa_rator/account/debtor_account'
require 'sepa_rator/account/address'
require 'sepa_rator/account/contact_details'
require 'sepa_rator/account/debtor_address'
require 'sepa_rator/account/creditor_account'
require 'sepa_rator/account/creditor_address'
require 'sepa_rator/transaction'
require 'sepa_rator/transaction/direct_debit_transaction'
require 'sepa_rator/transaction/credit_transfer_transaction'

# Builder stages — must load before profiles (profiles reference stage classes).
require 'sepa_rator/builders/credit_transfer/group_header'
require 'sepa_rator/builders/credit_transfer/payment_information'
require 'sepa_rator/builders/credit_transfer/transaction/payment_id'
require 'sepa_rator/builders/credit_transfer/transaction/amount'
require 'sepa_rator/builders/credit_transfer/transaction/credit_transfer_mandate'
require 'sepa_rator/builders/credit_transfer/transaction/ultimate_debtor'
require 'sepa_rator/builders/credit_transfer/transaction/creditor_agent'
require 'sepa_rator/builders/credit_transfer/transaction/creditor'
require 'sepa_rator/builders/credit_transfer/transaction/creditor_account'
require 'sepa_rator/builders/credit_transfer/transaction/ultimate_creditor'
require 'sepa_rator/builders/credit_transfer/transaction/instructions_for_creditor_agent'
require 'sepa_rator/builders/credit_transfer/transaction/txn_instruction_for_debtor_agent'
require 'sepa_rator/builders/credit_transfer/transaction/purpose'
require 'sepa_rator/builders/credit_transfer/transaction/regulatory_reporting'
require 'sepa_rator/builders/credit_transfer/transaction/remittance_information'

require 'sepa_rator/builders/direct_debit/group_header'
require 'sepa_rator/builders/direct_debit/payment_information'
require 'sepa_rator/builders/direct_debit/transaction/payment_id'
require 'sepa_rator/builders/direct_debit/transaction/amount'
require 'sepa_rator/builders/direct_debit/transaction/direct_debit_info'
require 'sepa_rator/builders/direct_debit/transaction/ultimate_creditor'
require 'sepa_rator/builders/direct_debit/transaction/debtor_agent'
require 'sepa_rator/builders/direct_debit/transaction/debtor'
require 'sepa_rator/builders/direct_debit/transaction/debtor_account'
require 'sepa_rator/builders/direct_debit/transaction/ultimate_debtor'
require 'sepa_rator/builders/direct_debit/transaction/purpose'
require 'sepa_rator/builders/direct_debit/transaction/remittance_information'

require 'sepa_rator/message'
require 'sepa_rator/message/direct_debit'
require 'sepa_rator/message/credit_transfer'

# Profile validators (national rules) — loaded before profiles that use them.
require 'sepa_rator/validators/cfonb/structured_address'
require 'sepa_rator/validators/dk/min_amount'

# Profiles — loaded last, after message/transaction classes and stages.
# EPC / CFONB / DK compose from ISO, so ISO must load first.
require 'sepa_rator/profiles/iso'
require 'sepa_rator/profiles/epc'
require 'sepa_rator/profiles/cfonb'
require 'sepa_rator/profiles/dk'

# Country defaults must load AFTER all variant profiles have been defined.
require 'sepa_rator/profiles/country_defaults'
