# Contributing

Stocklet is built by BuildLark S.A.S. `main` is protected: every change lands
through a pull request with both required checks green. Direct pushes to `main`
are rejected, including by admins.

## The flow

1. Branch off `main`, named after what it does: `feat/…`, `fix/…`, `chore/…`,
   `docs/…`.
2. Commit in [Conventional Commits](https://www.conventionalcommits.org) form,
   scoped to the area touched — `fix(inventario): …`, `feat(pedidos): …`.
   Messages are in English.
3. Open the pull request and fill in the template. The "How to verify" section
   is the one that matters: say what a reviewer has to run or click.
4. Wait for both checks. `main` requires the branch to be up to date, so rebase
   if it moved: `git pull --rebase origin main`.
5. Squash merge, and delete the branch.

## The two required checks

| Check | What it runs |
| --- | --- |
| **Domain, UI and analysis** | `flutter analyze`, `flutter test`, `flutter build web --release` |
| **Firestore access rules** | the 46 access cases in `test/rules/` against the Firestore emulator |

Both are in [`.github/workflows/ci.yml`](.github/workflows/ci.yml). The job
names *are* the required check names configured in Settings → Rules: renaming a
job without renaming the rule leaves `main` waiting on a check that never
arrives.

Run them yourself before pushing:

```
flutter analyze && flutter test
cd test/rules && npm test        # needs Java, Node 24+ and the Firebase CLI
```

CI has no Firebase credentials and does not need any. It copies
`tool/ci/firebase_options.dart.stub` over the ignored `lib/firebase_options.dart`
so the code compiles; nothing in CI talks to a real project. Android is not
built in CI, because signing the `.aab` needs the release key and that key never
leaves its owner's machine.

## What never goes into a commit

`lib/firebase_options.dart`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`, `android/key.properties`, `*.jks`,
`*.keystore`. They are all in `.gitignore`; the repository is public, so check
`git status` before committing rather than trusting that.

Screenshots and sample data come from the demo business (*Postres Aurora*),
never from a real one — no real customer name, email or phone number.

## Setup

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for installing the project,
running the emulators, deploying, and regenerating icons.
