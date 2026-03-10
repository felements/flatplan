# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes    |

Only the latest minor release in the current major version receives security fixes.

## Reporting a Vulnerability

**Please do NOT open a public issue for security vulnerabilities.**

If you discover a security issue, report it privately so we can address it before it is disclosed publicly:

1. Use GitHub's [security advisory](https://github.com/felements/flatplan/security/advisories/new) feature.

### What to include

- A clear description of the vulnerability and its potential impact.
- Steps to reproduce or a proof-of-concept.
- Affected version(s).
- Any suggested mitigations, if you have them.

## Response Timeline

| Action | Target time |
|--------|-------------|
| Acknowledgement of your report | Within 48 hours |
| Triage & severity assessment | Within 5 business days |
| Fix or mitigation release | Depends on severity |

We will keep you informed throughout the process and publicly credit you in the release notes (unless you prefer to remain anonymous).

## Scope

Flatplan is a **local-only desktop application**. It does not run a server, does not transmit data over a network, and does not handle authentication tokens. The primary security surface is:

- **File I/O** — YAML parsing and writing to the user's local filesystem.
- **Third-party dependencies** — vulnerabilities in Flutter/Dart packages listed in `pubspec.yaml`.
- **URL launching** — `url_launcher` usage in the Settings view.

Out-of-scope: social engineering, physical access attacks, or vulnerabilities in the user's operating system.
