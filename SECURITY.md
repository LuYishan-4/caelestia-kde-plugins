# Security

The Caelestia plugin store distributes third-party code that runs on users' machines inside the desktop shell, with the user's privileges. Treat the store accordingly.

## What we do

- Source-only policy. Compiled binaries and archives are rejected by CI.
- Human review. Every change to `plugins/` is reviewed by a maintainer before merge.
- Structured validation. All manifests must conform to `schemas/plugin.schema.json`.

## What you should know as a user

Only install plugins you trust. Review a plugin's source before installing it - the shell does not sandbox plugins.

## Reporting a vulnerability

- In a plugin: open a GitHub issue and mention the plugin id, or contact a maintainer privately for sensitive issues.
- In the store's infrastructure (validation scripts, CI, schemas): report privately to the maintainers; do not open a public issue.
