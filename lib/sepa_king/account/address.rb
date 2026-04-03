# frozen_string_literal: true

module SEPA
  class Address
    include ActiveModel::Validations
    extend Converter

    # PostalAddress6 fields (all schemas)
    attr_accessor :street_name,
                  :building_number,
                  :post_code,
                  :town_name,
                  :country_code,
                  :address_line1,
                  :address_line2,
                  # PostalAddress24 fields (.09/.08 and above)
                  :department,
                  :sub_department,
                  :building_name,
                  :floor,
                  :post_box,
                  :room,
                  :town_location_name,
                  :district_name,
                  :country_sub_division,
                  # PostalAddress27 fields (.13/.12 only)
                  :care_of,
                  :unit_number

    convert :street_name,          to: :text
    convert :building_number,      to: :text
    convert :post_code,            to: :text
    convert :town_name,            to: :text
    convert :country_code,         to: :text
    convert :address_line1,        to: :text
    convert :address_line2,        to: :text
    convert :department,           to: :text
    convert :sub_department,       to: :text
    convert :building_name,        to: :text
    convert :floor,                to: :text
    convert :post_box,             to: :text
    convert :room,                 to: :text
    convert :town_location_name,   to: :text
    convert :district_name,        to: :text
    convert :country_sub_division, to: :text
    convert :care_of,              to: :text
    convert :unit_number,          to: :text

    # Max lengths use the most permissive schema (PostalAddress27).
    # Stricter per-schema limits are enforced by XSD validation in validate_final_document!.
    validates_length_of :street_name,          maximum: 140
    validates_length_of :building_number,      maximum: 16
    validates_length_of :post_code,            maximum: 16
    validates_length_of :town_name,            maximum: 140
    validates_length_of :country_code,         is: 2
    validates_length_of :address_line1,        maximum: 70
    validates_length_of :address_line2,        maximum: 70
    validates_length_of :department,           maximum: 70,  allow_nil: true
    validates_length_of :sub_department,       maximum: 70,  allow_nil: true
    validates_length_of :building_name,        maximum: 140, allow_nil: true
    validates_length_of :floor,                maximum: 70,  allow_nil: true
    validates_length_of :post_box,             maximum: 16,  allow_nil: true
    validates_length_of :room,                 maximum: 70,  allow_nil: true
    validates_length_of :town_location_name,   maximum: 140, allow_nil: true
    validates_length_of :district_name,        maximum: 140, allow_nil: true
    validates_length_of :country_sub_division, maximum: 35,  allow_nil: true
    validates_length_of :care_of,              maximum: 140, allow_nil: true
    validates_length_of :unit_number,          maximum: 16,  allow_nil: true

    def initialize(attributes = {})
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end
  end
end
