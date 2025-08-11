# DragonShield – Software Versioning & Release Strategy  
*(copy‑paste into your repository’s `docs/` folder or wiki)*

---

## 1. Philosophy & Core Principles  

| Area | Source of Truth |
|------|----------------|
| **Development history** | Git commits + branches |
| **Release versions** | Semantic Versioning 2.0.0 (SemVer) |
| **Human‑readable history** | `CHANGELOG.md` (Keep a Changelog format) |

*No version strings live inside source files.* Git is authoritative for every line of code; SemVer tags are authoritative for every release.

---

## 2. Branch & Commit Playbook  

| Purpose | Branch prefix | Example |
|---------|---------------|---------|
| New feature | `feat/` | `feat/offline-cache` |
| Bug fix | `fix/` | `fix/login-race` |
| Chore / infra | `chore/` | `chore/ci-cache` |
| Hot patch | `hotfix/` | `hotfix/1.2.4-crash` |

**Conventional Commits** syntax (machine-parsable):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples  

```bash
feat(ui): add dark-mode toggle (#142)
fix(auth): handle token refresh race condition (#155)
docs(changelog): prepare release v1.3.0
```

Enable `commitlint` + a Git pre-commit hook so bad messages fail fast.

---

## 3. Applying the Strategy to Every Change  

> For **every logical change**, do all three:

1. **Atomic commit** on its own branch.  
2. **Descriptive message** using Conventional Commits.  
3. **Changelog line** in `[Unreleased]` (see §4).

---

## 4. CHANGELOG.md (Keep a Changelog)  

```markdown
## [Unreleased]
### Added
- New OAuth2 flow (#142)

### Fixed
- Crash on M1 Macs when resuming from sleep (#155)
```

Rules  

* Update **with every PR** that touches end-user behaviour.  
* Before a release, maintainer **consolidates** related bullet points into one clear entry.  
* Never duplicate the same change.

---

## 5. Release Versioning (SemVer 2.0.0)  

| Segment | Bump when… | Example |
|---------|------------|---------|
| `MAJOR` | Breaking API change | `2.0.0` |
| `MINOR` | Back‑compatible feature | `1.4.0` |
| `PATCH` | Back‑compatible fix | `1.4.3` |

### Pre‑release & build metadata  

* Release candidates: `1.4.0‑rc.1`  
* Betas / alphas: `1.4.0‑beta.3+build20250706`  
* Pre‑releases never reach production App Store.

---

## 6. Hotfix / Patch‑Only Workflow  

1. Branch from **`main`** → `hotfix/<version>`  
2. Apply fix, bump **PATCH** only.  
3. Tag & release (`v1.2.4`).  
4. Cherry‑pick hotfix commit back to `develop` (or merge if no divergence).

---

## 7. Release Workflow (Normal)  

1. **Stabilise** `main`.  
2. **Finalise changelog** – move `[Unreleased]` to a dated header:  
   `## [1.3.0] – 2025‑06‑30`.  
3. **Commit**:  
   `git commit -m "docs: prepare release v1.3.0"`  
4. **Tag** (annotated):  
   `git tag -a v1.3.0 -m "Release version 1.3.0"`  
5. **Push**:  
   `git push origin main --follow-tags`

---

## 8. Automation & CI Integration *(recommended)*  

* **CI gate**: fail build if commit message or changelog entry missing (`commitlint`, `changelog-ci`).  
* **semantic-release** (or `standard-version`) can auto‑generate GitHub Release notes & tags from Conventional Commits.  
* A GitHub Actions workflow should: lint → test → archive → notarise → upload `.dmg`.

---

## 9. Why This Beats Manual Versioning  

1. **Fewer merge conflicts** – no stray header comments to edit.  
2. **Zero duplication** – Git tracks code; changelog tracks releases.  
3. **Automation‑friendly** – commit messages drive changelog generation and CI releases.  
4. **Faster onboarding** – new devs recognise SemVer, Conventional Commits, and Keep a Changelog instantly.  
5. **Reliable hotfix path** – emergency patches do not block longer feature development.

---

### Quick‑start Checklist ✔︎  

- [ ] Install `commitlint` & Git hook.  
- [ ] Copy `CHANGELOG.md` template.  
- [ ] Protect `main` branch (PR reviews + passing CI required).  
- [ ] Add GitHub Actions workflow for lint/test/build/tag.  
- [ ] Document this strategy in `CONTRIBUTING.md` and share with the team.

*Version 2025‑07‑06*

