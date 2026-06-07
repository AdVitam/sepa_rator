# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

EXTENSION_GEMS = %w[at dk sps].freeze

desc 'Build the core gem and all extension gems into pkg/'
task :build_all do
  require_relative 'lib/sepa_rator/version'
  mkdir_p 'pkg'
  sh "gem build sepa_rator.gemspec -o pkg/sepa_rator-#{SEPA::VERSION}.gem"
  EXTENSION_GEMS.each do |ext|
    sh "cd sepa_rator-#{ext} && gem build sepa_rator-#{ext}.gemspec " \
       "-o ../pkg/sepa_rator-#{ext}-#{SEPA::VERSION}.gem"
  end
end
