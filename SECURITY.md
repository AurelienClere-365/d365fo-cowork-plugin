# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.x (current) | Yes |

## Reporting a vulnerability

**Do not open a public GitHub Issue for security vulnerabilities.**

Please report security issues by emailing both maintainers directly:

- Aurelien Clere — via [LinkedIn](https://www.linkedin.com/in/aurelien-clere/)
- Laze Janev — via [LinkedIn](https://www.linkedin.com/in/laze-janev/)

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fix (optional)

We will acknowledge receipt within 72 hours and aim to release a fix within 14 days
for confirmed critical issues.

## Security design

This plugin does not handle credentials directly. When using the Azure Connector
(Option C), secrets are managed via:

- **Azure AD Easy Auth** — tenant-level authentication enforced at the Container App
- **OAuthPluginVault** — M365 Copilot token injection (secrets never in source code)
- **Azure Key Vault** — client secret rotation (see README — Rotating the client secret)

The `azure-pipelines.yml` uses a variable group (`d365fo-cowork-secrets`) stored in
Azure DevOps, never committed to the repository.