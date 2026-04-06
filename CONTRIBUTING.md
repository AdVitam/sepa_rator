# Contributing to sepa_rator

## Getting started

1. Fork the repo and clone it locally.
2. Install dependencies: `bundle install`
3. Run the test suite: `bundle exec rubocop && bundle exec rspec`

## Making changes

1. Create a feature branch from `master`: `git switch -c feat/your-change`
2. Write tests for your changes.
3. Make sure all tests pass: `bundle exec rubocop && bundle exec rspec`
4. Commit with a descriptive message: `git commit -m "type: description"`
5. Push and open a pull request against `master`.

## Code style

* Follow the existing conventions and `.rubocop.yml` configuration.
* Two spaces for indentation, no tabs.
* All Ruby files must have `# frozen_string_literal: true`.

## Multi-version testing

Test against different ActiveModel versions:

```bash
BUNDLE_GEMFILE=gemfiles/Gemfile-activemodel-8.1.x bundle exec rspec
```
