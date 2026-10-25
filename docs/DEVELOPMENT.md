# Stocklet

Business management app for micro-businesses (sales, inventory, expenses, orders, notes and a team with roles), built with **Flutter + Firebase**. Multi-company and multi-language (es/en/pt/fr).

Published by **BuildLark S.A.S.** · Package: `com.buildlark.stocklet`

> Note: the internal Dart package is still named `reposteria_app` (historical, invisible to users). Firestore collection and field names are Spanish too — they are live production data, so they are not renamed.

## Stack

- **Flutter / Dart** (Android, iOS, web/PWA).
- **Firebase**: Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Analytics, Crashlytics.
- **RevenueCat** (`purchases_flutter`) for subscriptions (freemium; inactive until the Play account is set up).
- i18n with ARB + `gen-l10n`.

## Getting started

```
flutter pub get
flutter gen-l10n
flutter run
```

Needs the Firebase configuration files, which are not versioned: `android/app/google-services.json`, `lib/firebase_options.dart`, and for iOS `ios/Runner/GoogleService-Info.plist`.

## Common commands

```
flutter analyze
flutter test
flutter build appbundle              # .aab for Google Play
firebase deploy --only functions     # Cloud Functions
firebase deploy --only hosting       # web/ (after flutter build web)
```

## Cloud Functions

Three functions in `functions/`: `inventarioBajo` (push when a supply crosses
its minimum), `recordatorioPedidos` (daily notice of orders due) and
`eliminarCuenta` (account deletion, a store requirement). They need the Blaze
plan.

They run on **Node 22**. The move up from Node 20 was forced by Google shutting
it down on 2026-10-30, and it brought `firebase-admin` 14 and
`firebase-functions` 7 with it.

**`firebase-admin` 14 removed the namespace**: `admin.firestore()`,
`admin.auth()`, `admin.messaging()` and `admin.storage()` no longer exist.
Everything goes through modular imports (`getFirestore()`, `getAuth()`, …). Code
copied from an older example will fail with `admin.X is not a function`.

**Deploy with the npm CLI, not the winget one.** `firebase-admin` 14 pulls in
`jose`, which is ESM only, and the standalone winget CLI bundles Node 20 inside
and dies while merely parsing the code:

```
Error [ERR_REQUIRE_ESM]: require() of ES Module .../jose/dist/webapi/index.js
```

The npm one uses the system Node. If `firebase --version` reports less than 15:

```
npm install -g firebase-tools
winget uninstall Google.FirebaseCLI
```

To exercise them before deploying, the emulators load all three when started
with `--only functions,firestore,auth,storage`; the log must say
`Using node@22 from host`. `recordatorioPedidos` is skipped without the pubsub
emulator, but its handler can be called by hand with `.run({})`.

## Demo business (store screenshots)

Google Play listing screenshots **must not come from the real business**: the
screens show customer names and phone numbers, sales, costs and margins, and a
screenshot on Play is public and permanent.

That is what the demo business seeded into the emulators is for. The `--project`
has to match the one in `firebase_options.dart`: the Firestore emulator
partitions data by project, so under any other name the app signs in, finds an
empty database and sends you to create a business. In one terminal:

```
firebase emulators:start --only auth,firestore,storage --project mi-reposteria-app
```

In another, `npm install` once inside `tool/demo`, and then:

```
cd tool/demo
npm run seed
```

And the app pointed at the emulators:

```
flutter run --dart-define=STOCKLET_EMULATOR=true
```

Sign in with `demo@stocklet.app` / `demo1234` (emulator credentials; they do not
exist in the real project). Seeding again leaves everything exactly as the first
time, so the screenshots are repeatable.

The emulators have to keep running while you use the app: stop them and sign-in
fails with a generic error and the seeded data is gone (it reseeds in seconds).

The host address resolves itself: `10.0.2.2` on the Android emulator,
`localhost` on web and desktop. From a **physical phone** you have to pass your
machine's address on the local network:

```
flutter run --dart-define=STOCKLET_EMULATOR=true --dart-define=STOCKLET_EMULATOR_HOST=192.168.1.X
```

**If the Android emulator cannot reach `10.0.2.2`** (symptom: sign-in fails with
the generic error, and `adb shell nc -w 3 10.0.2.2 9099` answers
`Network is unreachable`), its network stack is broken. Rather than fight it,
tunnel through the debug cable:

```
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:9199 tcp:9199
```

And build pointing at `localhost`, which now goes out through the tunnel:

```
flutter run --dart-define=STOCKLET_EMULATOR=true --dart-define=STOCKLET_EMULATOR_HOST=localhost
```

The tunnels are lost when the AVD restarts and have to be recreated.

The `STOCKLET_EMULATOR` switch is `const` and off by default: a release build
strips it out of the binary.

## Tests

Pure logic (costing, units, formatting):

```
flutter test
```

The security rules have their own suite, separately (see below).

## Security rules

The rules live in the repository and are the only real barrier between one
business and another's data (the UI merely hides buttons):

- `firestore.rules` — per-business isolation and role permissions (`dueno`,
  `socio`, `empleado`).
- `storage.rules` — profile photos, business logo and PDF catalogues.

They have a suite that exercises them against the emulator. It needs Java,
**Node 24 or newer** (the `@firebase/*` v13 line declares `engines`
`node >=24.12.0`) and `npm install` once inside `test/rules`:

```
cd test/rules
npm test
```

To deploy them (this overwrites whatever is in the Firebase console):

```
firebase deploy --only firestore:rules,storage
```

Mind the target name: `firestore:rules` exists, but `storage:rules` does not. In
Storage, what follows the colon is a bucket *deploy target*, so the rules go up
with plain `storage`.

## Documentation

- `CONTRIBUTING.md` — branch and pull request flow, and the two required checks.
- `docs/play-listing.md` — screenshot script and copy for the Google Play listing.
- `docs/data-safety.md` — data inventory for the Google Play Data Safety form.
  Update it whenever the app starts collecting something new.
- `tool/graphic/README.md` — how the 1024×500 feature graphic is generated.

Project status, the monetisation plan and the launch checklist live outside this
repository, in `Creador Apps/Stocklet - Estado del proyecto.md`.
