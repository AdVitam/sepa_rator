# frozen_string_literal: true

require_relative 'lib/sepa_rator/version'

Gem::Specification.new do |s|
  s.name          = 'sepa_rator'
  s.version       = SEPA::VERSION
  s.authors       = ['Georg Leciejewski', 'Georg Ledermann', 'AdVitam']
  s.description   = 'Ruby gem for creating SEPA XML files (ISO 20022). ' \
                    'Supports pain.001.001.03/.09/.13 and pain.008.001.02/.08/.12.'
  s.summary       = 'Ruby gem for creating SEPA XML files'
  s.homepage      = 'https://github.com/AdVitam/sepa_rator'
  s.license       = 'MIT'

  s.metadata = {
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/AdVitam/sepa_rator',
    'changelog_uri' => 'https://github.com/AdVitam/sepa_rator/blob/master/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/AdVitam/sepa_rator/issues'
  }

  s.files         = Dir['lib/**/*', 'LICENSE.txt', 'README.md']
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.2'

  s.add_dependency 'activemodel', '>= 7.0', '< 9'
  s.add_dependency 'ibandit', '>= 1.0'
  s.add_dependency 'nokogiri', '>= 1.13'
end
