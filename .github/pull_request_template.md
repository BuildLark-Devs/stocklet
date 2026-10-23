## What this changes

<!-- One or two sentences. Name the user-visible effect, not the files touched. -->

## Why

<!-- The context a reviewer cannot get from the diff: the symptom, the report
     behind it, or the decision being implemented. -->

## How to verify

<!-- The exact steps or commands a reviewer runs to see it working. If it is a
     UI change, attach a before/after screenshot. -->

## Checklist

- [ ] `flutter analyze` and `flutter test` pass locally
- [ ] Touched `firestore.rules` or `storage.rules`? `cd test/rules && npm test` passes
- [ ] New user-facing text is in all four locales (`lib/l10n/app_{es,en,pt,fr}.arb`)
- [ ] No credentials committed: `lib/firebase_options.dart`, `android/key.properties`,
      `google-services.json` and `*.jks` stay out of git
- [ ] `docs/DEVELOPMENT.md` updated if the setup, the commands or a manual step changed
