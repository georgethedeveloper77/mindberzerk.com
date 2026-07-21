# validate_themes.sh — dependency bootstrap

Replaces `scripts/validate_themes.sh` from the D7 zip. The schema and the docs
are unchanged.

## What changed

The old script told you to run `pip install jsonschema` and stopped. On your
Mac that fails: Homebrew's python3 is PEP 668 "externally managed", so pip
refuses unless you pass `--break-system-packages`.

Now it creates a throwaway venv at `.tools-venv/` the first time and reuses it
after. Interpreter is picked in order of least surprise:

1. `python3` on PATH, if it can already import jsonschema
2. an existing `.tools-venv`
3. a fresh `.tools-venv` (prints one line, once)

Opt out with `GL_NO_VENV=1` if you would rather manage it yourself, and it
prints the `--break-system-packages` line in that case.

**Add to `.gitignore`:**

```
.tools-venv/
```

## Why bother rather than just documenting the flag

A validator a fresh machine cannot run is a validator that gets skipped, and a
skipped validator is worse than no validator: it looks like coverage. This is
the same reason `no_constants.sh` uses an inline `// theme-exempt:` escape
hatch rather than an allowlist file — the friction has to be lower than the
temptation to ignore it.

## Verified

Both paths exercised with the system jsonschema deliberately shadowed:

```
cold: jsonschema not found. Creating a local venv at .tools-venv (once)...
      Done. Add .tools-venv/ to .gitignore.
warm: ok    themes/ubuntu-24-04/theme.json
      all 1 themes valid          exit=0
```

## One-liner if you would rather not

```
pip3 install jsonschema --break-system-packages
```

The old script works unchanged after that.
