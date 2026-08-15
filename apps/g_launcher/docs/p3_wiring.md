# Wiring the keystore, three edits

Everything else in P3 is self-contained. These three touch files I have not
read, so they are described rather than patched: guessing at the contents of a
launcher's Application class is how a home screen stops starting.

## 1. Generate the bridge

    dart run pigeon --input pigeons/keys_api.dart

A NEW schema file, deliberately. Pigeon assigns codec ids positionally, so
adding a class to `launcher_api.dart` or `pack_api.dart` would shift the id of
everything after it, and both sides would still compile while every message
decoded as the wrong type. A separate schema has its own codec and cannot
collide.

## 2. Register it, where PackHostApi is registered

`KeysHostApiImpl` takes an `Executor`. The main-thread one is right: the
biometric callback arrives on it and the Pigeon reply must be sent from it.

    private val keysApi = KeysHostApiImpl(ContextCompat.getMainExecutor(this))

and alongside whatever line sets up `PackHostApi`:

    KeysHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, keysApi)

## 3. Lend it the Activity, in LauncherActivity

The same pattern `widgetHost` and `hostApi` already use, and for the same
reason: a biometric prompt needs a window.

In `onCreate`, beside the two existing attaches:

    keysApi.attachActivity(this)

In `onDestroy`, beside the two existing detaches:

    keysApi.detachActivity(this)

Both are identity-checked on the callee side, which matters on a configuration
change: the replacement Activity's `onCreate` runs BEFORE the outgoing one's
`onDestroy`, so an unconditional clear would throw away the reference just
handed over. `KeysHostApiImpl.detachActivity` checks, exactly as
`LauncherHostApiImpl` does.

## What is still not built

The `key` command, the key manager screen, and the paywall. The platform layer
below them is complete: generation, listing, deletion, signing behind a prompt,
and both encodings.

Wiring an identity into a connection is one line in `ssh_connection.dart`:

    identities: [ if (keyPair != null) keyPair ],

next to `onPasswordRequest`. dartssh2 tries public key before password when both
are present, which is the order you want: a key that works means the password
prompt never appears.
