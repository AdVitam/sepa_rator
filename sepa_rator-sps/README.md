# sepa_rator-sps

Swiss Payment Standards (SPS) XSD schemas for [sepa_rator](https://github.com/AdVitam/sepa_rator). Required to validate the `sps.*` profiles.

```ruby
gem 'sepa_rator-sps'
```

Bundler auto-requires `sepa_rator/sps`, which registers the schema directory with `SEPA.register_schema_root` — no further setup needed.
