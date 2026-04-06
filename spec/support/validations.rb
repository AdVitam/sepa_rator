# frozen_string_literal: true

# Test-only helper for checking validation errors on ActiveModel objects.
# Included into ActiveModel::Validations via RSpec before(:suite) in spec_helper.rb.
module SEPA
  module TestValidationHelpers
    # Returns an array of error messages for the given attribute after running validations.
    #
    # @param attribute [Symbol] the attribute to check errors on
    # @param options [Hash] optional validation context
    # @return [Array<String>] error messages
    def errors_on(attribute, options = {})
      valid_args = [options[:context]].compact
      valid?(*valid_args)

      [errors[attribute]].flatten.compact
    end

    alias error_on errors_on
  end
end
