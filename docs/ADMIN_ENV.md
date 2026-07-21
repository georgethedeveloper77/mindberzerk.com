# The two env values that are not obvious

## `ADMIN_UIDS`

Your **Firebase Auth UID**. A 28-character opaque string like
`kJ3nQ8vXpZaR2mT7wYbL9cD4eF1g`. It is not your email and not your Google
account id.

You do not have one until you have signed in at least once, which is a
chicken-and-egg you resolve like this:

1. Deploy the panel with `ADMIN_UIDS` set to anything, or empty.
2. Open it and sign in with Google. The sign-in will **succeed at Firebase and
   then be rejected by the panel with 403**, which is correct: Firebase now has
   a user record for you, and the allowlist does not.
3. Firebase Console → Authentication → Users. Your row is there. Copy the
   **User UID** column.
4. Put it in the secret, redeploy, sign in again.

Or from the CLI, if you would rather not deploy first:

```bash
firebase auth:export /tmp/users.json --project <project-id>
cat /tmp/users.json | jq -r '.users[] | "\(.email)  \(.localId)"'
rm /tmp/users.json
```

`localId` is the UID.

**An empty `ADMIN_UIDS` locks everybody out, deliberately.** A missing secret
means a misconfigured deploy, and the alternative interpretation — nobody is
listed, so everybody is an admin — is how a panel that can rewrite your CDN ends
up open to the internet. `auth.ts` logs an error and refuses.

## `FIREBASE_SERVICE_ACCOUNT`

Yes, the whole JSON, **as one line**, and **only for local development**.

In production App Hosting supplies application-default credentials and
`firebase-admin` picks them up with no service account at all. `auth.ts` checks
for this variable and falls back to `applicationDefault()` when it is absent, so
you never set it in `apphosting.yaml`.

Locally:

```bash
# Console -> Project settings -> Service accounts -> Generate new private key
# It downloads a .json.

# Flatten it onto one line and into .env.local:
echo "FIREBASE_SERVICE_ACCOUNT=$(jq -c . ~/Downloads/mindberzerk-firebase-adminsdk-*.json)" \
  >> admin/.env.local

# Then delete the download. It is a private key.
rm ~/Downloads/mindberzerk-firebase-adminsdk-*.json
```

Without `jq`:

```bash
echo "FIREBASE_SERVICE_ACCOUNT=$(tr -d '\n' < ~/Downloads/service-account.json)" \
  >> admin/.env.local
```

`.env.local` is gitignored by `create-next-app` already. Check that it still is
before you write to it, because that file now contains a private key that can
mint session cookies for your project.

## Everything else

| Variable | Where |
|---|---|
| `NEXT_PUBLIC_FIREBASE_*` | Console → Project settings → Your apps → the web app config. Public by design; they identify the project and authorise nothing. |
| `R2_ENDPOINT` | Already correct in `apphosting.yaml`. From the bucket's Settings page, S3 API row. |
| `R2_BUCKET` | `mindberzerk-cdn`. |
| `PACK_KEY_ID` | `mh-2026-07`. Must match a key present in `PackKeys.ACCEPTED_HEX`. |
