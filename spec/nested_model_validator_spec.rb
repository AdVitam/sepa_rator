# frozen_string_literal: true

require 'spec_helper'

NestedChild = Class.new do
  include ActiveModel::Model

  attr_accessor :name

  validates_presence_of :name

  def self.name
    'NestedChild'
  end
end

NestedParent = Class.new do
  include ActiveModel::Model

  attr_accessor :child

  validates :child, nested_model: true, allow_nil: true

  def self.name
    'NestedParent'
  end
end

RSpec.describe NestedModelValidator do
  context 'when child is nil' do
    it 'is valid' do
      expect(NestedParent.new(child: nil)).to be_valid
    end
  end

  context 'when child is valid' do
    it 'is valid' do
      expect(NestedParent.new(child: NestedChild.new(name: 'Test'))).to be_valid
    end
  end

  context 'when child is invalid' do
    it 'propagates child errors to parent' do
      parent = NestedParent.new(child: NestedChild.new(name: nil))

      expect(parent).not_to be_valid
      expect(parent.errors[:child]).not_to be_empty
    end
  end
end
