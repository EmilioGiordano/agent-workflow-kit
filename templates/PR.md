<!-- PR body template. The orchestrator fills it from the TASK, the implementer report and the review. Title: in the project's commit format (AGENTS.md commit_format). No attribution lines unless AGENTS.md allows them. A project PR template (.github/PULL_REQUEST_TEMPLATE*) wins: fill its sections with this content. -->
## What
<One paragraph: the user-visible change.>

## Decisions
- <choice> — rejected: <alternative>, because <reason>.

## Not done
- <what is knowingly left out, and where it is tracked>

## Covers
<requirement ids or issue numbers>

## Verification
- Review: PASS after <n> rounds (<reviewer verdict summary>).
- Extra reviews: <name: result, or n/a>.
- Gate after merging `<default-branch>`: <pass, with date and commit>.
- CI: <green on ... | cannot run (ci: <value>): gate re-run on the merged result, <pass, commit>>.
- UI validation (<mode>): <steps run and result; evidence links: screenshots, request/response logs, transcripts>. Or: `n/a — <reason>`.

## New dependencies
<name, purpose, alternative rejected, licence — or "none">

## Needs a human
- [ ] <what only a person can check: look, feel, a real screen reader, a real device>
