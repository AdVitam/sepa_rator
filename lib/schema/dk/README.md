# DK / DFÜ schemas

The Deutsche Kreditwirtschaft (DK) publishes its own XSDs derived from the ISO
20022 baseline for the DFÜ-Abkommen (EBICS) channel, notably:

- `pain.001.001.09_AXZ_GBIC5.xsd` — SEPA credit transfer (SCT)
- `pain.008.001.08_AXZ_GBIC5.xsd` — SEPA direct debit (SDD)

These XSDs tighten the ISO baseline with additional facets (minimum amounts,
structured addresses, restricted code lists). They are distributed by
<https://www.ebics.de/de/datenformate/ergaenzende-dokumente> and licensed by
DK — we do not vendor them in this gem.

The profiles under `lib/sepa_rator/profiles/dk.rb` currently reference the
ISO baseline XSDs (via `xsd_path: "iso/pain.*.xsd"`). To wire up the real DK
XSDs in production:

1. Download the files from the DK site above.
2. Drop them in this directory under their canonical names
   (`pain.001.001.09_AXZ_GBIC5.xsd`, `pain.008.001.08_AXZ_GBIC5.xsd`, …).
3. Update `lib/sepa_rator/profiles/dk.rb` to set
   `xsd_path: "dk/pain.001.001.09_AXZ_GBIC5.xsd"` for each profile.

The XSD cache (see `SchemaValidation#validate_final_document!`) is keyed by
`profile.id`, so swapping the XSD for a DK-specific one never collides with
the ISO baseline, even when they share the same ISO schema name.
