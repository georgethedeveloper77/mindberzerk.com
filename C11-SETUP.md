# C11 setup — Remote Config

The config screen reads and writes the live Firebase Remote Config template. Two
things make it work, both one-time.

## 1. The service account role

App Hosting runs as a service account. Grant it **Firebase Remote Config Admin**
in IAM (roles/firebaseremoteconfig.admin). No key file: the panel picks up
Application Default Credentials automatically.

## 2. GCP_PROJECT

Already set if C9 is configured. Otherwise, in apphosting.yaml:

```yaml
env:
  - variable: GCP_PROJECT
    value: mindberzerk
```

## The dependency

`google-auth-library` is used to mint the access token. It is almost certainly
already in the tree via other Google packages; if a build complains, `npm i
google-auth-library`.

## What this screen will and will not manage

It manages the keys in `KNOWN_KEYS` in `lib/remote-config.ts`. Today that is one:

- **cdn_base_url** — repoints every device's pack downloads. Read on the Flutter
  side, written to `.index/base_url` for the headless worker (CdnConfig).
  Validated exactly as the device validates it: https, 12 to 200 chars, or the
  device ignores it.

It deliberately does NOT manage:

- **minAppVersion** — per-pack inside the signed index, enforced by
  PackDownloader against the signature. A global RC key would be a second,
  unsigned source of truth for a value the device only trusts signed.
- **the per-theme feature toggles from the early mock** (drawer cube, verbose
  boot, and so on) — these are device-side prefs with no RC key. A toggle here
  would change nothing on a phone.

## Adding a key later

When the launcher grows a reader for a new RC value, add an entry to
`KNOWN_KEYS` with its `readBy` note, owning `app`, and a `validate` function that
mirrors whatever the device does with a bad value. The screen picks it up with
no other change. Until it is in that list, the panel shows it read-only under
"other keys in the template" so a console edit is visible but not silently
editable.

## Concurrency

All five apps share one Remote Config template. Every write carries the ETag the
page read and is refused with a 409 if the template moved, so two people editing
at once get "reload and retry" rather than one silently clobbering the other.
