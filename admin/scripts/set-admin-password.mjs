#!/usr/bin/env node
/**
 * Link a password credential to an EXISTING Firebase Auth user.
 *
 *   node scripts/set-admin-password.mjs <uid>
 *
 * ─── WHY A SCRIPT AND NOT THE CONSOLE ───────────────────────────────────────
 *
 * The Firebase console can create a user with a password and it can send a
 * reset link, but it cannot add a password to a user who signed up through
 * Google. Only the Admin SDK can, and it is one call.
 *
 * ─── WHY NOT JUST MAKE A SECOND ACCOUNT ─────────────────────────────────────
 *
 * Because a second account is a second UID, and the UID is the credential this
 * whole panel is gated on. A new one means editing the `admin-uids` secret,
 * granting access again and redeploying, and then living with two records that
 * can drift. `updateUser` on the existing UID adds a provider to the account
 * that is already on the allowlist and changes nothing else.
 *
 * ─── THE PASSWORD IS PROMPTED FOR, NEVER AN ARGUMENT ────────────────────────
 *
 * An argv password lands in `~/.zsh_history` in plaintext, and on a shared or
 * backed-up machine that is worse than having no password at all. It is read
 * from stdin with echo off, so it is never written anywhere.
 *
 * ─── CREDENTIALS ────────────────────────────────────────────────────────────
 *
 * Uses Application Default Credentials. If it cannot find any:
 *
 *   gcloud auth application-default login
 *   gcloud config set project mindberzerk-3eaf5
 *
 * Run from `admin/`. Needs `firebase-admin`, which is already a dependency of
 * the session route, so there is nothing to install.
 */

import { createInterface } from 'node:readline';
import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const PROJECT_ID = 'mindberzerk-3eaf5';

/** Read a line from stdin without echoing it to the terminal. */
function readSecret(prompt) {
  return new Promise((resolve, reject) => {
    const rl = createInterface({ input: process.stdin, output: process.stdout });

    // `readline` has no built-in masked mode. Muting the output stream for the
    // duration is the standard workaround: keystrokes still reach the buffer,
    // nothing reaches the screen.
    const write = rl._writeToOutput?.bind(rl);
    rl._writeToOutput = (s) => {
      if (s.includes(prompt)) write?.(s);
    };

    rl.question(prompt, (answer) => {
      rl._writeToOutput = write;
      rl.close();
      process.stdout.write('\n');
      resolve(answer);
    });
    rl.on('SIGINT', () => reject(new Error('cancelled')));
  });
}

async function main() {
  const uid = process.argv[2];
  if (!uid) {
    console.error('Usage: node scripts/set-admin-password.mjs <uid>');
    console.error('The uid is in Firebase console, Authentication, Users.');
    process.exit(1);
  }

  if (!getApps().length) {
    initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  }
  const auth = getAuth();

  // READ BEFORE WRITE, so a mistyped uid fails here with a clear message
  // rather than creating nothing and reporting success.
  const user = await auth.getUser(uid).catch(() => null);
  if (!user) {
    console.error(`No user with uid ${uid} in project ${PROJECT_ID}.`);
    process.exit(1);
  }

  console.log(`Account:   ${user.email ?? '(no email)'}`);
  console.log(`Providers: ${user.providerData.map((p) => p.providerId).join(', ') || 'none'}`);
  console.log('');

  const password = await readSecret('New password (min 6 chars): ');
  const again = await readSecret('Again: ');

  if (password !== again) {
    console.error('Those did not match. Nothing was changed.');
    process.exit(1);
  }
  if (password.length < 6) {
    // Firebase's own floor. Checked here so the failure is one line rather
    // than an SDK error object.
    console.error('Firebase requires at least 6 characters. Nothing was changed.');
    process.exit(1);
  }

  await auth.updateUser(uid, { password });

  const after = await auth.getUser(uid);
  console.log('');
  console.log('Password linked.');
  console.log(`Providers: ${after.providerData.map((p) => p.providerId).join(', ')}`);
  console.log(`Sign in at /admin as ${after.email}`);
}

main().catch((e) => {
  console.error(e?.message ?? e);
  process.exit(1);
});
