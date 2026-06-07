# frozen_string_literal: true

require_relative '../lib/sepa_rator/version'

Gem::Specification.new do |s|
  s.name          = 'sepa_rator-sps'
  s.version       = SEPA::VERSION
  s.authors       = ['AdVitam']
  s.description   = 'Swiss Payment Standards (SPS) XSD schemas for sepa_rator. ' \
                    'Required to validate the sps.* profiles.'
  s.summary       = 'Swiss XSD schemas for sepa_rator'
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

  s.add_dependency 'sepa_rator', '~> 2.0'
end
