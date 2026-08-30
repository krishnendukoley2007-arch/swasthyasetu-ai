# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.4.x   | ✅        |
| < 1.4   | ❌        |

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, report privately via GitHub's [Security Advisories](../../security/advisories/new) or contact the maintainer directly.

Please include:
- Affected version / build
- Steps to reproduce
- Potential impact

We aim to acknowledge reports within **72 hours** and provide a fix or mitigation plan within **14 days**.

## Security Notes for This Project

- **No API keys are committed.** The Gemini key is supplied via `--dart-define` or entered at runtime.
- **Health data stays on-device** (local SQLite) unless the user explicitly enables sync.
- **Location consent is OFF by default.**
- This is a screening-support tool, not a medical device — see the disclaimer in `README.md`.
