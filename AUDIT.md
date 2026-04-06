# Audit sepa_king — Suivi des corrections

Audit réalisé le 2026-04-03 sur le fork AdVitam de sepa_king.

---

## Sécurité

| ID | Sévérité | Constat | Statut |
|----|----------|---------|--------|
| S1 | Low | `public_send` avec noms d'attributs utilisateur — un allowlist serait plus défensif | ✅ `permitted_attributes` allowlist dans `AttributeInitializer` |
| S2 | Low | Pipe `\|` autorisé dans la regex `message_identification` | |
| S3 | Low | `iban-tools` sans contrainte de version dans le gemspec | |
| S4 | Low | Race condition bénigne sur le cache XSD (parsing redondant possible) | ✅ Double-checked locking propre dans `SchemaValidation` |
| S5 | Low | Path traversal dans le chargement XSD (mitigé par `SCHEMA_FEATURES.fetch`) | ✅ Garde-fou `SCHEMA_FEATURES.key?` dans `validate_final_document!` |
| S6 | Low | Les erreurs XSD peuvent contenir des fragments de données sensibles | ✅ Valeurs longues redactées + `validation_errors` structuré |
| S7 | Low | `currency` validé en longueur (3 chars) mais pas en format `[A-Z]{3}` | ✅ `validates_format_of :currency, with: /\A[A-Z]{3}\z/` |

---

## Architecture & qualité de code

### Haute priorité

| ID | Constat | Fichiers | Statut |
|----|---------|----------|--------|
| D1 | Pattern `initialize` dupliqué 3x | `account.rb`, `transaction.rb`, `address.rb` | ✅ Extrait dans `AttributeInitializer` concern |
| D4 | Bloc `PmtId` XML dupliqué | `credit_transfer.rb`, `direct_debit.rb` | ✅ Extrait dans `Message#build_payment_identification` |
| A1 | Validation incohérente : `message_identification=` / `creation_date_time=` lèvent `ArgumentError` au lieu d'ActiveModel | `message.rb:117-138` | ✅ Documenté — fail-fast intentionnel (lazy defaults) |

### Moyenne priorité

| ID | Constat | Statut |
|----|---------|--------|
| D3 | Bloc IBAN account XML dupliqué 4x | ✅ Extrait dans `Message#build_iban_account` |
| A2 | Clés de groupement transaction = hashes ad-hoc (pas de value object) | ✅ `Data.define` (`CreditTransferGroup`, `DirectDebitGroup`) |
| A3 | `CreditorAddress` / `DebtorAddress` sous-classes vides sans utilité | ✅ Conservé — distinction sémantique, API publique |
| A4 | `schema_compatible?` utilise `case/when` hardcodé au lieu de `SCHEMA_FEATURES` | ✅ Conservé — règles métier hétérogènes, séparation des concerns |
| A5 | Classe `Message` borderline god-class (XML + validation XSD + caching + helpers) | ✅ `SchemaValidation` extrait en concern |

### Basse priorité

| ID | Constat | Statut |
|----|---------|--------|
| N1 | `amendment_informations?` — "informations" n'est pas du bon anglais | |
| N2 | `initiating_party_id(builder)` devrait s'appeler `build_initiating_party_id` | |
| D5 | Duplication mineure de constantes (`UETR_SCHEMAS`, `instruction_priority`) | ✅ `instruction_priority` monté dans `Transaction` |

---

## Modernisation Ruby

### Haute priorité

| ID | Constat | Statut |
|----|---------|--------|
| M1 | RuboCop absent du CI (seul lefthook en local) | |
| M3 | 2 offenses RuboCop auto-fixables dans `spec/converter_spec.rb` | ✅ Corrigé |
| M4 | Lefthook ne lance pas RuboCop (uniquement rspec) | ✅ Ajouté `rubocop -A` au pre-commit |
| M5 | `.present?`/`.blank?` utilisés sans require explicite d'ActiveSupport | ✅ Remplacé par Ruby natif (`nil?`/`empty?`) |

### Moyenne priorité

| ID | Constat | Statut |
|----|---------|--------|
| M6 | Ruby 3.1 est EOL — bump minimum vers 3.2 | ✅ Bumped gemspec, rubocop, CI |
| M7 | Pas de `rubocop-rspec` — specs avec patterns obsolètes | ✅ Ajouté + autofix `ExampleWording` |
| M8 | Seuils RuboCop trop permissifs (AbcSize: 60, MethodLength: 60) | |
| M9 | `class_attribute` dans Message sans `instance_writer: false` | ✅ Ajouté `instance_writer: false` |
| M10 | `config.run_all_when_everything_filtered` obsolète dans spec_helper | ✅ Remplacé par `filter_run_when_matching :focus` |

### Basse priorité

| ID | Constat | Statut |
|----|---------|--------|
| M11 | Pas de documentation YARD sur l'API publique | ✅ YARD sur toutes les méthodes publiques de `Message` |
| M12 | Pas de `bundler-audit` en CI | |
| M13 | CI déclenché sur tous les push (pas filtré master + PR) | |
| M14 | Monkey-patching global d'`ActiveModel::Validations` dans les specs | ✅ Module `SEPA::TestValidationHelpers` inclus via `before(:suite)` |

---

## Complétude fonctionnelle

### Moyenne priorité

| ID | Constat | Impact | Statut |
|----|---------|--------|--------|
| F1 | Pas d'adresse postale débiteur dans CreditTransfer (niveau PmtInf) | Banques exigeant l'adresse pour cross-border | |
| F2 | Pas d'adresse postale créancier dans DirectDebit (niveau PmtInf) | Idem | |
| F9 | `OrgnlMndtId` manquant dans les informations d'amendement | Impossible de référencer un ancien ID de mandat | |

### Basse priorité

| ID | Constat | Statut |
|----|---------|--------|
| F3 | `ChrgBr` hardcodé à `SLEV` (CT) — limitant pour l'international | |
| F4 | `ChrgBr` hardcodé à `SLEV` (DD) — correct SEPA, mais inflexible | |
| F5 | Pas de `Purp/Cd` par transaction (seulement `CtgyPurp` au niveau groupe) | |
| F6 | Pas de `UltmtDbtr`/`UltmtCdtr` (feature corporate treasury) | |
| F10 | Pas de BIC ancien agent débiteur dans les amendements | |

### Déjà traité

| ID | Constat | Statut |
|----|---------|--------|
| F-INST | Support de `CtgyPurp/Cd = INST` (SCT Inst) | ✅ Tests ajoutés, validé sur .03/.09/.13 |
