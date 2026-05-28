# Privacy Policy — D365FO Cowork Plugin

**Last updated: 2026**

## What data this plugin processes

The D365FO Cowork Plugin provides AI assistant skills that query a locally-built
SQLite index of Microsoft Dynamics 365 Finance & Operations metadata (table names,
field names, class names, labels, security artefact names, etc.).

- **No personal data is collected, stored, or transmitted by this plugin.**
- The metadata index contains only schema information from your D365FO environment —
  it does not contain business transactions, user data, or confidential records.
- When using the Azure Connector (Option C), queries are routed through your own
  Azure Container App, hosted in your own Azure subscription. The authors have no
  access to your deployment.

## What the plugin does NOT do

- It does not transmit data to any third-party service other than the AI assistant
  you are already using (GitHub Copilot, Claude, etc.).
- It does not log queries or responses.
- It does not share metadata outside your organisation's Azure tenant.

## Third-party AI assistants

When you use this plugin with an AI assistant (GitHub Copilot, Claude Code, Cursor,
etc.), your queries are subject to that assistant's own privacy policy. The plugin
authors have no control over, or access to, those services.

## Contact

For privacy concerns, open an issue at
https://github.com/AurelienClere-365/d365fo-cowork-plugin/issues