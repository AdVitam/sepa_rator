# frozen_string_literal: true

require 'spec_helper'

# The suite loads schemas straight from the monorepo, so a broken
# `s.files` glob would ship an empty gem with specs green.
RSpec.describe 'gem packaging' do # rubocop:disable RSpec/DescribeClass
  def load_gemspec(dir, name)
    # Dir[] globs in gemspecs resolve against the CWD, like `gem build`.
    root = File.expand_path('..', __dir__)
    Dir.chdir(File.join(root, dir)) { Gem::Specification.load("#{name}.gemspec") }
  end

  def xsd_paths_for(prefix)
    SEPA::ProfileRegistry.all
                         .map(&:xsd_path)
                         .select { |path| path.start_with?("#{prefix}/") }
                         .uniq
  end

  describe 'sepa_rator (core)' do
    subject(:gemspec) { load_gemspec('.', 'sepa_rator') }

    it 'packages every ISO XSD referenced by a profile' do
      xsd_paths_for('iso').each do |xsd_path|
        expect(gemspec.files).to include("lib/schema/#{xsd_path}")
      end
    end

    it 'does not package any country-specific XSD' do
      expect(gemspec.files.grep(%r{^lib/schema/(at|dk|sps)/})).to be_empty
    end
  end

  SEPA::SchemaValidation::SCHEMA_GEMS.each do |prefix, gem_name|
    describe gem_name do
      subject(:gemspec) { load_gemspec(gem_name, gem_name) }

      it "packages every #{prefix}/ XSD referenced by a profile, the entry file and the license" do
        expect(gemspec.files).to include("lib/sepa_rator/#{prefix}.rb", 'LICENSE.txt')
        xsd_paths_for(prefix).each do |xsd_path|
          expect(gemspec.files).to include("lib/schema/#{xsd_path}")
        end
      end
    end
  end
end
