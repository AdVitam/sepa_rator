# frozen_string_literal: true

# Validates nested ActiveModel objects and propagates their errors.
# Defined at root level so ActiveModel's const_get lookup finds it from any namespace.
# Usage: validates :address, :contact_details, nested_model: true
class NestedModelValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value
    return if value.valid?

    value.errors.each { |error| record.errors.add(attribute, error.full_message) }
  end
end
