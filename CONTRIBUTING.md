# Contributing to D365FO Cowork Plugin

Thank you for your interest in contributing! This plugin helps functional consultants
and developers explore D365FO metadata using natural-language AI prompts.

## Ways to contribute

| Type | What to do |
|---|---|
| Bug report | Open a GitHub Issue using the Bug template |
| Feature request | Open a GitHub Issue using the Feature template |
| New skill | Follow the guide below |
| Improve an example | Edit `EXAMPLES.md` |
| Fix documentation | Edit `README.md` or skill files directly |

---

## Adding a new SKILL

1. **Create the folder** under `skills/`:
   ```
   skills/d365fo-<your-topic>/
   ```

2. **Create `SKILL.md`** with this exact frontmatter:
   ```yaml
   ---
   name: d365fo-<your-topic>
   description: |
     One-line trigger sentence.
     WHEN: "phrase 1", "phrase 2", "phrase 3".
   license: MIT
   metadata:
     version: "1.0"
   ---
   ```
   The `name` value must exactly match the folder name.

3. **Write the skill body** — describe what MCP tools are available and give
   1-3 prompt/response examples in the style of `EXAMPLES.md`.

4. **Register the skill** in `manifest.json`:
   ```json
   "agentSkills": [
     ...
     "skills/d365fo-<your-topic>"
   ]
   ```

5. **Validate locally**:
   ```powershell
   .\package.ps1
   ```
   All checks must show `[PASS]`.

6. **Open a Pull Request** — the GitHub Actions CI will run `package.ps1`
   automatically and block merge if any check fails.

---

## Commit message convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(skill): add d365fo-workflow-types skill
fix(manifest): correct agentSkills path for d365fo-enum-edt
docs(examples): rewrite Requirement 8 for functional consultant
chore(ci): update validate workflow to PowerShell 7
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`

---

## Branch strategy

| Branch | Purpose |
|---|---|
| `main` | Stable — protected, requires PR + CI pass |
| `dev` | Integration branch for work-in-progress |
| `feat/<topic>` | Feature branches — merge to `dev` first |

---

## Pull request checklist

Before opening a PR, confirm:

- [ ] `.\package.ps1` runs with all `[PASS]`
- [ ] New/changed skills have at least one example prompt
- [ ] `manifest.json` is updated if a new skill folder was added
- [ ] No secrets, index files (`.sqlite`), or ZIP artifacts are committed
- [ ] Commit messages follow Conventional Commits

---

## Code of Conduct

Be respectful and constructive. This is a professional tool for D365FO consultants.
Harassment or dismissive behaviour will not be tolerated.