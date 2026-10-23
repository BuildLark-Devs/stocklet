// CommonJS -> ESM bridge.
//
// `firebase emulators:exec` runs the script with the CLI bundled Node, which
// require()s the entry file and therefore accepts neither ESM nor the --test
// flag. This file is the CommonJS entry that imports the ESM suite; the
// node:test runner handles execution and sets the exit code on failure.

import('./firestore.test.js').catch((err) => {
  console.error(err);
  process.exit(1);
});
