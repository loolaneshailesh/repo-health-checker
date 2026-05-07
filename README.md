# Repo Health Checker

This README intentionally contains leftover merge conflict markers to
trigger Check 5 in isolation. It is long enough for Check 1, contains
no AWS keys (Check 4 stays clean), and has no external URLs (so
Check 9 has nothing to test).

## The deliberate mistake

Below is a section that was edited on two branches at once. Someone
ran `git merge`, saw the conflict, but forgot to resolve and clean up
the markers before committing:

<<<<<<< HEAD
This sentence is the version that lived on main.
=======
This sentence is the conflicting version from a feature branch.
>>>>>>> feat/conflicting-edit

## What you should observe

When CI runs on this branch, Check 5 will fail with the message
"Merge conflict markers found in files above" and `README.md` pinned
as the offender. Every other check should pass cleanly.
