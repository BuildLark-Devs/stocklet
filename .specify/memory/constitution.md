<!--
Sync Impact Report — 1.1.0 -> 1.2.0 (MINOR)

Why: the document was in Spanish while the repository moved to English, and two
of its statements had become false in the same change that added CI.

Principles changed:
- I. Renamed to "Spanish domain, English repository, translated interface". The
  rule itself is unchanged — domain vocabulary, Firestore keys, class, field and
  file names stay in Spanish — and the clause that comments, documentation,
  tests, commit messages and repository prose are written in English is now
  explicit instead of implied.
- V. The claim "the project has no CI" is retired. Both suites now run on every
  pull request as required status checks; the manual gate stays on top of them,
  it is not replaced.

Sections changed:
- Development Workflow: "development happens on main, there is no pull request
  process" replaced by the protected-branch flow. Commit messages move from
  Spanish to English.
- Governance: pointer corrected from README.md to docs/DEVELOPMENT.md.

Templates requiring no change: plan, spec, tasks and checklist templates carry
no language or branching assumptions.

Deferred: renaming Spanish identifiers in `lib/` and `functions/`, and the
`reposteria_app` package name, would require a MAJOR amendment to Principle I
plus a Firestore data migration. Not proposed.
-->

# Stocklet Constitution

## Core Principles

### I. Spanish domain, English repository, translated interface

The domain vocabulary (insumo, producto, receta, costeo, venta, gasto, pedido,
cotización, negocio) is the source of truth and is written in Spanish: class
names, fields, files, folders and Firestore keys MUST keep that language, even
though the Flutter code around them is English. These names are bound to live
production data and to the security rules; renaming them is a data migration,
not a translation.

Everything else in the repository is written in **English**: comments, doc
comments, documentation, test names, CI configuration, pull request and issue
templates, branch names and commit messages.

No text visible to the user may be written literally in the code: it MUST come
through `AppLocalizations` and be declared in all four ARB files (`app_es`,
`app_en`, `app_pt`, `app_fr`). A new key MUST be added to all four in the same
change; leaving a translation out breaks the language in production, not just
the build. After touching any ARB, `flutter gen-l10n` MUST be run.

Rationale: the product is sold in four languages, its data model is Spanish and
cannot move, and the repository is public. Separating the three planes is what
keeps untranslated strings and inconsistent model names from appearing.

### II. Per-business isolation and roles (NON-NEGOTIABLE)

Stocklet is multi-company. Every read and write of business data MUST be scoped
to `negocios/{negocioId}` of the active business; querying business collections
at the root level, or deriving the `negocioId` from anything other than the
current session in `DatosApp`, is forbidden.

The roles `dueno`, `socio` and `empleado` define what can be done. Hiding a
button in the UI is NOT access control: every restricted action MUST also be
validated server side (Firestore rules or a Cloud Function). A change that
widens what a role can do MUST review both sides in the same change.

Access to Pro features MUST go through `exigirPro(context)`
(`lib/servicios/gate_pro.dart`); ad-hoc `esPro` checks scattered across screens
are not allowed.

Rationale: a leak between businesses or a role escalation exposes third parties'
accounting data. It is the one failure in this app that cannot be patched after
the fact.

### III. State and persistence centralised in DatosApp

Screens (`lib/pantallas/`) MUST read and mutate state through `DatosApp`
(Provider) or a service in `lib/servicios/`. A screen instantiating
`FirebaseFirestore`, `FirebaseStorage`, `FirebaseAuth` or `FirebaseFunctions`
directly is forbidden.

The models in `lib/models/` MUST keep their own serialisation
(`fromMap`/`toMap`) and be the only place that knows the shape of the Firestore
document. Derived logic (costing, margins, summaries, trends) lives in
`lib/costeo.dart` and in `DatosApp`, not inside `build()`.

Screens SHOULD stay presentational; when a screen needs non-trivial new logic,
that logic MUST go in the model, the service or the `DatosApp` that owns it.

Rationale: with 91 Dart files and no repository layer, `DatosApp` is the only
boundary that stops every screen from inventing its own contract with Firestore.

### IV. Money, quantities and costing go through the helpers

Every displayed amount MUST be formatted with the helpers in
`lib/formato.dart`, respecting the currency and locale the business configured;
`toStringAsFixed`, hand-concatenated currency symbols and assumed decimal
separators are forbidden.

Unit conversions MUST use `lib/unidades.dart`, and cost, margin and suggested
price calculations MUST use `lib/costeo.dart`. Supply and recipe quantities
accept decimals and MUST be treated as `double`, never as integers.

Any new calculation rule MUST be added to these modules and reused, rather than
duplicated in whichever screen needed it first.

Rationale: the app is a multi-currency accounting tool; inconsistent rounding
between two screens destroys trust in every number it shows.

### V. Verification before delivering (NON-NEGOTIABLE)

The project has two automated suites, and since October 2026 both run in CI on
every pull request as required status checks (see `CONTRIBUTING.md`). CI is the
floor, not the ceiling: it cannot run the app, so the manual gate stays on top
of it. Before considering any change finished:

- `flutter analyze` MUST finish with no new errors or warnings.
- `flutter test` MUST pass in full (pure logic: costing, units, formatting).
- If the change touches `firestore.rules`, `storage.rules`, roles or
  permissions, the rules suite MUST pass in full: `cd test/rules && npm test`.
- If ARB files were touched, `flutter gen-l10n` MUST be run and the result MUST
  compile.
- The affected flow MUST be exercised at least once in the real app
  (`flutter run`); "it compiles" does not count as verified, and neither does a
  green test run.
- A change touching permissions, roles, billing or business data MUST also be
  tested with a role other than `dueno`.

What must arrive with a test, without exception:

- New or modified pure logic in `lib/costeo.dart`, `lib/unidades.dart` or
  `lib/formato.dart` MUST arrive with its test in `test/`.
- A change to the security rules or the role model MUST arrive with its test in
  `test/rules/`, covering both what is allowed and what is denied.
- A bug fixed in those modules SHOULD arrive with the test that would have
  caught it.

Whatever is left unverified MUST be reported instead of declaring the work done.

Rationale: the suites cover the money calculation and the isolation between
businesses, the two places where an error goes unnoticed until it has already
done damage. CI now runs them for you, but neither suite exercises the real app:
that is why the manual step does not disappear.

## Stack and Platform Constraints

- **Fixed stack**: Flutter/Dart (SDK `^3.12.2`) on Firebase (Auth, Firestore,
  Storage, Functions, Messaging, Analytics, Crashlytics). State with `provider`.
  Subscriptions with RevenueCat (`purchases_flutter`). Introducing a dependency
  of comparable weight to any of these requires an amendment to this document.
- **Deployment targets**: Android (Google Play, `com.buildlark.stocklet`), iOS
  and web/PWA through Firebase Hosting. A change MUST keep compiling for all
  three; if it breaks one, that MUST be stated explicitly.
- **Secrets and configuration**: `android/app/google-services.json`,
  `lib/firebase_options.dart` and `ios/Runner/GoogleService-Info.plist` are not
  versioned and MUST NOT be committed. No API key goes in the source. CI uses
  `tool/ci/firebase_options.dart.stub`, which carries filler values only.
- **Cloud Functions**: `functions/` is JavaScript and deploys separately
  (`firebase deploy --only functions`). A change that depends on a new function
  MUST state that the deployment is part of the delivery.
- **Monetisation**: the model is freemium and may be inactive (`esPro` = true).
  The code MUST work correctly with monetisation both active and inactive.
- **Observability**: unhandled errors MUST reach Crashlytics. No personal or
  accounting data from the businesses is written to logs.

## Development Workflow and Quality Gates

- **Spec Kit**: feature work follows `/speckit-specify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`. Bugs use the `bug` extension
  (`assess` → `fix` → `test`).
- **Branching**: `main` is protected. Every change lands through a pull request
  with both required checks green; direct pushes to `main` are rejected,
  including for admins. Branches are named `feat/…`, `fix/…`, `chore/…`,
  `docs/…`. The flow is documented in `CONTRIBUTING.md`.
- **Commits**: message in English, in Conventional Commits form, describing the
  functional change. A commit MUST NOT mix a new feature with a broad unrelated
  refactor.
- **Pre-merge gate**: Principle V in full. CI covers analyze, `flutter test` and
  the rules suite; the reviewer is responsible for the parts CI cannot check —
  the flow exercised in the real app, and the non-`dueno` role where it applies.
- **Pre-release gate**: `flutter build appbundle` for Play, and
  `flutter build web` + `firebase deploy --only hosting` for web; verify that
  the version in `pubspec.yaml` was incremented.
- **Complexity**: every new structure (service, layer, abstraction) MUST be
  justified against the alternative of extending `DatosApp`, the models or the
  existing helpers.

## Governance

This constitution takes precedence over any other practice, habit or style
preference in the project. When a plan, a task or a tool suggestion contradicts
it, the constitution wins.

**Amendments**: any change to this document MUST go through
`/speckit-constitution`, MUST include the Sync Impact Report with the version
change and the affected principles, and MUST record the new last-amended date. A
principle cannot be removed or weakened without writing in the report why it
stopped applying.

**Semantic versioning of this document**:

- MAJOR: a principle is removed or redefined incompatibly with the previous one.
- MINOR: a principle or section is added, or a guideline is materially extended.
- PATCH: clarifications, wording or corrections that do not change the meaning.

**Compliance**: every delivery MUST be verified against the five principles
before being considered finished; Principle V is the explicit gate. Exceptions
are allowed only if written into the feature plan, with their reason and a
bounded scope. A repeated exception is a sign that the constitution should be
amended, not that the rule can be ignored.

The day-to-day operational guides (commands, setup, stack) live in
`docs/DEVELOPMENT.md`; if that guide and this constitution disagree, this
constitution wins and the guide MUST be corrected.

**Version**: 1.2.0 | **Ratified**: 2026-09-15 | **Last Amended**: 2026-10-23
