# frozen_string_literal: true

source 'https://rubygems.org'

gemspec path: '..'

gem 'activemodel', '~> 6.1.4'

group :development, :test do
  gem 'rake'
  gem 'rspec'
end

group :test do
  gem 'coveralls_reborn', require: false
  gem 'simplecov', require: false
end
