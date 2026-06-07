# sepa_rator-at

Austrian (PSA/Stuzza) XSD schemas for [sepa_rator](https://github.com/AdVitam/sepa_rator). Required to validate the `at.*` profiles.

```ruby
gem 'sepa_rator-at'
```

Bundler auto-requires `sepa_rator/at`, which registers the schema directory with `SEPA.register_schema_root` — no further setup needed.

Note: `at/pain.001.001.09.xsd` and `at/pain.008.001.08.xsd` duplicate the ISO baseline copies shipped with the core gem. This is intentional: the PSA schemas reference them through `xs:redefine` with a `schemaLocation` relative to their own directory, and installed gems live in separate directories.
