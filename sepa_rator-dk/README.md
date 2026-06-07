# sepa_rator-dk

German (Deutsche Kreditwirtschaft / GBIC) XSD schemas for [sepa_rator](https://github.com/AdVitam/sepa_rator). Required to validate the `dk.*` profiles.

```ruby
gem 'sepa_rator-dk'
```

Bundler auto-requires `sepa_rator/dk`, which registers the schema directory with `SEPA.register_schema_root` — no further setup needed.
