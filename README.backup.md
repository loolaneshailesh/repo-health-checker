# Repo Health Checker

[![Repo Health Check](https://github.com/loolaneshailesh/repo-health-checker/actions/workflows/check.yml/badge.svg)](https://github.com/loolaneshailesh/repo-health-checker/actions/workflows/check.yml)

> **PACE 2026 — Week 1 Mini Project**
> A self-validating GitHub repository. Every push runs an automated health
> audit in the cloud. The badge above turns green when the repo is healthy
> and red the moment any rule is broken — just like a real CI gate.

---

## What this project is

This repo is a **CI gatekeeper for itself**. It contains:

1. A shell script (`check.sh`) that runs **9 quality checks** on the repo.
2. A GitHub Actions workflow (`.github/workflows/check.yml`) that runs the
   script automatically on **every push and every pull request**.
3. A scoring system that calculates a **Repo Health Score (0-100)** with a
   letter grade (A+, A, B, C, D, F).

If any required check fails, the script exits with code `1`, which makes
GitHub mark the run as **failed** and turn the CI badge red.

---

## The 9 checks (and why each one matters)

| #   | Check                                  | What it does                                                                                          | Why engineers care                                                                                          |
| --- | -------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 1   | **README sanity**                      | `README.md` must exist and have **>10 lines**.                                                        | A repo without docs is a black box. Empty/one-line READMEs are a red flag in code review.                   |
| 2   | **.gitignore present**                 | `.gitignore` must exist and be non-empty.                                                             | Without `.gitignore`, junk files (build outputs, IDE configs, secrets) leak into commits.                   |
| 3   | **No secret files**                    | No tracked file matches `.env`, `*.key`, `*.pem`, `id_rsa`, `*.p12`, `credentials.json`.              | These files contain credentials. Committing one is a real security incident.                                |
| 4   | **No hardcoded secrets** *(custom)*    | Regex-scans every text file for AWS keys (`AKIA...`), GitHub tokens (`ghp_...`), and `password = "..."` patterns. | A `.env` block won't help if someone pasted the key directly into source code. This is what TruffleHog does. |
| 5   | **No merge conflict markers** *(custom)* | Searches for `<<<<<<<`, `=======`, `>>>>>>>` lines that Git inserts during a botched merge.           | These slip into commits often. They make code unrunnable.                                                   |
| 6   | **No leftover debug code** *(custom, WARN)* | Looks for `console.log`, `debugger;`, and `TODO: REMOVE` in source files.                              | Debug statements shipped to production are noisy at best, security-leaky at worst.                          |
| 7   | **Commit message quality**             | Last 10 non-merge commits must each have **>5 words**.                                                | "fix" or "update" tells future-you nothing. Good messages save hours during incident response.              |
| 8   | **No oversized files** *(custom)*      | No tracked file may exceed **5 MB**.                                                                  | Git is bad at binaries. Big files bloat clones forever — even if you delete them later.                     |
| 9   | **No dead links** *(custom)*           | Extracts every `http(s)://` URL from `.md` files and verifies each one responds.                      | Documentation rots. Dead links in your README make the project look abandoned.                              |

Checks marked *(custom)* go beyond the assignment's example list — they
mirror the kind of checks real DevOps teams run.

---

## How it works (the architecture)

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
                              │  (free, ephemeral)   │
                              └──────────┬───────────┘
                                          │ runs
                                          ▼
                              ┌──────────────────────┐
                              │ ./check.sh           │
                              │  • 9 checks          │
                              │  • prints score      │
                              └──────────┬───────────┘
                                          │
                          exit 0 ─────────┼───────── exit 1
                              │                          │
                              ▼                          ▼
                        ✅ green badge            ❌ red badge
```

The runner is a fresh virtual machine that exists *only* for this run.
Nothing local needs to be set up.

---

## Files in this repo

| File                              | Purpose                                                              |
| --------------------------------- | -------------------------------------------------------------------- |
| `check.sh`                        | The shell script with all 9 checks and the scoring system.           |
| `.github/workflows/check.yml`     | Tells GitHub Actions when and how to run `check.sh`.                 |
| `.gitignore`                      | Lists file types Git must never track (secrets, builds, OS clutter). |
| `README.md`                       | This file.                                                           |

---

## Reading the output

When the runner finishes, the log looks like this:

```
╔══════════════════════════════════════════════════════════╗
║         REPO HEALTH CHECKER  —  PACE 2026 Week 1         ║
╚══════════════════════════════════════════════════════════╝

▶ Check 1: README.md exists and has substance
  ✔ PASS  README.md has 87 lines
▶ Check 2: .gitignore is present
  ✔ PASS  .gitignore present and non-empty
...
╔══════════════════════════════════════════════════════════╗
║                    HEALTH REPORT                         ║
╚══════════════════════════════════════════════════════════╝
  Checks passed   : 9 / 9
  Checks failed   : 0
  Warnings        : 0
  Health Score    : 100/100  [A+]

✔ CI GATE: PASSED — repo is healthy. Push approved.
```

If anything fails, the script prints **why**, exits with code 1, and the
badge turns red.

---

## How to run it locally (optional)

```bash
chmod +x check.sh
./check.sh
echo "Exit code: $?"
```

Anything other than `0` means at least one check failed.

---

## How to break it on purpose (and watch CI go red)

To prove the gate works, try any of these on a feature branch:

1. **Delete README.md** → Check 1 fails.
2. **Add a fake AWS key** (a string starting with `AKIA` followed by 16 uppercase letters/digits) to any file → Check 4 fails.
3. **Commit a 6 MB binary file** → Check 8 fails.
4. **Make a commit with message `wip`** → Check 7 fails.
5. **Add a `<<<<<<< HEAD` line** to any file → Check 5 fails.

Push the change, watch the badge turn red, fix the change, push again,
watch it turn green. That round-trip is the whole point of CI.

---

## Branching rules

- The `main` branch is **protected**: no direct pushes allowed.
- All work happens on feature branches and merges via **pull request**.
- A PR cannot merge until the Repo Health Check is green.

This mirrors how every real engineering team operates.

---

## Author

Built by **laas** for PACE 2026 — Week 1.
