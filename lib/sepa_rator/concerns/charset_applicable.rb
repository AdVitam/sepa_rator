# frozen_string_literal: true

module SEPA
  module CharsetApplicable
    # Rewrites text and identifier attributes (and those of nested models) to
    # the profile's repertoire. Caller-owned nested models are duplicated first.
    def apply_charset(charset)
      self.class.text_attributes.each { |attribute| convert_attribute(attribute, charset, :text) }
      self.class.identifier_attributes.each { |attribute| convert_attribute(attribute, charset, :identifier) }

      instance_variables.each do |name|
        nested = instance_variable_get(name)
        instance_variable_set(name, nested.dup.apply_charset(charset)) if nested.respond_to?(:apply_charset)
      end

      self
    end

    private

    def convert_attribute(attribute, charset, kind)
      name = :"@#{attribute}"
      instance_variable_set(name, charset.public_send(kind, instance_variable_get(name)))
    end
  end
end
