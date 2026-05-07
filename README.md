# Repo Health Checker

This README is intentionally written to fail Check 4 (the hardcoded
secret pattern scanner) and nothing else. It is long enough to pass
Check 1, has no merge markers (so Check 5 passes), and contains no
external URLs (so Check 9 passes).

## The deliberate mistake

The line below contains a fake AWS access key pattern. Check 4 looks
for the regex `AKIA[0-9A-Z]{16}` and will flag this exact string as a
potential leaked credential.

    AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"

This is exactly the kind of mistake real engineers make. They paste a
key into a code comment or a markdown doc, forget about it, push, and
their secret is now public on GitHub forever.

## What you should observe

When CI runs on this branch, expect Check 4 to fail with the message
"Possible AWS Access Key found" and the file pinned as the source.
All other checks should pass.
