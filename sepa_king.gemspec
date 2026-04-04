# frozen_string_literal: true

require_relative 'lib/sepa_king/version'

Gem::Specification.new do |s|
  s.name          = 'sepa_king'
  s.version       = SEPA::VERSION
  s.authors       = ['Georg Leciejewski', 'Georg Ledermann', 'AdVitam']
  s.description   = 'AdVitam fork of sepa_king. Ruby gem for creating SEPA XML files ' \
                    '(ISO 20022), with support for pain.001.001.09/.13 and pain.008.001.08/.12.'
  s.summary       = 'Ruby gem for creating SEPA XML files'
  s.homepage      = 'https://github.com/AdVitam/sepa_king'
  s.license       = 'MIT'

  s.metadata = {
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/AdVitam/sepa_king',
    'changelog_uri' => 'https://github.com/AdVitam/sepa_king/blob/master/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/AdVitam/sepa_king/issues'
  }

  s.files         = Dir['lib/**/*', 'LICENSE.txt', 'README.md']
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.2'

  s.add_dependency 'activemodel', '>= 7.0', '< 9'
  s.add_dependency 'iban-tools'
  s.add_dependency 'nokogiri', '>= 1.13'
end
