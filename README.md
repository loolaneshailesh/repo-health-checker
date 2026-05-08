# Repo Health Checker

[![Repo Health Check](https://github.com/loolaneshailesh/repo-health-checker/actions/workflows/check.yml/badge.svg)](https://github.com/loolaneshailesh/repo-health-checker/actions/workflows/check.yml)

> **PACE 2026 — Week 1 Mini Project** by *laas*
>
> A self-validating GitHub repository. Every push runs an automated health
> audit in the cloud. The badge above turns green when the repo is healthy
> and red the moment any rule is broken — just like a real CI gate.

---

## What this project is

This repo is a **CI gatekeeper for itself**. It contains a shell script
(`check.sh`) that performs **9 quality checks** on every push, a GitHub
Actions workflow that runs the script in the cloud, and a scoring system
that grades the repo from 0-100 with a letter grade.

If any required check fails, the script exits with code `1`, which makes
GitHub mark the run as failed and turn the CI badge red. When everything
passes, the badge stays green.

---

## The 9 checks

| #   | Check                                  | What it does                                                                                          | Why it matters                                                                                              |
| --- | -------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 1   | **README sanity**                      | `README.md` must exist and have **>10 lines**.                                                        | A repo without docs is a black box. Empty READMEs are a red flag in code review.                            |
| 2   | **.gitignore present**                 | `.gitignore` must exist and be non-empty.                                                             | Without it, junk files (build outputs, IDE configs, secrets) leak into commits.                             |
| 3   | **No secret files**                    | No tracked file matches `.env`, `*.key`, `*.pem`, `id_rsa`, `*.p12`, `credentials.json`.              | These files contain credentials. Committing one is a real security incident.                                |
| 4   | **No hardcoded secrets** *(custom)*    | Regex-scans every text file for AWS keys (`AKIA...`), GitHub tokens (`ghp_...`), and `password = "..."` patterns. | A `.env` block won't help if someone pasted the key directly into source.                                   |
| 5   | **No merge conflict markers** *(custom)* | Looks for `<<<<<<<`, `=======`, `>>>>>>>` lines that Git inserts during a botched merge.              | These slip into commits often and make code unrunnable.                                                     |
| 6   | **No leftover debug code** *(WARN)*    | Looks for `console.log`, `debugger;`, and `TODO: REMOVE` in source files.                              | Debug statements shipped to production are noisy at best, security-leaky at worst.                          |
| 7   | **Commit message quality**             | Last 10 non-merge commits must each have **>5 words**.                                                | "fix" or "update" tells future-you nothing during incident response.                                        |
| 8   | **No oversized files** *(custom)*      | No tracked file may exceed **5 MB**.                                                                  | Git is bad at binaries. Big files bloat clones forever — even after you delete them.                        |
| 9   | **No dead links** *(custom)*           | Extracts every `http(s)://` URL from `.md` files and verifies each one responds.                      | Documentation rots. Dead links make the project look abandoned.                                             |

Checks marked *(custom)* go beyond the assignment's example list — they
mirror what real DevOps teams run.

---

## Bonus features

This script ships with three professional touches:

### 1. Repo Health Score
After all checks run, the script computes a score out of 100 and a letter
grade (A+, A, B, C, D, F). Failures cap the base; warnings deduct 2 points
each (capped at 10). The score is printed in a colored health-report box.

### 2. Auto-fix mode
Run `./check.sh --fix` locally and the script will *offer to repair* common
problems interactively — missing README, missing/empty `.gitignore`,
tracked secret files. Each fix asks before applying. The auto-fix is
completely invisible in CI (it requires the `--fix` flag, which CI never
passes), so the gate behaviour is unchanged.

### 3. GitHub Actions diagnostic report
When running in CI, the script writes a markdown summary to
`$GITHUB_STEP_SUMMARY` so the workflow run page on GitHub shows a polished
report at the top with **per-failure remediation hints**. For each
failure, the report explains exactly how to fix it.

---

## How it works (architecture)

```
┌────────────┐    git push     ┌─────────────────────┐
│ Your code  │ ──────────────▶ │ GitHub repository   │
└────────────┘                 └──────────┬──────────┘
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │ GitHub Actions reads │
                              │   check.yml          │
                              └──────────┬───────────┘
                                          │ spins up
                                          ▼
                              ┌──────────────────────┐
                              │ Ubuntu cloud runner  │
                              └──────────┬───────────┘
                                          │ runs
                                          ▼
                              ┌──────────────────────┐
                              │ ./check.sh           │
                              │  • 9 checks          │
                              │  • health score      │
                              │  • diagnostic report │
                              └──────────┬───────────┘
                                          │
                          exit 0 ─────────┼───────── exit 1
                              │                          │
                              ▼                          ▼
                        ✅ green badge            ❌ red badge
```

The runner is a fresh virtual machine that lives only for this run.
Nothing local needs to be set up.

---

## Files in this repo

| File                              | Purpose                                                              |
| --------------------------------- | -------------------------------------------------------------------- |
| `check.sh`                        | The shell script with all 9 checks, scoring, auto-fix, diagnostic.   |
| `.github/workflows/check.yml`     | Tells GitHub Actions when and how to run `check.sh`.                 |
| `.gitignore`                      | Lists file types Git must never track.                               |
| `README.md`                       | This file.                                                           |

---

## How to run it locally

```bash
chmod +x check.sh
./check.sh                  # report-only mode (same as CI)
./check.sh --fix            # interactive mode: offers to fix problems
```

Anything other than `0` exit code means at least one check failed.

---

## Demo: breaking on purpose to verify the gate

Real CI is only credible if it goes red when something breaks. To
demonstrate that, you can deliberately trigger any failure:

1. **Delete README.md** → Check 1 fails.
2. **Add a fake AWS key** (a string starting with `AKIA` followed by 16 uppercase chars) to any file → Check 4 fails.
3. **Add lines starting with `<<<<<<<` to any file** → Check 5 fails.
4. **Commit a 6 MB binary** → Check 8 fails.
5. **Use a 1-word commit message** → Check 7 fails.

Push the change, watch the badge turn red, fix the change, push again,
watch it turn green. That round-trip is the core CI workflow.

---

## Branching rules

- The `main` branch is **protected**: no direct pushes allowed.
- All work happens on feature branches and merges via **pull request**.
- A PR cannot merge until the Repo Health Check is green.

This mirrors how every real engineering team operates.

---

## Author

Built by **laas** for PACE 2026 — Week 1 Mini Project.
