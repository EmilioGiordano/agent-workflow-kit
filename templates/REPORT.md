<!-- REPORT template. The orchestrator keeps one REPORT.md (untracked, never committed) per work session at the root of the main checkout and updates it after every event, not at the end (LESSONS L9). Newest entries first inside each section. Branch decisions go to the tracked decisions log (AGENTS.md decisions_log), not here. -->
# REPORT: <session or date>

## Pending decisions (the user decides; work on these lines is stopped)
- [ ] <decision needed> — options: <a / b>; blocked: <branches>; since <time>.

## Status
| Branch | PR | Review | Gate after merging the default branch | CI | UI validation | State |
|---|---|---|---|---|---|---|
| `<type>/<topic>` | #<n> | PASS r<k> | pass | green | pass (evidence) | merged / ready / in review / blocked |

## Merged
- `<branch>` -> #<n>, merge commit `<sha>`. Evidence: <screenshots, logs, CI link>.

## Review rounds
- `<branch>` r<k>: FAIL — <severity: finding> -> <fixed in sha | argued | deliberate>.

## Incidents
- <time> <what happened, impact, what was done, follow-up>.

## Decisions taken on the way
- `<branch>`: <decision and its reason, one line; the details live in the PR>.

## Needs a human
- <what only the user can check, per branch>
