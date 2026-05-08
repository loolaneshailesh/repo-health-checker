# Repo Health Checker

This README is intentionally broken to demonstrate the CI catching real problems.
When you swap this in as your README and push, watch which checks fail.

## Embedded test failures

Below are deliberately bad bits that should trip multiple checks:

1. A fake AWS access key (Check 4 should catch this):
   `AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"`

2. A leftover merge conflict marker (Check 5 should catch this):

<<<<<<< HEAD
This is the original line that was on main.
=======
This is the conflicting change from the feature branch.
>>>>>>> feat/conflicting-branch

3. A dead link (Check 9 should catch this):
   See [the docs](https://this-domain-definitely-does-not-exist-12345.com/page) for details.

That's it — the README is otherwise short and broken on purpose.
