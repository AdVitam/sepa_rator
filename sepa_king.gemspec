# frozen_string_literal: true

require_relative 'lib/sepa_king/version'

Gem::Specification.new do |s|
  s.name          = 'sepa_king'
  s.version       = SEPA::VERSION
  s.authors       = ['Georg Leciejewski', 'Georg Ledermann']
  s.email         = ['gl@salesking.eu', 'georg@ledermann.dev']
  s.description   = 'Implementation of Payments Initiation (ISO 20022)'
  s.summary       = 'Ruby gem for creating SEPA XML files'
  s.homepage      = 'https://github.com/salesking/sepa_king'
  s.license       = 'MIT'

  s.files         = Dir['lib/**/*', 'LICENSE.txt', 'README.md']
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.1'

  s.add_dependency 'activemodel', '>= 6.1', '< 9'
  s.add_dependency 'iban-tools'
  s.add_dependency 'nokogiri', '>= 1.13'
  s.metadata['rubygems_mfa_required'] = 'true'
end
