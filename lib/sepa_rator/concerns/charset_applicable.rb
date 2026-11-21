# frozen_string_literal: true

module SEPA
  module CharsetApplicable
    # Rewrites text and identifier attributes (and those of nested models) in
    # place to the profile's repertoire.
    def apply_charset(charset)
      self.class.text_attributes.each { |attribute| convert_attribute(attribute, charset, :text) }
      self.class.identifier_attributes.each { |attribute| convert_attribute(attribute, charset, :identifier) }
      each_nested_model { |_name, nested| nested.apply_charset(charset) }
      self
    end

    # Replaces caller-owned nested models with copies, once at admission, so
    # later in-place conversions never reach them and every holder of a nested
    # model (e.g. a direct debit group key) keeps seeing the converted object.
    def detach_nested_models
      each_nested_model { |name, nested| instance_variable_set(name, nested.dup.detach_nested_models) }
      self
    end

    private

    def each_nested_model
      instance_variables.each do |name|
        nested = instance_variable_get(name)
        yield name, nested if nested.respond_to?(:apply_charset)
      end
    end

    def convert_attribute(attribute, charset, kind)
      name = :"@#{attribute}"
      instance_variable_set(name, charset.public_send(kind, instance_variable_get(name)))
    end
  end
end
